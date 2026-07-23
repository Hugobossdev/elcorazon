<?php

namespace App\Services\Order;

use App\Models\MenuItem;
use App\Models\Order;
use App\Models\Promotion;
use App\Models\PromotionUsage;
use App\Models\User;
use App\Services\Delivery\DeliveryFeeService;
use App\Services\Notifications\NotificationService;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpKernel\Exception\HttpException;

/**
 * Logique métier des commandes (création, transitions, annulation).
 *
 * Toute la logique transactionnelle est centralisée ici afin de garder des
 * contrôleurs minces (Controllers → Services). Les totaux sont systématiquement
 * recalculés côté serveur : le client ne fournit jamais de montant.
 */
class OrderService
{
    public function __construct(
        private readonly DeliveryFeeService $deliveryFees,
        private readonly NotificationService $notifications,
    ) {}

    /**
     * Crée une commande à partir de données déjà validées (StoreOrderRequest).
     *
     * @param  array<string, mixed>  $data
     */
    public function create(User $user, array $data): Order
    {
        return DB::transaction(function () use ($user, $data): Order {
            $menuItems = MenuItem::query()
                ->whereIn('id', collect($data['items'])->pluck('menu_item_id'))
                ->get()
                ->keyBy('id');

            [$subtotal, $lines] = $this->buildLines($data['items'], $menuItems);

            $deliveryFee = $this->deliveryFees->compute(
                subtotal: $subtotal,
                latitude: isset($data['delivery_latitude']) ? (float) $data['delivery_latitude'] : null,
                longitude: isset($data['delivery_longitude']) ? (float) $data['delivery_longitude'] : null,
                isVip: $this->userIsVip($user),
            )['fee'];

            [$discount, $promotion, $deliveryFee] = $this->applyPromo(
                $data['promo_code'] ?? null,
                $subtotal,
                $deliveryFee,
            );

            $total = max(0, $subtotal + $deliveryFee - $discount);

            $order = Order::create([
                'user_id' => $user->id,
                'status' => 'pending',
                'subtotal' => round($subtotal, 2),
                'delivery_fee' => round($deliveryFee, 2),
                'discount' => round($discount, 2),
                'total' => round($total, 2),
                'delivery_address' => $data['delivery_address'],
                'delivery_latitude' => $data['delivery_latitude'] ?? null,
                'delivery_longitude' => $data['delivery_longitude'] ?? null,
                'delivery_notes' => $data['delivery_notes'] ?? null,
                'special_instructions' => $data['special_instructions'] ?? null,
                'payment_method' => $data['payment_method'],
                'payment_status' => 'pending',
                'promo_code' => $promotion?->promo_code,
                'order_time' => now(),
                'is_group_order' => $data['is_group_order'] ?? false,
                'group_id' => $data['group_id'] ?? null,
            ]);

            $order->items()->createMany($lines);
            $order->statusUpdates()->create([
                'status' => 'pending',
                'updated_by' => $user->id,
                'notes' => 'Commande créée',
            ]);

            if ($promotion !== null && $discount > 0) {
                $promotion->increment('used_count');
                PromotionUsage::create([
                    'promotion_id' => $promotion->id,
                    'user_id' => $user->id,
                    'order_id' => $order->id,
                    'discount_amount' => $discount,
                ]);
            }

            return $order;
        });
    }

    /**
     * Applique une transition de statut et notifie le client.
     */
    public function changeStatus(Order $order, string $status, ?string $notes, User $actor): Order
    {
        DB::transaction(function () use ($order, $status, $notes, $actor): void {
            $order->update([
                'status' => $status,
                'delivered_at' => $status === 'delivered' ? now() : $order->delivered_at,
            ]);

            $order->statusUpdates()->create([
                'status' => $status,
                'updated_by' => $actor->id,
                'notes' => $notes,
            ]);
        });

        $this->notifications->notify(
            userId: $order->user_id,
            title: 'Mise à jour de votre commande',
            message: "Votre commande est désormais : {$status}.",
            type: 'order_update',
            data: ['order_id' => $order->id, 'status' => $status],
        );

        return $order->fresh('statusUpdates');
    }

    /**
     * Annule une commande si son statut le permet encore.
     */
    public function cancel(Order $order, ?string $reason, User $actor): Order
    {
        if (in_array($order->status, ['delivered', 'cancelled'], true)) {
            throw new HttpException(422, 'Cette commande ne peut plus être annulée.');
        }

        DB::transaction(function () use ($order, $reason, $actor): void {
            $order->update(['status' => 'cancelled']);
            $order->statusUpdates()->create([
                'status' => 'cancelled',
                'updated_by' => $actor->id,
                'notes' => $reason ?? "Annulée par l'utilisateur",
            ]);
        });

        return $order->fresh('statusUpdates');
    }

    /**
     * Construit les lignes de commande et le sous-total à partir du catalogue.
     *
     * @param  array<int, array<string, mixed>>  $items
     * @param  Collection<string, MenuItem>  $menuItems
     * @return array{0: float, 1: array<int, array<string, mixed>>}
     */
    private function buildLines(array $items, $menuItems): array
    {
        $subtotal = 0.0;
        $lines = [];

        foreach ($items as $line) {
            $menuItem = $menuItems[$line['menu_item_id']];
            $unitPrice = (float) $menuItem->price;
            $quantity = (int) $line['quantity'];
            $lineTotal = $unitPrice * $quantity;
            $subtotal += $lineTotal;

            $lines[] = [
                'menu_item_id' => $menuItem->id,
                'menu_item_name' => $menuItem->name,
                'name' => $menuItem->name,
                'category' => optional($menuItem->category)->name ?? 'unknown',
                'menu_item_image' => $menuItem->image_url,
                'quantity' => $quantity,
                'unit_price' => $unitPrice,
                'total_price' => $lineTotal,
                'customizations' => $line['customizations'] ?? [],
                'notes' => $line['notes'] ?? null,
            ];
        }

        return [$subtotal, $lines];
    }

    /**
     * Applique un éventuel code promo. Un code invalide est simplement ignoré.
     *
     * @return array{0: float, 1: ?Promotion, 2: float} [remise, promo, fraisLivraison]
     */
    private function applyPromo(?string $code, float $subtotal, float $deliveryFee): array
    {
        if (empty($code)) {
            return [0.0, null, $deliveryFee];
        }

        $promotion = Promotion::where('promo_code', $code)->first();
        $computed = $promotion?->computeDiscount($subtotal);

        if ($computed === null) {
            return [0.0, null, $deliveryFee];
        }

        if ($promotion->discount_type === 'free_delivery') {
            $deliveryFee = 0.0;
        }

        return [$computed, $promotion, $deliveryFee];
    }

    private function userIsVip(User $user): bool
    {
        return $user->subscriptions()
            ->where('subscription_type', 'vip')
            ->where('status', 'active')
            ->exists();
    }
}

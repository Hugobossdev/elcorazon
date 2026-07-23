<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ActiveDelivery;
use App\Models\DeliveryLocation;
use App\Models\Order;
use App\Services\Notifications\NotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

/**
 * Actions réservées aux livreurs (rôle `delivery`).
 */
class DeliveryController extends Controller
{
    public function __construct(private readonly NotificationService $notifications)
    {
    }

    /** Commandes prêtes à être prises en charge (non assignées). */
    public function availableOrders(Request $request): JsonResponse
    {
        $orders = Order::query()
            ->whereNull('delivery_person_id')
            ->whereIn('status', ['ready', 'confirmed', 'preparing'])
            ->with('items')
            ->latest('created_at')
            ->paginate($request->integer('per_page', 20));

        return response()->json($orders);
    }

    /** Livraisons du livreur courant. */
    public function myDeliveries(Request $request): JsonResponse
    {
        $deliveries = ActiveDelivery::query()
            ->where('delivery_id', $request->user()->id)
            ->with('order.items')
            ->latest('created_at')
            ->paginate($request->integer('per_page', 20));

        return response()->json($deliveries);
    }

    /** Le livreur accepte une commande : assignation + active_delivery. */
    public function acceptOrder(Request $request, Order $order): JsonResponse
    {
        $driver = $request->user();

        if ($order->delivery_person_id !== null) {
            return response()->json(['message' => 'Commande déjà assignée.'], 409);
        }

        $delivery = DB::transaction(function () use ($order, $driver) {
            $order->update([
                'delivery_person_id' => $driver->id,
                'status' => 'picked_up',
            ]);

            $order->statusUpdates()->create([
                'status' => 'picked_up',
                'updated_by' => $driver->id,
                'notes' => 'Prise en charge par le livreur',
            ]);

            $driver->driver?->update(['status' => 'on_delivery', 'is_available' => false]);

            return ActiveDelivery::create([
                'delivery_id' => $driver->id,
                'order_id' => $order->id,
                'status' => 'accepted',
                'accepted_at' => now(),
            ]);
        });

        $this->notifications->notify(
            userId: $order->user_id,
            title: 'Livreur en route',
            message: 'Un livreur a pris en charge votre commande.',
            type: 'order_update',
            data: ['order_id' => $order->id],
            fromUserId: $driver->id,
        );

        return response()->json(['data' => $delivery->load('order')], 201);
    }

    /** Fait progresser le statut d'une livraison active. */
    public function updateDeliveryStatus(Request $request, ActiveDelivery $delivery): JsonResponse
    {
        abort_if($delivery->delivery_id !== $request->user()->id, 403, 'Accès refusé.');

        $data = $request->validate([
            'status' => ['required', Rule::in(['accepted', 'picked_up', 'on_the_way', 'delivered'])],
        ]);

        $timestampField = match ($data['status']) {
            'picked_up' => 'picked_up_at',
            'on_the_way' => 'started_delivery_at',
            'delivered' => 'delivered_at',
            default => null,
        };

        DB::transaction(function () use ($delivery, $data, $timestampField, $request) {
            $delivery->update(array_filter([
                'status' => $data['status'],
                $timestampField => $timestampField ? now() : null,
            ]));

            $delivery->order?->update(['status' => $data['status']]);
            $delivery->order?->statusUpdates()->create([
                'status' => $data['status'],
                'updated_by' => $request->user()->id,
            ]);

            if ($data['status'] === 'delivered') {
                $driver = $request->user()->driver;
                $driver?->update(['status' => 'available', 'is_available' => true]);
                $driver?->increment('completed_deliveries');
                $driver?->increment('total_deliveries');
                $delivery->order?->update(['delivered_at' => now()]);
            }
        });

        return response()->json(['data' => $delivery->fresh('order')]);
    }

    /** Publie la position temps réel du livreur pour une commande. */
    public function updateLocation(Request $request): JsonResponse
    {
        $driver = $request->user();

        $data = $request->validate([
            'order_id' => ['required', 'uuid', 'exists:orders,id'],
            'latitude' => ['required', 'numeric'],
            'longitude' => ['required', 'numeric'],
            'accuracy' => ['nullable', 'numeric'],
            'speed' => ['nullable', 'numeric'],
            'heading' => ['nullable', 'numeric'],
            'altitude' => ['nullable', 'numeric'],
        ]);

        $location = DeliveryLocation::create([
            'order_id' => $data['order_id'],
            'delivery_id' => $driver->id,
            'latitude' => $data['latitude'],
            'longitude' => $data['longitude'],
            'accuracy' => $data['accuracy'] ?? null,
            'speed' => $data['speed'] ?? null,
            'heading' => $data['heading'] ?? null,
            'altitude' => $data['altitude'] ?? null,
            'timestamp' => now(),
        ]);

        $driver->driver?->update([
            'current_location_latitude' => $data['latitude'],
            'current_location_longitude' => $data['longitude'],
            'last_location_update' => now(),
        ]);

        return response()->json(['data' => $location], 201);
    }

    /** Bascule en ligne / hors ligne. */
    public function toggleAvailability(Request $request): JsonResponse
    {
        $data = $request->validate([
            'is_available' => ['required', 'boolean'],
        ]);

        $driver = $request->user()->driver;
        abort_if($driver === null, 404, 'Profil livreur introuvable.');

        $driver->update([
            'is_available' => $data['is_available'],
            'status' => $data['is_available'] ? 'available' : 'offline',
            'last_online' => now(),
        ]);

        $request->user()->update(['is_online' => $data['is_available']]);

        return response()->json(['data' => $driver]);
    }
}

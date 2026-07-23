<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Services\Notifications\NotificationService;
use App\Services\Payment\PaydunyaService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

class PaymentController extends Controller
{
    public function __construct(
        private readonly PaydunyaService $paydunya,
        private readonly NotificationService $notifications,
    ) {
    }

    /** Initialise un paiement PayDunya pour une commande et renvoie l'URL de checkout. */
    public function initiatePaydunya(Request $request, Order $order): JsonResponse
    {
        abort_unless($order->user_id === $request->user()->id, 403, 'Accès refusé.');

        $status = $this->paydunya->status();
        if (! $status['configured']) {
            return response()->json([
                'message' => 'Passerelle de paiement non configurée.',
                'missing' => $status['missing'],
            ], 503);
        }

        if ($order->payment_status === 'completed') {
            return response()->json(['message' => 'Commande déjà payée.'], 422);
        }

        $result = $this->paydunya->createInvoice($order);

        if (! $result['success']) {
            Log::warning('Échec création facture PayDunya', ['order' => $order->id, 'raw' => $result['raw']]);

            return response()->json(['message' => 'Impossible de créer la facture de paiement.'], 502);
        }

        $order->update([
            'payment_status' => 'processing',
            'payment_transaction_id' => $result['token'],
        ]);

        return response()->json([
            'data' => [
                'checkout_url' => $result['checkout_url'],
                'token' => $result['token'],
            ],
        ]);
    }

    /**
     * Webhook PayDunya (IPN). Route publique : la véracité est vérifiée en
     * reconfirmant la facture auprès de PayDunya avant toute mise à jour.
     */
    public function paydunyaWebhook(Request $request): JsonResponse
    {
        $token = $request->input('token') ?? $request->input('data.token');

        if (empty($token)) {
            return response()->json(['message' => 'Token manquant.'], 422);
        }

        $confirmation = $this->paydunya->confirmInvoice($token);
        $orderId = $confirmation['order_id'];

        if ($orderId === null) {
            return response()->json(['message' => 'Commande introuvable dans la facture.'], 422);
        }

        $order = Order::find($orderId);
        if ($order === null) {
            return response()->json(['message' => 'Commande introuvable.'], 404);
        }

        $newStatus = match ($confirmation['status']) {
            'completed' => 'completed',
            'cancelled' => 'failed',
            default => 'pending',
        };

        $order->update(['payment_status' => $newStatus]);

        if ($newStatus === 'completed') {
            $order->update(['status' => $order->status === 'pending' ? 'confirmed' : $order->status]);
            $this->notifications->notify(
                userId: $order->user_id,
                title: 'Paiement confirmé',
                message: 'Votre paiement a bien été reçu.',
                type: 'success',
                data: ['order_id' => $order->id],
            );
        }

        return response()->json(['message' => 'Webhook traité.', 'payment_status' => $newStatus]);
    }
}

<?php

namespace App\Services\Payment;

use App\Models\Order;
use Illuminate\Http\Client\PendingRequest;
use Illuminate\Support\Facades\Http;

/**
 * Intégration PayDunya (Checkout Invoice API).
 *
 * Doc : https://paydunya.com/developers
 * Le montant est exprimé en XOF (FCFA), sans décimales.
 */
class PaydunyaService
{
    private const LIVE_BASE = 'https://app.paydunya.com/api/v1';
    private const SANDBOX_BASE = 'https://app.paydunya.com/sandbox-api/v1';

    /** @return array{configured: bool, missing: array<int, string>} */
    public function status(): array
    {
        $missing = [];
        foreach (['master_key', 'private_key', 'token'] as $k) {
            if (empty(config("services.paydunya.$k"))) {
                $missing[] = $k;
            }
        }

        return ['configured' => $missing === [], 'missing' => $missing];
    }

    private function client(): PendingRequest
    {
        $sandbox = (bool) config('services.paydunya.sandbox');
        $base = $sandbox ? self::SANDBOX_BASE : self::LIVE_BASE;

        return Http::baseUrl($base)
            ->withHeaders([
                'PAYDUNYA-MASTER-KEY' => (string) config('services.paydunya.master_key'),
                'PAYDUNYA-PRIVATE-KEY' => (string) config('services.paydunya.private_key'),
                'PAYDUNYA-TOKEN' => (string) config('services.paydunya.token'),
            ])
            ->acceptJson()
            ->timeout(30);
    }

    /**
     * Crée une facture de paiement pour une commande et retourne l'URL de
     * redirection PayDunya ainsi que le token de facture.
     *
     * @return array{success: bool, token: ?string, checkout_url: ?string, raw: array<string, mixed>}
     */
    public function createInvoice(Order $order): array
    {
        $response = $this->client()
            ->post('/checkout-invoice/create', [
                'invoice' => [
                    'total_amount' => (int) round((float) $order->total),
                    'description' => "Commande El Corazon #{$order->id}",
                ],
                'store' => [
                    'name' => (string) config('services.paydunya.store_name'),
                ],
                'actions' => [
                    'cancel_url' => (string) config('services.paydunya.cancel_url'),
                    'return_url' => (string) config('services.paydunya.return_url'),
                    'callback_url' => (string) config('services.paydunya.callback_url'),
                ],
                'custom_data' => [
                    'order_id' => $order->id,
                    'user_id' => $order->user_id,
                ],
            ])
            ->json();

        $success = ($response['response_code'] ?? null) === '00';

        return [
            'success' => $success,
            'token' => $response['token'] ?? null,
            'checkout_url' => $response['response_text'] ?? ($response['checkout_url'] ?? null),
            'raw' => $response ?? [],
        ];
    }

    /**
     * Confirme le statut d'une facture auprès de PayDunya (à appeler depuis le webhook).
     *
     * @return array{status: string, order_id: ?string, raw: array<string, mixed>}
     */
    public function confirmInvoice(string $token): array
    {
        $response = $this->client()
            ->get("/checkout-invoice/confirm/{$token}")
            ->json();

        return [
            'status' => $response['status'] ?? 'unknown', // completed | cancelled | pending
            'order_id' => $response['custom_data']['order_id'] ?? null,
            'raw' => $response ?? [],
        ];
    }
}

<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\Delivery\DeliveryFeeService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DeliveryQuoteController extends Controller
{
    public function __construct(private readonly DeliveryFeeService $fees)
    {
    }

    /** Devis de frais de livraison (affichage avant commande). */
    public function quote(Request $request): JsonResponse
    {
        $data = $request->validate([
            'subtotal' => ['required', 'numeric', 'min:0'],
            'latitude' => ['nullable', 'numeric'],
            'longitude' => ['nullable', 'numeric'],
        ]);

        $isVip = $request->user()->subscriptions()
            ->where('subscription_type', 'vip')
            ->where('status', 'active')
            ->exists();

        $result = $this->fees->compute(
            subtotal: (float) $data['subtotal'],
            latitude: isset($data['latitude']) ? (float) $data['latitude'] : null,
            longitude: isset($data['longitude']) ? (float) $data['longitude'] : null,
            isVip: $isVip,
        );

        return response()->json(['data' => $result]);
    }
}

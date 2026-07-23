<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Promotion;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class PromotionController extends Controller
{
    /** Liste des promotions (admin : toutes ; sinon actives et en cours). */
    public function index(Request $request): JsonResponse
    {
        $query = Promotion::query()->latest('created_at');

        if (! $request->user()?->isAdmin()) {
            $now = now();
            $query->where('is_active', true)
                ->where('start_date', '<=', $now)
                ->where('end_date', '>=', $now);
        }

        return response()->json($query->paginate($request->integer('per_page', 20)));
    }

    /** Valide un code promo pour un sous-total donné (retourne la remise calculée). */
    public function validateCode(Request $request): JsonResponse
    {
        $data = $request->validate([
            'promo_code' => ['required', 'string'],
            'subtotal' => ['required', 'numeric', 'min:0'],
        ]);

        $promotion = Promotion::where('promo_code', $data['promo_code'])->first();
        $discount = $promotion?->computeDiscount((float) $data['subtotal']);

        if ($discount === null) {
            return response()->json(['valid' => false, 'message' => 'Code promo invalide ou non applicable.'], 422);
        }

        return response()->json([
            'valid' => true,
            'data' => [
                'promo_code' => $promotion->promo_code,
                'discount' => $discount,
                'discount_type' => $promotion->discount_type,
                'free_delivery' => $promotion->discount_type === 'free_delivery',
            ],
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'description' => ['required', 'string'],
            'promo_code' => ['required', 'string', 'unique:promotions,promo_code'],
            'discount_type' => ['required', Rule::in(['percentage', 'fixed', 'free_delivery'])],
            'discount_value' => ['required', 'numeric', 'min:0'],
            'min_order_amount' => ['nullable', 'numeric', 'min:0'],
            'max_discount' => ['nullable', 'numeric', 'min:0'],
            'usage_limit' => ['nullable', 'integer', 'min:1'],
            'start_date' => ['required', 'date'],
            'end_date' => ['required', 'date', 'after:start_date'],
            'is_active' => ['boolean'],
        ]);

        $data['created_by'] = $request->user()->id;
        $promotion = Promotion::create($data);

        return response()->json(['data' => $promotion], 201);
    }

    public function update(Request $request, Promotion $promotion): JsonResponse
    {
        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'description' => ['sometimes', 'string'],
            'discount_value' => ['sometimes', 'numeric', 'min:0'],
            'min_order_amount' => ['nullable', 'numeric', 'min:0'],
            'max_discount' => ['nullable', 'numeric', 'min:0'],
            'usage_limit' => ['nullable', 'integer', 'min:1'],
            'start_date' => ['sometimes', 'date'],
            'end_date' => ['sometimes', 'date'],
            'is_active' => ['boolean'],
        ]);

        $promotion->update($data);

        return response()->json(['data' => $promotion]);
    }

    public function destroy(Promotion $promotion): JsonResponse
    {
        $promotion->delete();

        return response()->json(['message' => 'Promotion supprimée.']);
    }
}

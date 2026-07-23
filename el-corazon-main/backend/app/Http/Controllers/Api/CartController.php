<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\UserCart;
use App\Models\UserCartItem;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CartController extends Controller
{
    /** Panier courant + lignes + total calculé. */
    public function show(Request $request): JsonResponse
    {
        $user = $request->user();
        $cart = UserCart::firstOrCreate(['user_id' => $user->id]);
        $items = $user->cartItems()->get();

        return response()->json([
            'data' => [
                'cart' => $cart,
                'items' => $items,
                'summary' => $this->summary($cart, $items),
            ],
        ]);
    }

    public function addItem(Request $request): JsonResponse
    {
        $user = $request->user();
        UserCart::firstOrCreate(['user_id' => $user->id]);

        $data = $request->validate([
            'menu_item_id' => ['required', 'string'],
            'name' => ['required', 'string'],
            'price' => ['required', 'numeric', 'min:0'],
            'quantity' => ['required', 'integer', 'min:1'],
            'image_url' => ['nullable', 'string'],
            'customizations' => ['nullable', 'array'],
        ]);

        $item = $user->cartItems()->create($data);

        return response()->json(['data' => $item], 201);
    }

    public function updateItem(Request $request, UserCartItem $item): JsonResponse
    {
        abort_if($item->user_id !== $request->user()->id, 403, 'Accès refusé.');

        $data = $request->validate([
            'quantity' => ['sometimes', 'integer', 'min:1'],
            'customizations' => ['nullable', 'array'],
        ]);

        $item->update($data);

        return response()->json(['data' => $item]);
    }

    public function removeItem(Request $request, UserCartItem $item): JsonResponse
    {
        abort_if($item->user_id !== $request->user()->id, 403, 'Accès refusé.');
        $item->delete();

        return response()->json(['message' => 'Article retiré du panier.']);
    }

    public function clear(Request $request): JsonResponse
    {
        $request->user()->cartItems()->delete();

        return response()->json(['message' => 'Panier vidé.']);
    }

    /**
     * @param  \Illuminate\Support\Collection<int, UserCartItem>  $items
     * @return array<string, float>
     */
    private function summary(UserCart $cart, $items): array
    {
        $subtotal = $items->sum(fn (UserCartItem $i) => (float) $i->price * $i->quantity);
        $deliveryFee = (float) $cart->delivery_fee;
        $discount = (float) $cart->discount;

        return [
            'subtotal' => round($subtotal, 2),
            'delivery_fee' => round($deliveryFee, 2),
            'discount' => round($discount, 2),
            'total' => round(max(0, $subtotal + $deliveryFee - $discount), 2),
        ];
    }
}

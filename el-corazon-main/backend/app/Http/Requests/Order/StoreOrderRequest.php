<?php

namespace App\Http\Requests\Order;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * Règles de création d'une commande.
 *
 * L'autorisation « qui peut commander » est portée par la Policy
 * (OrderPolicy::create), appelée dans le contrôleur. Ici on se limite à la
 * validation des entrées : les totaux (sous-total, frais, remise) ne sont
 * jamais acceptés du client, ils sont recalculés côté serveur.
 */
class StoreOrderRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, array<int, mixed>>
     */
    public function rules(): array
    {
        return [
            'items' => ['required', 'array', 'min:1'],
            'items.*.menu_item_id' => ['required', 'uuid', 'exists:menu_items,id'],
            'items.*.quantity' => ['required', 'integer', 'min:1'],
            'items.*.customizations' => ['nullable', 'array'],
            'items.*.notes' => ['nullable', 'string'],
            'delivery_address' => ['required', 'string'],
            'delivery_latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'delivery_longitude' => ['nullable', 'numeric', 'between:-180,180'],
            'delivery_notes' => ['nullable', 'string'],
            'special_instructions' => ['nullable', 'string'],
            'payment_method' => ['required', Rule::in(['cash', 'card', 'wallet', 'mobile_money'])],
            'promo_code' => ['nullable', 'string'],
            'is_group_order' => ['boolean'],
            'group_id' => ['nullable', 'uuid'],
        ];
    }
}

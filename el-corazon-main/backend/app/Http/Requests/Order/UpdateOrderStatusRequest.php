<?php

namespace App\Http\Requests\Order;

use App\Models\Order;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * Règles de transition de statut d'une commande.
 *
 * L'autorisation (admin ou livreur assigné) est vérifiée dans le contrôleur
 * via OrderPolicy::update.
 */
class UpdateOrderStatusRequest extends FormRequest
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
            'status' => ['required', Rule::in(Order::STATUSES)],
            'notes' => ['nullable', 'string'],
        ];
    }
}

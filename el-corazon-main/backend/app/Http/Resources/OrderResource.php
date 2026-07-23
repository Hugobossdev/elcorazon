<?php

namespace App\Http\Resources;

use App\Models\Order;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Contrat de sortie stable pour une commande. Les relations ne sont exposées
 * que lorsqu'elles ont été explicitement chargées (whenLoaded) afin d'éviter
 * les requêtes N+1 et de garder une réponse déterministe.
 *
 * @mixin Order
 */
class OrderResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'user_id' => $this->user_id,
            'delivery_person_id' => $this->delivery_person_id,
            'status' => $this->status,

            'subtotal' => $this->subtotal,
            'delivery_fee' => $this->delivery_fee,
            'discount' => $this->discount,
            'total' => $this->total,

            'delivery_address' => $this->delivery_address,
            'delivery_latitude' => $this->delivery_latitude,
            'delivery_longitude' => $this->delivery_longitude,
            'delivery_notes' => $this->delivery_notes,
            'special_instructions' => $this->special_instructions,

            'payment_method' => $this->payment_method,
            'payment_status' => $this->payment_status,
            'promo_code' => $this->promo_code,

            'is_group_order' => $this->is_group_order,
            'group_id' => $this->group_id,

            'order_time' => $this->order_time,
            'estimated_delivery_time' => $this->estimated_delivery_time,
            'delivered_at' => $this->delivered_at,
            'created_at' => $this->created_at,
            'updated_at' => $this->updated_at,

            'items' => OrderItemResource::collection($this->whenLoaded('items')),
            'status_updates' => OrderStatusUpdateResource::collection($this->whenLoaded('statusUpdates')),
            'delivery_person' => new UserSummaryResource($this->whenLoaded('deliveryPerson')),
        ];
    }
}

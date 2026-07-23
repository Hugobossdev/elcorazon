<?php

namespace App\Http\Resources;

use App\Models\OrderStatusUpdate;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin OrderStatusUpdate
 */
class OrderStatusUpdateResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'status' => $this->status,
            'notes' => $this->notes,
            'updated_by' => $this->updated_by,
            'created_at' => $this->created_at,
        ];
    }
}

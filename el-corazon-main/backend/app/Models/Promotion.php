<?php

namespace App\Models;

use App\Models\Concerns\HasUuidPrimaryKey;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Promotion extends Model
{
    use HasUuidPrimaryKey;

    protected $table = 'promotions';

    protected $fillable = [
        'name',
        'description',
        'promo_code',
        'discount_type',
        'discount_value',
        'min_order_amount',
        'max_discount',
        'usage_limit',
        'used_count',
        'start_date',
        'end_date',
        'is_active',
        'created_by',
    ];

    protected $casts = [
        'discount_value' => 'float',
        'min_order_amount' => 'float',
        'max_discount' => 'float',
        'usage_limit' => 'integer',
        'used_count' => 'integer',
        'start_date' => 'datetime',
        'end_date' => 'datetime',
        'is_active' => 'boolean',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    public function usages(): HasMany
    {
        return $this->hasMany(PromotionUsage::class, 'promotion_id');
    }

    /**
     * Calcule le montant de la remise pour un sous-total donné, ou null si
     * la promo n'est pas applicable (expirée, inactive, seuil non atteint…).
     */
    public function computeDiscount(float $subtotal): ?float
    {
        $now = now();

        if (! $this->is_active
            || $now->lt($this->start_date)
            || $now->gt($this->end_date)
            || ($this->usage_limit !== null && $this->used_count >= $this->usage_limit)
            || $subtotal < (float) $this->min_order_amount) {
            return null;
        }

        $discount = match ($this->discount_type) {
            'percentage' => $subtotal * ((float) $this->discount_value / 100),
            'fixed' => (float) $this->discount_value,
            'free_delivery' => 0.0, // géré séparément sur les frais de livraison
            default => 0.0,
        };

        if ($this->max_discount !== null) {
            $discount = min($discount, (float) $this->max_discount);
        }

        return round(min($discount, $subtotal), 2);
    }
}

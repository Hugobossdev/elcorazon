<?php

namespace App\Models;

use App\Models\Concerns\HasUuidPrimaryKey;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Order extends Model
{
    use HasUuidPrimaryKey;

    protected $table = 'orders';

    public const STATUSES = [
        'pending', 'confirmed', 'preparing', 'ready',
        'picked_up', 'on_the_way', 'delivered', 'cancelled',
    ];

    protected $fillable = [
        'user_id',
        'delivery_person_id',
        'status',
        'subtotal',
        'delivery_fee',
        'discount',
        'total',
        'delivery_address',
        'delivery_latitude',
        'delivery_longitude',
        'delivery_notes',
        'special_instructions',
        'payment_method',
        'payment_status',
        'payment_transaction_id',
        'promo_code',
        'order_time',
        'estimated_delivery_time',
        'delivered_at',
        'is_group_order',
        'group_id',
    ];

    protected $casts = [
        'subtotal' => 'float',
        'delivery_fee' => 'float',
        'discount' => 'float',
        'total' => 'float',
        'delivery_latitude' => 'float',
        'delivery_longitude' => 'float',
        'order_time' => 'datetime',
        'estimated_delivery_time' => 'datetime',
        'delivered_at' => 'datetime',
        'is_group_order' => 'boolean',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function deliveryPerson(): BelongsTo
    {
        return $this->belongsTo(User::class, 'delivery_person_id');
    }

    public function items(): HasMany
    {
        return $this->hasMany(OrderItem::class, 'order_id');
    }

    public function statusUpdates(): HasMany
    {
        return $this->hasMany(OrderStatusUpdate::class, 'order_id');
    }

    public function activeDelivery(): HasOne
    {
        return $this->hasOne(ActiveDelivery::class, 'order_id');
    }

    public function deliveryLocations(): HasMany
    {
        return $this->hasMany(DeliveryLocation::class, 'order_id');
    }
}

<?php

namespace App\Models;

use App\Models\Concerns\HasUuidPrimaryKey;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SubscriptionOrder extends Model
{
    use HasUuidPrimaryKey;

    public $timestamps = false;

    protected $table = 'subscription_orders';

    protected $fillable = [
        'subscription_id', 'order_id', 'meal_count',
    ];

    protected $casts = [
        'meal_count' => 'integer',
        'created_at' => 'datetime',
    ];

    public function subscription(): BelongsTo
    {
        return $this->belongsTo(Subscription::class, 'subscription_id');
    }

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class, 'order_id');
    }
}

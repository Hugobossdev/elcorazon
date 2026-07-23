<?php

namespace App\Models;

use App\Models\Concerns\HasUuidPrimaryKey;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Subscription extends Model
{
    use HasUuidPrimaryKey;

    protected $table = 'subscriptions';

    protected $fillable = [
        'user_id', 'subscription_type', 'plan_name', 'meals_per_week', 'price_per_meal',
        'monthly_price', 'status', 'current_period_start', 'current_period_end',
        'meals_used_this_period', 'auto_renew', 'cancelled_at',
    ];

    protected $casts = [
        'meals_per_week' => 'integer',
        'price_per_meal' => 'float',
        'monthly_price' => 'float',
        'current_period_start' => 'datetime',
        'current_period_end' => 'datetime',
        'meals_used_this_period' => 'integer',
        'auto_renew' => 'boolean',
        'cancelled_at' => 'datetime',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }
}

<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** La clé primaire est un identifiant textuel (non UUID). */
class LoyaltyReward extends Model
{
    public $incrementing = false;

    public $timestamps = false;

    protected $keyType = 'string';

    protected $table = 'loyalty_rewards';

    protected $fillable = [
        'id', 'title', 'description', 'cost', 'reward_type', 'value', 'is_active',
    ];

    protected $casts = [
        'cost' => 'integer',
        'value' => 'float',
        'is_active' => 'boolean',
        'created_at' => 'datetime',
    ];
}

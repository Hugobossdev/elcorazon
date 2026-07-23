<?php

namespace App\Models;

use App\Models\Concerns\HasUuidPrimaryKey;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class RewardRedemption extends Model
{
    use HasUuidPrimaryKey;

    public $timestamps = false;

    protected $table = 'reward_redemptions';

    protected $fillable = [
        'user_id', 'reward_id', 'cost', 'metadata', 'status',
    ];

    protected $casts = [
        'cost' => 'integer',
        'metadata' => 'array',
        'created_at' => 'datetime',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }
}

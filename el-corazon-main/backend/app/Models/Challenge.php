<?php

namespace App\Models;

use App\Models\Concerns\HasUuidPrimaryKey;
use Illuminate\Database\Eloquent\Model;

class Challenge extends Model
{
    use HasUuidPrimaryKey;

    public $timestamps = false;

    protected $table = 'challenges';

    protected $fillable = [
        'title', 'description', 'challenge_type', 'target_value', 'reward_points',
        'reward_discount', 'start_date', 'end_date', 'is_active',
    ];

    protected $casts = [
        'target_value' => 'integer',
        'reward_points' => 'integer',
        'reward_discount' => 'float',
        'start_date' => 'datetime',
        'end_date' => 'datetime',
        'is_active' => 'boolean',
        'created_at' => 'datetime',
    ];
}

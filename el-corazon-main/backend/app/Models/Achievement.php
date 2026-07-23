<?php

namespace App\Models;

use App\Models\Concerns\HasUuidPrimaryKey;
use Illuminate\Database\Eloquent\Model;

class Achievement extends Model
{
    use HasUuidPrimaryKey;

    public $timestamps = false;

    protected $table = 'achievements';

    protected $fillable = [
        'name', 'description', 'icon', 'points_reward', 'badge_reward',
        'condition_type', 'condition_value', 'is_active',
    ];

    protected $casts = [
        'points_reward' => 'integer',
        'condition_value' => 'integer',
        'is_active' => 'boolean',
        'created_at' => 'datetime',
    ];
}

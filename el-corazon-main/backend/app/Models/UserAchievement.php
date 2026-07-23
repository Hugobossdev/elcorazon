<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Clé composite (user_id, achievement_id). Eloquent ne gère pas nativement les
 * clés composites : on manipule ces lignes via upsert/where explicites.
 */
class UserAchievement extends Model
{
    public $incrementing = false;

    public $timestamps = false;

    protected $primaryKey = 'user_id';

    protected $keyType = 'string';

    protected $table = 'user_achievements';

    protected $fillable = [
        'user_id', 'achievement_id', 'progress', 'is_unlocked', 'unlocked_at', 'updated_at',
    ];

    protected $casts = [
        'progress' => 'integer',
        'is_unlocked' => 'boolean',
        'unlocked_at' => 'datetime',
        'updated_at' => 'datetime',
    ];
}

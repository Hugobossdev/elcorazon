<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** Clé composite (user_id, badge_id). */
class UserBadge extends Model
{
    public $incrementing = false;

    public $timestamps = false;

    protected $primaryKey = 'user_id';

    protected $keyType = 'string';

    protected $table = 'user_badges';

    protected $fillable = [
        'user_id', 'badge_id', 'progress', 'is_unlocked', 'unlocked_at', 'updated_at',
    ];

    protected $casts = [
        'progress' => 'integer',
        'is_unlocked' => 'boolean',
        'unlocked_at' => 'datetime',
        'updated_at' => 'datetime',
    ];
}

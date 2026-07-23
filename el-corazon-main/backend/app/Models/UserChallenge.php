<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** Clé composite (user_id, challenge_id). */
class UserChallenge extends Model
{
    public $incrementing = false;

    public $timestamps = false;

    protected $primaryKey = 'user_id';

    protected $keyType = 'string';

    protected $table = 'user_challenges';

    protected $fillable = [
        'user_id', 'challenge_id', 'progress', 'is_completed', 'completed_at', 'updated_at',
    ];

    protected $casts = [
        'progress' => 'integer',
        'is_completed' => 'boolean',
        'completed_at' => 'datetime',
        'updated_at' => 'datetime',
    ];
}

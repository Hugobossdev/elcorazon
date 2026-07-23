<?php

namespace App\Models;

use App\Models\Concerns\HasUuidPrimaryKey;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class SocialGroup extends Model
{
    use HasUuidPrimaryKey;

    protected $table = 'social_groups';

    protected $fillable = [
        'name', 'description', 'group_type', 'creator_id', 'invite_code',
        'is_private', 'max_members', 'member_count', 'is_active',
    ];

    protected $casts = [
        'is_private' => 'boolean',
        'max_members' => 'integer',
        'member_count' => 'integer',
        'is_active' => 'boolean',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'creator_id');
    }

    public function members(): HasMany
    {
        return $this->hasMany(GroupMember::class, 'group_id');
    }

    public function posts(): HasMany
    {
        return $this->hasMany(SocialPost::class, 'group_id');
    }
}

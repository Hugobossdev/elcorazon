<?php

namespace App\Models;

use App\Models\Concerns\HasUuidPrimaryKey;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class AdminRole extends Model
{
    use HasUuidPrimaryKey;

    protected $table = 'admin_roles';

    protected $fillable = [
        'name',
        'description',
        'permissions',
        'is_active',
        'is_default',
    ];

    protected $casts = [
        'permissions' => 'array',
        'is_active' => 'boolean',
        'is_default' => 'boolean',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    public function assignments(): HasMany
    {
        return $this->hasMany(UserAdminRole::class, 'role_id');
    }
}

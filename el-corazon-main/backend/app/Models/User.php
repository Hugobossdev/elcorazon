<?php

namespace App\Models;

use App\Models\Concerns\HasUuidPrimaryKey;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Laravel\Sanctum\HasApiTokens;

/**
 * Table centrale des utilisateurs (client / admin / delivery).
 *
 * L'authentification est émise par Laravel via Sanctum (jetons personnels).
 * `auth_user_id` reste disponible comme pont éventuel vers Supabase Auth.
 */
class User extends Authenticatable
{
    use HasApiTokens;
    use HasUuidPrimaryKey;

    protected $table = 'users';

    protected $fillable = [
        'auth_user_id',
        'name',
        'email',
        'phone',
        'password',
        'role',
        'profile_image',
        'loyalty_points',
        'badges',
        'is_online',
        'is_active',
        'last_seen',
        'verification_status',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected $casts = [
        'password' => 'hashed',
        'loyalty_points' => 'integer',
        'badges' => 'array',
        'is_online' => 'boolean',
        'is_active' => 'boolean',
        'last_seen' => 'datetime',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    /** Claims du JWT Supabase attachés le temps de la requête (non persistés). */
    protected array $supabaseClaims = [];

    public function setSupabaseClaims(array $claims): void
    {
        $this->supabaseClaims = $claims;
    }

    public function getSupabaseClaims(): array
    {
        return $this->supabaseClaims;
    }

    public function isAdmin(): bool
    {
        return $this->role === 'admin';
    }

    public function isDriver(): bool
    {
        return $this->role === 'delivery';
    }

    public function isClient(): bool
    {
        return $this->role === 'client';
    }

    // Relations -----------------------------------------------------------

    public function driver(): HasOne
    {
        return $this->hasOne(Driver::class, 'user_id');
    }

    public function addresses(): HasMany
    {
        return $this->hasMany(Address::class, 'user_id');
    }

    public function orders(): HasMany
    {
        return $this->hasMany(Order::class, 'user_id');
    }

    public function assignedOrders(): HasMany
    {
        return $this->hasMany(Order::class, 'delivery_person_id');
    }

    public function notifications(): HasMany
    {
        return $this->hasMany(Notification::class, 'user_id');
    }

    public function cart(): HasOne
    {
        return $this->hasOne(UserCart::class, 'user_id');
    }

    public function cartItems(): HasMany
    {
        return $this->hasMany(UserCartItem::class, 'user_id');
    }

    public function loyaltyTransactions(): HasMany
    {
        return $this->hasMany(LoyaltyTransaction::class, 'user_id');
    }

    public function subscriptions(): HasMany
    {
        return $this->hasMany(Subscription::class, 'user_id');
    }

    public function adminRoles(): HasMany
    {
        return $this->hasMany(UserAdminRole::class, 'user_id');
    }
}

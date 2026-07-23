<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * Panier utilisateur : la clé primaire est `user_id` (1 panier / utilisateur).
 */
class UserCart extends Model
{
    public $incrementing = false;

    public const CREATED_AT = null;

    protected $primaryKey = 'user_id';

    protected $keyType = 'string';

    protected $table = 'user_carts';

    protected $fillable = [
        'user_id',
        'delivery_fee',
        'discount',
        'promo_code',
    ];

    protected $casts = [
        'delivery_fee' => 'float',
        'discount' => 'float',
        'updated_at' => 'datetime',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function items(): HasMany
    {
        return $this->hasMany(UserCartItem::class, 'user_id', 'user_id');
    }
}

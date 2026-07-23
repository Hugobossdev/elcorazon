<?php

namespace App\Models;

use App\Models\Concerns\HasUuidPrimaryKey;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class UserCartItem extends Model
{
    use HasUuidPrimaryKey;

    protected $table = 'user_cart_items';

    protected $fillable = [
        'user_id',
        'menu_item_id',
        'name',
        'price',
        'quantity',
        'image_url',
        'customizations',
    ];

    protected $casts = [
        'price' => 'float',
        'quantity' => 'integer',
        'customizations' => 'array',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }
}

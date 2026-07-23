<?php

namespace App\Models;

use App\Models\Concerns\HasUuidPrimaryKey;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ProductReview extends Model
{
    use HasUuidPrimaryKey;

    protected $table = 'product_reviews';

    protected $fillable = [
        'menu_item_id',
        'user_id',
        'user_name',
        'rating',
        'title',
        'comment',
        'photos',
        'is_verified_purchase',
        'helpful_count',
    ];

    protected $casts = [
        'rating' => 'float',
        'photos' => 'array',
        'is_verified_purchase' => 'boolean',
        'helpful_count' => 'integer',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    public function menuItem(): BelongsTo
    {
        return $this->belongsTo(MenuItem::class, 'menu_item_id');
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }
}

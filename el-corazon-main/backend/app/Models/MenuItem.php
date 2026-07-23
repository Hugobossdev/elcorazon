<?php

namespace App\Models;

use App\Models\Concerns\HasUuidPrimaryKey;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;

class MenuItem extends Model
{
    use HasUuidPrimaryKey;

    protected $table = 'menu_items';

    protected $fillable = [
        'name',
        'description',
        'price',
        'category_id',
        'image_url',
        'is_popular',
        'is_vegetarian',
        'is_vegan',
        'is_available',
        'available_quantity',
        'vip_exclusive',
        'ingredients',
        'calories',
        'allergens',
        'preparation_time',
        'rating',
        'review_count',
        'sort_order',
    ];

    protected $casts = [
        'price' => 'float',
        'is_popular' => 'boolean',
        'is_vegetarian' => 'boolean',
        'is_vegan' => 'boolean',
        'is_available' => 'boolean',
        'available_quantity' => 'integer',
        'vip_exclusive' => 'boolean',
        'ingredients' => 'array',
        'calories' => 'integer',
        'allergens' => 'array',
        'preparation_time' => 'integer',
        'rating' => 'float',
        'review_count' => 'integer',
        'sort_order' => 'integer',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    public function category(): BelongsTo
    {
        return $this->belongsTo(MenuCategory::class, 'category_id');
    }

    public function reviews(): HasMany
    {
        return $this->hasMany(ProductReview::class, 'menu_item_id');
    }

    public function customizationOptions(): BelongsToMany
    {
        return $this->belongsToMany(
            CustomizationOption::class,
            'menu_item_customizations',
            'menu_item_id',
            'customization_option_id',
        )->withPivot(['is_required', 'sort_order']);
    }
}

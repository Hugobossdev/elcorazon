<?php

namespace App\Models;

use App\Models\Concerns\HasUuidPrimaryKey;
use Illuminate\Database\Eloquent\Model;

class CustomizationOption extends Model
{
    use HasUuidPrimaryKey;

    protected $table = 'customization_options';

    protected $fillable = [
        'name',
        'category',
        'price_modifier',
        'is_default',
        'max_quantity',
        'description',
        'image_url',
        'allergens',
        'is_active',
    ];

    protected $casts = [
        'price_modifier' => 'float',
        'is_default' => 'boolean',
        'max_quantity' => 'integer',
        'allergens' => 'array',
        'is_active' => 'boolean',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];
}

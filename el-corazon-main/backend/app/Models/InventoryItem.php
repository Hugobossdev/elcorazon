<?php

namespace App\Models;

use App\Models\Concerns\HasUuidPrimaryKey;
use Illuminate\Database\Eloquent\Model;

class InventoryItem extends Model
{
    use HasUuidPrimaryKey;

    protected $table = 'inventory_items';

    protected $fillable = [
        'name',
        'category',
        'current_stock',
        'minimum_stock',
        'unit',
        'unit_price',
        'last_restock_date',
        'expiry_date',
        'supplier',
        'location',
    ];

    protected $casts = [
        'current_stock' => 'float',
        'minimum_stock' => 'float',
        'unit_price' => 'float',
        'last_restock_date' => 'datetime',
        'expiry_date' => 'datetime',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];
}

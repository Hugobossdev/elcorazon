<?php

namespace App\Models;

use App\Models\Concerns\HasUuidPrimaryKey;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class OrderItem extends Model
{
    use HasUuidPrimaryKey;

    public $timestamps = false;

    protected $table = 'order_items';

    protected $fillable = [
        'order_id',
        'menu_item_id',
        'menu_item_name',
        'name',
        'category',
        'menu_item_image',
        'quantity',
        'unit_price',
        'total_price',
        'customizations',
        'notes',
    ];

    protected $casts = [
        'quantity' => 'integer',
        'unit_price' => 'float',
        'total_price' => 'float',
        'customizations' => 'array',
        'created_at' => 'datetime',
    ];

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class, 'order_id');
    }

    public function menuItem(): BelongsTo
    {
        return $this->belongsTo(MenuItem::class, 'menu_item_id');
    }
}

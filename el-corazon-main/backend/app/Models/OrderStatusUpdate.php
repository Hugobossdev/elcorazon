<?php

namespace App\Models;

use App\Models\Concerns\HasUuidPrimaryKey;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class OrderStatusUpdate extends Model
{
    use HasUuidPrimaryKey;

    public $timestamps = false;

    protected $table = 'order_status_updates';

    protected $fillable = [
        'order_id',
        'status',
        'updated_by',
        'notes',
    ];

    protected $casts = [
        'created_at' => 'datetime',
    ];

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class, 'order_id');
    }
}

<?php

namespace App\Models;

use App\Models\Concerns\HasUuidPrimaryKey;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ReturnRequest extends Model
{
    use HasUuidPrimaryKey;

    public $timestamps = false;

    protected $table = 'return_requests';

    protected $fillable = [
        'user_id', 'order_id', 'reason', 'items', 'refund_amount',
        'status', 'resolved_at',
    ];

    protected $casts = [
        'items' => 'array',
        'refund_amount' => 'float',
        'created_at' => 'datetime',
        'resolved_at' => 'datetime',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class, 'order_id');
    }
}

<?php

namespace App\Models;

use App\Models\Concerns\HasUuidPrimaryKey;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class GroupPayment extends Model
{
    use HasUuidPrimaryKey;

    protected $table = 'group_payments';

    protected $fillable = [
        'group_id',
        'order_id',
        'total_amount',
        'paid_amount',
        'status',
        'initiated_by',
        'metadata',
    ];

    protected $casts = [
        'total_amount' => 'float',
        'paid_amount' => 'float',
        'metadata' => 'array',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class, 'order_id');
    }

    public function participants(): HasMany
    {
        return $this->hasMany(GroupPaymentParticipant::class, 'group_payment_id');
    }
}

<?php

namespace App\Models;

use App\Models\Concerns\HasUuidPrimaryKey;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class GroupPaymentParticipant extends Model
{
    use HasUuidPrimaryKey;

    protected $table = 'group_payment_participants';

    protected $fillable = [
        'group_payment_id',
        'user_id',
        'name',
        'email',
        'phone',
        'operator',
        'amount',
        'paid_amount',
        'status',
        'transaction_id',
        'payment_result',
    ];

    protected $casts = [
        'amount' => 'float',
        'paid_amount' => 'float',
        'payment_result' => 'array',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    public function groupPayment(): BelongsTo
    {
        return $this->belongsTo(GroupPayment::class, 'group_payment_id');
    }
}

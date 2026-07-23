<?php

namespace App\Models;

use App\Models\Concerns\HasUuidPrimaryKey;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class LoyaltyTransaction extends Model
{
    use HasUuidPrimaryKey;

    public $timestamps = false;

    protected $table = 'loyalty_transactions';

    protected $fillable = [
        'user_id', 'transaction_type', 'points', 'description', 'metadata',
    ];

    protected $casts = [
        'points' => 'integer',
        'metadata' => 'array',
        'created_at' => 'datetime',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }
}

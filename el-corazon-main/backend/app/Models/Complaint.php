<?php

namespace App\Models;

use App\Models\Concerns\HasUuidPrimaryKey;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Complaint extends Model
{
    use HasUuidPrimaryKey;

    public $timestamps = false;

    protected $table = 'complaints';

    protected $fillable = [
        'user_id', 'order_id', 'type', 'subject', 'description',
        'photos', 'status', 'resolution',
    ];

    protected $casts = [
        'photos' => 'array',
        'created_at' => 'datetime',
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

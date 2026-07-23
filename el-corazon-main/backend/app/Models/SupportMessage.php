<?php

namespace App\Models;

use App\Models\Concerns\HasUuidPrimaryKey;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SupportMessage extends Model
{
    use HasUuidPrimaryKey;

    public $timestamps = false;

    protected $table = 'support_messages';

    protected $fillable = [
        'ticket_id', 'admin_id', 'user_id', 'message',
    ];

    protected $casts = ['created_at' => 'datetime'];

    public function ticket(): BelongsTo
    {
        return $this->belongsTo(SupportTicket::class, 'ticket_id');
    }
}

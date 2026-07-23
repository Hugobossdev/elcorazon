<?php

namespace App\Models;

use App\Models\Concerns\HasUuidPrimaryKey;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class SupportTicket extends Model
{
    use HasUuidPrimaryKey;

    public $timestamps = false;

    protected $table = 'support_tickets';

    protected $fillable = [
        'user_id', 'category', 'subject', 'description', 'attachments',
        'status', 'resolved_at', 'resolution',
    ];

    protected $casts = [
        'attachments' => 'array',
        'created_at' => 'datetime',
        'resolved_at' => 'datetime',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function messages(): HasMany
    {
        return $this->hasMany(SupportMessage::class, 'ticket_id');
    }
}

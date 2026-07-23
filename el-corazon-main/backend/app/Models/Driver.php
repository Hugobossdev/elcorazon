<?php

namespace App\Models;

use App\Models\Concerns\HasUuidPrimaryKey;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Driver extends Model
{
    use HasUuidPrimaryKey;

    protected $table = 'drivers';

    protected $fillable = [
        'user_id',
        'profile_photo_url',
        'license_number',
        'id_number',
        'vehicle_type',
        'vehicle_number',
        'license_photo_url',
        'id_card_photo_url',
        'vehicle_photo_url',
        'verification_status',
        'verification_notes',
        'verified_by',
        'verified_at',
        'total_deliveries',
        'completed_deliveries',
        'rating',
        'total_ratings',
        'total_earnings',
        'is_available',
        'status',
        'current_location_latitude',
        'current_location_longitude',
        'last_location_update',
        'last_online',
        'notes',
        'is_active',
    ];

    protected $casts = [
        'verified_at' => 'datetime',
        'total_deliveries' => 'integer',
        'completed_deliveries' => 'integer',
        'rating' => 'float',
        'total_ratings' => 'integer',
        'total_earnings' => 'float',
        'is_available' => 'boolean',
        'current_location_latitude' => 'float',
        'current_location_longitude' => 'float',
        'last_location_update' => 'datetime',
        'last_online' => 'datetime',
        'is_active' => 'boolean',
        'created_at' => 'datetime',
        'updated_at' => 'datetime',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }
}

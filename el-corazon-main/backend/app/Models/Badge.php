<?php

namespace App\Models;

use App\Models\Concerns\HasUuidPrimaryKey;
use Illuminate\Database\Eloquent\Model;

class Badge extends Model
{
    use HasUuidPrimaryKey;

    public $timestamps = false;

    protected $table = 'badges';

    protected $fillable = [
        'title', 'description', 'icon', 'points_required', 'criteria', 'is_active',
    ];

    protected $casts = [
        'points_required' => 'integer',
        'is_active' => 'boolean',
        'created_at' => 'datetime',
    ];
}

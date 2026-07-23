<?php

namespace App\Models;

use App\Models\Concerns\HasUuidPrimaryKey;
use Illuminate\Database\Eloquent\Model;

class PostLike extends Model
{
    use HasUuidPrimaryKey;

    public $timestamps = false;

    protected $table = 'post_likes';

    protected $fillable = ['post_id', 'user_id'];

    protected $casts = ['created_at' => 'datetime'];
}

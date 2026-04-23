<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Invitation extends Model
{
    use HasFactory;

    protected $fillable = [
        'email',
        'token',
        'role',
        'allowed_apps',
        'created_by',
        'expires_at',
        'used_at',
    ];

    protected $casts = [
        'allowed_apps' => 'array',
        'expires_at' => 'datetime',
        'used_at' => 'datetime',
    ];

    public function creator()
    {
        return $this->belongsTo(User::class, 'created_by');
    }
}

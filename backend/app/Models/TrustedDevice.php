<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class TrustedDevice extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'device_id',
        'device_name',
        'os_type',
        'fingerprint_data',
        'last_active_at',
        'is_blocked',
    ];

    protected $casts = [
        'fingerprint_data' => 'array',
        'last_active_at' => 'datetime',
        'is_blocked' => 'boolean',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}

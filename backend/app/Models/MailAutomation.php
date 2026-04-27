<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class MailAutomation extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'name',
        'to',
        'subject',
        'body',
        'trigger_type',
        'schedule_time',
        'schedule_days',
        'is_active',
        'last_run_at',
    ];

    protected $casts = [
        'is_active' => 'boolean',
        'last_run_at' => 'datetime',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}

<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class MailConfiguration extends Model
{
    protected $fillable = [
        'user_id',
        'email',
        'password',
        'imap_host',
        'imap_port',
        'imap_encryption',
        'smtp_host',
        'smtp_port',
        'smtp_encryption',
        'is_active',
    ];

    protected $hidden = [
        'password',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}

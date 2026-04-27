<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class LoginSecurity extends Model
{
    use HasFactory;
    
    protected $table = 'login_security';
    protected $fillable = ['ip_address', 'attempts', 'blocked_until'];
}

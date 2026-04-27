<?php

namespace App\Models;

use Illuminate\Contracts\Auth\MustVerifyEmail;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    /**
     * The attributes that are mass assignable.
     *
     * @var array<int, string>
     */
    protected $fillable = [
        'name',
        'email',
        'password',
        'role',
        'uid',
        'phone',
        'current_company_id',
        'key_1',
        'key_2',
        'key_3',
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var array<int, string>
     */
    protected $hidden = [
        'password',
        'remember_token',
        'key_1',  // Security keys must NEVER appear in API responses
        'key_2',
        'key_3',
    ];

    /**
     * The attributes that should be cast.
     *
     * @var array<string, string>
     */
    protected $casts = [
        'email_verified_at' => 'datetime',
    ];

    public function companies()
    {
        return $this->belongsToMany(Company::class, 'company_user')
                    ->withPivot('role', 'status')
                    ->withTimestamps();
    }

    public function devices()
    {
        return $this->hasMany(TrustedDevice::class);
    }

    protected static function booted()
    {
        static::creating(function ($user) {
            if (empty($user->uid)) {
                $user->uid = self::generateUniqueUid($user->role);
            }
        });

        static::updating(function ($user) {
            // If the role has changed, regenerate the UID to match the new role prefix
            if ($user->isDirty('role')) {
                $user->uid = self::generateUniqueUid($user->role);
            }
        });
    }
    public static function generateUniqueUid($role)
    {
        $prefix = match ($role) {
            'super_admin' => 'SID',
            'admin'       => 'AID',
            'manager'     => 'MID',
            'staff'       => 'TAF',
            default       => 'UID',
        };

        do {
            $uid = $prefix . str_pad(rand(0, 999999), 6, '0', STR_PAD_LEFT);
        } while (self::where('uid', $uid)->exists());

        return $uid;
    }
}

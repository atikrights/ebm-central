<?php

use App\Models\User;
use Illuminate\Support\Facades\DB;

require __DIR__.'/vendor/autoload.php';
$app = require_once __DIR__.'/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

$users = User::all();

foreach ($users as $user) {
    $prefix = match ($user->role) {
        'super_admin' => 'SID',
        'admin'       => 'AID',
        'manager'     => 'MID',
        'staff'       => 'TAF',
        default       => 'UID',
    };
    
    // Always regenerate to apply new prefixes
    $uid = $prefix . str_pad(rand(0, 999999), 6, '0', STR_PAD_LEFT);
    
    while (User::where('uid', $uid)->exists()) {
        $uid = $prefix . str_pad(rand(0, 999999), 6, '0', STR_PAD_LEFT);
    }
    
    $user->uid = $uid;
    $user->save();
    echo "Updated user {$user->email} with UID: {$uid}\n";
}

echo "Done updating " . count($users) . " users.\n";

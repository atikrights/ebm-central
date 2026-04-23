<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\User;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        // Create Master Super Admin
        User::updateOrCreate(
            ['email' => 'atik@ebfic.com'],
            [
                'name' => 'Atikur Rahman',
                'password' => Hash::make('admin123'),
                'role' => 'super_admin',
                'email_verified_at' => now(),
            ]
        );

        // Create a test Admin
        User::updateOrCreate(
            ['email' => 'sabbir@ebfic.com'],
            [
                'name' => 'Sabbir Ahammed',
                'password' => Hash::make('admin123'),
                'role' => 'admin',
                'email_verified_at' => now(),
            ]
        );
    }
}

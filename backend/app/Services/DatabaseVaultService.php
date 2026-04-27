<?php

namespace App\Services;

use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\DB;
use Exception;

class DatabaseVaultService
{
    /**
     * Switch the active database connection at runtime.
     * Only Super Admin should trigger this via Governance API.
     */
    public function connectToVault(string $databaseName, string $username = 'root', string $password = '')
    {
        try {
            // Define a new dynamic connection
            Config::set("database.connections.dynamic_vault", [
                'driver'    => 'mysql',
                'host'      => env('DB_HOST', '127.0.0.1'),
                'port'      => env('DB_PORT', '3306'),
                'database'  => $databaseName,
                'username'  => $username,
                'password'  => $password,
                'charset'   => 'utf8mb4',
                'collation' => 'utf8mb4_unicode_ci',
                'prefix'    => '',
                'strict'    => true,
                'engine'    => null,
            ]);

            // Test the connection
            DB::connection('dynamic_vault')->getPdo();

            // Set as default connection for the rest of the request
            Config::set('database.default', 'dynamic_vault');
            DB::purge('mysql');
            DB::reconnect('dynamic_vault');

            return true;
        } catch (Exception $e) {
            // Log the error securely
            \Log::error("Vault Switch Failed: " . $e->getMessage());
            return false;
        }
    }
}

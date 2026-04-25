<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\DatabaseConfig;
use App\Events\DataUpdated;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class DatabaseController extends Controller
{
    /**
     * List all database configurations.
     */
    public function index()
    {
        $configs = DatabaseConfig::all();
        // Mask passwords before sending to UI
        return response()->json($configs->map(function($config) {
            $config->password = '********'; 
            return $config;
        }));
    }

    /**
     * Store a new database configuration.
     */
    public function store(Request $request)
    {
        $request->validate([
            'name' => 'required|string',
            'host' => 'required|string',
            'port' => 'required|integer',
            'database_name' => 'required|string',
            'username' => 'required|string',
            'password' => 'required|string',
        ]);

        $config = DatabaseConfig::create($request->all());

        // Notify other systems in real-time
        event(new DataUpdated('NEW_DATABASE_ADDED', [
            'id' => $config->id,
            'name' => $config->name,
            'host' => $config->host,
            'database' => $config->database_name
        ]));

        return response()->json([
            'message' => 'Database configuration secured and added successfully.',
            'config' => $config
        ]);
    }

    /**
     * Get system storage and database status.
     */
    public function systemStatus()
    {
        try {
            $diskTotal = disk_total_space("/");
            $diskFree = disk_free_space("/");
            $diskUsed = $diskTotal - $diskFree;

            // Get database sizes (MySQL specific)
            $dbSizes = DB::select("SELECT table_schema AS 'database', 
                                   ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'size_mb' 
                                   FROM information_schema.TABLES 
                                   GROUP BY table_schema");

            return response()->json([
                'storage' => [
                    'total' => round($diskTotal / 1073741824, 2), // GB
                    'used' => round($diskUsed / 1073741824, 2), // GB
                    'free' => round($diskFree / 1073741824, 2), // GB
                    'percent' => round(($diskUsed / $diskTotal) * 100, 2)
                ],
                'databases' => $dbSizes,
                'php_version' => PHP_VERSION,
                'server_time' => now()->toDateTimeString()
            ]);
        } catch (\Exception $e) {
            return response()->json(['error' => 'Could not fetch system status: ' . $e->getMessage()], 500);
        }
    }

    /**
     * Delete a database configuration.
     */
    public function destroy($id)
    {
        $config = DatabaseConfig::findOrFail($id);
        $config->delete();

        event(new DataUpdated('DATABASE_REMOVED', ['id' => $id]));

        return response()->json(['message' => 'Database configuration removed.']);
    }
}

<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use App\Models\User;

class StorageController extends Controller
{
    /**
     * Unified Storage Gateway for all EBM platforms
     * Only accessible by Super Admin for global management.
     */
    public function listFiles(Request $request)
    {
        // Check governance access
        if ($request->user()->role !== 'super_admin') {
            return response()->json(['message' => 'Unauthorized. L4 clearance required.'], 403);
        }

        $directory = $request->get('directory', '/');
        
        $files = Storage::disk('public')->files($directory);
        $directories = Storage::disk('public')->directories($directory);

        return response()->json([
            'files' => $files,
            'directories' => $directories,
            'disk' => env('FILESYSTEM_DISK', 'local')
        ]);
    }

    public function uploadFile(Request $request)
    {
        $request->validate([
            'file' => 'required|file|max:10240', // 10MB limit
            'path' => 'nullable|string'
        ]);

        $path = $request->get('path', 'shared_assets');
        $file = $request->file('file');
        
        $uploadedPath = Storage::disk('public')->put($path, $file);

        return response()->json([
            'message' => 'File uploaded to central storage.',
            'path' => $uploadedPath,
            'url' => Storage::disk('public')->url($uploadedPath)
        ]);
    }

    public function deleteFile(Request $request)
    {
        if ($request->user()->role !== 'super_admin') {
            return response()->json(['message' => 'Unauthorized.'], 403);
        }

        $request->validate(['path' => 'required|string']);

        if (Storage::disk('public')->exists($request->path)) {
            Storage::disk('public')->delete($request->path);
            return response()->json(['message' => 'File permanently deleted from Vault.']);
        }

        return response()->json(['message' => 'File not found.'], 404);
    }
}

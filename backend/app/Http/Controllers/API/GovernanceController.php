<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\Invitation;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Carbon\Carbon;

class GovernanceController extends Controller
{
    /**
     * Generate an invitation token for a new admin/user.
     */
    public function generateInvitation(Request $request)
    {
        $request->validate([
            'email' => 'required|email',
            'role' => 'required|in:admin,manager,staff',
            'allowed_apps' => 'nullable|array',
        ]);

        $token = Str::random(40);
        
        // 6 hours expiry as requested
        $expiresAt = Carbon::now()->addHours(6);

        $invitation = Invitation::create([
            'email' => $request->email,
            'token' => $token,
            'role' => $request->role,
            'allowed_apps' => $request->allowed_apps ?? ['ebm-app'],
            'created_by' => $request->user()?->id ?? 1, // Fallback to 1 for local testing if not logged in
            'expires_at' => $expiresAt,
        ]);

        // Use descriptive URL format: /join/role/token
        $frontendUrl = env('FRONTEND_URL', 'http://localhost:3000');
        $joinLink = $frontendUrl . "/#/join/" . $request->role . "/" . $token;

        return response()->json([
            'message' => 'Invitation generated successfully',
            'invitation_link' => $joinLink,
            'token' => $token,
            'expires_at' => $expiresAt->toDateTimeString(),
        ]);
    }

    /**
     * Validate an invitation token.
     */
    public function validateInvitation($token)
    {
        $invitation = Invitation::where('token', $token)
            ->whereNull('used_at')
            ->where('expires_at', '>', Carbon::now())
            ->first();

        if (!$invitation) {
            return response()->json(['message' => 'Invalid or expired invitation'], 404);
        }

        return response()->json([
            'email' => $invitation->email,
            'role' => $invitation->role,
            'allowed_apps' => $invitation->allowed_apps
        ]);
    }

    /**
     * Get all active system users and their devices.
     */
    public function systemUsers()
    {
        $users = User::with(['companies'])->get();
        return response()->json($users);
    }

    public function deleteUser($id)
    {
        $user = \App\Models\User::find($id);
        if (!$user) {
            return response()->json(['message' => 'User not found'], 404);
        }

        // Prevent deleting own account if needed, but for now allow super admin full control
        $user->delete();

        return response()->json(['message' => 'User deleted successfully']);
    }

    public function updateRole(Request $request, $id)
    {
        $request->validate([
            'role' => 'required|in:super_admin,admin,manager,staff'
        ]);

        $user = \App\Models\User::find($id);
        if (!$user) {
            return response()->json(['message' => 'User not found'], 404);
        }

        if ($user->id === $request->user()->id && $request->role !== 'super_admin') {
            return response()->json(['message' => 'You cannot downgrade your own super admin role'], 403);
        }

        $user->role = $request->role;
        $user->save();

        return response()->json(['message' => 'User role updated successfully', 'user' => $user]);
    }

    public function updateUser(Request $request, $id)
    {
        $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|email|unique:users,email,' . $id,
            'role' => 'required|in:super_admin,admin,manager,staff',
        ]);

        $user = \App\Models\User::find($id);
        if (!$user) {
            return response()->json(['message' => 'User not found'], 404);
        }

        $user->name = $request->name;
        $user->email = $request->email;
        $user->role = $request->role;

        if ($request->has('password') && !empty($request->password)) {
            $user->password = \Illuminate\Support\Facades\Hash::make($request->password);
        }

        $user->save();

        return response()->json(['message' => 'User updated successfully', 'user' => $user]);
    }
}

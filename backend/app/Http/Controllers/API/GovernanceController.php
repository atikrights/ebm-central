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
            'role' => 'required|in:super_admin,admin,manager,staff',
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

        // Auto-detect domain for 100% correctness
        $baseUrl = $request->getSchemeAndHttpHost();
        $joinLink = $baseUrl . "/join/" . $token;

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
}

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
            'expires_days' => 'nullable|integer'
        ]);

        $token = Str::random(40);
        
        $invitation = Invitation::create([
            'email' => $request->email,
            'token' => $token,
            'role' => $request->role,
            'allowed_apps' => $request->allowed_apps ?? ['ebm-app'],
            'created_by' => $request->user()->id,
            'expires_at' => Carbon::now()->addDays($request->expires_days ?? 7),
        ]);

        // In production, we would send an email here.
        // For now, we return the join link for the Super Admin to copy.
        $joinLink = config('app.url') . "/join?token=" . $token;

        return response()->json([
            'message' => 'Invitation generated successfully',
            'invitation_link' => $joinLink,
            'token' => $token
        ]);
    }

    /**
     * Get all active system users and their devices.
     */
    public function systemUsers()
    {
        $users = User::with(['companies', 'devices'])->get();
        return response()->json($users);
    }
}

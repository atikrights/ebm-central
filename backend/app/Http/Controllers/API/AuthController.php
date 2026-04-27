<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\Invitation;
use App\Models\AuditLog;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Auth;
use App\Models\LoginSecurity;
use Carbon\Carbon;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\Cache;
use App\Events\UserCreated;
use App\Services\EncryptionService;


class AuthController extends Controller
{
    private EncryptionService $crypto;

    public function __construct(EncryptionService $crypto)
    {
        $this->crypto = $crypto;
    }

    // ─── IP Block Helpers ────────────────────────────────────────────────

    private function checkIpBlock($ip)
    {
        $security = LoginSecurity::where('ip_address', $ip)->first();
        if ($security && $security->blocked_until && Carbon::now()->lessThan($security->blocked_until)) {
            return $security->blocked_until;
        }
        return null;
    }

    private function recordFailedAttempt($ip)
    {
        $security = LoginSecurity::firstOrCreate(['ip_address' => $ip]);
        $security->attempts += 1;
        if ($security->attempts >= 5) {
            $security->blocked_until = Carbon::now()->addHours(24);
        }
        $security->save();
    }

    private function resetAttempts($ip)
    {
        LoginSecurity::where('ip_address', $ip)->update(['attempts' => 0, 'blocked_until' => null]);
    }

    // ─── Verify Triple Security Keys ─────────────────────────────────────

    public function verifyKeys(Request $request)
    {
        $ip = $request->ip();

        // 1. IP Block check
        $blockedUntil = $this->checkIpBlock($ip);
        if ($blockedUntil) {
            AuditLog::warning('ip_blocked_attempt', 'Blocked IP attempted key verification', [
                'metadata' => ['blocked_until' => $blockedUntil->toDateTimeString()],
            ], null, $request);

            return response()->json([
                'message'      => 'Your IP is blocked for 24 hours due to multiple failed attempts.',
                'blocked_until' => $blockedUntil->toDateTimeString(),
                'redirect_url' => 'https://atikrights.com',
            ], 403);
        }

        // 2. User lookup
        $user = User::where('email', $request->email)->first();
        if (!$user || $user->role !== 'super_admin') {
            $this->recordFailedAttempt($ip);
            AuditLog::critical('key_verify_failed', 'Super admin key verification failed — user not found or wrong role', [
                'target_email' => $request->email,
                'metadata'     => ['reason' => 'user_not_found_or_role_mismatch'],
            ], null, $request);

            return response()->json(['message' => 'Unauthorized access'], 401);
        }

        // 3. Verify encrypted keys
        // The Flutter app sends AES-256-CBC encrypted keys.
        // The database also stores AES-256-CBC encrypted keys.
        // We compare encrypted == encrypted (no decryption needed).
        $keysMatch = $this->crypto->verifyEncrypted($request->key_1 ?? '', $user->key_1 ?? '')
                  && $this->crypto->verifyEncrypted($request->key_2 ?? '', $user->key_2 ?? '')
                  && $this->crypto->verifyEncrypted($request->key_3 ?? '', $user->key_3 ?? '');

        if (!$keysMatch) {
            $this->recordFailedAttempt($ip);
            AuditLog::critical('key_verify_failed', 'Super admin triple-key verification failed', [
                'metadata' => ['reason' => 'key_mismatch'],
            ], $user, $request);

            return response()->json(['message' => 'Security keys verification failed'], 403);
        }

        // 4. All keys correct — issue gate token
        $gateToken = Str::random(60);
        Cache::put('gate_token_' . $gateToken, $user->id, now()->addMinutes(5));

        AuditLog::info('key_verify_success', 'Super admin triple-key verification passed — gate token issued', [
            'metadata' => ['gate_token_expires_in' => '5 minutes'],
        ], $user, $request);

        return response()->json([
            'message'    => 'Master keys authorized',
            'gate_token' => $gateToken,
        ]);
    }

    // ─── Super Admin Login ────────────────────────────────────────────────

    public function login(Request $request)
    {
        $ip = $request->ip();

        $blockedUntil = $this->checkIpBlock($ip);
        if ($blockedUntil) {
            return response()->json(['message' => 'IP Blocked', 'redirect_url' => 'https://atikrights.com'], 403);
        }

        // 1. Initial Identity Check (Email only)
        $user = User::where('email', $request->email)->first();
        if (!$user) {
            $this->recordFailedAttempt($ip);
            return response()->json(['message' => 'Invalid credentials'], 401);
        }

        // 2. Role Guard: EBM Central is for ADMIN and SUPER_ADMIN only
        if (!in_array($user->role, ['admin', 'super_admin'])) {
            AuditLog::warning('login_denied', "Access denied for role: {$user->role}", ['email' => $user->email], $user, $request);
            return response()->json(['message' => 'Access restricted to administrators only.'], 403);
        }

        // 3. Security Gate for SUPER_ADMIN
        if ($user->role === 'super_admin') {
            $gateToken = $request->gate_token;
            if (!$gateToken || Cache::get('gate_token_' . $gateToken) != $user->id) {
                $this->recordFailedAttempt($ip);
                AuditLog::critical('login_failed', 'Super Admin login attempt without valid gate token', [], $user, $request);
                return response()->json(['message' => 'Triple-key gate authorization required for Super Admin'], 403);
            }
            Cache::forget('gate_token_' . $gateToken);
        }

        // 4. Password Verification
        if (!Hash::check($request->password, $user->password)) {
            $this->recordFailedAttempt($ip);
            AuditLog::critical('login_failed', 'Identity verification failed (password mismatch)', [], $user, $request);
            return response()->json(['message' => 'Invalid credentials'], 401);
        }

        // Success
        $this->resetAttempts($ip);
        $token = $user->createToken('auth_token')->plainTextToken;

        AuditLog::info('login_success', "{$user->role} logged in successfully", [], $user, $request);

        return response()->json([
            'access_token' => $token,
            'token_type'   => 'Bearer',
            'user'         => $user,
        ]);
    }

    // ─── Invitation-Based Registration ───────────────────────────────────

    public function register(Request $request)
    {
        $request->validate([
            'name'             => 'required|string|max:255',
            'email'            => 'required|string|email|max:255|unique:users',
            'password'         => 'required|string|min:6|confirmed',
            'invitation_token' => 'required|string',
        ]);

        $invitation = Invitation::where('token', $request->invitation_token)
            ->where('email', $request->email)
            ->whereNull('used_at')
            ->where('expires_at', '>', Carbon::now())
            ->first();

        if (!$invitation) {
            AuditLog::warning('registration_failed', 'Registration attempt with invalid invitation', [
                'target_email' => $request->email,
                'metadata'     => ['reason' => 'invalid_or_expired_invitation'],
            ], null, $request);

            return response()->json(['message' => 'Invalid or expired invitation'], 400);
        }

        if ($invitation->role === 'super_admin') {
            return response()->json(['message' => 'Super Admin cannot be created via invitation'], 403);
        }

        $user = User::create([
            'name'     => $request->name,
            'email'    => $request->email,
            'password' => Hash::make($request->password),
            'role'     => $invitation->role,
        ]);

        $invitation->update(['used_at' => Carbon::now()]);
        event(new UserCreated($user));

        AuditLog::info('user_registered', "New user registered via invitation: {$user->email}", [
            'target'      => $user,
            'target_type' => 'User',
            'metadata'    => ['role' => $user->role, 'invitation_id' => $invitation->id],
        ], null, $request);

        $token = $user->createToken('auth_token')->plainTextToken;

        return response()->json([
            'access_token' => $token,
            'token_type'   => 'Bearer',
            'user'         => $user,
        ]);
    }

    // ─── Manual User Creation (Super Admin Only) ──────────────────────────

    public function manualCreate(Request $request)
    {
        $request->validate([
            'name'     => 'required|string|max:255',
            'email'    => 'required|string|email|max:255|unique:users',
            'password' => 'required|string|min:6',
            'role'     => 'required|in:super_admin,admin,manager,staff',
        ]);

        // Keys arrive AES-256 encrypted from the Flutter Super Admin app.
        // Store them as-is (encrypted) in the database.
        $user = User::create([
            'name'     => $request->name,
            'email'    => $request->email,
            'password' => Hash::make($request->password),
            'role'     => $request->role,
            'key_1'    => $request->key_1 ?? null, // Already AES-256 encrypted
            'key_2'    => $request->key_2 ?? null,
            'key_3'    => $request->key_3 ?? null,
        ]);

        event(new UserCreated($user));

        // Get the acting super admin from the request token
        $actor = $request->user();

        AuditLog::critical('user_created', "Manual user creation: {$user->email} as {$user->role}", [
            'target'      => $user,
            'target_type' => 'User',
            'metadata'    => [
                'new_role'   => $user->role,
                'has_keys'   => $request->role === 'super_admin',
            ],
        ], $actor, $request);

        return response()->json([
            'message' => 'User created successfully',
            'user'    => $user,
        ]);
    }

    // ─── Logout ───────────────────────────────────────────────────────────

    public function logout(Request $request)
    {
        $user = $request->user();
        AuditLog::info('logout', 'User logged out', [], $user, $request);

        $request->user()->currentAccessToken()->delete();
        return response()->json(['message' => 'Logged out successfully']);
    }

    public function user(Request $request)
    {
        return response()->json($request->user());
    }
}

<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use Illuminate\Http\Request;

class AuditLogController extends Controller
{
    /**
     * GET /api/governance/audit-logs
     * 
     * Returns paginated audit logs for the Security Timeline screen.
     * Accessible by Super Admin only (enforced in routes/api.php).
     */
    public function index(Request $request)
    {
        $query = AuditLog::query()->orderByDesc('created_at');

        // Filter by severity
        if ($request->filled('severity')) {
            $query->where('severity', $request->severity);
        }

        // Filter by event type
        if ($request->filled('event_type')) {
            $query->where('event_type', $request->event_type);
        }

        // Filter by actor email
        if ($request->filled('actor_email')) {
            $query->where('actor_email', 'like', '%' . $request->actor_email . '%');
        }

        // Filter by IP
        if ($request->filled('ip_address')) {
            $query->where('ip_address', $request->ip_address);
        }

        // Date range
        if ($request->filled('from')) {
            $query->whereDate('created_at', '>=', $request->from);
        }
        if ($request->filled('to')) {
            $query->whereDate('created_at', '<=', $request->to);
        }

        $logs = $query->paginate($request->get('per_page', 50));

        return response()->json($logs);
    }

    /**
     * GET /api/governance/audit-logs/stats
     * Returns summary stats for the Security Timeline dashboard cards.
     */
    public function stats()
    {
        return response()->json([
            'total'           => AuditLog::count(),
            'critical_today'  => AuditLog::where('severity', 'critical')
                                    ->whereDate('created_at', today())
                                    ->count(),
            'login_success'   => AuditLog::where('event_type', 'login_success')->count(),
            'login_failed'    => AuditLog::where('event_type', 'login_failed')->count(),
            'key_verify_fail' => AuditLog::where('event_type', 'key_verify_failed')->count(),
            'users_created'   => AuditLog::where('event_type', 'user_created')->count(),
        ]);
    }
}

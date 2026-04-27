<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * AuditLog Model — WRITE-ONLY (Immutable)
 * 
 * IMPORTANT: Never call ->update() or ->delete() on this model.
 * All security events should be logged via AuditLog::record().
 */
class AuditLog extends Model
{
    // Disable updated_at — audit logs are immutable
    const UPDATED_AT = null;

    protected $fillable = [
        'user_id',
        'actor_name',
        'actor_email',
        'actor_role',
        'event_type',
        'description',
        'target_type',
        'target_id',
        'target_email',
        'ip_address',
        'user_agent',
        'metadata',
        'severity',
    ];

    protected $casts = [
        'metadata'   => 'array',
        'created_at' => 'datetime',
    ];

    /**
     * Central static method to write an immutable audit event.
     * Use this everywhere instead of AuditLog::create() directly.
     * 
     * @param string      $eventType   e.g. 'login_success', 'key_verify_failed'
     * @param string      $description Human-readable description
     * @param array       $context     Optional: target, metadata, severity, etc.
     * @param User|null   $actor       The authenticated user (null for unauthenticated events)
     * @param \Illuminate\Http\Request|null $request
     */
    public static function record(
        string $eventType,
        string $description,
        array  $context = [],
        ?User  $actor = null,
        $request = null
    ): self {
        $data = [
            'event_type'  => $eventType,
            'description' => $description,
            'severity'    => $context['severity'] ?? 'info',
        ];

        // Actor info (snapshot — preserved even if user is later deleted)
        if ($actor) {
            $data['user_id']     = $actor->id;
            $data['actor_name']  = $actor->name;
            $data['actor_email'] = $actor->email;
            $data['actor_role']  = $actor->role;
        }

        // Target info
        if (isset($context['target'])) {
            $target = $context['target'];
            $data['target_type']  = $context['target_type'] ?? get_class($target);
            $data['target_id']    = $target->id ?? null;
            $data['target_email'] = $target->email ?? null;
        }
        if (isset($context['target_email'])) {
            $data['target_email'] = $context['target_email'];
        }

        // Request context
        if ($request) {
            $data['ip_address'] = $request->ip();
            $data['user_agent'] = $request->userAgent();
        }

        // Extra metadata
        if (isset($context['metadata'])) {
            $data['metadata'] = $context['metadata'];
        }

        return static::create($data);
    }

    // ─── Severity Helpers ───────────────────────────────────────────────

    public static function info(string $event, string $desc, array $ctx = [], $actor = null, $req = null): self
    {
        return static::record($event, $desc, array_merge($ctx, ['severity' => 'info']), $actor, $req);
    }

    public static function warning(string $event, string $desc, array $ctx = [], $actor = null, $req = null): self
    {
        return static::record($event, $desc, array_merge($ctx, ['severity' => 'warning']), $actor, $req);
    }

    public static function critical(string $event, string $desc, array $ctx = [], $actor = null, $req = null): self
    {
        return static::record($event, $desc, array_merge($ctx, ['severity' => 'critical']), $actor, $req);
    }
}

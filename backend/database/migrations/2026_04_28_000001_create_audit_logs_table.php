<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * IMMUTABLE AUDIT LOG TABLE
     * 
     * This table is WRITE-ONLY. No UPDATE or DELETE is ever performed on it.
     * Every sensitive action in the EBM ecosystem is recorded here permanently.
     * 
     * Recorded Events (event_type):
     *   - login_success / login_failed / logout
     *   - key_verify_success / key_verify_failed
     *   - user_created / user_updated / user_deleted
     *   - role_changed
     *   - invitation_generated / invitation_used
     *   - ip_blocked
     *   - link_generated
     */
    public function up(): void
    {
        Schema::create('audit_logs', function (Blueprint $table) {
            $table->id();
            
            // Who did it (null for unauthenticated attempts)
            $table->unsignedBigInteger('user_id')->nullable();
            $table->string('actor_name')->nullable();   // Name snapshot at time of event
            $table->string('actor_email')->nullable();  // Email snapshot at time of event
            $table->string('actor_role')->nullable();   // Role snapshot at time of event

            // What happened
            $table->string('event_type', 80)->index(); // e.g. 'login_success', 'key_verify_failed'
            $table->string('description')->nullable();  // Human-readable description
            
            // Target (optional — who/what was affected)
            $table->string('target_type')->nullable();  // e.g. 'User', 'Invitation'
            $table->unsignedBigInteger('target_id')->nullable();
            $table->string('target_email')->nullable();

            // Context
            $table->string('ip_address', 45)->nullable()->index();
            $table->text('user_agent')->nullable();
            $table->json('metadata')->nullable(); // Extra data (e.g. old/new role, token expiry)

            // Severity level: info | warning | critical
            $table->enum('severity', ['info', 'warning', 'critical'])->default('info')->index();

            // Timestamps (created_at is the event time, updated_at is intentionally omitted)
            $table->timestamp('created_at')->useCurrent()->index();
            
            // Foreign key (soft reference — we keep log even if user is deleted)
            $table->index(['user_id', 'event_type']);
        });

        // SECURITY: Revoke DELETE and UPDATE privileges on this table at the DB level.
        // Run this manually on your MySQL server as root:
        //   REVOKE DELETE, UPDATE ON ebm_central.audit_logs FROM 'your_db_user'@'%';
        // This makes logs truly immutable even if the PHP application is compromised.
    }

    public function down(): void
    {
        Schema::dropIfExists('audit_logs');
    }
};

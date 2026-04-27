<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('mail_automations', function (Blueprint $label) {
            $label->id();
            $label->foreignId('user_id')->constrained()->onDelete('cascade');
            $label->string('name'); // e.g. "Weekly Report"
            $label->string('to'); // comma separated emails or department ID
            $label->string('subject');
            $label->text('body');
            $label->string('trigger_type'); // e.g. "schedule", "event"
            $label->string('schedule_time')->nullable(); // e.g. "09:00"
            $label->string('schedule_days')->nullable(); // e.g. "Mon,Wed,Fri"
            $label->boolean('is_active')->default(true);
            $label->timestamp('last_run_at')->nullable();
            $label->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('mail_automations');
    }
};

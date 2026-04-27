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
        Schema::create('global_ai_guidelines', function (Blueprint $label) {
            $label->id();
            $label->string('title');
            $label->text('content'); // The guideline text
            $label->boolean('is_active')->default(true);
            $label->integer('priority')->default(0);
            $label->timestamps();
        });

        Schema::create('ai_usage_logs', function (Blueprint $label) {
            $label->id();
            $label->foreignId('user_id')->constrained()->onDelete('cascade');
            $label->string('feature'); // e.g. "mail_compose"
            $label->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('ai_usage_logs');
        Schema::dropIfExists('global_ai_guidelines');
    }
};

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
        Schema::table('global_ai_guidelines', function (Blueprint $table) {
            $table->longText('content')->change();
            $table->longText('short_description')->nullable()->change();
            $table->longText('topic_description')->nullable()->change();
            $table->longText('guide_policy')->nullable()->change();
            $table->longText('guide_note')->nullable()->change();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('global_ai_guidelines', function (Blueprint $table) {
            $table->text('content')->change();
            $table->text('short_description')->nullable()->change();
            $table->text('topic_description')->nullable()->change();
            $table->text('guide_policy')->nullable()->change();
            $table->text('guide_note')->nullable()->change();
        });
    }
};

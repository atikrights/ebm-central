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
            $table->string('type')->default('mail')->after('id');
        });
        Schema::table('ai_configs', function (Blueprint $table) {
            $table->string('type')->default('mail')->after('id');
        });
    }

    public function down(): void
    {
        Schema::table('global_ai_guidelines', function (Blueprint $table) {
            $table->dropColumn('type');
        });
        Schema::table('ai_configs', function (Blueprint $table) {
            $table->dropColumn('type');
        });
    }
};

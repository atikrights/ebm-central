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
        Schema::create('login_security', function (Blueprint $table) {
            $table->id();
            $table->string('ip_address')->unique();
            $table->integer('attempts')->default(0);
            $table->timestamp('blocked_until')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('login_security');
    }
};

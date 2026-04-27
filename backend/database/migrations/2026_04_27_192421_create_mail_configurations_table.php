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
        Schema::create('mail_configurations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->string('email')->unique();
            $table->text('password'); // Encrypted
            $table->string('imap_host')->default('imap.hostinger.com');
            $table->integer('imap_port')->default(993);
            $table->string('imap_encryption')->default('ssl');
            $table->string('smtp_host')->default('smtp.hostinger.com');
            $table->integer('smtp_port')->default(465);
            $table->string('smtp_encryption')->default('ssl');
            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('mail_configurations');
    }
};

<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('transactions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->onDelete('cascade');
            $table->foreignId('task_id')->nullable()->constrained()->onDelete('set null'); // Link to income/expense task
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->decimal('amount', 15, 2);
            $table->enum('type', ['credit', 'debit']);
            $table->string('category', 100)->nullable();
            $table->text('notes')->nullable();
            $table->dateTime('transaction_date')->useCurrent();
            $table->timestamps();
            
            $table->index(['company_id', 'transaction_date']);
        });

        Schema::create('messages', function (Blueprint $table) {
            $table->id();
            $table->foreignId('sender_id')->constrained('users')->onDelete('cascade');
            $table->foreignId('receiver_id')->nullable()->constrained('users')->onDelete('cascade'); // Null if group/channel
            $table->foreignId('company_id')->constrained()->onDelete('cascade');
            $table->text('content');
            $table->enum('type', ['text', 'image', 'file', 'system'])->default('text');
            $table->string('attachment_path')->nullable();
            $table->boolean('is_read')->default(false);
            $table->timestamps();
            
            $table->index(['sender_id', 'created_at']);
        });

        Schema::create('meetings', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->onDelete('cascade');
            $table->foreignId('host_id')->constrained('users')->onDelete('cascade');
            $table->string('title');
            $table->text('notes')->nullable();
            $table->dateTime('scheduled_at');
            $table->integer('duration_minutes')->default(30);
            $table->string('join_link')->nullable();
            $table->enum('status', ['scheduled', 'ongoing', 'completed', 'cancelled'])->default('scheduled');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('meetings');
        Schema::dropIfExists('messages');
        Schema::dropIfExists('transactions');
    }
};

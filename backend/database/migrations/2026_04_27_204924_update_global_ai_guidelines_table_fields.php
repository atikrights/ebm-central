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
        Schema::table('global_ai_guidelines', function (Blueprint $label) {
            $label->string('guide_id', 8)->unique()->after('id');
            $label->text('short_description')->nullable()->after('title');
            $label->string('topic')->nullable()->after('short_description');
            $label->text('topic_description')->nullable()->after('topic');
            $label->text('guide_policy')->nullable()->after('content');
            $label->text('guide_note')->nullable()->after('guide_policy');
        });

        Schema::create('ai_configs', function (Blueprint $label) {
            $label->id();
            $label->string('model_name'); // e.g. "gemini-pro", "gpt-4"
            $label->string('api_key')->nullable();
            $label->string('base_url')->nullable();
            $label->boolean('is_active')->default(false);
            $label->json('settings')->nullable(); // temperature, max_tokens, etc.
            $label->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('ai_configs');
        Schema::table('global_ai_guidelines', function (Blueprint $label) {
            $label->dropColumn(['guide_id', 'short_description', 'topic', 'topic_description', 'guide_policy', 'guide_note']);
        });
    }
};

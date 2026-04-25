<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        Schema::create('database_configs', function (Blueprint $box) {
            $box->id();
            $box->string('name');
            $box->string('host');
            $box->integer('port')->default(3306);
            $box->string('database_name');
            $box->text('username'); // Text because it's encrypted
            $box->text('password'); // Text because it's encrypted
            $box->boolean('is_active')->default(true);
            $box->json('metadata')->nullable();
            $box->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        Schema::dropIfExists('database_configs');
    }
};

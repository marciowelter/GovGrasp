<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class () extends Migration {
    public function up(): void
    {
        Schema::create('worker_runs', function (Blueprint $table) {
            $table->id();
            $table->string('status', 50)->default('running')->index();
            $table->unsignedInteger('opportunities_fetched')->default(0);
            $table->unsignedInteger('opportunities_qualified')->default(0);
            $table->text('error_message')->nullable();
            $table->timestampTz('started_at')->nullable();
            $table->timestampTz('completed_at')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('worker_runs');
    }
};

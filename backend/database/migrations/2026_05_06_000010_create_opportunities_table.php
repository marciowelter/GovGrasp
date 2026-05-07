<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class () extends Migration {
    public function up(): void
    {
        if (Schema::hasTable('opportunities')) {
            return;
        }

        Schema::create('opportunities', function (Blueprint $table) {
            $table->id();
            $table->string('ocid', 255)->unique();
            $table->string('title', 500);
            $table->text('description')->nullable();
            $table->string('buyer_name', 255)->nullable();
            $table->decimal('value_amount', 15, 2)->nullable();
            $table->string('value_currency', 10)->default('GBP');
            $table->timestampTz('deadline')->nullable();
            $table->timestampTz('published_at')->nullable();
            $table->string('source', 50)->default('contracts_finder');
            $table->string('status', 50)->default('new')->index();
            $table->boolean('qualified')->nullable();
            $table->unsignedInteger('ai_score')->nullable();
            $table->text('ai_reasoning')->nullable();
            $table->string('framework', 100)->nullable()->index();
            $table->string('raw_s3_key', 500)->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('opportunities');
    }
};

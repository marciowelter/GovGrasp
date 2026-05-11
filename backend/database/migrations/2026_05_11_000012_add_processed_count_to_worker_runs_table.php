<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class () extends Migration {
    public function up(): void
    {
        if (!Schema::hasTable('worker_runs') || Schema::hasColumn('worker_runs', 'processed_count')) {
            return;
        }

        Schema::table('worker_runs', function (Blueprint $table): void {
            $table->unsignedInteger('processed_count')->default(0)->after('opportunities_fetched');
        });
    }

    public function down(): void
    {
        if (!Schema::hasTable('worker_runs') || !Schema::hasColumn('worker_runs', 'processed_count')) {
            return;
        }

        Schema::table('worker_runs', function (Blueprint $table): void {
            $table->dropColumn('processed_count');
        });
    }
};

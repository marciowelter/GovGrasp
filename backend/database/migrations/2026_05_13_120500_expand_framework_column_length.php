<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class () extends Migration {
    public function up(): void
    {
        if (!Schema::hasTable('opportunities')) {
            return;
        }

        // Só executa o ALTER COLUMN se não for SQLite
        if (DB::getDriverName() !== 'sqlite') {
            DB::statement('ALTER TABLE opportunities ALTER COLUMN framework TYPE VARCHAR(500)');
        }
    }

    public function down(): void
    {
        if (!Schema::hasTable('opportunities')) {
            return;
        }

        // Só executa o ALTER COLUMN se não for SQLite
        if (DB::getDriverName() !== 'sqlite') {
            DB::statement('ALTER TABLE opportunities ALTER COLUMN framework TYPE VARCHAR(100)');
        }
    }
};

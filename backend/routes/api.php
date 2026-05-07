<?php

use App\Http\Controllers\OpportunityController;
use App\Http\Controllers\WorkerController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function (): void {
    // Opportunities
    Route::get('opportunities/stats', [OpportunityController::class, 'stats']);
    Route::get('opportunities', [OpportunityController::class, 'index']);
    Route::get('opportunities/{opportunity}', [OpportunityController::class, 'show']);

    // Worker pipeline
    Route::post('worker/trigger', [WorkerController::class, 'trigger']);
    Route::get('worker/status', [WorkerController::class, 'status']);
});

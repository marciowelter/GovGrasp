<?php

namespace App\Http\Controllers;

use App\Models\WorkerRun;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Http;

class WorkerController extends Controller
{
    private string $workerUrl;

    public function __construct()
    {
        $this->workerUrl = rtrim(config('services.worker.url', 'http://worker:8001'), '/');
    }

    public function trigger(): JsonResponse
    {
        try {
            $response = Http::timeout(5)->post("{$this->workerUrl}/trigger");

            return response()->json([
                'status' => 'triggered',
                'worker_response' => $response->json(),
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'status' => 'error',
                'message' => 'Worker service unreachable: ' . $e->getMessage(),
            ], 503);
        }
    }

    public function status(): JsonResponse
    {
        $lastRun = WorkerRun::latest()->first();

        $workerLive = null;
        try {
            $workerLive = Http::timeout(3)->get("{$this->workerUrl}/status")->json();
        } catch (\Exception) {
            // Worker may not be running locally — that is fine
        }

        return response()->json([
            'last_run' => $lastRun,
            'worker_status' => $workerLive,
        ]);
    }
}

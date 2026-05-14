<?php

namespace Tests\Feature\Controllers;

use App\Models\WorkerRun;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class WorkerControllerTest extends TestCase
{
    use RefreshDatabase;

    public function test_status_returns_last_run()
    {
        $run = WorkerRun::factory()->create();
        $response = $this->getJson('/api/v1/worker/status');
        $response->assertOk()->assertJsonFragment(['id' => $run->id]);
    }

    public function test_trigger_success()
    {
        Http::fake([
            '*/trigger' => Http::response(['ok' => true], 200),
        ]);
        $response = $this->postJson('/api/v1/worker/trigger', [
            'start_date' => '2024-01-01',
        ]);
        $response->assertOk()->assertJsonFragment(['status' => 'triggered']);
    }

    public function test_trigger_failure()
    {
        Http::fake([
            '*/trigger' => Http::response(null, 500),
        ]);
        $response = $this->postJson('/api/v1/worker/trigger', [
            'start_date' => '2024-01-01',
        ]);
        $response->assertStatus(503);
    }

    public function test_abort_success()
    {
        Http::fake([
            '*/abort' => Http::response(['ok' => true], 200),
        ]);
        $response = $this->postJson('/api/v1/worker/abort');
        $response->assertOk()->assertJsonFragment(['status' => 'ok']);
    }

    public function test_abort_failure()
    {
        Http::fake([
            '*/abort' => Http::response(null, 500),
        ]);
        $response = $this->postJson('/api/v1/worker/abort');
        $response->assertStatus(503);
    }
}

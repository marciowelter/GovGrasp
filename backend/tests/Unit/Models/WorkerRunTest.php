<?php

namespace Tests\Unit\Models;

use App\Models\WorkerRun;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class WorkerRunTest extends TestCase
{
    use RefreshDatabase;

    public function test_fillable_attributes()
    {
        $data = [
            'status' => 'done',
            'opportunities_fetched' => 10,
            'processed_count' => 8,
            'opportunities_qualified' => 5,
            'error_message' => 'none',
            'started_at' => now(),
            'completed_at' => now(),
        ];
        $run = WorkerRun::create($data);
        foreach ($data as $key => $value) {
            if (in_array($key, ['started_at', 'completed_at'])) {
                $this->assertEquals($value->format('Y-m-d H:i'), $run->{$key}->format('Y-m-d H:i'));
            } else {
                $this->assertEquals($run->{$key}, $value);
            }
        }
    }

    public function test_casts()
    {
        $run = WorkerRun::factory()->create([
            'started_at' => now(),
            'completed_at' => now(),
        ]);
        $this->assertInstanceOf(\Illuminate\Support\Carbon::class, $run->started_at);
        $this->assertInstanceOf(\Illuminate\Support\Carbon::class, $run->completed_at);
    }
}

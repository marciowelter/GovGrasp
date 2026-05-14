<?php

namespace Database\Factories;

use App\Models\WorkerRun;
use Illuminate\Database\Eloquent\Factories\Factory;

class WorkerRunFactory extends Factory
{
    protected $model = WorkerRun::class;

    public function definition(): array
    {
        return [
            'status' => $this->faker->randomElement(['done', 'running', 'failed']),
            'opportunities_fetched' => $this->faker->numberBetween(0, 100),
            'processed_count' => $this->faker->numberBetween(0, 100),
            'opportunities_qualified' => $this->faker->numberBetween(0, 100),
            'error_message' => null,
            'started_at' => now()->subMinutes(rand(1, 60)),
            'completed_at' => now(),
        ];
    }
}

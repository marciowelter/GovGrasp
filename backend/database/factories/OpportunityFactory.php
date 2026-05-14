<?php

namespace Database\Factories;

use App\Models\Opportunity;
use Illuminate\Database\Eloquent\Factories\Factory;

class OpportunityFactory extends Factory
{
    protected $model = Opportunity::class;

    public function definition(): array
    {
        return [
            'ocid' => $this->faker->uuid(),
            'title' => $this->faker->sentence(3),
            'description' => $this->faker->paragraph(),
            'buyer_name' => $this->faker->company(),
            'value_amount' => $this->faker->randomFloat(2, 1000, 100000),
            'value_currency' => 'BRL',
            'deadline' => now()->addDays(rand(1, 30)),
            'published_at' => now()->subDays(rand(1, 30)),
            'source' => 'src',
            'status' => $this->faker->randomElement(['new', 'qualified', 'rejected']),
            'qualified' => $this->faker->boolean(),
            'ai_score' => $this->faker->numberBetween(0, 100),
            'ai_reasoning' => $this->faker->sentence(),
            'framework' => $this->faker->word(),
            'raw_s3_key' => $this->faker->sha1(),
        ];
    }
}

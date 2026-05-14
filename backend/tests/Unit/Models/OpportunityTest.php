<?php

namespace Tests\Unit\Models;

use App\Models\Opportunity;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class OpportunityTest extends TestCase
{
    use RefreshDatabase;

    public function test_fillable_attributes()
    {
        $data = [
            'ocid' => '123',
            'title' => 'Test',
            'description' => 'Desc',
            'buyer_name' => 'Buyer',
            'value_amount' => 1000.50,
            'value_currency' => 'BRL',
            'deadline' => now(),
            'published_at' => now(),
            'source' => 'src',
            'status' => 'new',
            'qualified' => true,
            'ai_score' => 90,
            'ai_reasoning' => 'AI',
            'framework' => 'FW',
            'raw_s3_key' => 'key',
        ];
        $opp = Opportunity::create($data);
        foreach ($data as $key => $value) {
            if (in_array($key, ['deadline', 'published_at'])) {
                $this->assertEquals($value->format('Y-m-d H:i'), $opp->{$key}->format('Y-m-d H:i'));
            } else {
                $this->assertEquals($opp->{$key}, $value);
            }
        }
    }

    public function test_scope_qualified()
    {
        Opportunity::factory()->create(['status' => 'qualified']);
        Opportunity::factory()->create(['status' => 'rejected']);
        $this->assertEquals(1, Opportunity::qualified()->count());
    }

    public function test_scope_search()
    {
        Opportunity::factory()->create(['title' => 'UniqueTitle']);
        $this->assertEquals(1, Opportunity::search('UniqueTitle')->count());
    }
}

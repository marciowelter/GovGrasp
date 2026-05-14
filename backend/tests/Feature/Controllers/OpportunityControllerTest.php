<?php

namespace Tests\Feature\Controllers;

use App\Models\Opportunity;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class OpportunityControllerTest extends TestCase
{
    use RefreshDatabase;

    public function test_index_returns_opportunities()
    {
        Opportunity::factory()->count(3)->create();
        $response = $this->getJson('/api/v1/opportunities');
        $response->assertOk()->assertJsonStructure(['data']);
    }

    public function test_show_returns_opportunity()
    {
        $opp = Opportunity::factory()->create();
        $response = $this->getJson("/api/v1/opportunities/{$opp->id}");
        $response->assertOk()->assertJsonFragment(['id' => $opp->id]);
    }

    public function test_stats_returns_stats()
    {
        Opportunity::factory()->count(2)->create(['status' => 'qualified']);
        Opportunity::factory()->count(1)->create(['status' => 'rejected']);
        $response = $this->getJson('/api/v1/opportunities/stats');
        $response->assertOk()->assertJsonStructure(['total', 'qualified', 'rejected', 'new', 'today', 'frameworks']);
    }

    public function test_delete_all_deletes_opportunities()
    {
        Opportunity::factory()->count(2)->create();
        $response = $this->deleteJson('/api/v1/opportunities');
        $response->assertOk();
        $this->assertEquals(0, Opportunity::count());
    }
}

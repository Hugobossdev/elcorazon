<?php

namespace Tests\Feature;

use Tests\TestCase;

class HealthTest extends TestCase
{
    public function test_api_root_returns_ok(): void
    {
        $this->getJson('/api')
            ->assertOk()
            ->assertJson(['status' => 'ok']);
    }

    public function test_protected_route_requires_authentication(): void
    {
        $this->getJson('/api/me')->assertUnauthorized();
    }
}

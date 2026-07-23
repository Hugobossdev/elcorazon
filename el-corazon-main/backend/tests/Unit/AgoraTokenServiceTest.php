<?php

namespace Tests\Unit;

use App\Services\Rtc\AgoraTokenService;
use PHPUnit\Framework\TestCase;

class AgoraTokenServiceTest extends TestCase
{
    public function test_it_builds_a_versioned_rtc_token(): void
    {
        $service = new AgoraTokenService(
            appId: '0123456789abcdef0123456789abcdef',
            appCertificate: 'fedcba9876543210fedcba9876543210',
        );

        $token = $service->buildRtcToken('canal-test', uid: 42, ttl: 3600);

        // Le token 006 commence par la version puis l'App ID.
        $this->assertStringStartsWith('0060123456789abcdef0123456789abcdef', $token);
        $this->assertTrue($service->isConfigured());
    }
}

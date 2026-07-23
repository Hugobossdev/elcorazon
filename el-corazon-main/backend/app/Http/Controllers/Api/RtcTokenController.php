<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\Rtc\AgoraTokenService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class RtcTokenController extends Controller
{
    public function __construct(private readonly AgoraTokenService $agora)
    {
    }

    /** Émet un token RTC Agora pour un canal donné. */
    public function token(Request $request): JsonResponse
    {
        if (! $this->agora->isConfigured()) {
            return response()->json(['message' => 'Agora non configuré côté serveur.'], 503);
        }

        $data = $request->validate([
            'channel' => ['required', 'string', 'max:64'],
            'uid' => ['nullable', 'integer', 'min:0'],
            'ttl' => ['nullable', 'integer', 'min:60', 'max:86400'],
        ]);

        $uid = $data['uid'] ?? 0;
        $token = $this->agora->buildRtcToken($data['channel'], $uid, $data['ttl'] ?? null);

        return response()->json([
            'data' => [
                'token' => $token,
                'channel' => $data['channel'],
                'uid' => $uid,
                'app_id' => config('services.agora.app_id'),
            ],
        ]);
    }
}

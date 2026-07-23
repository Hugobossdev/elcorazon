<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\Push\FcmService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PushController extends Controller
{
    public function __construct(private readonly FcmService $fcm)
    {
    }

    /** État de configuration FCM (diagnostic admin). */
    public function status(): JsonResponse
    {
        return response()->json(['data' => ['configured' => $this->fcm->isConfigured()]]);
    }

    /** Envoi d'un push de test vers un ou plusieurs tokens (admin / QA). */
    public function test(Request $request): JsonResponse
    {
        if (! $this->fcm->isConfigured()) {
            return response()->json(['message' => 'FCM non configuré côté serveur.'], 503);
        }

        $data = $request->validate([
            'tokens' => ['required', 'array', 'min:1'],
            'tokens.*' => ['string'],
            'title' => ['required', 'string', 'max:255'],
            'body' => ['required', 'string'],
            'data' => ['nullable', 'array'],
        ]);

        $results = [];
        foreach ($data['tokens'] as $token) {
            $results[] = [
                'token' => substr($token, 0, 12).'…',
                'sent' => $this->fcm->sendToToken($token, $data['title'], $data['body'], $data['data'] ?? []),
            ];
        }

        return response()->json(['data' => $results]);
    }
}

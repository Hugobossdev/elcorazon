<?php

namespace App\Services\Push;

use Firebase\JWT\JWT;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Envoi de notifications push via Firebase Cloud Messaging (API HTTP v1).
 *
 * L'authentification repose sur un compte de service Firebase (JSON) dont on
 * dérive un jeton OAuth2 (assertion JWT RS256 échangée contre un access token),
 * mis en cache pendant sa durée de validité.
 */
class FcmService
{
    private const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';
    private const TOKEN_URI = 'https://oauth2.googleapis.com/token';

    /** @return array<string, mixed>|null */
    private function credentials(): ?array
    {
        $raw = config('services.firebase.credentials');

        if (empty($raw)) {
            return null;
        }

        // Autorise soit un JSON inline, soit un chemin vers le fichier.
        if (is_string($raw) && is_file($raw)) {
            $raw = file_get_contents($raw);
        }

        $decoded = is_array($raw) ? $raw : json_decode((string) $raw, true);

        return is_array($decoded) ? $decoded : null;
    }

    public function isConfigured(): bool
    {
        return $this->credentials() !== null;
    }

    private function projectId(): ?string
    {
        return config('services.firebase.project_id')
            ?? ($this->credentials()['project_id'] ?? null);
    }

    private function accessToken(): ?string
    {
        $creds = $this->credentials();

        if ($creds === null) {
            return null;
        }

        return Cache::remember('fcm_access_token', 3300, function () use ($creds) {
            $now = time();
            $assertion = JWT::encode([
                'iss' => $creds['client_email'],
                'scope' => self::SCOPE,
                'aud' => self::TOKEN_URI,
                'iat' => $now,
                'exp' => $now + 3600,
            ], $creds['private_key'], 'RS256');

            $response = Http::asForm()->post(self::TOKEN_URI, [
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion' => $assertion,
            ]);

            return $response->json('access_token');
        });
    }

    /**
     * Envoie une notification à un token d'appareil.
     *
     * @param  array<string, string>  $data  Données personnalisées (payload silencieux).
     */
    public function sendToToken(string $deviceToken, string $title, string $body, array $data = []): bool
    {
        $accessToken = $this->accessToken();
        $projectId = $this->projectId();

        if ($accessToken === null || $projectId === null) {
            Log::warning('FCM non configuré : notification ignorée.', ['title' => $title]);

            return false;
        }

        $response = Http::withToken($accessToken)
            ->post("https://fcm.googleapis.com/v1/projects/{$projectId}/messages:send", [
                'message' => [
                    'token' => $deviceToken,
                    'notification' => [
                        'title' => $title,
                        'body' => $body,
                    ],
                    'data' => array_map('strval', $data),
                ],
            ]);

        if (! $response->successful()) {
            Log::warning('Échec envoi FCM', ['status' => $response->status(), 'body' => $response->body()]);
        }

        return $response->successful();
    }
}

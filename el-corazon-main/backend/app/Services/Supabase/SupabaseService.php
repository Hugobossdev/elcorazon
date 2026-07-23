<?php

namespace App\Services\Supabase;

use Illuminate\Http\Client\PendingRequest;
use Illuminate\Support\Facades\Http;

/**
 * Client léger pour l'API REST d'administration de Supabase (Auth Admin +
 * Storage), utilisé côté serveur avec la clé `service_role`.
 *
 * ⚠️ La clé service_role contourne le RLS : ne jamais l'exposer au client.
 */
class SupabaseService
{
    public function __construct(
        private readonly ?string $url = null,
        private readonly ?string $serviceRoleKey = null,
    ) {
    }

    private function baseUrl(): string
    {
        return rtrim($this->url ?? (string) config('services.supabase.url'), '/');
    }

    private function key(): string
    {
        return $this->serviceRoleKey ?? (string) config('services.supabase.service_role_key');
    }

    private function client(): PendingRequest
    {
        $key = $this->key();

        return Http::baseUrl($this->baseUrl())
            ->withHeaders([
                'apikey' => $key,
                'Authorization' => 'Bearer '.$key,
            ])
            ->acceptJson()
            ->timeout(15);
    }

    /**
     * Crée un utilisateur dans auth.users (email déjà confirmé).
     *
     * @param  array<string, mixed>  $metadata
     * @return array<string, mixed>
     */
    public function createAuthUser(string $email, string $password, array $metadata = []): array
    {
        return $this->client()
            ->post('/auth/v1/admin/users', [
                'email' => $email,
                'password' => $password,
                'email_confirm' => true,
                'user_metadata' => $metadata,
            ])
            ->throw()
            ->json();
    }

    /** Supprime un utilisateur auth par son id. */
    public function deleteAuthUser(string $authUserId): bool
    {
        return $this->client()
            ->delete("/auth/v1/admin/users/{$authUserId}")
            ->successful();
    }

    /**
     * Génère une URL signée pour un objet privé du Storage.
     *
     * @return array<string, mixed>
     */
    public function createSignedUrl(string $bucket, string $path, int $expiresIn = 3600): array
    {
        return $this->client()
            ->post("/storage/v1/object/sign/{$bucket}/{$path}", [
                'expiresIn' => $expiresIn,
            ])
            ->throw()
            ->json();
    }
}

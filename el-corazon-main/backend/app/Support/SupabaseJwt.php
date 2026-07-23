<?php

namespace App\Support;

use Firebase\JWT\JWT;
use Firebase\JWT\Key;
use Throwable;

/**
 * Vérifie et décode les JWT d'accès émis par Supabase Auth.
 *
 * Supabase signe ses tokens en HS256 avec le "JWT Secret" du projet
 * (Project Settings > API). Le backend partage ce secret pour authentifier
 * les requêtes venues des applications Flutter sans appeler Supabase.
 */
class SupabaseJwt
{
    public function __construct(
        private readonly string $secret,
        private readonly string $algorithm = 'HS256',
    ) {
    }

    /**
     * Décode le token et retourne le payload, ou lève une exception si invalide.
     *
     * @return array<string, mixed>
     */
    public function decode(string $token): array
    {
        if ($this->secret === '') {
            throw new \RuntimeException('SUPABASE_JWT_SECRET non configuré.');
        }

        $decoded = JWT::decode($token, new Key($this->secret, $this->algorithm));

        return json_decode(json_encode($decoded), true);
    }

    /**
     * Variante silencieuse : retourne null au lieu de lever une exception.
     *
     * @return array<string, mixed>|null
     */
    public function tryDecode(string $token): ?array
    {
        try {
            return $this->decode($token);
        } catch (Throwable) {
            return null;
        }
    }
}

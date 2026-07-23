<?php

namespace App\Providers;

use App\Models\User;
use App\Support\SupabaseJwt;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->singleton(SupabaseJwt::class, function () {
            return new SupabaseJwt(
                secret: (string) config('services.supabase.jwt_secret'),
            );
        });
    }

    public function boot(): void
    {
        // En test, le schéma Supabase n'existe pas : on reconstruit un sous-ensemble
        // suffisant en SQLite via des migrations dédiées, chargées avant les
        // migrations d'infrastructure auth (personal_access_tokens + auth fields).
        if ($this->app->environment('testing')) {
            $this->loadMigrationsFrom(base_path('tests/database/migrations'));
        }

        // Guard stateless : l'identité est portée par le JWT émis par Supabase Auth.
        // Le token est vérifié en HS256 avec le "JWT Secret" du projet, puis la ligne
        // applicative `users` est résolue via `auth_user_id` (= claim `sub`).
        Auth::viaRequest('supabase', function (Request $request): ?User {
            $token = $this->bearerToken($request);

            if ($token === null) {
                return null;
            }

            $payload = app(SupabaseJwt::class)->tryDecode($token);

            if ($payload === null || empty($payload['sub'])) {
                return null;
            }

            /** @var User|null $user */
            $user = User::query()
                ->where('auth_user_id', $payload['sub'])
                ->first();

            // On expose le payload brut pour les contrôleurs qui en ont besoin
            // (email, rôle Supabase, metadata) sans refaire de décodage.
            if ($user !== null) {
                $user->setSupabaseClaims($payload);
            }

            return $user;
        });
    }

    private function bearerToken(Request $request): ?string
    {
        $token = $request->bearerToken();

        return $token !== null && $token !== '' ? $token : null;
    }
}

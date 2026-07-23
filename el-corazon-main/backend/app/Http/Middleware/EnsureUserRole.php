<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Restreint une route à un ou plusieurs rôles applicatifs.
 *
 * Usage : ->middleware('role:admin') ou ->middleware('role:admin,delivery').
 * Doit être placé après `auth:sanctum`.
 */
class EnsureUserRole
{
    public function handle(Request $request, Closure $next, string ...$roles): Response
    {
        $user = $request->user();

        if ($user === null) {
            return response()->json(['message' => 'Non authentifié.'], 401);
        }

        if (! empty($roles) && ! in_array($user->role, $roles, true)) {
            return response()->json([
                'message' => 'Accès refusé : rôle insuffisant.',
                'required_roles' => $roles,
            ], 403);
        }

        return $next($request);
    }
}

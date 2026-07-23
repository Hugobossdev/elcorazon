<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Symfony\Component\HttpFoundation\Response;

/**
 * Exige un JWT Supabase valide correspondant à une ligne `users` existante.
 *
 * Le guard `supabase` (enregistré dans AppServiceProvider) fait le décodage ;
 * ce middleware se contente de rejeter les requêtes non authentifiées et de
 * fixer le guard par défaut pour la suite de la requête.
 */
class SupabaseAuthenticate
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = Auth::guard('supabase')->user();

        if ($user === null) {
            return response()->json([
                'message' => 'Non authentifié. Un jeton Supabase valide est requis.',
            ], 401);
        }

        // Rend $request->user() et auth()->user() disponibles sans préciser le guard.
        Auth::setUser($user);
        $request->setUserResolver(fn () => $user);

        return $next($request);
    }
}

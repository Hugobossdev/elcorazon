<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

/**
 * Authentification émise par Laravel (Sanctum, jetons personnels).
 *
 * Les applications Flutter s'authentifient via /auth/register et /auth/login,
 * puis envoient le jeton reçu en en-tête `Authorization: Bearer <token>`.
 */
class AuthController extends Controller
{
    /** Inscription d'un nouveau compte (client ou livreur). */
    public function register(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'phone' => ['required', 'string', 'max:32', 'unique:users,phone'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
            // L'auto-inscription en admin est interdite (compte créé par un admin).
            'role' => ['nullable', Rule::in(['client', 'delivery'])],
        ]);

        $user = User::create([
            'name' => $data['name'],
            'email' => $data['email'],
            'phone' => $data['phone'],
            'password' => $data['password'], // haché via cast 'hashed'
            'role' => $data['role'] ?? 'client',
            'is_active' => true,
        ]);

        $token = $user->createToken('api')->plainTextToken;

        return response()->json([
            'data' => $user,
            'token' => $token,
            'token_type' => 'Bearer',
        ], 201);
    }

    /** Connexion : renvoie un jeton Sanctum. */
    public function login(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
            'device_name' => ['nullable', 'string', 'max:255'],
        ]);

        $user = User::where('email', $data['email'])->first();

        if ($user === null || $user->password === null || ! Hash::check($data['password'], $user->password)) {
            throw ValidationException::withMessages([
                'email' => ['Identifiants invalides.'],
            ]);
        }

        if (! $user->is_active) {
            return response()->json(['message' => 'Compte désactivé.'], 403);
        }

        $user->update(['is_online' => true, 'last_seen' => now()]);

        $token = $user->createToken($data['device_name'] ?? 'api')->plainTextToken;

        return response()->json([
            'data' => $user,
            'token' => $token,
            'token_type' => 'Bearer',
        ]);
    }

    /**
     * Pont de migration : échange un jeton Supabase Auth (vérifié par le guard
     * `supabase`) contre un jeton Sanctum, sans mot de passe côté Laravel.
     * Permet aux comptes existants d'utiliser l'API pendant la bascule du
     * frontend. À retirer une fois la migration terminée.
     */
    public function exchange(Request $request): JsonResponse
    {
        $user = $request->user();
        $user->update(['is_online' => true, 'last_seen' => now()]);

        $token = $user->createToken('supabase-bridge')->plainTextToken;

        return response()->json([
            'data' => $user,
            'token' => $token,
            'token_type' => 'Bearer',
        ]);
    }

    /** Déconnexion : révoque le jeton courant. */
    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();
        $request->user()->update(['is_online' => false, 'last_seen' => now()]);

        return response()->json(['message' => 'Déconnecté.']);
    }

    /** Révoque tous les jetons de l'utilisateur (déconnexion globale). */
    public function logoutAll(Request $request): JsonResponse
    {
        $request->user()->tokens()->delete();

        return response()->json(['message' => 'Déconnecté de tous les appareils.']);
    }

    /** Profil de l'utilisateur courant. */
    public function me(Request $request): JsonResponse
    {
        return response()->json([
            'data' => $request->user()->load('driver'),
        ]);
    }

    public function updateProfile(Request $request): JsonResponse
    {
        $user = $request->user();

        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'phone' => ['sometimes', 'string', 'max:32', Rule::unique('users', 'phone')->ignore($user->id)],
            'profile_image' => ['nullable', 'string'],
        ]);

        $user->update($data);

        return response()->json(['data' => $user]);
    }

    /** Change le mot de passe (vérifie l'actuel). */
    public function changePassword(Request $request): JsonResponse
    {
        $user = $request->user();

        $data = $request->validate([
            'current_password' => ['required', 'string'],
            'password' => ['required', 'string', 'min:8', 'confirmed'],
        ]);

        if ($user->password === null || ! Hash::check($data['current_password'], $user->password)) {
            throw ValidationException::withMessages([
                'current_password' => ['Mot de passe actuel incorrect.'],
            ]);
        }

        $user->update(['password' => $data['password']]);

        return response()->json(['message' => 'Mot de passe mis à jour.']);
    }

    /** Met à jour la présence (is_online / last_seen). */
    public function heartbeat(Request $request): JsonResponse
    {
        $user = $request->user();
        $user->update([
            'is_online' => $request->boolean('is_online', true),
            'last_seen' => now(),
        ]);

        return response()->json(['data' => ['is_online' => $user->is_online]]);
    }
}

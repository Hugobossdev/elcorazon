<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Driver;
use App\Services\Notifications\NotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/**
 * Gestion des livreurs côté administration + profil livreur (self-service).
 */
class DriverController extends Controller
{
    public function __construct(private readonly NotificationService $notifications)
    {
    }

    /** Liste des livreurs (admin), filtrable par statut de vérification / disponibilité. */
    public function index(Request $request): JsonResponse
    {
        $query = Driver::query()->with('user');

        if ($request->filled('verification_status')) {
            $query->where('verification_status', $request->input('verification_status'));
        }

        if ($request->boolean('available_only')) {
            $query->where('is_available', true)->where('status', 'available');
        }

        return response()->json($query->paginate($request->integer('per_page', 20)));
    }

    public function show(Driver $driver): JsonResponse
    {
        return response()->json(['data' => $driver->load('user')]);
    }

    /** Crée/complète le profil livreur de l'utilisateur courant. */
    public function upsertOwnProfile(Request $request): JsonResponse
    {
        $user = $request->user();
        abort_unless($user->isDriver(), 403, 'Seuls les livreurs peuvent créer un profil livreur.');

        $data = $request->validate([
            'profile_photo_url' => ['nullable', 'string'],
            'license_number' => ['nullable', 'string'],
            'id_number' => ['nullable', 'string'],
            'vehicle_type' => ['nullable', 'string'],
            'vehicle_number' => ['nullable', 'string'],
            'license_photo_url' => ['nullable', 'string'],
            'id_card_photo_url' => ['nullable', 'string'],
            'vehicle_photo_url' => ['nullable', 'string'],
        ]);

        $driver = Driver::updateOrCreate(['user_id' => $user->id], $data);

        return response()->json(['data' => $driver], 201);
    }

    /** Vérification d'un livreur par un admin. */
    public function verify(Request $request, Driver $driver): JsonResponse
    {
        $data = $request->validate([
            'verification_status' => ['required', Rule::in(['approved', 'rejected', 'pending'])],
            'verification_notes' => ['nullable', 'string'],
        ]);

        $driver->update([
            'verification_status' => $data['verification_status'],
            'verification_notes' => $data['verification_notes'] ?? null,
            'verified_by' => $request->user()->id,
            'verified_at' => now(),
        ]);

        $this->notifications->notify(
            userId: $driver->user_id,
            title: 'Statut de vérification',
            message: "Votre dossier livreur est : {$data['verification_status']}.",
            type: 'info',
            data: ['verification_status' => $data['verification_status']],
        );

        return response()->json(['data' => $driver->load('user')]);
    }
}

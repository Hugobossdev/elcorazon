<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Address;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class AddressController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        return response()->json([
            'data' => $request->user()->addresses()->orderByDesc('is_default')->get(),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $this->validateData($request);

        $address = DB::transaction(function () use ($request, $data) {
            if (! empty($data['is_default'])) {
                $request->user()->addresses()->update(['is_default' => false]);
            }

            return $request->user()->addresses()->create($data);
        });

        return response()->json(['data' => $address], 201);
    }

    public function update(Request $request, Address $address): JsonResponse
    {
        $this->authorizeOwner($request, $address);
        $data = $this->validateData($request, updating: true);

        DB::transaction(function () use ($request, $address, $data) {
            if (! empty($data['is_default'])) {
                $request->user()->addresses()->where('id', '!=', $address->id)->update(['is_default' => false]);
            }
            $address->update($data);
        });

        return response()->json(['data' => $address]);
    }

    public function destroy(Request $request, Address $address): JsonResponse
    {
        $this->authorizeOwner($request, $address);
        $address->delete();

        return response()->json(['message' => 'Adresse supprimée.']);
    }

    private function authorizeOwner(Request $request, Address $address): void
    {
        abort_if($address->user_id !== $request->user()->id, 403, 'Accès refusé.');
    }

    /** @return array<string, mixed> */
    private function validateData(Request $request, bool $updating = false): array
    {
        $required = $updating ? 'sometimes' : 'required';

        return $request->validate([
            'name' => [$required, 'string', 'max:255'],
            'address' => [$required, 'string'],
            'city' => [$required, 'string', 'max:255'],
            'postal_code' => [$required, 'string', 'max:32'],
            'latitude' => ['nullable', 'numeric'],
            'longitude' => ['nullable', 'numeric'],
            'type' => ['nullable', 'string', 'max:32'],
            'is_default' => ['boolean'],
        ]);
    }
}

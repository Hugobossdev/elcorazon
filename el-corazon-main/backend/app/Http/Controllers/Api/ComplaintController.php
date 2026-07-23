<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Complaint;
use App\Models\Order;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class ComplaintController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = Complaint::query()->latest('created_at');

        if (! $request->user()->isAdmin()) {
            $query->where('user_id', $request->user()->id);
        }

        return response()->json($query->paginate($request->integer('per_page', 20)));
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'order_id' => ['required', 'uuid', 'exists:orders,id'],
            'type' => ['required', Rule::in(['quality', 'delivery', 'service', 'other'])],
            'subject' => ['required', 'string', 'max:255'],
            'description' => ['required', 'string'],
            'photos' => ['nullable', 'array'],
        ]);

        // On ne peut réclamer que sur sa propre commande.
        $order = Order::findOrFail($data['order_id']);
        abort_if($order->user_id !== $request->user()->id, 403, 'Accès refusé.');

        $complaint = Complaint::create([
            'user_id' => $request->user()->id,
            'order_id' => $data['order_id'],
            'type' => $data['type'],
            'subject' => $data['subject'],
            'description' => $data['description'],
            'photos' => $data['photos'] ?? [],
            'status' => 'pending',
        ]);

        return response()->json(['data' => $complaint], 201);
    }

    /** Traitement d'une réclamation (admin). */
    public function resolve(Request $request, Complaint $complaint): JsonResponse
    {
        abort_unless($request->user()->isAdmin(), 403, 'Réservé aux administrateurs.');

        $data = $request->validate([
            'status' => ['required', Rule::in(['under_review', 'resolved', 'rejected'])],
            'resolution' => ['nullable', 'string'],
        ]);

        $complaint->update([
            'status' => $data['status'],
            'resolution' => $data['resolution'] ?? $complaint->resolution,
        ]);

        return response()->json(['data' => $complaint]);
    }
}

<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\SupportTicket;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class SupportController extends Controller
{
    /** Tickets : les siens (client) ou tous (admin). */
    public function index(Request $request): JsonResponse
    {
        $query = SupportTicket::query()->latest('created_at');

        if (! $request->user()->isAdmin()) {
            $query->where('user_id', $request->user()->id);
        }

        if ($request->filled('status')) {
            $query->where('status', $request->input('status'));
        }

        return response()->json($query->paginate($request->integer('per_page', 20)));
    }

    public function show(Request $request, SupportTicket $ticket): JsonResponse
    {
        $this->authorizeAccess($request, $ticket);

        return response()->json(['data' => $ticket->load('messages')]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'category' => ['required', 'string', 'max:255'],
            'subject' => ['required', 'string', 'max:255'],
            'description' => ['required', 'string'],
            'attachments' => ['nullable', 'array'],
        ]);

        $ticket = SupportTicket::create([
            'user_id' => $request->user()->id,
            'category' => $data['category'],
            'subject' => $data['subject'],
            'description' => $data['description'],
            'attachments' => $data['attachments'] ?? [],
            'status' => 'open',
        ]);

        return response()->json(['data' => $ticket], 201);
    }

    /** Ajoute un message au fil du ticket (client ou admin). */
    public function addMessage(Request $request, SupportTicket $ticket): JsonResponse
    {
        $this->authorizeAccess($request, $ticket);

        $data = $request->validate([
            'message' => ['required', 'string'],
        ]);

        $isAdmin = $request->user()->isAdmin();
        $message = $ticket->messages()->create([
            'admin_id' => $isAdmin ? $request->user()->id : null,
            'user_id' => $isAdmin ? null : $request->user()->id,
            'message' => $data['message'],
        ]);

        // Un message admin passe le ticket en cours de traitement.
        if ($isAdmin && $ticket->status === 'open') {
            $ticket->update(['status' => 'in_progress']);
        }

        return response()->json(['data' => $message], 201);
    }

    /** Résolution / changement de statut (admin). */
    public function setStatus(Request $request, SupportTicket $ticket): JsonResponse
    {
        abort_unless($request->user()->isAdmin(), 403, 'Réservé aux administrateurs.');

        $data = $request->validate([
            'status' => ['required', Rule::in(['open', 'in_progress', 'resolved', 'closed'])],
            'resolution' => ['nullable', 'string'],
        ]);

        $ticket->update([
            'status' => $data['status'],
            'resolution' => $data['resolution'] ?? $ticket->resolution,
            'resolved_at' => in_array($data['status'], ['resolved', 'closed'], true) ? now() : $ticket->resolved_at,
        ]);

        return response()->json(['data' => $ticket]);
    }

    private function authorizeAccess(Request $request, SupportTicket $ticket): void
    {
        abort_unless(
            $request->user()->isAdmin() || $ticket->user_id === $request->user()->id,
            403,
            'Accès refusé.'
        );
    }
}

<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\GroupPayment;
use App\Models\GroupPaymentParticipant;
use App\Models\Order;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Paiement partagé : répartition du montant d'une commande entre plusieurs
 * participants (« diviser l'addition »).
 */
class GroupPaymentController extends Controller
{
    /** Initie un paiement partagé pour une commande + ses participants. */
    public function store(Request $request, Order $order): JsonResponse
    {
        abort_if($order->user_id !== $request->user()->id, 403, 'Accès refusé.');

        if (GroupPayment::where('order_id', $order->id)->exists()) {
            return response()->json(['message' => 'Un paiement partagé existe déjà pour cette commande.'], 409);
        }

        $data = $request->validate([
            'group_id' => ['nullable', 'uuid'],
            'participants' => ['required', 'array', 'min:1'],
            'participants.*.user_id' => ['nullable', 'uuid', 'exists:users,id'],
            'participants.*.name' => ['required', 'string', 'max:255'],
            'participants.*.email' => ['nullable', 'email'],
            'participants.*.phone' => ['nullable', 'string', 'max:32'],
            'participants.*.operator' => ['nullable', 'string', 'max:64'],
            'participants.*.amount' => ['required', 'numeric', 'min:0'],
        ]);

        $sumParts = collect($data['participants'])->sum('amount');
        if (round($sumParts, 2) !== round((float) $order->total, 2)) {
            return response()->json([
                'message' => 'La somme des parts doit égaler le total de la commande.',
                'order_total' => (float) $order->total,
                'participants_total' => round($sumParts, 2),
            ], 422);
        }

        $groupPayment = DB::transaction(function () use ($order, $request, $data) {
            $groupPayment = GroupPayment::create([
                'group_id' => $data['group_id'] ?? null,
                'order_id' => $order->id,
                'total_amount' => $order->total,
                'paid_amount' => 0,
                'status' => 'pending',
                'initiated_by' => $request->user()->id,
                'metadata' => [],
            ]);

            foreach ($data['participants'] as $p) {
                $groupPayment->participants()->create([
                    'user_id' => $p['user_id'] ?? null,
                    'name' => $p['name'],
                    'email' => $p['email'] ?? null,
                    'phone' => $p['phone'] ?? null,
                    'operator' => $p['operator'] ?? null,
                    'amount' => $p['amount'],
                    'paid_amount' => 0,
                    'status' => 'pending',
                ]);
            }

            return $groupPayment;
        });

        return response()->json(['data' => $groupPayment->load('participants')], 201);
    }

    public function show(Request $request, GroupPayment $groupPayment): JsonResponse
    {
        $this->authorizeAccess($request, $groupPayment);

        return response()->json(['data' => $groupPayment->load('participants', 'order')]);
    }

    /** Marque la part d'un participant comme réglée et met à jour les totaux. */
    public function markParticipantPaid(Request $request, GroupPaymentParticipant $participant): JsonResponse
    {
        $groupPayment = $participant->groupPayment;
        $this->authorizeAccess($request, $groupPayment);

        $data = $request->validate([
            'transaction_id' => ['nullable', 'string'],
        ]);

        DB::transaction(function () use ($participant, $groupPayment, $data) {
            $participant->update([
                'status' => 'paid',
                'paid_amount' => $participant->amount,
                'transaction_id' => $data['transaction_id'] ?? null,
            ]);

            $paid = $groupPayment->participants()->sum('paid_amount');
            $allPaid = $groupPayment->participants()->where('status', '!=', 'paid')->doesntExist();

            $groupPayment->update([
                'paid_amount' => $paid,
                'status' => $allPaid ? 'completed' : 'in_progress',
            ]);

            // Quand tout est réglé, la commande est marquée payée.
            if ($allPaid) {
                $groupPayment->order?->update(['payment_status' => 'completed']);
            }
        });

        return response()->json(['data' => $groupPayment->fresh('participants')]);
    }

    private function authorizeAccess(Request $request, GroupPayment $groupPayment): void
    {
        $user = $request->user();
        $isParticipant = $groupPayment->participants()->where('user_id', $user->id)->exists();
        $allowed = $user->isAdmin()
            || $groupPayment->initiated_by === $user->id
            || $isParticipant;

        abort_unless($allowed, 403, 'Accès refusé.');
    }
}

<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Order;
use App\Models\ReturnRequest;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class ReturnRequestController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = ReturnRequest::query()->latest('created_at');

        if (! $request->user()->isAdmin()) {
            $query->where('user_id', $request->user()->id);
        }

        return response()->json($query->paginate($request->integer('per_page', 20)));
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'order_id' => ['required', 'uuid', 'exists:orders,id'],
            'reason' => ['required', 'string'],
            'items' => ['required', 'array', 'min:1'],
            'items.*' => ['string'],
            'refund_amount' => ['required', 'numeric', 'min:0'],
        ]);

        $order = Order::findOrFail($data['order_id']);
        abort_if($order->user_id !== $request->user()->id, 403, 'Accès refusé.');

        $return = ReturnRequest::create([
            'user_id' => $request->user()->id,
            'order_id' => $data['order_id'],
            'reason' => $data['reason'],
            'items' => $data['items'],
            'refund_amount' => $data['refund_amount'],
            'status' => 'pending',
        ]);

        return response()->json(['data' => $return], 201);
    }

    /** Décision sur une demande de retour (admin). */
    public function decide(Request $request, ReturnRequest $returnRequest): JsonResponse
    {
        abort_unless($request->user()->isAdmin(), 403, 'Réservé aux administrateurs.');

        $data = $request->validate([
            'status' => ['required', Rule::in(['approved', 'rejected', 'refunded'])],
        ]);

        $returnRequest->update([
            'status' => $data['status'],
            'resolved_at' => now(),
        ]);

        return response()->json(['data' => $returnRequest]);
    }
}

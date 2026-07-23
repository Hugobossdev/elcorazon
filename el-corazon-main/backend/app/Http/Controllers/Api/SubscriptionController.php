<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Subscription;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class SubscriptionController extends Controller
{
    /** Abonnements de l'utilisateur courant. */
    public function index(Request $request): JsonResponse
    {
        return response()->json([
            'data' => $request->user()->subscriptions()->latest('created_at')->get(),
        ]);
    }

    public function show(Request $request, Subscription $subscription): JsonResponse
    {
        $this->authorizeOwner($request, $subscription);

        return response()->json(['data' => $subscription]);
    }

    /** Souscrit un nouveau plan. */
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'subscription_type' => ['required', Rule::in(['weekly', 'monthly', 'vip'])],
            'plan_name' => ['nullable', 'string', 'max:255'],
            'meals_per_week' => ['nullable', 'integer', 'min:0'],
            'price_per_meal' => ['nullable', 'numeric', 'min:0'],
            'monthly_price' => ['required', 'numeric', 'min:0'],
            'auto_renew' => ['boolean'],
        ]);

        $now = now();
        $periodEnd = $data['subscription_type'] === 'weekly'
            ? $now->copy()->addWeek()
            : $now->copy()->addMonth();

        $subscription = $request->user()->subscriptions()->create([
            'subscription_type' => $data['subscription_type'],
            'plan_name' => $data['plan_name'] ?? null,
            'meals_per_week' => $data['meals_per_week'] ?? 0,
            'price_per_meal' => $data['price_per_meal'] ?? 0,
            'monthly_price' => $data['monthly_price'],
            'status' => 'active',
            'current_period_start' => $now,
            'current_period_end' => $periodEnd,
            'meals_used_this_period' => 0,
            'auto_renew' => $data['auto_renew'] ?? true,
        ]);

        return response()->json(['data' => $subscription], 201);
    }

    /** Met en pause / réactive. */
    public function setStatus(Request $request, Subscription $subscription): JsonResponse
    {
        $this->authorizeOwner($request, $subscription);

        $data = $request->validate([
            'status' => ['required', Rule::in(['active', 'paused'])],
        ]);

        $subscription->update(['status' => $data['status']]);

        return response()->json(['data' => $subscription]);
    }

    public function cancel(Request $request, Subscription $subscription): JsonResponse
    {
        $this->authorizeOwner($request, $subscription);

        $subscription->update([
            'status' => 'cancelled',
            'auto_renew' => false,
            'cancelled_at' => now(),
        ]);

        return response()->json(['data' => $subscription]);
    }

    private function authorizeOwner(Request $request, Subscription $subscription): void
    {
        abort_if($subscription->user_id !== $request->user()->id, 403, 'Accès refusé.');
    }
}

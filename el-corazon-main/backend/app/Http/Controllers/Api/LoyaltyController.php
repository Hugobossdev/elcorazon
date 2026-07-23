<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\LoyaltyReward;
use App\Models\LoyaltyTransaction;
use App\Models\RewardRedemption;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class LoyaltyController extends Controller
{
    /** Solde de points + dernières transactions. */
    public function summary(Request $request): JsonResponse
    {
        $user = $request->user();

        return response()->json([
            'data' => [
                'loyalty_points' => $user->loyalty_points,
                'badges' => $user->badges ?? [],
                'recent_transactions' => $user->loyaltyTransactions()
                    ->latest('created_at')
                    ->limit(20)
                    ->get(),
            ],
        ]);
    }

    /** Catalogue des récompenses échangeables. */
    public function rewards(): JsonResponse
    {
        return response()->json([
            'data' => LoyaltyReward::where('is_active', true)->orderBy('cost')->get(),
        ]);
    }

    /** Historique complet des transactions de points (paginé). */
    public function transactions(Request $request): JsonResponse
    {
        return response()->json(
            $request->user()->loyaltyTransactions()
                ->latest('created_at')
                ->paginate($request->integer('per_page', 30))
        );
    }

    /** Échange de points contre une récompense (débit atomique). */
    public function redeem(Request $request, LoyaltyReward $reward): JsonResponse
    {
        $user = $request->user();

        abort_unless($reward->is_active, 422, 'Récompense indisponible.');

        if ($user->loyalty_points < $reward->cost) {
            return response()->json([
                'message' => 'Points insuffisants.',
                'required' => $reward->cost,
                'available' => $user->loyalty_points,
            ], 422);
        }

        $redemption = DB::transaction(function () use ($user, $reward) {
            $user->decrement('loyalty_points', $reward->cost);

            LoyaltyTransaction::create([
                'user_id' => $user->id,
                'transaction_type' => 'redeem',
                'points' => -$reward->cost,
                'description' => "Échange : {$reward->title}",
                'metadata' => ['reward_id' => $reward->id],
            ]);

            return RewardRedemption::create([
                'user_id' => $user->id,
                'reward_id' => $reward->id,
                'cost' => $reward->cost,
                'metadata' => ['reward_title' => $reward->title],
                'status' => 'pending',
            ]);
        });

        return response()->json([
            'data' => $redemption,
            'remaining_points' => $user->fresh()->loyalty_points,
        ], 201);
    }
}

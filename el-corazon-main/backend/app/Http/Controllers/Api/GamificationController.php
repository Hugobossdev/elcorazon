<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Achievement;
use App\Models\Badge;
use App\Models\Challenge;
use App\Models\UserAchievement;
use App\Models\UserBadge;
use App\Models\UserChallenge;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class GamificationController extends Controller
{
    /** Liste des succès avec la progression de l'utilisateur courant. */
    public function achievements(Request $request): JsonResponse
    {
        $achievements = Achievement::where('is_active', true)->get();
        $progress = UserAchievement::where('user_id', $request->user()->id)
            ->get()
            ->keyBy('achievement_id');

        return response()->json([
            'data' => $achievements->map(fn (Achievement $a) => [
                'achievement' => $a,
                'progress' => $progress[$a->id]->progress ?? 0,
                'is_unlocked' => (bool) ($progress[$a->id]->is_unlocked ?? false),
                'unlocked_at' => $progress[$a->id]->unlocked_at ?? null,
            ])->values(),
        ]);
    }

    /** Défis actifs (dans leur fenêtre temporelle) + progression. */
    public function challenges(Request $request): JsonResponse
    {
        $now = now();
        $challenges = Challenge::where('is_active', true)
            ->where('start_date', '<=', $now)
            ->where('end_date', '>=', $now)
            ->get();

        $progress = UserChallenge::where('user_id', $request->user()->id)
            ->get()
            ->keyBy('challenge_id');

        return response()->json([
            'data' => $challenges->map(fn (Challenge $c) => [
                'challenge' => $c,
                'progress' => $progress[$c->id]->progress ?? 0,
                'is_completed' => (bool) ($progress[$c->id]->is_completed ?? false),
            ])->values(),
        ]);
    }

    /** Badges disponibles + ceux débloqués par l'utilisateur. */
    public function badges(Request $request): JsonResponse
    {
        $badges = Badge::where('is_active', true)->orderBy('points_required')->get();
        $unlocked = UserBadge::where('user_id', $request->user()->id)
            ->where('is_unlocked', true)
            ->pluck('badge_id')
            ->all();

        return response()->json([
            'data' => $badges->map(fn (Badge $b) => [
                'badge' => $b,
                'is_unlocked' => in_array($b->id, $unlocked, true),
            ])->values(),
        ]);
    }
}

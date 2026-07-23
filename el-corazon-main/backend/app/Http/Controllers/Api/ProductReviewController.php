<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\MenuItem;
use App\Models\ProductReview;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ProductReviewController extends Controller
{
    /** Avis d'un article (public). */
    public function index(MenuItem $menuItem): JsonResponse
    {
        return response()->json(
            $menuItem->reviews()->latest()->paginate(20)
        );
    }

    /** Créer / mettre à jour son avis (1 avis par utilisateur et par article). */
    public function store(Request $request, MenuItem $menuItem): JsonResponse
    {
        $user = $request->user();

        $data = $request->validate([
            'rating' => ['required', 'numeric', 'min:1', 'max:5'],
            'title' => ['nullable', 'string', 'max:255'],
            'comment' => ['required', 'string'],
            'photos' => ['nullable', 'array'],
        ]);

        $review = DB::transaction(function () use ($menuItem, $user, $data) {
            $review = ProductReview::updateOrCreate(
                ['menu_item_id' => $menuItem->id, 'user_id' => $user->id],
                [
                    'user_name' => $user->name,
                    'rating' => $data['rating'],
                    'title' => $data['title'] ?? null,
                    'comment' => $data['comment'],
                    'photos' => $data['photos'] ?? [],
                ],
            );

            $this->recomputeItemRating($menuItem);

            return $review;
        });

        return response()->json(['data' => $review], 201);
    }

    public function destroy(Request $request, ProductReview $review): JsonResponse
    {
        // L'auteur ou un admin peut supprimer.
        if ($review->user_id !== $request->user()->id && ! $request->user()->isAdmin()) {
            return response()->json(['message' => 'Accès refusé.'], 403);
        }

        $menuItem = $review->menuItem;
        $review->delete();

        if ($menuItem) {
            $this->recomputeItemRating($menuItem);
        }

        return response()->json(['message' => 'Avis supprimé.']);
    }

    /** Recalcule la note moyenne et le nombre d'avis de l'article. */
    private function recomputeItemRating(MenuItem $menuItem): void
    {
        $stats = $menuItem->reviews()
            ->selectRaw('COUNT(*) as count, COALESCE(AVG(rating), 0) as avg')
            ->first();

        $menuItem->update([
            'rating' => round((float) $stats->avg, 2),
            'review_count' => (int) $stats->count,
        ]);
    }
}

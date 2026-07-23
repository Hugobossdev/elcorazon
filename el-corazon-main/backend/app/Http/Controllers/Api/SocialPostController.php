<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\GroupMember;
use App\Models\PostComment;
use App\Models\PostLike;
use App\Models\SocialPost;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class SocialPostController extends Controller
{
    /** Fil : posts publics + posts des groupes de l'utilisateur. */
    public function index(Request $request): JsonResponse
    {
        $groupIds = GroupMember::where('user_id', $request->user()->id)
            ->where('is_active', true)
            ->pluck('group_id');

        $posts = SocialPost::query()
            ->with('user:id,name,profile_image')
            ->where(function ($q) use ($groupIds) {
                $q->where('is_public', true)
                    ->orWhereIn('group_id', $groupIds);
            })
            ->latest('created_at')
            ->paginate($request->integer('per_page', 20));

        return response()->json($posts);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'content' => ['required', 'string'],
            'post_type' => ['required', Rule::in(['order_share', 'review', 'photo', 'text', 'event'])],
            'group_id' => ['nullable', 'uuid', 'exists:social_groups,id'],
            'order_id' => ['nullable', 'uuid', 'exists:orders,id'],
            'image_url' => ['nullable', 'string'],
            'is_public' => ['boolean'],
        ]);

        // Si posté dans un groupe, vérifier l'appartenance.
        if (! empty($data['group_id'])) {
            $isMember = GroupMember::where('group_id', $data['group_id'])
                ->where('user_id', $request->user()->id)
                ->where('is_active', true)
                ->exists();
            abort_unless($isMember, 403, 'Vous n\'êtes pas membre de ce groupe.');
        }

        $post = SocialPost::create([
            'user_id' => $request->user()->id,
            'group_id' => $data['group_id'] ?? null,
            'content' => $data['content'],
            'post_type' => $data['post_type'],
            'order_id' => $data['order_id'] ?? null,
            'image_url' => $data['image_url'] ?? null,
            'is_public' => $data['is_public'] ?? true,
        ]);

        return response()->json(['data' => $post->load('user:id,name,profile_image')], 201);
    }

    public function destroy(Request $request, SocialPost $post): JsonResponse
    {
        abort_if($post->user_id !== $request->user()->id && ! $request->user()->isAdmin(), 403, 'Accès refusé.');
        $post->delete();

        return response()->json(['message' => 'Publication supprimée.']);
    }

    /** Like / unlike (bascule) avec maintien du compteur. */
    public function toggleLike(Request $request, SocialPost $post): JsonResponse
    {
        $existing = PostLike::where('post_id', $post->id)
            ->where('user_id', $request->user()->id)
            ->first();

        $liked = DB::transaction(function () use ($existing, $post, $request) {
            if ($existing !== null) {
                $existing->delete();
                if ($post->likes_count > 0) {
                    $post->decrement('likes_count');
                }

                return false;
            }

            PostLike::create(['post_id' => $post->id, 'user_id' => $request->user()->id]);
            $post->increment('likes_count');

            return true;
        });

        return response()->json([
            'data' => ['liked' => $liked, 'likes_count' => $post->fresh()->likes_count],
        ]);
    }

    public function comments(SocialPost $post): JsonResponse
    {
        return response()->json(
            $post->comments()->with('user:id,name,profile_image')->latest('created_at')->paginate(30)
        );
    }

    public function addComment(Request $request, SocialPost $post): JsonResponse
    {
        $data = $request->validate([
            'content' => ['required', 'string'],
        ]);

        $comment = DB::transaction(function () use ($post, $request, $data) {
            $comment = PostComment::create([
                'post_id' => $post->id,
                'user_id' => $request->user()->id,
                'content' => $data['content'],
            ]);
            $post->increment('comments_count');

            return $comment;
        });

        return response()->json(['data' => $comment->load('user:id,name,profile_image')], 201);
    }
}

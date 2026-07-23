<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\GroupMember;
use App\Models\SocialGroup;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class SocialGroupController extends Controller
{
    /** Groupes dont l'utilisateur est membre. */
    public function index(Request $request): JsonResponse
    {
        $groupIds = GroupMember::where('user_id', $request->user()->id)
            ->where('is_active', true)
            ->pluck('group_id');

        return response()->json([
            'data' => SocialGroup::whereIn('id', $groupIds)
                ->where('is_active', true)
                ->withCount('members')
                ->get(),
        ]);
    }

    public function show(Request $request, SocialGroup $group): JsonResponse
    {
        $this->authorizeMember($request, $group);

        return response()->json([
            'data' => $group->load('members.user'),
        ]);
    }

    /** Crée un groupe ; le créateur en devient membre (role creator). */
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string'],
            'group_type' => ['required', Rule::in(['family', 'friends', 'work', 'neighborhood', 'custom'])],
            'is_private' => ['boolean'],
            'max_members' => ['nullable', 'integer', 'min:2'],
        ]);

        $group = DB::transaction(function () use ($request, $data) {
            $group = SocialGroup::create([
                'name' => $data['name'],
                'description' => $data['description'] ?? null,
                'group_type' => $data['group_type'],
                'creator_id' => $request->user()->id,
                'invite_code' => $this->generateInviteCode(),
                'is_private' => $data['is_private'] ?? false,
                'max_members' => $data['max_members'] ?? 50,
                'member_count' => 1,
                'is_active' => true,
            ]);

            $group->members()->create([
                'user_id' => $request->user()->id,
                'role' => 'creator',
                'joined_at' => now(),
                'is_active' => true,
            ]);

            return $group;
        });

        return response()->json(['data' => $group], 201);
    }

    /** Rejoint un groupe via son code d'invitation. */
    public function join(Request $request): JsonResponse
    {
        $data = $request->validate([
            'invite_code' => ['required', 'string'],
        ]);

        $group = SocialGroup::where('invite_code', $data['invite_code'])
            ->where('is_active', true)
            ->first();

        if ($group === null) {
            return response()->json(['message' => 'Code d\'invitation invalide.'], 404);
        }

        $existing = GroupMember::where('group_id', $group->id)
            ->where('user_id', $request->user()->id)
            ->first();

        if ($existing !== null && $existing->is_active) {
            return response()->json(['message' => 'Vous êtes déjà membre de ce groupe.'], 409);
        }

        if ($group->member_count >= $group->max_members) {
            return response()->json(['message' => 'Groupe complet.'], 422);
        }

        DB::transaction(function () use ($group, $request, $existing) {
            if ($existing !== null) {
                $existing->update(['is_active' => true]);
            } else {
                $group->members()->create([
                    'user_id' => $request->user()->id,
                    'role' => 'member',
                    'joined_at' => now(),
                    'is_active' => true,
                ]);
            }
            $group->increment('member_count');
        });

        return response()->json(['data' => $group->fresh()]);
    }

    /** Quitte le groupe. */
    public function leave(Request $request, SocialGroup $group): JsonResponse
    {
        $member = GroupMember::where('group_id', $group->id)
            ->where('user_id', $request->user()->id)
            ->where('is_active', true)
            ->first();

        abort_if($member === null, 404, 'Vous n\'êtes pas membre de ce groupe.');

        DB::transaction(function () use ($member, $group) {
            $member->update(['is_active' => false]);
            if ($group->member_count > 0) {
                $group->decrement('member_count');
            }
        });

        return response()->json(['message' => 'Vous avez quitté le groupe.']);
    }

    private function authorizeMember(Request $request, SocialGroup $group): void
    {
        $isMember = GroupMember::where('group_id', $group->id)
            ->where('user_id', $request->user()->id)
            ->where('is_active', true)
            ->exists();

        abort_unless($isMember, 403, 'Accès réservé aux membres du groupe.');
    }

    private function generateInviteCode(): string
    {
        do {
            $code = Str::upper(Str::random(8));
        } while (SocialGroup::where('invite_code', $code)->exists());

        return $code;
    }
}

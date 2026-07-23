<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\MenuItem;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MenuItemController extends Controller
{
    /** Catalogue filtrable et paginé. */
    public function index(Request $request): JsonResponse
    {
        $query = MenuItem::query()->with('category');

        if ($request->filled('category_id')) {
            $query->where('category_id', $request->input('category_id'));
        }

        if ($request->filled('search')) {
            $term = '%'.$request->input('search').'%';
            $query->where(function ($q) use ($term) {
                $q->where('name', 'ilike', $term)
                    ->orWhere('description', 'ilike', $term);
            });
        }

        if ($request->boolean('popular_only')) {
            $query->where('is_popular', true);
        }

        if (! $request->boolean('include_unavailable')) {
            $query->where('is_available', true);
        }

        $sort = (string) $request->input('sort', 'sort_order');
        $allowedSorts = ['sort_order', 'price', 'rating', 'created_at', 'name'];
        if (in_array($sort, $allowedSorts, true)) {
            $direction = $request->input('direction', 'asc') === 'desc' ? 'desc' : 'asc';
            $query->orderBy($sort, $direction);
        }

        return response()->json(
            $query->paginate($request->integer('per_page', 20))
        );
    }

    public function show(MenuItem $menuItem): JsonResponse
    {
        return response()->json([
            'data' => $menuItem->load(['category', 'customizationOptions']),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $this->validateData($request);
        $item = MenuItem::create($data);

        return response()->json(['data' => $item->load('category')], 201);
    }

    public function update(Request $request, MenuItem $menuItem): JsonResponse
    {
        $data = $this->validateData($request, updating: true);
        $menuItem->update($data);

        return response()->json(['data' => $menuItem->load('category')]);
    }

    public function destroy(MenuItem $menuItem): JsonResponse
    {
        $menuItem->delete();

        return response()->json(['message' => 'Article supprimé.']);
    }

    /** Bascule rapide de disponibilité (usage admin/opérateur). */
    public function toggleAvailability(MenuItem $menuItem): JsonResponse
    {
        $menuItem->update(['is_available' => ! $menuItem->is_available]);

        return response()->json(['data' => $menuItem]);
    }

    /** @return array<string, mixed> */
    private function validateData(Request $request, bool $updating = false): array
    {
        $required = $updating ? 'sometimes' : 'required';

        return $request->validate([
            'name' => [$required, 'string', 'max:255'],
            'description' => [$required, 'string'],
            'price' => [$required, 'numeric', 'min:0'],
            'category_id' => [$required, 'uuid', 'exists:menu_categories,id'],
            'image_url' => ['nullable', 'string'],
            'is_popular' => ['boolean'],
            'is_vegetarian' => ['boolean'],
            'is_vegan' => ['boolean'],
            'is_available' => ['boolean'],
            'available_quantity' => ['nullable', 'integer', 'min:0'],
            'vip_exclusive' => ['boolean'],
            'ingredients' => ['nullable', 'array'],
            'calories' => ['nullable', 'integer', 'min:0'],
            'allergens' => ['nullable', 'array'],
            'preparation_time' => ['nullable', 'integer', 'min:0'],
            'sort_order' => ['nullable', 'integer'],
        ]);
    }
}

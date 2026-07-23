<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\MenuCategory;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MenuCategoryController extends Controller
{
    /** Liste publique des catégories actives (ou toutes pour un admin). */
    public function index(Request $request): JsonResponse
    {
        $query = MenuCategory::query()->orderBy('sort_order');

        if (! $request->boolean('all')) {
            $query->where('is_active', true);
        }

        if ($request->boolean('with_counts')) {
            $query->withCount('items');
        }

        return response()->json(['data' => $query->get()]);
    }

    public function show(MenuCategory $category): JsonResponse
    {
        return response()->json(['data' => $category->loadCount('items')]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255', 'unique:menu_categories,name'],
            'display_name' => ['required', 'string', 'max:255'],
            'emoji' => ['required', 'string', 'max:16'],
            'description' => ['nullable', 'string'],
            'sort_order' => ['nullable', 'integer'],
            'is_active' => ['boolean'],
        ]);

        $category = MenuCategory::create($data);

        return response()->json(['data' => $category], 201);
    }

    public function update(Request $request, MenuCategory $category): JsonResponse
    {
        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:255', 'unique:menu_categories,name,'.$category->id],
            'display_name' => ['sometimes', 'string', 'max:255'],
            'emoji' => ['sometimes', 'string', 'max:16'],
            'description' => ['nullable', 'string'],
            'sort_order' => ['nullable', 'integer'],
            'is_active' => ['boolean'],
        ]);

        $category->update($data);

        return response()->json(['data' => $category]);
    }

    public function destroy(MenuCategory $category): JsonResponse
    {
        $category->delete();

        return response()->json(['message' => 'Catégorie supprimée.']);
    }
}

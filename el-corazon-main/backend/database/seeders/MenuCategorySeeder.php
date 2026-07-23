<?php

namespace Database\Seeders;

use App\Models\MenuCategory;
use Illuminate\Database\Seeder;

class MenuCategorySeeder extends Seeder
{
    public function run(): void
    {
        $categories = [
            ['name' => 'burgers', 'display_name' => 'Burgers', 'emoji' => '🍔'],
            ['name' => 'pizzas', 'display_name' => 'Pizzas', 'emoji' => '🍕'],
            ['name' => 'boissons', 'display_name' => 'Boissons', 'emoji' => '🥤'],
            ['name' => 'desserts', 'display_name' => 'Desserts', 'emoji' => '🍰'],
            ['name' => 'accompagnements', 'display_name' => 'Accompagnements', 'emoji' => '🍟'],
            ['name' => 'salades', 'display_name' => 'Salades', 'emoji' => '🥗'],
            ['name' => 'menus', 'display_name' => 'Menus', 'emoji' => '🍽️'],
            ['name' => 'specialites', 'display_name' => 'Spécialités', 'emoji' => '⭐'],
        ];

        foreach ($categories as $index => $category) {
            MenuCategory::firstOrCreate(
                ['name' => $category['name']],
                [
                    'display_name' => $category['display_name'],
                    'emoji' => $category['emoji'],
                    'sort_order' => $index,
                    'is_active' => true,
                ],
            );
        }
    }
}

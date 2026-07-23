<?php

namespace Database\Seeders;

use App\Models\Achievement;
use Illuminate\Database\Seeder;

class AchievementSeeder extends Seeder
{
    public function run(): void
    {
        $achievements = [
            ['name' => 'first_order', 'description' => 'Première commande passée', 'icon' => '🎉', 'points_reward' => 50, 'condition_type' => 'orders_count', 'condition_value' => 1],
            ['name' => 'regular', 'description' => '10 commandes passées', 'icon' => '🔥', 'points_reward' => 200, 'condition_type' => 'orders_count', 'condition_value' => 10],
            ['name' => 'big_spender', 'description' => '50 000 FCFA dépensés', 'icon' => '💎', 'points_reward' => 300, 'condition_type' => 'total_spent', 'condition_value' => 50000],
            ['name' => 'week_streak', 'description' => '7 jours consécutifs', 'icon' => '📅', 'points_reward' => 150, 'condition_type' => 'streak_days', 'condition_value' => 7],
        ];

        foreach ($achievements as $achievement) {
            Achievement::firstOrCreate(
                ['name' => $achievement['name']],
                $achievement + ['badge_reward' => null, 'is_active' => true],
            );
        }
    }
}

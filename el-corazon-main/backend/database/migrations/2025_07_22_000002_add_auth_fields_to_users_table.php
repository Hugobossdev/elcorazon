<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Prépare la table `users` (créée par Supabase) à une authentification émise
 * par Laravel : ajout du mot de passe haché, du remember_token, et
 * assouplissement du lien vers auth.users (désormais optionnel).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            if (! Schema::hasColumn('users', 'password')) {
                $table->text('password')->nullable();
            }
            if (! Schema::hasColumn('users', 'remember_token')) {
                $table->string('remember_token', 100)->nullable();
            }
        });

        // DDL spécifiques à PostgreSQL (Supabase). Ignorés sur d'autres drivers
        // (ex. SQLite en test), où `auth_user_id` est déjà créé nullable.
        if (DB::getDriverName() === 'pgsql') {
            // auth_user_id devient optionnel (les comptes créés via Laravel n'en ont pas).
            DB::statement('ALTER TABLE users ALTER COLUMN auth_user_id DROP NOT NULL');

            // Supprime la contrainte FK vers auth.users si elle existe (nom conventionnel Supabase).
            DB::statement('ALTER TABLE users DROP CONSTRAINT IF EXISTS users_auth_user_id_fkey');
        }
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            if (Schema::hasColumn('users', 'remember_token')) {
                $table->dropColumn('remember_token');
            }
            if (Schema::hasColumn('users', 'password')) {
                $table->dropColumn('password');
            }
        });
    }
};

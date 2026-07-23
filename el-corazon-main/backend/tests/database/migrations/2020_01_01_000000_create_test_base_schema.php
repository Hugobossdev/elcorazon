<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Schéma de test (SQLite uniquement).
 *
 * En production, ces tables appartiennent à Supabase (source de vérité, voir
 * SCHEMA_BDD_COMPLET.md) et ne sont pas recréées par Laravel. Ici on reconstruit
 * le sous-ensemble nécessaire aux tests d'intégration, SANS les colonnes d'auth
 * Sanctum : celles-ci sont ajoutées ensuite par la migration
 * `add_auth_fields_to_users`, reproduisant fidèlement la séquence de prod.
 *
 * Les UUID sont générés côté application (HasUuidPrimaryKey), d'où des clés
 * `uuid` sans auto-incrément.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('users', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('auth_user_id')->nullable();
            $table->string('name')->nullable();
            $table->string('email')->nullable()->unique();
            $table->string('phone')->nullable();
            $table->string('role')->default('client');
            $table->string('profile_image')->nullable();
            $table->integer('loyalty_points')->default(0);
            $table->json('badges')->nullable();
            $table->boolean('is_online')->default(false);
            $table->boolean('is_active')->default(true);
            $table->timestamp('last_seen')->nullable();
            $table->string('verification_status')->nullable();
            $table->timestamps();
        });

        Schema::create('menu_categories', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('name');
            $table->string('display_name')->nullable();
            $table->string('emoji')->nullable();
            $table->text('description')->nullable();
            $table->integer('sort_order')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });

        Schema::create('menu_items', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('name');
            $table->text('description')->nullable();
            $table->decimal('price', 10, 2)->default(0);
            $table->uuid('category_id')->nullable();
            $table->string('image_url')->nullable();
            $table->boolean('is_popular')->default(false);
            $table->boolean('is_vegetarian')->default(false);
            $table->boolean('is_vegan')->default(false);
            $table->boolean('is_available')->default(true);
            $table->integer('available_quantity')->nullable();
            $table->boolean('vip_exclusive')->default(false);
            $table->json('ingredients')->nullable();
            $table->integer('calories')->nullable();
            $table->json('allergens')->nullable();
            $table->integer('preparation_time')->nullable();
            $table->float('rating')->nullable();
            $table->integer('review_count')->nullable();
            $table->integer('sort_order')->nullable();
            $table->timestamps();
        });

        Schema::create('orders', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('user_id');
            $table->uuid('delivery_person_id')->nullable();
            $table->string('status')->default('pending');
            $table->decimal('subtotal', 10, 2)->default(0);
            $table->decimal('delivery_fee', 10, 2)->default(0);
            $table->decimal('discount', 10, 2)->default(0);
            $table->decimal('total', 10, 2)->default(0);
            $table->text('delivery_address')->nullable();
            $table->float('delivery_latitude')->nullable();
            $table->float('delivery_longitude')->nullable();
            $table->text('delivery_notes')->nullable();
            $table->text('special_instructions')->nullable();
            $table->string('payment_method')->nullable();
            $table->string('payment_status')->default('pending');
            $table->string('payment_transaction_id')->nullable();
            $table->string('promo_code')->nullable();
            $table->timestamp('order_time')->nullable();
            $table->timestamp('estimated_delivery_time')->nullable();
            $table->timestamp('delivered_at')->nullable();
            $table->boolean('is_group_order')->default(false);
            $table->uuid('group_id')->nullable();
            $table->timestamps();
        });

        Schema::create('order_items', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('order_id');
            $table->uuid('menu_item_id')->nullable();
            $table->string('menu_item_name')->nullable();
            $table->string('name');
            $table->string('category')->nullable();
            $table->string('menu_item_image')->nullable();
            $table->integer('quantity')->default(1);
            $table->float('unit_price')->default(0);
            $table->float('total_price')->default(0);
            $table->json('customizations')->nullable();
            $table->text('notes')->nullable();
            $table->timestamp('created_at')->nullable();
        });

        Schema::create('order_status_updates', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('order_id');
            $table->string('status');
            $table->uuid('updated_by')->nullable();
            $table->text('notes')->nullable();
            $table->timestamp('created_at')->nullable();
        });

        Schema::create('subscriptions', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('user_id');
            $table->string('subscription_type')->nullable();
            $table->string('plan_name')->nullable();
            $table->integer('meals_per_week')->nullable();
            $table->float('price_per_meal')->nullable();
            $table->float('monthly_price')->nullable();
            $table->string('status')->default('active');
            $table->timestamp('current_period_start')->nullable();
            $table->timestamp('current_period_end')->nullable();
            $table->integer('meals_used_this_period')->nullable();
            $table->boolean('auto_renew')->nullable();
            $table->timestamp('cancelled_at')->nullable();
            $table->timestamps();
        });

        Schema::create('promotions', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('promo_code')->nullable();
            $table->string('discount_type')->nullable();
            $table->decimal('discount_value', 10, 2)->nullable();
            $table->integer('used_count')->default(0);
            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });

        Schema::create('promotion_usages', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('promotion_id');
            $table->uuid('user_id');
            $table->uuid('order_id')->nullable();
            $table->decimal('discount_amount', 10, 2)->default(0);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('promotion_usages');
        Schema::dropIfExists('promotions');
        Schema::dropIfExists('subscriptions');
        Schema::dropIfExists('order_status_updates');
        Schema::dropIfExists('order_items');
        Schema::dropIfExists('orders');
        Schema::dropIfExists('menu_items');
        Schema::dropIfExists('menu_categories');
        Schema::dropIfExists('users');
    }
};

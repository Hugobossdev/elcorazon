<?php

namespace Tests\Feature;

use App\Models\MenuCategory;
use App\Models\MenuItem;
use App\Models\Order;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Tests d'intégration HTTP du domaine Order (gabarit de référence).
 *
 * S'appuie sur le schéma de test SQLite (tests/database/migrations) reconstruit
 * par RefreshDatabase, puis les migrations d'auth de production.
 */
class OrderTest extends TestCase
{
    use RefreshDatabase;

    private function client(): User
    {
        return User::create([
            'name' => 'Client Test',
            'email' => 'client-'.uniqid().'@test.dev',
            'role' => 'client',
        ]);
    }

    private function menuItem(float $price = 5.0): MenuItem
    {
        $category = MenuCategory::create(['name' => 'Plats']);

        return MenuItem::create([
            'name' => 'Burger',
            'price' => $price,
            'category_id' => $category->id,
            'is_available' => true,
        ]);
    }

    public function test_un_client_cree_une_commande_avec_totaux_calcules_serveur(): void
    {
        $user = $this->client();
        $item = $this->menuItem(5.0);
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/orders', [
            'items' => [
                ['menu_item_id' => $item->id, 'quantity' => 2],
            ],
            'delivery_address' => '12 rue du Test',
            'payment_method' => 'cash',
            // Un sous-total falsifié par le client doit être ignoré.
            'subtotal' => 9999,
            'total' => 1,
        ]);

        $response->assertStatus(201)
            ->assertJsonPath('data.status', 'pending')
            ->assertJsonPath('data.subtotal', 10.0)
            ->assertJsonPath('data.payment_status', 'pending')
            ->assertJsonCount(1, 'data.items');

        $this->assertDatabaseHas('orders', [
            'user_id' => $user->id,
            'subtotal' => 10.0,
            'status' => 'pending',
        ]);
        // Une ligne d'historique de statut est créée à l'ouverture.
        $this->assertDatabaseHas('order_status_updates', [
            'status' => 'pending',
            'updated_by' => $user->id,
        ]);
    }

    public function test_creation_refuse_une_charge_utile_invalide(): void
    {
        Sanctum::actingAs($this->client());

        $this->postJson('/api/orders', [
            'items' => [],
            'payment_method' => 'bitcoin',
        ])->assertStatus(422)
            ->assertJsonValidationErrors(['items', 'delivery_address', 'payment_method']);
    }

    public function test_un_client_ne_voit_pas_la_commande_dun_autre(): void
    {
        $owner = $this->client();
        $order = Order::create([
            'user_id' => $owner->id,
            'status' => 'pending',
            'subtotal' => 10, 'delivery_fee' => 0, 'discount' => 0, 'total' => 10,
            'delivery_address' => 'x', 'payment_method' => 'cash', 'payment_status' => 'pending',
        ]);

        Sanctum::actingAs($this->client()); // un autre client

        $this->getJson("/api/orders/{$order->id}")->assertStatus(403);
    }

    public function test_un_client_ne_peut_pas_changer_le_statut(): void
    {
        $owner = $this->client();
        $order = Order::create([
            'user_id' => $owner->id,
            'status' => 'pending',
            'subtotal' => 10, 'delivery_fee' => 0, 'discount' => 0, 'total' => 10,
            'delivery_address' => 'x', 'payment_method' => 'cash', 'payment_status' => 'pending',
        ]);

        Sanctum::actingAs($owner); // le propriétaire lui-même

        $this->postJson("/api/orders/{$order->id}/status", ['status' => 'confirmed'])
            ->assertStatus(403);
    }

    public function test_un_admin_peut_faire_transiter_le_statut(): void
    {
        $owner = $this->client();
        $admin = User::create([
            'name' => 'Admin', 'email' => 'admin-'.uniqid().'@test.dev', 'role' => 'admin',
        ]);
        $order = Order::create([
            'user_id' => $owner->id,
            'status' => 'pending',
            'subtotal' => 10, 'delivery_fee' => 0, 'discount' => 0, 'total' => 10,
            'delivery_address' => 'x', 'payment_method' => 'cash', 'payment_status' => 'pending',
        ]);

        Sanctum::actingAs($admin);

        $this->postJson("/api/orders/{$order->id}/status", ['status' => 'confirmed'])
            ->assertStatus(200)
            ->assertJsonPath('data.status', 'confirmed');

        $this->assertDatabaseHas('orders', ['id' => $order->id, 'status' => 'confirmed']);
    }
}

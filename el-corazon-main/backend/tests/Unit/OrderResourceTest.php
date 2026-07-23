<?php

namespace Tests\Unit;

use App\Http\Resources\OrderResource;
use App\Models\Order;
use App\Models\OrderItem;
use Illuminate\Http\Request;
use PHPUnit\Framework\TestCase;

/**
 * Vérifie le contrat de sortie d'une commande : champs exposés, relations
 * présentes uniquement quand chargées (whenLoaded), sans requête base.
 */
class OrderResourceTest extends TestCase
{
    private function baseOrder(): Order
    {
        $order = new Order([
            'user_id' => 'u-1',
            'status' => 'pending',
            'subtotal' => 10.0,
            'delivery_fee' => 2.5,
            'discount' => 0.0,
            'total' => 12.5,
            'delivery_address' => '12 rue du Test',
            'payment_method' => 'cash',
            'payment_status' => 'pending',
        ]);
        $order->id = 'o-1';

        return $order;
    }

    public function test_expose_les_champs_scalaires_attendus(): void
    {
        $data = (new OrderResource($this->baseOrder()))->resolve(Request::create('/'));

        $this->assertSame('o-1', $data['id']);
        $this->assertSame('pending', $data['status']);
        $this->assertSame(12.5, $data['total']);
        $this->assertSame('cash', $data['payment_method']);
        $this->assertArrayHasKey('delivery_address', $data);
    }

    public function test_relations_absentes_quand_non_chargees(): void
    {
        $data = (new OrderResource($this->baseOrder()))->resolve(Request::create('/'));

        // whenLoaded : les relations non chargées ne doivent pas apparaître.
        $this->assertArrayNotHasKey('items', $data);
        $this->assertArrayNotHasKey('status_updates', $data);
        $this->assertArrayNotHasKey('delivery_person', $data);
    }

    public function test_relations_presentes_quand_chargees(): void
    {
        $order = $this->baseOrder();
        $item = new OrderItem([
            'menu_item_id' => 'm-1',
            'name' => 'Burger',
            'category' => 'Plats',
            'quantity' => 2,
            'unit_price' => 5.0,
            'total_price' => 10.0,
        ]);
        $item->id = 'oi-1';
        $order->setRelation('items', collect([$item]));

        $data = (new OrderResource($order))->resolve(Request::create('/'));

        $this->assertArrayHasKey('items', $data);
        $this->assertCount(1, $data['items']);
        $this->assertSame('Burger', $data['items'][0]['name']);
    }
}

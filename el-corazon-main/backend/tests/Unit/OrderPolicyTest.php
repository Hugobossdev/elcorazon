<?php

namespace Tests\Unit;

use App\Models\Order;
use App\Models\User;
use App\Policies\OrderPolicy;
use PHPUnit\Framework\TestCase;

/**
 * Vérifie la logique d'autorisation des commandes sans toucher la base :
 * les modèles sont instanciés en mémoire, la Policy ne lit que des attributs.
 */
class OrderPolicyTest extends TestCase
{
    private OrderPolicy $policy;

    protected function setUp(): void
    {
        parent::setUp();
        $this->policy = new OrderPolicy;
    }

    private function user(string $id, string $role): User
    {
        $user = new User(['role' => $role]);
        $user->id = $id;

        return $user;
    }

    private function order(string $ownerId, ?string $driverId = null): Order
    {
        $order = new Order;
        $order->user_id = $ownerId;
        $order->delivery_person_id = $driverId;

        return $order;
    }

    public function test_client_voit_uniquement_ses_commandes(): void
    {
        $owner = $this->user('u-1', 'client');
        $stranger = $this->user('u-2', 'client');
        $order = $this->order('u-1');

        $this->assertTrue($this->policy->view($owner, $order));
        $this->assertFalse($this->policy->view($stranger, $order));
    }

    public function test_livreur_assigne_voit_la_commande(): void
    {
        $assigned = $this->user('d-9', 'delivery');
        $other = $this->user('d-8', 'delivery');
        $order = $this->order('u-1', 'd-9');

        $this->assertTrue($this->policy->view($assigned, $order));
        $this->assertFalse($this->policy->view($other, $order));
    }

    public function test_admin_a_acces_total(): void
    {
        $admin = $this->user('a-1', 'admin');
        $order = $this->order('u-1', 'd-9');

        $this->assertTrue($this->policy->view($admin, $order));
        $this->assertTrue($this->policy->update($admin, $order));
        $this->assertTrue($this->policy->cancel($admin, $order));
    }

    public function test_transition_statut_reservee_admin_ou_livreur_assigne(): void
    {
        $order = $this->order('u-1', 'd-9');

        $this->assertTrue($this->policy->update($this->user('d-9', 'delivery'), $order));
        $this->assertFalse($this->policy->update($this->user('d-8', 'delivery'), $order));
        // Le client propriétaire ne peut pas changer le statut lui-même.
        $this->assertFalse($this->policy->update($this->user('u-1', 'client'), $order));
    }

    public function test_creation_autorisee_pour_tout_utilisateur(): void
    {
        $this->assertTrue($this->policy->create($this->user('u-1', 'client')));
        $this->assertTrue($this->policy->create($this->user('d-1', 'delivery')));
    }
}

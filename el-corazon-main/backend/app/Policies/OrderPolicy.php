<?php

namespace App\Policies;

use App\Models\Order;
use App\Models\User;

/**
 * Autorisations centralisées pour les commandes.
 *
 * Règles applicatives :
 * - admin : accès total ;
 * - client : uniquement ses propres commandes ;
 * - livreur : uniquement les commandes qui lui sont assignées.
 *
 * Auto-découverte Laravel : App\Models\Order → App\Policies\OrderPolicy.
 */
class OrderPolicy
{
    /** Tout utilisateur authentifié peut créer une commande. */
    public function create(User $user): bool
    {
        return true;
    }

    /** Consultation d'une commande précise. */
    public function view(User $user, Order $order): bool
    {
        return $this->owns($user, $order);
    }

    /** Transition de statut : admin ou livreur assigné. */
    public function update(User $user, Order $order): bool
    {
        return $user->isAdmin()
            || ($user->isDriver() && $order->delivery_person_id === $user->id);
    }

    /** Annulation : mêmes ayants droit que la consultation. */
    public function cancel(User $user, Order $order): bool
    {
        return $this->owns($user, $order);
    }

    /** Admin, propriétaire client ou livreur assigné. */
    private function owns(User $user, Order $order): bool
    {
        return $user->isAdmin()
            || $order->user_id === $user->id
            || $order->delivery_person_id === $user->id;
    }
}

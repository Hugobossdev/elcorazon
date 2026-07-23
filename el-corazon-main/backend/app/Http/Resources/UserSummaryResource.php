<?php

namespace App\Http\Resources;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Représentation publique et minimale d'un utilisateur (ex. livreur associé à
 * une commande). N'expose jamais d'informations sensibles (email, rôle interne,
 * statut de vérification, etc.).
 *
 * @mixin User
 */
class UserSummaryResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'phone' => $this->phone,
            'profile_image' => $this->profile_image,
        ];
    }
}

<?php

namespace App\Services\Notifications;

use App\Models\Notification;
use App\Services\Push\FcmService;

/**
 * Centralise la création de notifications en base. La diffusion temps réel est
 * assurée par Supabase Realtime côté client ; un push FCM est envoyé en plus
 * lorsqu'un token d'appareil est fourni et que FCM est configuré.
 *
 * NB : le schéma Supabase ne stocke pas encore les tokens FCM. Pour un push
 * automatique sur chaque notification, ajouter une table `device_tokens`
 * (user_id, token, platform) et charger les tokens ici.
 */
class NotificationService
{
    public function __construct(private readonly FcmService $fcm)
    {
    }

    /**
     * @param  array<string, mixed>  $data
     * @param  array<int, string>  $pushTokens  Tokens d'appareil à notifier (optionnel).
     */
    public function notify(
        string $userId,
        string $title,
        string $message,
        string $type = 'info',
        array $data = [],
        ?string $fromUserId = null,
        array $pushTokens = [],
    ): Notification {
        $notification = Notification::create([
            'user_id' => $userId,
            'from_user_id' => $fromUserId,
            'title' => $title,
            'message' => $message,
            'type' => $type,
            'is_read' => false,
            'data' => $data,
        ]);

        if ($pushTokens !== [] && $this->fcm->isConfigured()) {
            $payload = array_map('strval', $data + ['notification_id' => $notification->id, 'type' => $type]);
            foreach ($pushTokens as $token) {
                $this->fcm->sendToToken($token, $title, $message, $payload);
            }
        }

        return $notification;
    }
}

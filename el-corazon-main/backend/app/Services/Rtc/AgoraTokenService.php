<?php

namespace App\Services\Rtc;

/**
 * Génère des tokens RTC Agora (schéma legacy « 006 »), utilisés par les appels
 * audio/vidéo des apps client et livreur.
 *
 * Le certificat d'application (App Certificate) ne doit jamais quitter le serveur.
 * L'algorithme reproduit le RtcTokenBuilder officiel d'Agora.
 */
class AgoraTokenService
{
    private const VERSION = '006';

    // Privilèges RTC.
    private const PRIVILEGE_JOIN_CHANNEL = 1;
    private const PRIVILEGE_PUBLISH_AUDIO = 2;
    private const PRIVILEGE_PUBLISH_VIDEO = 3;
    private const PRIVILEGE_PUBLISH_DATA = 4;

    public function __construct(
        private readonly ?string $appId = null,
        private readonly ?string $appCertificate = null,
    ) {
    }

    private function appId(): string
    {
        return $this->appId ?? (string) config('services.agora.app_id');
    }

    private function appCertificate(): string
    {
        return $this->appCertificate ?? (string) config('services.agora.app_certificate');
    }

    public function isConfigured(): bool
    {
        return $this->appId() !== '' && $this->appCertificate() !== '';
    }

    /**
     * Construit un token pour rejoindre et publier sur un canal.
     *
     * @param  string  $channelName  Nom du canal RTC.
     * @param  int     $uid          UID Agora (0 = auto-assigné par Agora).
     * @param  int|null $ttl         Durée de validité en secondes.
     */
    public function buildRtcToken(string $channelName, int $uid = 0, ?int $ttl = null): string
    {
        $ttl ??= (int) config('services.agora.token_ttl', 3600);
        $expire = time() + $ttl;

        $salt = random_int(1, 99999999);
        $ts = time() + 24 * 3600;
        $uidStr = $uid === 0 ? '' : (string) $uid;

        $messages = [
            self::PRIVILEGE_JOIN_CHANNEL => $expire,
            self::PRIVILEGE_PUBLISH_AUDIO => $expire,
            self::PRIVILEGE_PUBLISH_VIDEO => $expire,
            self::PRIVILEGE_PUBLISH_DATA => $expire,
        ];

        $toSign = $this->packUint32($salt)
            . $this->packUint32($ts)
            . $this->packMapUint32($messages);

        $signature = hash_hmac(
            'sha256',
            $this->appId() . $channelName . $uidStr . $toSign,
            $this->appCertificate(),
            true,
        );

        $content = $this->packString($signature)
            . $this->packUint32(crc32($channelName) & 0xFFFFFFFF)
            . $this->packUint32(crc32($uidStr) & 0xFFFFFFFF)
            . $this->packString($toSign);

        return self::VERSION . $this->appId() . base64_encode($content);
    }

    private function packUint16(int $x): string
    {
        return pack('v', $x);
    }

    private function packUint32(int $x): string
    {
        return pack('V', $x);
    }

    private function packString(string $value): string
    {
        return $this->packUint16(strlen($value)) . $value;
    }

    /** @param array<int, int> $map */
    private function packMapUint32(array $map): string
    {
        ksort($map);
        $buffer = $this->packUint16(count($map));
        foreach ($map as $key => $value) {
            $buffer .= $this->packUint16($key) . $this->packUint32($value);
        }

        return $buffer;
    }
}

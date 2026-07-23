<?php

namespace App\Services\Delivery;

/**
 * Calcul des frais de livraison côté serveur (source de vérité).
 *
 * Règle répliquée depuis l'app cliente (DeliveryConfig / DeliveryFeeService) :
 *  - frais = base + prix_par_km × distance (Haversine depuis le restaurant) ;
 *  - plafonné à un maximum, arrondi à la dizaine supérieure ;
 *  - gratuit si sous-total ≥ seuil, ou client VIP ;
 *  - frais par défaut si les coordonnées de livraison sont absentes.
 *
 * Valeurs surchargeables via config/services.php > delivery.
 */
class DeliveryFeeService
{
    private function cfg(string $key, float $default): float
    {
        $value = config("services.delivery.$key");

        return $value !== null ? (float) $value : $default;
    }

    /**
     * @return array{fee: float, distance_km: float|null, free: bool, reason: string}
     */
    public function compute(
        float $subtotal,
        ?float $latitude = null,
        ?float $longitude = null,
        bool $isVip = false,
    ): array {
        $base = $this->cfg('base_fee', 500.0);
        $perKm = $this->cfg('price_per_km', 200.0);
        $maxFee = $this->cfg('max_fee', 5000.0);
        $defaultFee = $this->cfg('default_fee', 1000.0);
        $freeThreshold = $this->cfg('free_delivery_threshold', 10000.0);

        if ($isVip) {
            return ['fee' => 0.0, 'distance_km' => null, 'free' => true, 'reason' => 'vip'];
        }

        if ($subtotal >= $freeThreshold) {
            return ['fee' => 0.0, 'distance_km' => null, 'free' => true, 'reason' => 'threshold'];
        }

        // Sans coordonnées, on ne peut pas mesurer la distance → frais par défaut.
        if ($latitude === null || $longitude === null) {
            return [
                'fee' => $this->roundUpToTen($defaultFee),
                'distance_km' => null,
                'free' => false,
                'reason' => 'default_no_coords',
            ];
        }

        $distance = $this->haversineKm(
            $this->cfg('restaurant_latitude', 6.1375),
            $this->cfg('restaurant_longitude', 1.2123),
            $latitude,
            $longitude,
        );

        $fee = min($base + $perKm * $distance, $maxFee);

        return [
            'fee' => $this->roundUpToTen($fee),
            'distance_km' => round($distance, 2),
            'free' => false,
            'reason' => 'distance',
        ];
    }

    /** Distance orthodromique en kilomètres (formule de Haversine). */
    private function haversineKm(float $lat1, float $lon1, float $lat2, float $lon2): float
    {
        $earthRadius = 6371.0; // km
        $dLat = deg2rad($lat2 - $lat1);
        $dLon = deg2rad($lon2 - $lon1);

        $a = sin($dLat / 2) ** 2
            + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLon / 2) ** 2;

        return $earthRadius * (2 * atan2(sqrt($a), sqrt(1 - $a)));
    }

    private function roundUpToTen(float $value): float
    {
        return ceil($value / 10) * 10;
    }
}

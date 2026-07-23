<?php

return [

    // Supabase — projet PostgreSQL + Auth + Storage partagé par les 3 apps.
    'supabase' => [
        'url' => env('SUPABASE_URL'),
        'anon_key' => env('SUPABASE_ANON_KEY'),
        'service_role_key' => env('SUPABASE_SERVICE_ROLE_KEY'),
        // Secret de signature des JWT (Project Settings > API > JWT Secret).
        'jwt_secret' => env('SUPABASE_JWT_SECRET', env('JWT_SECRET')),
    ],

    // PayDunya — passerelle de paiement Afrique de l'Ouest.
    'paydunya' => [
        'master_key' => env('PAYDUNYA_MASTER_KEY'),
        'private_key' => env('PAYDUNYA_PRIVATE_KEY'),
        'public_key' => env('PAYDUNYA_PUBLIC_KEY'),
        'token' => env('PAYDUNYA_TOKEN'),
        'sandbox' => (bool) env('PAYDUNYA_IS_SANDBOX', false),
        'store_name' => env('PAYDUNYA_STORE_NAME', 'El Corazon'),
        'callback_url' => env('PAYDUNYA_CALLBACK_URL'),
        'return_url' => env('PAYDUNYA_RETURN_URL'),
        'cancel_url' => env('PAYDUNYA_CANCEL_URL'),
    ],

    // Agora — tokens RTC pour les appels audio/vidéo.
    'agora' => [
        'app_id' => env('AGORA_APP_ID'),
        'app_certificate' => env('AGORA_APP_CERTIFICATE'),
        'token_ttl' => (int) env('AGORA_TOKEN_TTL', 3600),
    ],

    // Firebase Cloud Messaging — notifications push.
    'firebase' => [
        'credentials' => env('FIREBASE_CREDENTIALS_JSON'),
        'project_id' => env('FIREBASE_PROJECT_ID'),
    ],

    'google_maps' => [
        'key' => env('GOOGLE_MAPS_API_KEY'),
    ],

    // Règle de calcul des frais de livraison (voir DeliveryFeeService).
    'delivery' => [
        'base_fee' => env('DELIVERY_BASE_FEE', 500),
        'price_per_km' => env('DELIVERY_PRICE_PER_KM', 200),
        'max_fee' => env('DELIVERY_MAX_FEE', 5000),
        'default_fee' => env('DELIVERY_DEFAULT_FEE', 1000),
        'free_delivery_threshold' => env('DELIVERY_FREE_THRESHOLD', 10000),
        'restaurant_latitude' => env('RESTAURANT_LATITUDE', 6.1375),
        'restaurant_longitude' => env('RESTAURANT_LONGITUDE', 1.2123),
    ],

];

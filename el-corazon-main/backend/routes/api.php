<?php

use App\Http\Controllers\Api\AddressController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\AnalyticsController;
use App\Http\Controllers\Api\CartController;
use App\Http\Controllers\Api\ComplaintController;
use App\Http\Controllers\Api\DeliveryController;
use App\Http\Controllers\Api\DeliveryQuoteController;
use App\Http\Controllers\Api\DriverController;
use App\Http\Controllers\Api\GamificationController;
use App\Http\Controllers\Api\GroupPaymentController;
use App\Http\Controllers\Api\LoyaltyController;
use App\Http\Controllers\Api\MenuCategoryController;
use App\Http\Controllers\Api\MenuItemController;
use App\Http\Controllers\Api\NotificationController;
use App\Http\Controllers\Api\OrderController;
use App\Http\Controllers\Api\PaymentController;
use App\Http\Controllers\Api\ProductReviewController;
use App\Http\Controllers\Api\PromotionController;
use App\Http\Controllers\Api\PushController;
use App\Http\Controllers\Api\ReturnRequestController;
use App\Http\Controllers\Api\RtcTokenController;
use App\Http\Controllers\Api\SocialGroupController;
use App\Http\Controllers\Api\SocialPostController;
use App\Http\Controllers\Api\SubscriptionController;
use App\Http\Controllers\Api\SupportController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Routes API — El Corazon
|--------------------------------------------------------------------------
| Toutes les routes authentifiées attendent un Bearer token Sanctum.
| Middlewares : `auth:sanctum` (jeton valide) et `role:...` (rôle applicatif).
*/

Route::get('/', fn () => response()->json([
    'name' => config('app.name'),
    'version' => '1.0.0',
    'status' => 'ok',
]));

// --- Public (catalogue) --------------------------------------------------
Route::get('menu/categories', [MenuCategoryController::class, 'index']);
Route::get('menu/categories/{category}', [MenuCategoryController::class, 'show']);
Route::get('menu/items', [MenuItemController::class, 'index']);
Route::get('menu/items/{menuItem}', [MenuItemController::class, 'show']);
Route::get('menu/items/{menuItem}/reviews', [ProductReviewController::class, 'index']);

// --- Webhooks (publics, vérifiés côté serveur) ---------------------------
Route::post('webhooks/paydunya', [PaymentController::class, 'paydunyaWebhook']);

// --- Authentification (publique) -----------------------------------------
Route::post('auth/register', [AuthController::class, 'register']);
Route::post('auth/login', [AuthController::class, 'login']);

// Pont de migration : échange d'un jeton Supabase contre un jeton Sanctum.
Route::post('auth/exchange', [AuthController::class, 'exchange'])
    ->middleware('supabase.auth');

// --- Authentifié (tous rôles, jeton Sanctum) -----------------------------
Route::middleware('auth:sanctum')->group(function () {
    // Auth / profil
    Route::post('auth/logout', [AuthController::class, 'logout']);
    Route::post('auth/logout-all', [AuthController::class, 'logoutAll']);
    Route::post('auth/change-password', [AuthController::class, 'changePassword']);
    Route::get('me', [AuthController::class, 'me']);
    Route::put('me', [AuthController::class, 'updateProfile']);
    Route::post('me/heartbeat', [AuthController::class, 'heartbeat']);

    // Adresses
    Route::apiResource('addresses', AddressController::class)->except(['show']);

    // Panier
    Route::get('cart', [CartController::class, 'show']);
    Route::post('cart/items', [CartController::class, 'addItem']);
    Route::put('cart/items/{item}', [CartController::class, 'updateItem']);
    Route::delete('cart/items/{item}', [CartController::class, 'removeItem']);
    Route::delete('cart', [CartController::class, 'clear']);

    // Devis de frais de livraison (calcul serveur)
    Route::post('delivery/quote', [DeliveryQuoteController::class, 'quote']);

    // Commandes
    Route::get('orders', [OrderController::class, 'index']);
    Route::post('orders', [OrderController::class, 'store']);
    Route::get('orders/{order}', [OrderController::class, 'show']);
    Route::post('orders/{order}/status', [OrderController::class, 'updateStatus']);
    Route::post('orders/{order}/cancel', [OrderController::class, 'cancel']);

    // Avis produits
    Route::post('menu/items/{menuItem}/reviews', [ProductReviewController::class, 'store']);
    Route::delete('reviews/{review}', [ProductReviewController::class, 'destroy']);

    // Paiements
    Route::post('orders/{order}/pay/paydunya', [PaymentController::class, 'initiatePaydunya']);

    // Promotions (lecture + validation de code)
    Route::get('promotions', [PromotionController::class, 'index']);
    Route::post('promotions/validate', [PromotionController::class, 'validateCode']);

    // Notifications
    Route::get('notifications', [NotificationController::class, 'index']);
    Route::get('notifications/unread-count', [NotificationController::class, 'unreadCount']);
    Route::post('notifications/{notification}/read', [NotificationController::class, 'markAsRead']);
    Route::post('notifications/read-all', [NotificationController::class, 'markAllAsRead']);
    Route::delete('notifications/{notification}', [NotificationController::class, 'destroy']);

    // Token RTC Agora (appels)
    Route::post('rtc/token', [RtcTokenController::class, 'token']);

    // Fidélité
    Route::get('loyalty/summary', [LoyaltyController::class, 'summary']);
    Route::get('loyalty/rewards', [LoyaltyController::class, 'rewards']);
    Route::get('loyalty/transactions', [LoyaltyController::class, 'transactions']);
    Route::post('loyalty/rewards/{reward}/redeem', [LoyaltyController::class, 'redeem']);

    // Gamification
    Route::get('gamification/achievements', [GamificationController::class, 'achievements']);
    Route::get('gamification/challenges', [GamificationController::class, 'challenges']);
    Route::get('gamification/badges', [GamificationController::class, 'badges']);

    // Abonnements
    Route::get('subscriptions', [SubscriptionController::class, 'index']);
    Route::post('subscriptions', [SubscriptionController::class, 'store']);
    Route::get('subscriptions/{subscription}', [SubscriptionController::class, 'show']);
    Route::post('subscriptions/{subscription}/status', [SubscriptionController::class, 'setStatus']);
    Route::post('subscriptions/{subscription}/cancel', [SubscriptionController::class, 'cancel']);

    // Social — groupes
    Route::get('social/groups', [SocialGroupController::class, 'index']);
    Route::post('social/groups', [SocialGroupController::class, 'store']);
    Route::post('social/groups/join', [SocialGroupController::class, 'join']);
    Route::get('social/groups/{group}', [SocialGroupController::class, 'show']);
    Route::post('social/groups/{group}/leave', [SocialGroupController::class, 'leave']);

    // Social — posts
    Route::get('social/posts', [SocialPostController::class, 'index']);
    Route::post('social/posts', [SocialPostController::class, 'store']);
    Route::delete('social/posts/{post}', [SocialPostController::class, 'destroy']);
    Route::post('social/posts/{post}/like', [SocialPostController::class, 'toggleLike']);
    Route::get('social/posts/{post}/comments', [SocialPostController::class, 'comments']);
    Route::post('social/posts/{post}/comments', [SocialPostController::class, 'addComment']);

    // Support — tickets
    Route::get('support/tickets', [SupportController::class, 'index']);
    Route::post('support/tickets', [SupportController::class, 'store']);
    Route::get('support/tickets/{ticket}', [SupportController::class, 'show']);
    Route::post('support/tickets/{ticket}/messages', [SupportController::class, 'addMessage']);
    Route::post('support/tickets/{ticket}/status', [SupportController::class, 'setStatus']);

    // Réclamations & retours
    Route::get('complaints', [ComplaintController::class, 'index']);
    Route::post('complaints', [ComplaintController::class, 'store']);
    Route::post('complaints/{complaint}/resolve', [ComplaintController::class, 'resolve']);
    Route::get('return-requests', [ReturnRequestController::class, 'index']);
    Route::post('return-requests', [ReturnRequestController::class, 'store']);
    Route::post('return-requests/{returnRequest}/decide', [ReturnRequestController::class, 'decide']);

    // Paiements partagés (diviser l'addition)
    Route::post('orders/{order}/group-payment', [GroupPaymentController::class, 'store']);
    Route::get('group-payments/{groupPayment}', [GroupPaymentController::class, 'show']);
    Route::post('group-payments/participants/{participant}/pay', [GroupPaymentController::class, 'markParticipantPaid']);

    // Journalisation d'évènements analytics
    Route::post('analytics/events', [AnalyticsController::class, 'logEvent']);

    // --- Livreurs (role: delivery) --------------------------------------
    Route::middleware('role:delivery')->prefix('delivery')->group(function () {
        Route::post('profile', [DriverController::class, 'upsertOwnProfile']);
        Route::get('available-orders', [DeliveryController::class, 'availableOrders']);
        Route::get('my-deliveries', [DeliveryController::class, 'myDeliveries']);
        Route::post('orders/{order}/accept', [DeliveryController::class, 'acceptOrder']);
        Route::post('deliveries/{delivery}/status', [DeliveryController::class, 'updateDeliveryStatus']);
        Route::post('location', [DeliveryController::class, 'updateLocation']);
        Route::post('availability', [DeliveryController::class, 'toggleAvailability']);
    });

    // --- Administration (role: admin) -----------------------------------
    Route::middleware('role:admin')->prefix('admin')->group(function () {
        // Menu
        Route::post('menu/categories', [MenuCategoryController::class, 'store']);
        Route::put('menu/categories/{category}', [MenuCategoryController::class, 'update']);
        Route::delete('menu/categories/{category}', [MenuCategoryController::class, 'destroy']);
        Route::post('menu/items', [MenuItemController::class, 'store']);
        Route::put('menu/items/{menuItem}', [MenuItemController::class, 'update']);
        Route::delete('menu/items/{menuItem}', [MenuItemController::class, 'destroy']);
        Route::post('menu/items/{menuItem}/toggle', [MenuItemController::class, 'toggleAvailability']);

        // Livreurs
        Route::get('drivers', [DriverController::class, 'index']);
        Route::get('drivers/{driver}', [DriverController::class, 'show']);
        Route::post('drivers/{driver}/verify', [DriverController::class, 'verify']);

        // Promotions
        Route::post('promotions', [PromotionController::class, 'store']);
        Route::put('promotions/{promotion}', [PromotionController::class, 'update']);
        Route::delete('promotions/{promotion}', [PromotionController::class, 'destroy']);

        // Analytics / reporting
        Route::get('analytics/dashboard', [AnalyticsController::class, 'dashboard']);
        Route::get('analytics/revenue', [AnalyticsController::class, 'revenue']);
        Route::get('analytics/top-items', [AnalyticsController::class, 'topItems']);

        // Push (diagnostic + test)
        Route::get('push/status', [PushController::class, 'status']);
        Route::post('push/test', [PushController::class, 'test']);
    });
});

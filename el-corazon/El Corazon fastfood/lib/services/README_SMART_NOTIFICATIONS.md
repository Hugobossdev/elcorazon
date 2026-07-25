# 🔔 Guide des Notifications Push Intelligentes

## Vue d'ensemble

L'amélioration #17 implémente un système de notifications push intelligentes avec :
- Personnalisation basée sur l'historique et les préférences utilisateur
- Segmentation des utilisateurs
- Analyse des comportements d'achat
- Messages contextuels et pertinents

## Types de Notifications

### 1. Promotions Personnalisées (`SmartNotificationType.promotion`)

Analyse les catégories préférées de l'utilisateur et envoie des promotions ciblées.

```dart
await smartNotificationService.sendPersonalizedNotification(
  userId: userId,
  type: SmartNotificationType.promotion,
);
```

**Personnalisation :**
- Détecte la catégorie préférée basée sur l'historique
- Message adapté : "Promotion spéciale sur vos pizzas préférés !"

### 2. Rappels de Commande (`SmartNotificationType.orderReminder`)

Envoie des rappels basés sur la fréquence d'achat.

```dart
await smartNotificationService.sendPersonalizedNotification(
  userId: userId,
  type: SmartNotificationType.orderReminder,
);
```

**Personnalisation :**
- Messages différents selon le temps écoulé depuis la dernière commande
- Si > 7 jours : "Cela fait X jours que vous ne nous avez pas visités..."
- Sinon : "Envie d'un bon repas ?"

### 3. Favoris Disponibles (`SmartNotificationType.favoriteAvailable`)

Notifie quand un article favori devient disponible.

```dart
await smartNotificationService.sendPersonalizedNotification(
  userId: userId,
  type: SmartNotificationType.favoriteAvailable,
);
```

**Personnalisation :**
- Utilise les favoris de l'utilisateur
- Message : "{Nom du favori} est de nouveau disponible !"

### 4. Nouveaux Arrivages (`SmartNotificationType.newArrival`)

Informe sur les nouveaux articles dans les catégories préférées.

```dart
await smartNotificationService.sendPersonalizedNotification(
  userId: userId,
  type: SmartNotificationType.newArrival,
);
```

**Personnalisation :**
- Basé sur les catégories préférées
- Message : "Découvrez nos nouveaux pizzas fraîchement ajoutés !"

### 5. Statut de Commande (`SmartNotificationType.orderStatus`)

Notifications de statut personnalisées.

```dart
await smartNotificationService.sendPersonalizedNotification(
  userId: userId,
  type: SmartNotificationType.orderStatus,
  customData: {
    'order': order,
  },
);
```

**Personnalisation :**
- Titre et message adaptés au statut
- Utilise le numéro de commande

### 6. Récompenses de Fidélité (`SmartNotificationType.loyaltyReward`)

Encourage l'utilisation des points de fidélité.

```dart
await smartNotificationService.sendPersonalizedNotification(
  userId: userId,
  type: SmartNotificationType.loyaltyReward,
);
```

**Personnalisation :**
- Affiche les points actuels
- Indique les points manquants pour la prochaine récompense

### 7. Panier Abandonné (`SmartNotificationType.abandonedCart`)

Rappelle les articles oubliés dans le panier.

```dart
await smartNotificationService.sendPersonalizedNotification(
  userId: userId,
  type: SmartNotificationType.abandonedCart,
  customData: {
    'cartItems': cartItems,
  },
);
```

**Personnalisation :**
- Affiche le nombre d'articles
- Message incitatif pour finaliser

## Utilisation

### 1. Initialiser le Service

```dart
final smartNotificationService = SmartNotificationService();
await smartNotificationService.initialize();
```

### 2. Envoyer une Notification Personnalisée

```dart
await smartNotificationService.sendPersonalizedNotification(
  userId: userId,
  type: SmartNotificationType.promotion,
  customData: {
    'message': 'Message personnalisé optionnel',
  },
);
```

### 3. Envoyer des Notifications Segmentées

```dart
// Envoyer à un groupe d'utilisateurs
final userIds = ['user1', 'user2', 'user3'];
await smartNotificationService.sendSegmentedNotification(
  userIds: userIds,
  type: SmartNotificationType.promotion,
  customData: {
    'message': 'Promotion exclusive pour vous !',
  },
);
```

## Personnalisation Avancée

### Analyse des Préférences

Le service analyse automatiquement :
- **Historique des commandes** : Catégories et articles les plus commandés
- **Favoris** : Articles marqués comme favoris
- **Points de fidélité** : Statut de récompenses
- **Fréquence d'achat** : Dernière commande et habitudes

### Messages Contextuels

Les messages sont générés dynamiquement :
- Utilisation du nom des catégories préférées
- Adaptation du ton selon le contexte
- Inclusion d'emojis appropriés
- Informations pertinentes (dates, quantités, etc.)

## Exemple Complet

```dart
class NotificationExample {
  final SmartNotificationService _notificationService;

  NotificationExample(this._notificationService);

  Future<void> sendPromotionToUser(String userId) async {
    // Envoyer une promotion personnalisée
    await _notificationService.sendPersonalizedNotification(
      userId: userId,
      type: SmartNotificationType.promotion,
    );
  }

  Future<void> remindUserToOrder(String userId) async {
    // Rappeler à l'utilisateur de commander
    await _notificationService.sendPersonalizedNotification(
      userId: userId,
      type: SmartNotificationType.orderReminder,
    );
  }

  Future<void> notifyFavoriteAvailable(String userId) async {
    // Notifier la disponibilité d'un favori
    await _notificationService.sendPersonalizedNotification(
      userId: userId,
      type: SmartNotificationType.favoriteAvailable,
    );
  }

  Future<void> sendLoyaltyReward(String userId) async {
    // Encourager l'utilisation des points
    await _notificationService.sendPersonalizedNotification(
      userId: userId,
      type: SmartNotificationType.loyaltyReward,
    );
  }

  Future<void> remindAbandonedCart(
    String userId,
    List<CartItem> cartItems,
  ) async {
    // Rappeler le panier abandonné
    await _notificationService.sendPersonalizedNotification(
      userId: userId,
      type: SmartNotificationType.abandonedCart,
      customData: {
        'cartItems': cartItems.map((item) => item.toMap()).toList(),
      },
    );
  }
}
```

## Intégration avec PushNotificationService

Le service utilise `PushNotificationService` pour l'envoi effectif :

```dart
// Méthode publique ajoutée dans PushNotificationService
await pushNotificationService.sendCustomNotification(
  title: 'Titre',
  body: 'Message',
  payload: jsonEncode({'type': 'promotion'}),
  channelId: 'marketing',
);
```

## Bénéfices

- ✅ **Engagement amélioré** : Messages pertinents et personnalisés
- ✅ **Taux d'ouverture plus élevé** : Notifications ciblées
- ✅ **Meilleure conversion** : Appels à l'action contextuels
- ✅ **Expérience utilisateur** : Messages adaptés aux préférences
- ✅ **Segmentation** : Envoi ciblé à des groupes d'utilisateurs


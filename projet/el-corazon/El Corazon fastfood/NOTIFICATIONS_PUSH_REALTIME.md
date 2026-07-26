# 🔔 Notifications Push avec Supabase Realtime Database

## Vue d'ensemble

Le projet **El Corazón** utilise une architecture hybride pour les notifications push qui combine :
- **Supabase Realtime** : Pour écouter les changements en temps réel dans la base de données
- **Flutter Local Notifications** : Pour afficher les notifications push sur l'appareil

## Architecture

```
┌─────────────────┐
│  Supabase DB    │
│  (notifications)│
└────────┬────────┘
         │ INSERT/UPDATE
         ▼
┌─────────────────────────┐
│ Supabase Realtime       │
│ (Postgres Changes)      │
└────────┬────────────────┘
         │ Stream
         ▼
┌─────────────────────────┐
│ SupabaseRealtimeService │
│ (Écoute les changements)│
└────────┬────────────────┘
         │
         ├─────────────────┐
         │                 │
         ▼                 ▼
┌──────────────────┐  ┌─────────────────────┐
│NotificationService│  │PushNotificationService│
│(Gestion locale)  │  │(Notifications push) │
└──────────────────┘  └─────────────────────┘
         │
         ▼
┌─────────────────────────┐
│ Flutter Local           │
│ Notifications           │
│ (Affichage système)     │
└─────────────────────────┘
```

## Composants principaux

### 1. **SupabaseRealtimeService** (`lib/services/supabase_realtime_service.dart`)

Service central qui s'abonne aux changements de la base de données Supabase.

#### Fonctionnalités clés :

```107:134:El Corazón/lib/services/supabase_realtime_service.dart
  void _subscribeToNotifications(String userId) {
    try {
      _notificationChannel = _supabase
          .channel('public:notifications:$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              final record = payload.newRecord as Map<String, dynamic>?;
              final message =
                  record?['message']?.toString() ?? 'Nouvelle notification';
              _notificationsController.add(message);
              notifyListeners();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint(
        'SupabaseRealtimeService: error subscribing to notifications - $e',
      );
    }
  }
```

**Ce que fait ce service :**
- Crée un canal Realtime spécifique à l'utilisateur : `public:notifications:$userId`
- Écoute les **INSERT** dans la table `notifications`
- Filtre par `user_id` pour ne recevoir que les notifications de l'utilisateur connecté
- Émet un stream de messages via `_notificationsController`

### 2. **NotificationService** (`lib/services/notification_service.dart`)

Service qui gère l'affichage des notifications locales et s'abonne aux notifications Realtime.

#### Abonnement Realtime :

```139:181:El Corazón/lib/services/notification_service.dart
  /// S'abonne aux notifications en temps réel depuis Supabase
  Future<void> _subscribeToRealtimeNotifications(String userId) async {
    try {
      // S'abonner au stream du service Realtime
      _notificationSubscription = _realtimeService.notifications.listen(
        (message) {
          debugPrint('NotificationService: Notification reçue: $message');
          // Le message est juste une chaîne, on doit récupérer les détails depuis la DB
          _refreshLatestNotification(userId);
        },
        onError: (error) {
          debugPrint(
            'NotificationService: Erreur dans le stream de notifications - $error',
          );
        },
      );

      // S'abonner directement aux changements de la table notifications
      _notificationChannel = _supabase
          .channel('notifications_$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              final record = payload.newRecord;
              _handleRealtimeNotification(record);
            },
          )
          .subscribe();

      debugPrint(
        'NotificationService: Abonnement aux notifications Realtime activé',
      );
    } catch (e) {
      debugPrint('NotificationService: Erreur lors de l\'abonnement - $e');
    }
  }
```

**Double abonnement :**
1. **Stream du SupabaseRealtimeService** : Écoute les messages génériques
2. **Canal direct Supabase** : Écoute directement les changements de la table avec les données complètes

#### Traitement des notifications :

```183:219:El Corazón/lib/services/notification_service.dart
  /// Gère une notification reçue en temps réel
  void _handleRealtimeNotification(Map<String, dynamic> notificationData) {
    try {
      final notification = {
        'id': notificationData['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        'title': notificationData['title']?.toString() ?? 'Notification',
        'message': notificationData['message']?.toString() ?? '',
        'type': notificationData['type']?.toString() ?? 'info',
        'isRead': notificationData['is_read'] ?? false,
        'time': notificationData['created_at'] != null
            ? DateTime.parse(notificationData['created_at'].toString())
            : DateTime.now(),
        'icon': _getIconForType(notificationData['type']?.toString() ?? 'info'),
        'data': notificationData['data'] ?? {},
        'backendId': notificationData['id']?.toString(),
      };

      // Ajouter la notification à la liste
      _notifications.insert(0, notification);
      _updateUnreadCount();
      notifyListeners();

      // Afficher la notification locale
      _showLocalNotification(
        title: notification['title'] as String,
        body: notification['message'] as String,
        type: notification['type'] as String,
      );

      debugPrint('NotificationService: Notification traitée et affichée');
    } catch (e) {
      debugPrint(
        'NotificationService: Erreur lors du traitement de la notification - $e',
      );
    }
  }
```

**Processus :**
1. Parse les données de la notification depuis Supabase
2. Ajoute la notification à la liste locale
3. Met à jour le compteur de non-lus
4. **Affiche une notification push locale** via `_showLocalNotification()`

### 3. **PushNotificationService** (`lib/services/push_notification_service.dart`)

Service avancé pour les notifications push avec différents types et canaux.

#### Types de notifications supportés :

- **Commandes** (`order_status`) : Statut des commandes
- **Livraisons** (`delivery`) : Mises à jour de livraison
- **Promotions** (`promotion`) : Offres spéciales
- **Achievements** (`achievement`) : Récompenses de gamification
- **Social** (`social`) : Interactions sociales

#### Canaux Android :

```78:121:El Corazón/lib/services/push_notification_service.dart
  /// Crée les canaux de notification Android
  Future<void> _createNotificationChannels() async {
    const List<AndroidNotificationChannel> channels = [
      AndroidNotificationChannel(
        'orders',
        'Commandes',
        description: 'Notifications pour les commandes',
        importance: Importance.max,
      ),
      AndroidNotificationChannel(
        'delivery',
        'Livraisons',
        description: 'Notifications pour les livraisons',
        importance: Importance.max,
      ),
      AndroidNotificationChannel(
        'promotions',
        'Promotions',
        description: 'Notifications pour les promotions',
        importance: Importance.high,
        enableVibration: false,
      ),
      AndroidNotificationChannel(
        'achievements',
        'Achievements',
        description: 'Notifications pour les achievements',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        'social',
        'Social',
        description: 'Notifications sociales',
        playSound: false,
        enableVibration: false,
      ),
    ];

    for (final channel in channels) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }
```

## Flux de données

### 1. **Création d'une notification (Backend)**

Quand une notification est créée dans Supabase (via un trigger, une fonction, ou directement) :

```sql
INSERT INTO notifications (user_id, title, message, type, data)
VALUES ('user-123', 'Commande confirmée', 'Votre commande est en préparation', 'order_status', '{"orderId": "order-456"}');
```

### 2. **Détection Realtime**

Supabase Realtime détecte l'INSERT et envoie un événement à tous les clients abonnés au canal `public:notifications:user-123`.

### 3. **Réception dans l'app**

Le `SupabaseRealtimeService` reçoit l'événement via le callback `onPostgresChanges` :

```120:126:El Corazón/lib/services/supabase_realtime_service.dart
            callback: (payload) {
              final record = payload.newRecord as Map<String, dynamic>?;
              final message =
                  record?['message']?.toString() ?? 'Nouvelle notification';
              _notificationsController.add(message);
              notifyListeners();
            },
```

### 4. **Traitement et affichage**

Le `NotificationService` :
- Reçoit les données complètes via son propre canal
- Parse et formate la notification
- Ajoute à la liste locale
- **Affiche une notification push système**

## Structure de la table `notifications` dans Supabase

La table doit avoir au minimum ces colonnes :

```sql
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id),
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  type TEXT DEFAULT 'info', -- 'order_status', 'delivery', 'promotion', etc.
  data JSONB, -- Données supplémentaires (orderId, promoCode, etc.)
  is_read BOOLEAN DEFAULT FALSE,
  read_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Index pour les performances
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_created_at ON notifications(created_at DESC);

-- Activer Realtime pour cette table
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
```

## Utilisation dans le code

### Initialisation

```dart
// Dans main.dart ou service_initializer.dart
final notificationService = NotificationService();
await notificationService.initialize(userId: currentUserId);
```

### Envoyer une notification depuis le backend

```dart
// Via SupabaseRealtimeService
await supabaseRealtimeService.sendNotification(
  targetUserId: 'user-123',
  message: 'Votre commande est prête !',
);
```

### Écouter les notifications

```dart
// Le NotificationService écoute automatiquement via Realtime
// Les notifications sont ajoutées à la liste et affichées automatiquement
final notifications = notificationService.notifications;
final unreadCount = notificationService.unreadCount;
```

## Avantages de cette architecture

✅ **Temps réel** : Les notifications arrivent instantanément via Supabase Realtime  
✅ **Synchronisation** : Les notifications sont stockées en base de données  
✅ **Offline** : Les notifications sont chargées depuis la DB au démarrage  
✅ **Multi-plateforme** : Fonctionne sur Android et iOS  
✅ **Personnalisable** : Canaux différents selon le type de notification  
✅ **Scalable** : Supabase gère la scalabilité du Realtime

## Limitations actuelles

⚠️ **Notifications locales uniquement** : Pas de notifications push cloud (FCM/APNS)  
⚠️ **Nécessite une connexion** : Le Realtime nécessite une connexion active  
⚠️ **Pas de notifications programmées cloud** : Les notifications programmées sont locales

## Améliorations possibles

1. **Intégrer FCM/APNS** pour les notifications push cloud
2. **Notifications programmées côté serveur** via des fonctions Supabase
3. **Badge de notification** sur l'icône de l'app
4. **Actions de notification** (boutons d'action)
5. **Groupement de notifications** (Android)

## Exemples de notifications

### Notification de commande

```dart
// Créée automatiquement quand le statut change
{
  "title": "🍔 Statut de votre commande",
  "message": "Votre commande #12345678 est en cours de préparation 👨‍🍳",
  "type": "order_status",
  "data": {
    "orderId": "order-123",
    "status": "preparing"
  }
}
```

### Notification de livraison

```dart
{
  "title": "🚗 Votre livreur arrive!",
  "message": "Jean livrera votre commande dans 10 minutes",
  "type": "delivery",
  "data": {
    "orderId": "order-123",
    "deliveryPersonName": "Jean",
    "estimatedTime": "10 minutes"
  }
}
```

### Notification de promotion

```dart
{
  "title": "🎁 Promotion spéciale",
  "message": "Profitez de 20% de réduction avec le code PROMO20",
  "type": "promotion",
  "data": {
    "promoCode": "PROMO20",
    "discount": 20
  }
}
```

## Conclusion

L'architecture actuelle combine efficacement **Supabase Realtime** pour la détection en temps réel et **Flutter Local Notifications** pour l'affichage système. Cette approche offre une expérience utilisateur fluide avec des notifications instantanées et synchronisées avec la base de données.


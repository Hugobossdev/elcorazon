# 🏗️ Architecture - El Corazon Fastfood

Documentation de l'architecture et de la structure du projet.

## 📐 Vue d'ensemble

El Corazon Fastfood suit une architecture **en couches** avec séparation des responsabilités :

```
┌─────────────────────────────────────┐
│         Presentation Layer          │  ← Screens & Widgets
├─────────────────────────────────────┤
│         Business Logic Layer        │  ← Services & State
├─────────────────────────────────────┤
│          Data Layer                 │  ← Models & APIs
└─────────────────────────────────────┘
```

## 📁 Structure des dossiers

```
lib/
├── models/              # 📦 Modèles de données
│   ├── user.dart
│   ├── menu_item.dart
│   ├── order.dart
│   ├── address.dart
│   └── ...
│
├── screens/             # 📱 Interfaces utilisateur
│   ├── client/          # Écrans clients
│   │   ├── home_screen.dart
│   │   ├── menu_screen.dart
│   │   ├── cart_screen.dart
│   │   ├── delivery_tracking_screen.dart
│   │   ├── cake_order_screen.dart
│   │   └── address_management_screen.dart
│   │
│   ├── driver/          # Écrans livreurs
│   │   ├── delivery_home_screen.dart
│   │   ├── delivery_orders_screen.dart
│   │   └── earnings_screen.dart
│   │
│   └── admin/           # Écrans administration
│       ├── dashboard_screen.dart
│       ├── orders_management_screen.dart
│       └── menu_management_screen.dart
│
├── services/            # 🔧 Logique métier
│   ├── app_service.dart              # Service principal
│   ├── auth_service.dart             # Authentification
│   ├── database_service.dart         # Base de données
│   ├── cart_service.dart             # Panier
│   ├── customization_service.dart    # Personnalisation
│   ├── location_service.dart         # Géolocalisation
│   ├── socket_service.dart           # WebSocket temps réel
│   ├── paydunya_service.dart         # Paiements
│   ├── driver_rating_service.dart    # Notes livreurs
│   └── ...
│
├── widgets/             # 🧩 Composants réutilisables
│   ├── custom_button.dart
│   ├── custom_text_field.dart
│   ├── loading_indicator.dart
│   └── ...
│
├── utils/               # 🛠️ Utilitaires
│   ├── price_formatter.dart
│   ├── date_formatter.dart
│   ├── validators.dart
│   └── constants.dart
│
├── theme.dart           # 🎨 Thème de l'application
└── main.dart            # 🚀 Point d'entrée
```

## 🔄 Flux de données

### State Management : Provider

L'application utilise **Provider** pour la gestion d'état :

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => AppService()),
    ChangeNotifierProvider(create: (_) => CartService()),
    ChangeNotifierProvider(create: (_) => CustomizationService()),
    // ...
  ],
  child: MyApp(),
)
```

### Architecture des services

```
┌──────────────┐
│  AppService  │  ← Service principal, orchestrateur
└──────┬───────┘
       │
       ├─→ AuthService          (Authentification)
       ├─→ dépôts du socle      (elcorazon_core → API Django)
       ├─→ CartService          (Gestion panier)
       ├─→ LocationService      (GPS)
       └─→ SocketService        (Temps réel)
```

## 🗄️ Modèle de données

### Modèles principaux

```dart
class User {
  final String id;
  final String email;
  final String name;
  final UserRole role; // client, driver, admin
  // ...
}

class MenuItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String? imageUrl;
  final bool isAvailable;
  // ...
}

class Order {
  final String id;
  final String userId;
  final String? driverId;
  final OrderStatus status;
  final double totalAmount;
  final List<OrderItem> items;
  final Address deliveryAddress;
  // ...
}
```

## 🔌 Intégrations externes

### Backend API (Node.js)

```
Base URL: https://backend-qbwe.onrender.com

Endpoints WebSocket:
- /socket.io - Connexion temps réel
- Events: driver_location, order_status_changed
```

### Backend Django

```
L'application ne parle qu'à l'API — jamais à une base.

Ce que le serveur établit, et qu'elle ne recalcule pas :
- prix, remises, frais de livraison
- statuts de commande (machines à états)
- éligibilité d'un livreur, points de fidélité
- remboursements

Entités partagées : packages/elcorazon_core/lib/src/
Chacune annonce en commentaire le sérialiseur qu'elle reflète.
```

### PayDunya

```
Méthodes de paiement:
- Mobile Money (Orange, MTN, Moov)
- Cartes bancaires
- Portefeuille interne

Flow:
1. Créer invoice → PayDunya
2. Redirection → Page paiement
3. Callback → Validation commande
```

### Google Maps

```
Utilisations:
- Affichage carte livraison
- Sélection adresse
- Calcul distance
- Suivi GPS livreur

SDK: google_maps_flutter
```

## 🔐 Sécurité

### Authentification

- Jetons JWT émis par le backend Django
- Rafraîchissement automatique par l'`ApiClient` du socle
- Session persistante, portée par `sessionProvider` (Riverpod)

### Permissions

```dart
enum UserRole {
  client,   // Accès menu, commandes, historique
  driver,   // Accès livraisons, gains
  admin,    // Accès total dashboard
}
```

### Variables d'environnement

Toutes les clés sensibles dans `.env` :

```
✅ .env (gitignored)
✅ .env.example (committé)
❌ Pas de clés en dur dans le code
```

## 📱 Navigation

### Structure de navigation

```
Main App
├── Client Flow
│   ├── HomeScreen
│   ├── MenuScreen
│   ├── CakeOrderScreen
│   ├── CartScreen
│   ├── CheckoutScreen
│   └── DeliveryTrackingScreen
│
├── Driver Flow
│   ├── DeliveryHomeScreen
│   ├── DeliveryOrdersScreen
│   └── EarningsScreen
│
└── Admin Flow
    ├── DashboardScreen
    ├── OrdersManagementScreen
    └── MenuManagementScreen
```

## 🎨 Thème et Design

### Material Design 3

```dart
ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primary,
  ),
)
```

### Palette de couleurs

```dart
class AppColors {
  static const primary = Color(0xFFE53935);      // Rouge
  static const secondary = Color(0xFFFFA726);    // Orange
  static const accent = Color(0xFF42A5F5);       // Bleu
  // ...
}
```

## 🔄 Temps réel et WebSocket

### SocketService

```dart
class SocketService {
  // Connexion au backend
  void connect(String userId);
  
  // Écouter les événements
  void on(String event, Function callback);
  
  // Émettre des événements
  void emit(String event, dynamic data);
  
  // Events principaux:
  // - driver_location (Position GPS)
  // - order_status_changed (Statut commande)
  // - new_order (Nouvelle commande)
}
```

## 🧪 Patterns utilisés

- **Singleton** : Services (AppService, DatabaseService)
- **Provider** : State management
- **Repository** : dépôts du socle, un par domaine
- **Factory** : Création modèles (Model.fromMap())
- **Observer** : temps réel (WebSocket Django Channels)

## 🚀 Performance

### Optimisations

- **Lazy loading** : Chargement différé des images
- **Caching** : Adresses et préférences utilisateur
- **Pagination** : Liste de commandes, historique
- **Image optimization** : Compression, formats adaptés

## 📊 Monitoring et Logs

```dart
debugPrint('✅ Succès');
debugPrint('⚠️ Avertissement');
debugPrint('❌ Erreur');
debugPrint('🔄 En cours');
```

---

**Prochaine étape** : Consultez [API_GUIDE.md](API_GUIDE.md) pour la documentation des APIs et [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) pour les conventions de développement.

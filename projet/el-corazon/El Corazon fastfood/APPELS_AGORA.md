# 📞 Système d'Appels Vocaux avec Agora

## Vue d'ensemble

Le système d'appels vocaux permet aux clients et livreurs de communiquer directement via l'application en utilisant **Agora RTC Engine** pour la communication en temps réel.

## Architecture

```
┌─────────────────┐
│  Client/Livreur │
│  (App Flutter)  │
└────────┬────────┘
         │
         ├─────────────────┐
         │                 │
         ▼                 ▼
┌─────────────────┐  ┌─────────────────┐
│  CallService    │  │  AgoraService   │
│  (Gestion)      │  │  (RTC Engine)   │
└────────┬────────┘  └────────┬────────┘
         │                     │
         │                     │
         ▼                     ▼
┌─────────────────────────────────┐
│     Supabase Database           │
│     (Table: calls)              │
└─────────────────────────────────┘
         │
         │ Realtime
         ▼
┌─────────────────────────────────┐
│  Supabase Realtime              │
│  (Notifications d'appels)       │
└─────────────────────────────────┘
```

## Composants principaux

### 1. **CallService** (`lib/services/call_service.dart`)

Service central de gestion des appels qui :
- Gère les appels sortants et entrants
- Synchronise avec Supabase pour l'historique
- Écoute les appels entrants via Realtime
- Intègre avec AgoraService pour la communication

#### Fonctionnalités principales :

```dart
// Initier un appel sortant
final call = await callService.initiateCall(
  orderId: 'order-123',
  callerId: 'user-456',
  receiverId: 'driver-789',
  callerName: 'Client',
  receiverName: 'Livreur',
);

// Accepter un appel entrant
await callService.acceptCall(call);

// Rejeter un appel
await callService.rejectCall(call);

// Terminer un appel
await callService.endCall();
```

### 2. **CallScreen** (`lib/screens/client/call_screen.dart`)

Écran d'appel avec interface utilisateur complète :
- Affichage du statut de l'appel
- Contrôles (mute, speaker, raccrocher)
- Compteur de durée d'appel
- Gestion des appels entrants/sortants

### 3. **IncomingCallHandler** (`lib/widgets/incoming_call_handler.dart`)

Widget global qui :
- Écoute les appels entrants en temps réel
- Affiche une notification/dialog pour les appels entrants
- Permet d'accepter ou rejeter l'appel

### 4. **Table `calls` dans Supabase**

Structure de la table :

```sql
CREATE TABLE calls (
    id UUID PRIMARY KEY,
    order_id UUID REFERENCES orders(id),
    caller_id UUID REFERENCES users(id),
    receiver_id UUID REFERENCES users(id),
    caller_name TEXT,
    receiver_name TEXT,
    type TEXT DEFAULT 'voice', -- 'voice' ou 'video'
    direction TEXT, -- 'incoming' ou 'outgoing'
    state TEXT, -- 'idle', 'calling', 'ringing', 'connected', 'ended', etc.
    channel_id TEXT, -- Canal Agora
    started_at TIMESTAMP,
    ended_at TIMESTAMP,
    duration INTEGER, -- Durée en secondes
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);
```

## Flux d'un appel

### Appel sortant (Client → Livreur)

1. **Client appuie sur "Appeler"** dans `DeliveryTrackingScreen`
2. **CallService.initiateCall()** est appelé
3. Un enregistrement est créé dans la table `calls` avec `state = 'calling'`
4. **AgoraService** rejoint le canal avec l'ID unique
5. L'état passe à `'ringing'` (sonne)
6. Le livreur reçoit une notification via Supabase Realtime
7. Si accepté : `state = 'connected'`, l'appel commence
8. Si rejeté : `state = 'rejected'`, l'appel se termine

### Appel entrant (Livreur → Client)

1. **Livreur initie un appel** via son interface
2. Un enregistrement est créé avec `direction = 'incoming'`
3. **Supabase Realtime** détecte l'insertion
4. **IncomingCallHandler** reçoit l'événement
5. Un dialog s'affiche avec les options "Accepter" / "Rejeter"
6. Si accepté : l'écran d'appel s'ouvre et la communication commence

## Intégration dans l'application

### 1. Dans `main.dart`

Le `IncomingCallHandler` est intégré globalement :

```dart
MaterialApp(
  builder: (context, child) {
    return ErrorBoundary(
      child: IncomingCallHandler(
        child: ServiceInitializationWidget(child: child!),
      ),
    );
  },
)
```

### 2. Dans `DeliveryTrackingScreen`

Bouton d'appel intégré :

```dart
_buildActionItem(
  icon: Icons.phone_in_talk,
  label: 'Appeler',
  onTap: _startVoiceCall,
  color: hasDriver ? Colors.green : Colors.grey,
  isEnabled: hasDriver,
),
```

### 3. Initialisation du service

Le `CallService` s'initialise automatiquement quand l'utilisateur est connecté via `IncomingCallHandler`.

## Configuration Agora

### Variables d'environnement

Dans votre fichier `.env` :

```env
AGORA_APP_ID=your_agora_app_id
BACKEND_URL=http://your-backend-url
```

### Backend pour les tokens

Le backend doit exposer un endpoint pour générer les tokens Agora :

```
GET /api/agora/rtc-token?channel={channelId}&uid={uid}&expire={seconds}
```

Réponse :
```json
{
  "token": "agora_rtc_token_string"
}
```

## États d'un appel

| État | Description |
|------|-------------|
| `idle` | État initial |
| `calling` | Appel en cours d'établissement |
| `ringing` | Sonne (en attente de réponse) |
| `connected` | Appel connecté et actif |
| `ended` | Appel terminé normalement |
| `rejected` | Appel rejeté |
| `missed` | Appel manqué (pas de réponse) |
| `failed` | Échec de l'appel |

## Fonctions SQL disponibles

### Créer un appel

```sql
SELECT create_call(
  'order-id'::uuid,
  'caller-id'::uuid,
  'receiver-id'::uuid,
  'Nom Appelant',
  'Nom Receveur',
  'voice',
  'outgoing'
);
```

### Mettre à jour l'état d'un appel

```sql
SELECT update_call_state(
  'call-id'::uuid,
  'connected',
  NOW(), -- started_at
  NULL,  -- ended_at
  NULL   -- duration
);
```

## Notifications automatiques

Quand un appel entrant arrive, une notification est automatiquement créée via le trigger `incoming_call_notification_trigger` :

- **Titre** : "📞 Appel entrant"
- **Message** : "{Nom} vous appelle pour la commande #{orderId}"
- **Type** : `info`
- **Data** : Contient `callId`, `orderId`, `callerId`, etc.

## Gestion des permissions

Les permissions microphone sont gérées automatiquement par le SDK Agora. L'utilisateur sera invité à autoriser l'accès au microphone lors du premier appel.

## Historique des appels

Récupérer l'historique pour une commande :

```dart
final history = await callService.getCallHistory(orderId);
```

## Améliorations futures

- [ ] Appels vidéo (déjà préparé dans le code)
- [ ] Enregistrement des appels (avec consentement)
- [ ] Transcription automatique
- [ ] Appels de groupe (pour commandes groupées)
- [ ] Statistiques d'appels (durée moyenne, nombre d'appels, etc.)

## Dépannage

### L'appel ne se connecte pas

1. Vérifier que `AGORA_APP_ID` est configuré
2. Vérifier que le backend génère correctement les tokens
3. Vérifier les permissions microphone
4. Vérifier la connexion internet

### Les appels entrants ne fonctionnent pas

1. Vérifier que `CallService.initialize()` est appelé avec le bon `userId`
2. Vérifier que Supabase Realtime est activé pour la table `calls`
3. Vérifier que `IncomingCallHandler` est bien intégré dans `main.dart`

### Erreur de token Agora

1. Vérifier que le backend est accessible
2. Vérifier que l'endpoint `/api/agora/rtc-token` fonctionne
3. Vérifier les paramètres `channel`, `uid`, `expire` dans la requête

## Exemple d'utilisation complète

```dart
// 1. Dans un écran, initier un appel
final callService = CallService();
await callService.initialize(userId: currentUser.id);

final call = await callService.initiateCall(
  orderId: order.id,
  callerId: currentUser.id,
  receiverId: order.deliveryPersonId!,
  callerName: currentUser.name,
  receiverName: 'Livreur',
);

if (call != null) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => CallScreen(
        orderId: order.id,
        receiverName: 'Livreur',
        direction: CallDirection.outgoing,
      ),
    ),
  );
}

// 2. Les appels entrants sont gérés automatiquement
// via IncomingCallHandler qui affiche un dialog
```

## Conclusion

Le système d'appels est maintenant complètement intégré et permet une communication fluide entre clients et livreurs directement depuis l'application, sans avoir besoin de quitter l'app pour passer un appel téléphonique traditionnel.



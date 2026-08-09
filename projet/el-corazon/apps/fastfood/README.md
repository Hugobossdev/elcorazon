# 🍔 El Corazon Fastfood

Application mobile de commande de restauration rapide avec livraison en temps réel, développée avec Flutter.

## 📱 Fonctionnalités

### Pour les Clients
- 🛒 **Commande en ligne** - Parcourir le menu et passer des commandes
- 🎂 **Gâteaux personnalisés** - Créer des gâteaux sur-mesure avec configurateur complet
- 📍 **Suivi en temps réel** - Suivre la livraison sur une carte avec GPS
- 💳 **Paiement intégré** - PayDunya (Mobile Money, Carte bancaire)
- ⭐ **Notation** - Évaluer les plats et les livreurs
- 📍 **Gestion d'adresses** - Sauvegarder les adresses favorites avec géolocalisation
- 📞 **Appels VoIP** - Contacter le livreur via Agora

### Pour les Livreurs
- 📦 **Gestion des commandes** - Accepter et gérer les livraisons
- 🗺️ **Navigation GPS** - Suivi en temps réel de la position
- 💰 **Suivi des gains** - Historique et demandes de retrait
- 📊 **Statistiques** - Performance et évaluations

### Pour les Administrateurs  
- 📊 **Dashboard** - Vue d'ensemble des opérations
- 👥 **Gestion des utilisateurs** - Clients, livreurs, personnel
- 🍽️ **Gestion du menu** - Plats, catégories, prix
- 📈 **Statistiques** - Ventes, commandes, revenus
- 🗺️ **Suivi des livreurs** - Positions en temps réel

## 🚀 Démarrage rapide

```bash
# 1. Cloner le dépôt
git clone <repository-url>
cd "El Corazon fastfood"

# 2. Installer les dépendances
flutter pub get

# 3. Configurer l'environnement
cp .env.example .env
# Éditer .env avec vos clés API

# 4. Lancer l'application
flutter run
```

> **📖 Pour les instructions d'installation détaillées, consultez [SETUP.md](SETUP.md)**

## 🏗️ Architecture

```
lib/
├── models/          # Modèles de données
├── screens/         # Interfaces utilisateur
│   ├── client/      # Écrans clients
│   ├── driver/      # Écrans livreurs
│   └── admin/       # Écrans admin
├── services/        # Logique métier et APIs
├── widgets/         # Composants réutilisables
└── utils/           # Utilitaires et helpers
```

> **📐 Pour plus de détails, consultez [ARCHITECTURE.md](ARCHITECTURE.md)**

## 🔧 Technologies

- **Framework**: Flutter 3.x
- **Backend** : Django REST + PostgreSQL/PostGIS (`backend/`)
- **Socle partagé** : `packages/elcorazon_core` — entités et dépôts communs aux
  trois applications
- **Paiement** : PayDunya, **côté serveur** — l'application demande une adresse
  de règlement et lit l'état que le webhook signé a écrit
- **Maps** : Google Maps API
- **Appels** : Agora RTC, jetons signés par le backend
- **État** : Provider dans l'application, Riverpod pour la session du socle
- **Temps réel** : WebSocket Django Channels

## 📚 Documentation

- [SETUP.md](SETUP.md) — installation et configuration
- [ARCHITECTURE.md](ARCHITECTURE.md) — architecture du projet
- [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) — guide développeur
- [TODO.md](TODO.md) — tâches et bugs connus
- [CHANGELOG.md](CHANGELOG.md) — historique des versions
- [docs/](docs/) — notes techniques datées, dont certaines décrivent du code
  qui n'existe plus ; l'index dit lesquelles
- [../../docs/architecture/](../../docs/architecture/) — architecture générale,
  modèle de données, plan de migration et ADR

L'API se documente elle-même : le backend publie son schéma OpenAPI sur
`/api/v1/schema/`.

## 🔐 Sécurité

**Aucune clé sensible ne va dans `.env`.** C'est l'inverse de ce que cette
section disait, et l'inverse est faux : une clé placée dans le `.env` d'une
application est une clé dans le binaire distribué, lisible par quiconque le
décompresse. Le `.env` ignoré par Git protège le dépôt, pas le produit.

- `.env` ne contient que des valeurs **publiques par nature** : l'adresse de
  l'API, l'App ID Agora, la configuration cliente Firebase, et la clé Google
  Maps — cette dernière à restreindre par empreinte d'application et par API
  dans la console Google, faute de quoi elle est utilisable par n'importe qui
- Les **secrets** restent côté backend : les quatre clés marchandes PayDunya,
  le certificat Agora qui signe les jetons d'appel, les accès à la base
- `.env.example` fait foi : il ne liste que ce que le code lit

## 🤝 Contribution

Consultez [CONTRIBUTING.md](CONTRIBUTING.md) pour les directives de contribution.

## 📄 Licence

Propriétaire - El Corazon Fastfood

## 📞 Support

Pour toute question, contactez l'équipe de développement.

---

**Version actuelle**: 1.0.0  
**Dernière mise à jour**: Février 2026

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
- **Backend**: Supabase + Node.js (Render.com)
- **Paiement**: PayDunya
- **Maps**: Google Maps API
- **Appels**: Agora RTC
- **State Management**: Provider
- **Temps réel**: WebSocket + Supabase Realtime

## 📚 Documentation

- [SETUP.md](SETUP.md) - Installation et configuration
- [ARCHITECTURE.md](ARCHITECTURE.md) - Architecture du projet
- [API_GUIDE.md](API_GUIDE.md) - Documentation des APIs
- [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) - Guide développeur
- [TODO.md](TODO.md) - Tâches et bugs connus
- [CHANGELOG.md](CHANGELOG.md) - Historique des versions

## 🔐 Sécurité

⚠️ **IMPORTANT** : Ne committez JAMAIS le fichier `.env` avec vos vraies clés API !

- Utilisez `.env.example` comme template
- Toutes les clés sensibles doivent être dans `.env`
- Le `.env` est ignoré par Git

## 🤝 Contribution

Consultez [CONTRIBUTING.md](CONTRIBUTING.md) pour les directives de contribution.

## 📄 Licence

Propriétaire - El Corazon Fastfood

## 📞 Support

Pour toute question, contactez l'équipe de développement.

---

**Version actuelle**: 1.0.0  
**Dernière mise à jour**: Février 2026

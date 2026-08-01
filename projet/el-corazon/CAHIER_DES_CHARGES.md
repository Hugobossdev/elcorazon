# 📋 Cahier des Charges - Écosystème El Corazón

**Version** : 1.0  
**Date** : Décembre 2024  
**Projet** : Plateforme de livraison de repas multi-applications

---

## 📑 Table des Matières

1. [Vue d'ensemble du projet](#1-vue-densemble-du-projet)
2. [Application Client (El Corazón Fast)](#2-application-client-el-corazón-fast)
3. [Application Livreur (El Corazón Dely)](#3-application-livreur-el-corazón-dely)
4. [Application Admin (El Corazón Admin)](#4-application-admin-el-corazón-admin)
5. [Architecture technique commune](#5-architecture-technique-commune)
6. [Exigences non-fonctionnelles](#6-exigences-non-fonctionnelles)
7. [Contraintes et dépendances](#7-contraintes-et-dépendances)
8. [Planning et livrables](#8-planning-et-livrables)

---

## 1. Vue d'ensemble du projet

### 1.1 Contexte

El Corazón est une plateforme complète de livraison de repas composée de trois applications interconnectées permettant de gérer l'ensemble du cycle de commande, de la sélection des produits à la livraison finale.

### 1.2 Objectifs

- **Pour les clients** : Offrir une expérience de commande fluide, personnalisée et engageante
- **Pour les livreurs** : Fournir des outils efficaces pour gérer et optimiser les livraisons
- **Pour les administrateurs** : Permettre une gestion complète et une analyse approfondie de l'activité

### 1.3 Portée du projet

Le projet comprend :
- 3 applications mobiles/web (Client, Livreur, Admin)
- 1 backend commun : **Django 5.2 + DRF + Channels**, PostgreSQL 17 + PostGIS,
  Redis, Celery, MinIO (`backend/`)
- 1 socle Dart partagé par les trois applications (`packages/elcorazon_core`)
- Intégrations avec services externes (Google Maps, PayDunya, Agora, Firebase),
  **toutes rattachées côté serveur** : aucune clé de prestataire ne voyage dans
  une application

### 1.4 Public cible

- **Clients finaux** : Particuliers souhaitant commander des repas
- **Livreurs** : Coursiers partenaires effectuant les livraisons
- **Administrateurs** : Gestionnaires du restaurant et de la plateforme

---

## 2. Application Client (El Corazón Fast)

### 2.1 Description générale

Application mobile destinée aux clients finaux pour parcourir le menu, personnaliser leurs commandes, effectuer des paiements et suivre leurs livraisons en temps réel.

### 2.2 Fonctionnalités principales

#### 2.2.1 Authentification et gestion de compte

**Exigences fonctionnelles :**

- **Inscription/Connexion**
  - Inscription par email/mot de passe
  - Connexion avec email/mot de passe
  - Vérification OTP par email
  - Connexion via réseaux sociaux (optionnel)
  - Mode invité (consultation sans compte)
  - Récupération de mot de passe

- **Gestion du profil**
  - Édition des informations personnelles (nom, email, téléphone)
  - Upload et modification de photo de profil
  - Gestion des préférences (allergies, régimes alimentaires)
  - Historique des commandes
  - Statistiques personnelles (points, niveau, badges)

- **Gestion des adresses**
  - Ajout de plusieurs adresses de livraison
  - Sélection d'adresse par défaut
  - Géolocalisation automatique
  - Validation d'adresse
  - Historique des adresses utilisées

#### 2.2.2 Catalogue et menu

**Exigences fonctionnelles :**

- **Affichage du menu**
  - Liste complète des produits disponibles
  - Catégorisation (Entrées, Plats, Desserts, Boissons, etc.)
  - Images haute qualité pour chaque produit
  - Prix et disponibilité en temps réel
  - Informations nutritionnelles (optionnel)

- **Recherche et filtres**
  - Recherche textuelle avancée
  - Filtres par catégorie
  - Filtres par prix
  - Filtres par disponibilité
  - Tri (prix, popularité, nouveauté)
  - Suggestions intelligentes

- **Détails produit**
  - Description complète
  - Galerie d'images
  - Options de personnalisation disponibles
  - Avis et notes des clients
  - Produits similaires/recommandés

#### 2.2.3 Personnalisation avancée des produits

**Exigences fonctionnelles :**

- **Système de personnalisation flexible**
  - Options par catégorie (Taille, Cuisson, Sauce, Garniture, etc.)
  - Modification des prix selon les options
  - Validation des personnalisations requises
  - Limites de quantité par option
  - Aperçu en temps réel du prix total

- **Types de personnalisation supportés**
  - **Burgers** : Cuisson, retrait d'ingrédients, ajouts d'extras
  - **Pizzas** : Taille, base, garnitures, fromages
  - **Gâteaux** : Forme, nombre d'étages, saveurs, décorations, photos comestibles
  - **Plats** : Accompagnements, niveau d'épices, portions

- **Interface utilisateur**
  - Interface dédiée par type de produit
  - Visualisation des modifications
  - Calcul automatique du prix final
  - Sauvegarde des personnalisations favorites

#### 2.2.4 Panier et commandes

**Exigences fonctionnelles :**

- **Gestion du panier**
  - Ajout/Modification/Suppression d'articles
  - Quantités multiples
  - Personnalisations par article
  - Calcul automatique des totaux
  - Frais de livraison dynamiques
  - Application de codes promo
  - Sauvegarde du panier (persistance)

- **Passage de commande**
  - Sélection de l'adresse de livraison
  - Choix du mode de paiement
  - Sélection d'heure de livraison (si disponible)
  - Récapitulatif détaillé
  - Confirmation de commande
  - Numéro de suivi unique

- **Suivi des commandes**
  - Statuts en temps réel (En préparation, En livraison, Livré)
  - Historique complet des commandes
  - Détails de chaque commande
  - Réclamation/Retour possible
  - Réédition de commande

#### 2.2.5 Paiements

**Exigences fonctionnelles :**

- **Méthodes de paiement**
  - **PayDunya** : Mobile Money (Orange Money, MTN Mobile Money, Moov Money)
  - **Portefeuille interne** : Crédit prépayé
  - **Paiement partagé** : Division de l'adresse entre plusieurs utilisateurs
  - **Paiement à la livraison** : Cash on delivery (optionnel)

- **Gestion des transactions**
  - Historique des transactions
  - Remboursements
  - Rechargement du portefeuille
  - Notifications de paiement
  - Sécurité des données de paiement

#### 2.2.6 Suivi de livraison en temps réel

**Exigences fonctionnelles :**

- **Visualisation sur carte**
  - Position du livreur en temps réel
  - Position du restaurant
  - Position du client
  - Itinéraire de livraison
  - Mise à jour automatique (toutes les 10 secondes)

- **Informations de livraison**
  - Estimation du temps d'arrivée
  - Distance restante
  - Statut de livraison
  - Informations du livreur (nom, photo, note)
  - Historique du trajet

#### 2.2.7 Commandes groupées

**Exigences fonctionnelles :**

- **Création de groupe**
  - Création d'une demande de livraison groupée
  - Définition de l'adresse de livraison
  - Définition de l'heure de livraison
  - Rayon de participation (ex: 2km)
  - Partage du lien d'invitation

- **Participation**
  - Rejoindre un groupe existant
  - Voir les groupes disponibles sur carte/liste
  - Ajouter des articles au panier groupé
  - Voir les articles des autres participants

- **Gestion**
  - Partage automatique des frais de livraison
  - Calcul dynamique selon le nombre de participants
  - Gestion des participants
  - Commandes planifiées avec récurrence (quotidienne, hebdomadaire, mensuelle)

#### 2.2.8 Gamification et fidélité

**Exigences fonctionnelles :**

- **Système de points (XP)**
  - Points gagnés par commande
  - Points bonus pour actions spéciales
  - Historique des points gagnés/dépensés

- **Niveaux utilisateur**
  - 6 niveaux progressifs :
    1. Gourmand Débutant (< 100 pts)
    2. Amateur de Saveurs (< 300 pts)
    3. Connaisseur Culinaire (< 600 pts)
    4. Expert Gastronome (< 1000 pts)
    5. Maître El Corazón (< 1500 pts)
    6. Légende Culinaire (> 1500 pts)
  - Avantages par niveau
  - Progression visible

- **Badges et achievements**
  - Badges débloquables (Explorateur, Série de Victoires, etc.)
  - Conditions de déblocage
  - Collection complète visible

- **Challenges**
  - Défis temporaires
  - Récompenses spéciales
  - Suivi de progression

- **Streak (Série)**
  - Calcul des jours consécutifs de commande
  - Bonus pour séries longues
  - Notification de rappel

- **Récompenses**
  - Échange de points contre produits gratuits
  - Remises sur commandes
  - Offres exclusives

#### 2.2.9 Communication

**Exigences fonctionnelles :**

- **Chat avec livreur**
  - Messages texte en temps réel
  - Notifications de nouveaux messages
  - Historique des conversations
  - Partage de position

- **Appels audio/vidéo**
  - Appels vocaux avec le livreur
  - Appels vidéo (optionnel)
  - Via Agora RTC
  - Gestion des permissions

- **Support client**
  - Chat avec support
  - Tickets de réclamation
  - FAQ intégrée
  - Centre d'aide

#### 2.2.10 Notifications

**Exigences fonctionnelles :**

- **Types de notifications**
  - Nouvelle commande confirmée
  - Statut de commande changé
  - Livreur assigné
  - Livraison en cours
  - Livraison terminée
  - Promotions disponibles
  - Rappels de commande

- **Gestion**
  - Centre de notifications
  - Historique complet
  - Paramètres de notification
  - Notifications push et locales

#### 2.2.11 Mode hors-ligne

**Exigences fonctionnelles :**

- **Cache local**
  - Menu complet en cache (validité 24h)
  - Consultation sans connexion
  - Synchronisation automatique au retour de connexion

- **Commandes hors-ligne**
  - Passage de commande en mode hors-ligne
  - File d'attente de synchronisation
  - Retry automatique avec backoff exponentiel

- **Gestion de la connectivité**
  - Détection automatique
  - Indicateur de statut
  - Synchronisation différée

#### 2.2.12 Avis et notes

**Exigences fonctionnelles :**

- **Notation des produits**
  - Note de 1 à 5 étoiles
  - Commentaires textuels
  - Photos (optionnel)
  - Affichage des notes moyennes

- **Notation des livreurs**
  - Note de 1 à 5 étoiles
  - Commentaires
  - Impact sur la réputation

#### 2.2.13 Promotions et codes promo

**Exigences fonctionnelles :**

- **Codes promo**
  - Application de codes
  - Validation en temps réel
  - Historique des codes utilisés
  - Codes à usage unique/multiple

- **Promotions**
  - Affichage des promotions actives
  - Notifications de nouvelles promotions
  - Conditions d'éligibilité

### 2.3 Exigences techniques

- **Framework** : Flutter SDK ^3.5.0
- **State Management** : Provider & Riverpod
- **Accès aux données** : `elcorazon_core` (client HTTP, session, dépôts par
  domaine) contre l'API Django `/api/v1/*` — jamais d'accès direct à une base
- **Stockage local** : SQLite (sqflite), SharedPreferences — **cache
  uniquement**, jamais source de vérité
- **Cartes** : Google Maps Flutter
- **Géolocalisation** : Geolocator
- **Paiements** : PayDunya SDK
- **Communication** : Agora RTC Engine
- **Notifications** : Firebase Cloud Messaging

### 2.4 Interfaces utilisateur

- Design moderne et intuitif
- Thème clair/sombre
- Responsive (mobile, tablette)
- Animations fluides
- Accessibilité (support lecteurs d'écran)

---

## 3. Application Livreur (El Corazón Dely)

### 3.1 Description générale

Application mobile dédiée aux livreurs pour recevoir, gérer et effectuer les livraisons efficacement avec outils de navigation et communication intégrés.

### 3.2 Fonctionnalités principales

#### 3.2.1 Authentification livreur

**Exigences fonctionnelles :**

- **Connexion**
  - Authentification par email/mot de passe
  - Vérification du statut livreur
  - Récupération de mot de passe
  - Session persistante

- **Profil livreur**
  - Informations personnelles
  - Documents (permis, assurance, etc.)
  - Statut de vérification
  - Statistiques de performance

#### 3.2.2 Gestion des commandes

**Exigences fonctionnelles :**

- **Réception de commandes**
  - Notifications push pour nouvelles commandes
  - Liste des commandes disponibles
  - Informations détaillées (adresse, montant, distance)
  - Acceptation/Refus de commande
  - Délai de réponse (ex: 30 secondes)

- **Gestion du statut**
  - Mode En ligne/Hors ligne
  - Statut de livraison (En route, Livré, etc.)
  - Mise à jour manuelle/automatique
  - Historique des commandes

- **Détails de commande**
  - Informations client (nom, téléphone, adresse)
  - Liste des articles
  - Instructions spéciales
  - Montant total
  - Frais de livraison

#### 3.2.3 Navigation et géolocalisation

**Exigences fonctionnelles :**

- **Navigation GPS**
  - Itinéraire vers le restaurant
  - Itinéraire vers le client
  - Navigation guidée (Google Maps intégré)
  - Estimation du temps de trajet
  - Mise à jour en temps réel

- **Suivi de position**
  - Partage automatique de position (toutes les 10 secondes)
  - Visualisation sur carte
  - Historique du trajet
  - Optimisation d'itinéraire

#### 3.2.4 Communication

**Exigences fonctionnelles :**

- **Chat avec client**
  - Messages texte en temps réel
  - Notifications de nouveaux messages
  - Templates de messages rapides
  - Partage de position

- **Appels audio/vidéo**
  - Appels vocaux avec le client
  - Appels vidéo (optionnel)
  - Via Agora RTC
  - Gestion des appels entrants

- **Support**
  - Contact avec le support
  - Signalement de problèmes
  - Assistance d'urgence

#### 3.2.5 Tableau de bord des gains

**Exigences fonctionnelles :**

- **Statistiques financières**
  - Gains du jour/semaine/mois
  - Nombre de livraisons
  - Montant moyen par livraison
  - Graphiques de performance

- **Historique des paiements**
  - Liste des livraisons effectuées
  - Détails de chaque paiement
  - Période de paiement
  - Export des données

- **Objectifs et récompenses**
  - Objectifs quotidiens/hebdomadaires
  - Bonus de performance
  - Classement (optionnel)

#### 3.2.6 Notifications

**Exigences fonctionnelles :**

- **Types de notifications**
  - Nouvelle commande disponible
  - Commande acceptée/refusée
  - Message du client
  - Appel entrant
  - Mise à jour de statut
  - Promotions spéciales

- **Gestion**
  - Paramètres de notification
  - Mode silencieux pendant livraison
  - Notifications prioritaires

#### 3.2.7 Gamification livreur

**Exigences fonctionnelles :**

- **Système de points**
  - Points par livraison
  - Bonus pour performance
  - Niveaux de livreur

- **Badges**
  - Badges de performance
  - Records personnels
  - Récompenses spéciales

### 3.3 Exigences techniques

- **Framework** : Flutter SDK ^3.9.2
- **State Management** : Provider
- **Accès aux données** : `elcorazon_core` contre l'API Django `/api/v1/*` ;
  Firebase Cloud Messaging pour le push
- **Navigation** : Google Maps Flutter
- **Géolocalisation** : Geolocator
- **Communication** : Agora RTC Engine
- **Notifications** : Firebase Cloud Messaging
- **Commandes vocales** : Speech to Text

### 3.4 Interfaces utilisateur

- Interface optimisée pour usage en mouvement
- Boutons larges et accessibles
- Mode sombre pour usage nocturne
- Notifications visuelles importantes

---

## 4. Application Admin (El Corazón Admin)

### 4.1 Description générale

Application web/desktop pour administrateurs et restaurateurs permettant la gestion complète de la plateforme, des produits, commandes, livreurs et analytics.

### 4.2 Fonctionnalités principales

#### 4.2.1 Authentification et sécurité

**Exigences fonctionnelles :**

- **Connexion sécurisée**
  - Authentification par email/mot de passe
  - Vérification OTP
  - Session sécurisée
  - Déconnexion automatique

- **Gestion des rôles**
  - Super Admin
  - Manager
  - Opérateur
  - Permissions granulaires par fonctionnalité

#### 4.2.2 Dashboard et analytics

**Exigences fonctionnelles :**

- **Vue d'ensemble**
  - Revenus totaux (jour/semaine/mois)
  - Nombre de commandes
  - Taux de conversion
  - Taux de satisfaction
  - Graphiques interactifs (Fl_chart)

- **Métriques détaillées**
  - Revenus par période
  - Commandes par statut
  - Performance des produits
  - Performance des livreurs
  - Engagement utilisateurs

- **Rapports**
  - Génération de rapports PDF
  - Export Excel/CSV
  - Rapports personnalisables
  - Rapports planifiés

#### 4.2.3 Gestion des produits

**Exigences fonctionnelles :**

- **CRUD produits**
  - Création/Modification/Suppression
  - Upload d'images multiples
  - Gestion des catégories
  - Gestion des stocks
  - Prix et promotions

- **Gestion des catégories**
  - Création/Modification/Suppression
  - Ordre d'affichage
  - Images de catégorie

- **Personnalisation**
  - Configuration des options de personnalisation
  - Règles de validation
  - Modificateurs de prix

#### 4.2.4 Gestion des commandes

**Exigences fonctionnelles :**

- **Vue des commandes**
  - Liste complète
  - Vue Kanban (En attente, En préparation, En livraison, Livré)
  - Filtres avancés (date, statut, livreur, client)
  - Recherche

- **Gestion des statuts**
  - Changement de statut
  - Attribution de livreur
  - Annulation/Remplacement
  - Gestion des remboursements

- **Détails de commande**
  - Informations complètes
  - Articles commandés
  - Historique des modifications
  - Communication avec client

#### 4.2.5 Gestion des livreurs

**Exigences fonctionnelles :**

- **Gestion de la flotte**
  - Liste des livreurs
  - Statut (En ligne/Hors ligne)
  - Position en temps réel
  - Performance (livraisons, notes)

- **Attribution**
  - Attribution manuelle de commandes
  - Zones de livraison
  - Disponibilité

- **Gestion des documents**
  - Vérification des documents
  - Statut de vérification
  - Expiration des documents

#### 4.2.6 Gestion des clients

**Exigences fonctionnelles :**

- **Liste des clients**
  - Recherche et filtres
  - Détails du profil
  - Historique des commandes
  - Statistiques d'engagement

- **Gestion**
  - Blocage/Déblocage
  - Notes et commentaires
  - Support client

#### 4.2.7 Marketing et promotions

**Exigences fonctionnelles :**

- **Promotions**
  - Création/Modification/Suppression
  - Codes promo
  - Conditions d'éligibilité
  - Dates de validité

- **Notifications push**
  - Envoi de notifications ciblées
  - Campagnes marketing
  - Notifications transactionnelles

- **Analytics marketing**
  - Taux d'ouverture
  - Taux de conversion
  - ROI des campagnes

#### 4.2.8 Gestion des rôles et permissions

**Exigences fonctionnelles :**

- **Création de rôles**
  - Définition de rôles personnalisés
  - Attribution de permissions
  - Hiérarchie des rôles

- **Permissions granulaires**
  - Lecture/Écriture/Suppression par module
  - Accès aux données sensibles
  - Audit des actions

### 4.3 Exigences techniques

- **Framework** : Flutter SDK >=3.0.0 <4.0.0
- **State Management** : Provider, Riverpod (session)
- **Accès aux données** : `elcorazon_core`, routes `/manage/*` et
  `/administration/*` de l'API Django, sous permissions nommées (ADR-005)
- **Graphiques** : Fl_chart, Syncfusion Flutter Charts
- **Rapports** : PDF, Printing
- **UI** : Flex Color Scheme, Animations

### 4.4 Interfaces utilisateur

- Interface responsive (Desktop/Tablette)
- Navigation sidebar + bottom navigation (mobile)
- Design professionnel
- Graphiques interactifs
- Tableaux de données avancés

---

## 5. Architecture technique commune

### 5.1 Infrastructure backend

**Backend Django (`backend/`)**
- **API REST** `/api/v1/*` (DRF) — contrat versionné et documenté en OpenAPI,
  erreurs au format RFC 9457 (ADR-009)
- **Authentification JWT** (ADR-004) : le type de compte est porté par le
  jeton, les permissions par des rôles cumulables (ADR-005)
- **WebSockets** (Channels) `/ws/*` — suivi de course, file du livreur, appels
- **Tâches de fond** (Celery) — notifications, agrégats, expirations
- **PostgreSQL 17 + PostGIS** — les invariants métier sont défendus par des
  contraintes de base, pas seulement par du code applicatif
- **Redis** — cache, courtier Celery, couche de canaux
- **MinIO** — stockage **privé** ; les pièces justificatives et les images
  sortent en URL signées qui expirent

> **Le client ne décide de rien qui engage l'enseigne.** Prix, remises, statuts
> de commande, éligibilité d'un livreur, points de fidélité et remboursements
> sont établis par le serveur. C'est le principe qui a guidé la migration : voir
> [docs/architecture/04-migration-flutter.md](docs/architecture/04-migration-flutter.md).

**Tables principales :**
- `users` : Utilisateurs (clients, livreurs, admins)
- `orders` : Commandes
- `order_items` : Articles de commande
- `menu_items` : Produits
- `categories` : Catégories de produits
- `delivery_locations` : Positions GPS
- `messages` : Messages de chat
- `calls` : Appels
- `reviews` : Avis et notes
- `promotions` : Promotions
- `wallet_transactions` : Transactions portefeuille

### 5.2 Services externes

**Google Maps Platform**
- Géolocalisation
- Géocodage
- Itinéraires
- Calcul de distances

**Firebase**
- Cloud Messaging (notifications push)
- Analytics (optionnel)

**Agora RTC**
- Communication audio/vidéo
- Appels en temps réel

**PayDunya**
- Paiements Mobile Money
- Gestion des transactions

### 5.3 Sécurité

- Authentification sécurisée (JWT, ADR-004 — rotation et révocation des jetons)
- Chiffrement des données sensibles
- Autorisation à trois étages (ADR-005) : type de compte, permission nommée
  (`domaine.action`), et cloisonnement par établissement dans les requêtes
- Validation des entrées
- Protection CSRF
- HTTPS obligatoire

### 5.4 Performance

- Cache local (SQLite)
- Optimisation des requêtes
- Pagination des listes
- Lazy loading des images
- Compression des données

---

## 6. Exigences non-fonctionnelles

### 6.1 Performance

- **Temps de chargement** : < 3 secondes pour l'écran principal
- **Temps de réponse API** : < 1 seconde pour la plupart des requêtes
- **Fluidité** : 60 FPS pour les animations
- **Taille de l'application** : Optimisée pour mobile

### 6.2 Disponibilité

- **Uptime** : 99.5% minimum
- **Redondance** : Sauvegarde automatique des données
- **Mode dégradé** : Fonctionnement partiel en cas de panne

### 6.3 Scalabilité

- Support de 1000+ utilisateurs simultanés
- Architecture extensible
- Base de données optimisée

### 6.4 Compatibilité

- **iOS** : Version 12.0 et supérieure
- **Android** : Version 5.0 (API 21) et supérieure
- **Web** : Navigateurs modernes (Chrome, Firefox, Safari, Edge)

### 6.5 Accessibilité

- Support des lecteurs d'écran
- Contraste suffisant
- Tailles de police ajustables
- Navigation au clavier (web)

### 6.6 Internationalisation

- Support multilingue (Français, Anglais)
- Format de dates/heures localisé
- Devises locales (FCFA)

---

## 7. Contraintes et dépendances

### 7.1 Contraintes techniques

- Dépendance à un backend auto-hébergé (Django, PostgreSQL, Redis) : la
  disponibilité de la plateforme dépend de son exploitation
- Nécessité de clés API (Google Maps, PayDunya, Agora)
- Connexion internet requise pour la plupart des fonctionnalités
- Permissions GPS pour la géolocalisation

### 7.2 Contraintes légales

- Conformité RGPD pour les données personnelles
- Conditions générales d'utilisation
- Politique de confidentialité
- Gestion des paiements sécurisée

### 7.3 Dépendances externes

- Services tiers (Google Maps, PayDunya, Agora, Firebase)
- Mises à jour des SDK Flutter
- Disponibilité des services cloud

---

## 8. Planning et livrables

### 8.1 Phases de développement

**Phase 1 : Fondations (Complétée ~85%)**
- Architecture de base
- Authentification
- Gestion des produits
- Commandes de base

**Phase 2 : Fonctionnalités avancées (En cours)**
- Personnalisation avancée
- Commandes groupées
- Gamification
- Mode hors-ligne

**Phase 3 : Optimisations (À venir)**
- Performance
- Analytics avancés
- Amélioration UX
- Tests complets

### 8.2 Livrables

**Application Client**
- ✅ Application mobile fonctionnelle (~85%)
- ⚠️ Intégrations finales (PayDunya, Agora)
- ⚠️ Tests utilisateurs

**Application Livreur**
- ✅ Application mobile fonctionnelle (~90%)
- ⚠️ Optimisations finales
- ⚠️ Tests terrain

**Application Admin**
- ✅ Application web/desktop fonctionnelle (~95%)
- ⚠️ Rapports avancés
- ⚠️ Analytics complets

### 8.3 Métriques de succès

- Taux d'adoption : > 70% des utilisateurs actifs
- Taux de conversion : > 15% de commandes
- Satisfaction utilisateur : > 4.5/5
- Temps de livraison moyen : < 45 minutes
- Taux d'erreur : < 1%

---

## 9. Glossaire

- **XP** : Points d'expérience dans le système de gamification
- **RLS** : Row Level Security (sécurité au niveau des lignes)
- **CRUD** : Create, Read, Update, Delete (opérations de base)
- **OTP** : One-Time Password (mot de passe à usage unique)
- **SDK** : Software Development Kit
- **API** : Application Programming Interface
- **FCM** : Firebase Cloud Messaging
- **RTC** : Real-Time Communication

---

## 10. Contacts et support

Pour toute question ou clarification concernant ce cahier des charges, veuillez contacter l'équipe de développement.

---

**Document créé le** : Décembre 2024  
**Dernière mise à jour** : Décembre 2024  
**Version** : 1.0


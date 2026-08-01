# 🔍 Fonctionnalités Détaillées - El Corazón

Ce document explore en profondeur les mécanismes techniques et fonctionnels des modules clés de l'écosystème El Corazón.

---

## 1. 👥 Commandes Groupées (Group Delivery)
**Service :** `GroupDeliveryService` (`elcora_fast`)

Cette fonctionnalité permet à plusieurs utilisateurs de se regrouper pour une livraison unique, partageant ainsi les frais.

### ⚙️ Mécanisme
1.  **Création** : Un "initiateur" crée une demande de livraison groupée (`GroupDeliveryRequest`).
    *   Un `groupId` unique est généré.
    *   L'adresse et l'heure de livraison sont fixées.
    *   Un rayon de livraison maximum (ex: 2km) est défini pour accepter les participants proches.
2.  **Rejoindre un groupe** :
    *   Les utilisateurs voient les demandes actives sur une carte ou une liste.
    *   Si un utilisateur rejoint, son `userId` est ajouté à la liste `joinedUserIds`.
    *   Sa commande est liée au `group_id`.
3.  **Calcul des Frais** :
    *   Le coût de livraison de base (ex: 2000 FCFA) est divisé dynamiquement par le nombre de participants.
    *   Formule : `sharedDeliveryCost = baseCost / numberOfParticipants`.
4.  **Planification** :
    *   Support des commandes planifiées (`ScheduledOrder`) avec récurrence (quotidienne, hebdomadaire, mensuelle).
    *   Vérification des créneaux horaires disponibles (max 10 commandes/heure).

---

## 2. 🎨 Personnalisation Avancée (Product Customization)
**Service :** `CustomizationService` (`elcora_fast`)

Un moteur de règles flexible pour gérer les options de produits complexes (burgers, pizzas, gâteaux sur mesure).

### ⚙️ Structure des Données
*   **`CustomizationOption`** : Représente une option unitaire (ex: "Sans oignons", "Supplément Fromage").
    *   `category` : Type d'option (taille, cuisson, sauce, garniture, forme, étages, glaçage...).
    *   `priceModifier` : Impact sur le prix (+ ou -).
    *   `maxQuantity` : Limite par option (ex: max 2 portions de frites).
    *   `isRequired` / `isDefault` : Règles de validation.
*   **Validation** :
    *   Le service vérifie que toutes les catégories requises ont une sélection.
    *   Vérifie que les quantités maximales ne sont pas dépassées.

### 🛠️ Exemples de Règles
*   **Gâteaux** : Choix de forme (Rond, Carré...), nombre d'étages (impact prix important), saveurs (Vanille, Chocolat), et décorations (photo comestible).
*   **Burgers** : Cuisson (Saignant, À point), retrait d'ingrédients (allergènes), ajouts d'extras.

---

## 3. 🎮 Gamification & Fidélité
**Service :** `GamificationService` (`elcora_fast`)

Système complet pour engager les utilisateurs via des récompenses et une progression ludique.

### 🏆 Niveaux et Progression
Les points d'expérience (XP) déterminent le niveau de l'utilisateur :
1.  **Gourmand Débutant** (< 100 pts)
2.  **Amateur de Saveurs** (< 300 pts)
3.  **Connaisseur Culinaire** (< 600 pts)
4.  **Expert Gastronome** (< 1000 pts)
5.  **Maître El Corazón** (< 1500 pts)
6.  **Légende Culinaire** (> 1500 pts)

### 🎖️ Mécaniques
*   **Badges (Achievements)** : Débloqués via des actions spécifiques (ex: "Explorateur" pour 10 plats différents essayés, "Série de Victoires" pour 7 jours de commande consécutifs).
*   **Challenges** : Défis temporaires (ex: "Défi Weekend : Commander 3 fois ce weekend").
*   **Streak (Série)** : Calcul des jours consécutifs de commande pour bonus.
*   **Récompenses** : Échange de points contre des produits gratuits ou remises (ex: Boisson gratuite = 50 pts).

---

## 4. 📡 Mode Hors-Ligne (Offline Sync)
**Service :** `OfflineSyncService` (`elcora_fast`)

Assure la continuité de service même sans connexion internet.

### 🏗️ Architecture Technique
*   **Stockage Local** : Utilise **SQLite** (`sqflite`) pour stocker les données structurées et **SharedPreferences** pour les métadata simples.
*   **Tables Locales** :
    *   `offline_orders` : Commandes passées hors ligne.
    *   `cached_menu_items` / `cached_categories` : Catalogue complet (validité 24h).
    *   `pending_user_updates` : Modifications de profil en attente.
    *   `pending_cart_updates` : Sauvegarde du panier.

### 🔄 Synchronisation
1.  **Détection** : Écoute les changements de connectivité via `connectivity_plus`.
2.  **Queue de Sync** : Les opérations sont empilées dans les tables locales avec un statut `pending`.
3.  **Reprise** : Dès que la connexion revient, le service dépile les files d'attente et rejoue les requêtes contre l'API Django.
4.  **Gestion d'erreurs** : Système de `retry` avec backoff exponentiel pour les échecs de sync.

---

## 5. 📊 Analytics & Reporting
**Service :** `AnalyticsService` (`admin`)

Moteur d'analyse de données pour les administrateurs.

### 📈 Métriques Suivies
*   **Revenus** : Total, moyenne par commande, évolution journalière.
*   **Performance Produits** : Ventes par catégorie, top produits.
*   **Performance Livreurs** : Nombre de livraisons, temps moyen, notations (simulées pour l'instant).
*   **Engagement** : Nouveaux utilisateurs vs récurrents (via `getGeneralStats`).

### 🛠️ Optimisation
*   Les requêtes sont segmentées (Revenue, Orders, Categories) pour éviter les timeouts.
*   Filtres de plage transmis à l'API (`placed_at__gte`, `placed_at__lte`), appliqués côté serveur — et non sur une liste déjà chargée.

---

## 6. 🚚 Realtime Tracking & Géolocalisation
**Service :** `RealtimeTrackingService` (`elcora_dely` / `elcora_fast`)

Cœur logistique de l'application permettant le suivi en temps réel.

### 📍 Fonctionnement
*   **Mise à jour Position** : L'app livreur envoie sa position GPS toutes les 10 secondes via `Geolocator`.
*   **Diffusion** : Django Channels diffuse ces coordonnées sur le canal de la course, après avoir vérifié le droit d'y accéder **avant** d'accepter la connexion (ADR-008).
*   **Géocodage** : Conversion automatique des adresses textuelles en coordonnées Lat/Lng via Google Maps API (ou service interne `GeocodingService`) pour calculer les itinéraires et frais de livraison précis.
*   **Estimation** : Calcul du temps de trajet estimé (`calculateTravelTime`) pour informer le client.










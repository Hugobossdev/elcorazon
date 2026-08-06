# 📊 État des Fonctionnalités - Écosystème El Corazón

**Dernière révision** : 5 août 2026

> ⚠️ **Inventaire fonctionnel daté.** Le corps de ce document a été écrit en
> décembre 2024, quand les trois applications parlaient directement à Supabase.
> Les fonctionnalités listées existent toujours pour la plupart, mais **leur
> mise en œuvre a changé de fond en comble** : elles passent désormais par le
> backend Django (`backend/`), et plusieurs ont été retirées parce qu'elles ne
> tenaient pas — voir la liste plus bas.
>
> La référence à jour est **[docs/architecture/04-migration-flutter.md](docs/architecture/04-migration-flutter.md)**,
> qui trace domaine par domaine ce qui a été migré, construit ou supprimé.

## 🏗️ Ce qui a changé depuis cet inventaire

**Supabase a été retiré des trois applications** (1er août 2026). Elles ne
parlent plus qu'au backend Django : `supabase_flutter` a quitté les trois
`pubspec.yaml`, et `grep -rn "package:supabase" */lib` ne rend plus rien.

Le déplacement n'était pas cosmétique. Ce que le client décidait, le serveur le
décide :

- **les prix et les remises** (invariant C1) — le catalogue et les codes
  promotionnels ne se calculent plus à l'écran ;
- **les permissions** (ADR-005) — les rôles du back-office n'étaient appliqués
  que côté interface ; un « Opérateur » privé d'un module appelait quand même
  son API ;
- **le cloisonnement par établissement** — un opérateur de Kara lisait les
  commandes de Lomé ;
- **les secrets** — clés marchandes PayDunya, certificat Agora et clés Supabase
  vivaient dans des binaires distribués ; ils sont côté serveur.

**Fonctionnalités retirées**, faute d'équivalent et parce qu'elles ne
fonctionnaient pas comme annoncé : le portefeuille client, la validation
document par document des dossiers livreurs, les dates d'expiration de pièces,
les prévisions de vente et le « risque d'attrition » calculés dans le
navigateur, et l'auto-inscription des livreurs (un livreur s'embauche, il ne
s'inscrit pas).

## 🔄 Deuxième vague (3 août 2026)

**PayDunya a quitté les applications.** Elles embarquaient encore les clés
marchandes (`MASTER_KEY`, `PRIVATE_KEY`, `TOKEN`) et appelaient
`app.paydunya.com` depuis l'appareil : extraire ces clés d'un binaire distribué
permettait d'encaisser et de rembourser au nom de l'enseigne, sans permission,
sans trace et sans plafond. Le règlement passe maintenant par
`POST /payments/{commande}/initiate/`, et **seul le webhook signé fait avancer
une transaction** — le retour de l'utilisateur sur l'application n'écrit aucun
état.

> ⚠️ Les clés qui étaient dans les binaires publiés doivent être considérées
> comme compromises. Procédure : [docs/security/paydunya_rotation.md](docs/security/paydunya_rotation.md).

**Les reliquats de l'ancien backend Node ont disparu** : le mandataire
`localhost:3000` des API Google, le socket `10.0.2.2:3000` du back-office et la
dépendance `socket_io_client`.

**Deux domaines servis mais inexploités sont branchés.** `social` et
`group-carts` étaient complets et testés côté serveur depuis la Phase 4 sans
qu'aucune application ne les appelle :

- **Groupes** — création, adhésion par code d'invitation, sortie, fil de
  publications, j'aime, commentaires. Le code d'invitation vient du serveur et
  n'est servi qu'aux membres du groupe ;
- **Commande groupée** — ouverture, invitation, ajout d'articles, verrouillage,
  confirmation en commande, paiement partagé.

**Les trois applications ont des tests, et la CI les exécute.** `flutter test`
est bloquant sur `fastfood`, `dely` et `admin` en plus du socle partagé.

**Le déploiement de production est écrit** — `docker-compose.prod.yml`, Nginx
avec TLS et renouvellement Let's Encrypt, scripts `deploy.sh`, `backup.sh`,
`restore.sh`. Il n'a pas encore tourné sur une infrastructure réelle : voir
[docs/deploiement.md](docs/deploiement.md).

## 🔄 Troisième vague (5 août 2026) — suivi et géolocalisation

**Les frais de livraison ne se calculent plus sur le téléphone.** L'application
cliente appliquait son propre barème — 500 F de base, 200 F du kilomètre à vol
d'oiseau depuis des coordonnées de restaurant écrites en dur, livraison offerte
au-dessus de 10 000 F, plafond à 5 000 F. Aucune de ces valeurs n'existait côté
serveur, qui facture depuis le barème de la **zone qui couvre l'adresse
d'arrivée** : l'écran annonçait un prix, la commande en retenait un autre.

Deux routes existaient déjà côté serveur et n'étaient appelées par personne :

- `GET /geography/zones/resolve/` — ce point est-il desservi, à quel barème,
  avec quel délai et quel minimum de commande ;
- `POST /orders/preview/` — le devis complet de la commande, par le même chemin
  de calcul que sa création.

Le barème vit donc en **donnée** : ouvrir un quartier ou relever un forfait se
fait depuis le back-office, sans republier les applications.

**Le seuil de franco est enfin réglable depuis le back-office.** Le champ
existait en base et dans l'API depuis l'origine, mais aucun écran ne le
montrait : une zone qui offrait la livraison au-dessus d'un montant l'offrait
jusqu'à ce qu'un développeur passe en base. L'onglet « Tarifs » qui aurait dû
le porter listait cinq zones inventées (« Zone Centre », « Zone Nord »…) dont
les montants partaient dans les préférences locales du poste — personne ne les
facturait. Il liste désormais les zones réelles et permet d'en modifier le nom,
le forfait, le seuil de gratuité, le temps estimé et l'état actif.

**Le stockage des fichiers est arbitré** (ADR-011) : trois compartiments
publics pour ce qui est fait pour être vu (images d'articles, bannières,
avatars) et un compartiment privé pour ce qui ne l'est jamais (pièces
d'identité des livreurs, preuves de livraison). Les premiers sont servis par
des URL stables et cachables, les seconds par des URL signées qui expirent.

**Le faux suivi de livraison a disparu des trois applications.** Un
`startDeliveryTracking` local lançait une minuterie qui faisait passer une
commande de « en préparation » à « livré avec succès » en quarante secondes,
sans jamais interroger le serveur — un client dont le repas n'était pas parti
voyait son écran annoncer la livraison. Étaient également fabriqués sur
l'appareil : l'itinéraire affiché (quatre points obtenus en ajoutant des
millièmes de degré au départ) et la liste des « restaurants à proximité ». Le
suivi réel, lui, existait déjà et n'a pas changé : `ws/orders/{id}/tracking/`,
alimenté par le livreur, diffusé au client et au personnel.

---

Ce document présente l'état d'implémentation des fonctionnalités des 3
applications de l'écosystème El Corazón.

---

## 📱 1. EL CORA FAST (Application Client)

### ✅ Fonctionnalités Complètement Implémentées

#### 🔐 Authentification & Profil
- ✅ Connexion/Inscription (Email/Mot de passe)
- ✅ Gestion du profil utilisateur
- ✅ Vérification OTP
- ✅ Mode invité (Guest mode)
- ✅ Gestion des adresses de livraison
- ✅ Sélecteur d'adresses multiples

#### 🛒 Catalogue & Menu
- ✅ Affichage du menu complet
- ✅ Catégorisation des produits
- ✅ Recherche avancée de produits
- ✅ Filtres par catégorie
- ✅ Détails des produits
- ✅ Cache local du menu (mode hors-ligne)

#### 🎨 Personnalisation de Produits
- ✅ Personnalisation avancée (burgers, pizzas, gâteaux)
- ✅ Options de personnalisation (taille, cuisson, sauce, garniture)
- ✅ Options transmises au panier serveur, qui les valorise (invariant C1 —
  l'application affiche un **total estimé**, jamais un prix facturable)
- ✅ Validation des personnalisations sur les bornes du groupe (`min_select`/`max_select`)
- ✅ Interface dédiée pour gâteaux sur mesure — commandable dès que l'établissement a publié
  l'article et ses groupes d'options au catalogue ; sinon l'écran reste une vitrine et le
  dit, au lieu d'accepter une commande que le serveur refuse

#### 🛍️ Panier & Commandes
- ✅ Gestion du panier (ajout, modification, suppression)
- ✅ Calcul automatique des totaux
- ✅ Application de codes promo
- ✅ Historique des commandes
- ✅ Détails des commandes
- ✅ Statuts de commande en temps réel

#### 💰 Paiements
- ✅ Intégration PayDunya (structure prête)
- ✅ Paiement partagé (split payment)
- ✅ Portefeuille interne (wallet)
- ✅ Historique des transactions
- ⚠️ **TODO** : Implémentation complète de l'API PayDunya (actuellement simulée)

#### 🚚 Suivi de Livraison
- ✅ Suivi en temps réel sur carte (`ws/orders/{id}/tracking/`)
- ✅ Position du livreur en direct
- ✅ Estimation du temps de livraison — **délai annoncé par la zone**, lu du
  serveur ; il n'est plus déduit d'une distance divisée par une vitesse moyenne
  choisie dans l'application
- ✅ Notifications de statut
- ✅ Historique des livraisons
- 🔴 **Retiré le 5 août 2026** : la progression simulée localement, qui
  déclarait la commande livrée quarante secondes après l'avoir passée

#### 👥 Commandes Groupées
- ✅ Création de groupes de livraison
- ✅ Rejoindre un groupe existant
- ✅ Partage des frais de livraison
- ✅ Gestion des participants
- ✅ Commandes planifiées avec récurrence

#### 🎮 Gamification
- ✅ Système de points (XP)
- ✅ Niveaux utilisateur (6 niveaux)
- ✅ Badges et achievements
- ✅ Challenges temporaires
- ✅ Streak (série de jours consécutifs)
- ✅ Récompenses échangeables
- ✅ Tableau des récompenses

#### 📱 Notifications
- ✅ Notifications locales
- ✅ Notifications push (structure)
- ✅ Centre de notifications
- ✅ Historique des notifications
- ✅ **Projet Firebase créé et validé côté serveur** (`elcorazon-9595`,
  5 août 2026) : authentification du compte de service, envoi accepté par
  l'API v1, codes de refus conformes à ce que le connecteur classe
- ⚠️ **Reste** : une livraison sur un appareil Android physique, et **toute la
  configuration iOS** (`GoogleService-Info.plist` et clé APNs manquants). Voir
  `docs/firebase.md` §7

#### 💬 Communication
- ✅ Chat avec le livreur
- ✅ Chat avec le support
- ✅ Appels vidéo/audio (Agora - structure)
- ⚠️ **TODO** : Configuration complète Agora RTC

#### 🌐 Mode Hors-Ligne
- ✅ Cache local (SQLite)
- ✅ Synchronisation automatique
- ✅ Consultation du menu hors-ligne
- ✅ Passage de commande hors-ligne (queue)
- ✅ Gestion de la connectivité

#### 🔍 Recherche & Découverte
- ✅ Recherche avancée
- ✅ Filtres multiples
- ✅ Suggestions intelligentes
- ✅ Recommandations IA (structure)
- ⚠️ **TODO** : Amélioration des recommandations IA

#### ⭐ Avis & Notes
- ✅ Notation des produits
- ✅ Notation des livreurs
- ✅ Commentaires et avis
- ✅ Affichage des notes moyennes

#### 🎁 Promotions & Codes Promo
- ✅ Application de codes promo
- ✅ Gestion des promotions
- ✅ Notifications de promotions
- ✅ Historique des codes utilisés

#### 🗺️ Géolocalisation
- ✅ Détection de position GPS
- ✅ Géocodage d'adresses
- ✅ Calcul d'itinéraires
- ✅ Couverture et frais de livraison — **décidés par le serveur**
  (`/geography/zones/resolve/` et `/orders/preview/`) depuis le barème de la
  zone qui couvre l'adresse, plus par un tarif au kilomètre embarqué dans
  l'application
- ⚠️ **TODO** : Configuration Google Maps API Key

#### 📊 Autres Fonctionnalités
- ✅ Favoris
- ✅ Support client
- ✅ Réclamations et retours
- ✅ Thème clair/sombre
- ✅ Gestion des erreurs
- ✅ Performance monitoring
- ✅ Validation de formulaires

### ⚠️ Fonctionnalités Partiellement Implémentées

1. **Paiements PayDunya** — *migré, voir la deuxième vague en tête de document*
   - L'application appelle `POST /payments/{commande}/initiate/` et suit l'état
     rendu par le serveur. Elle ne joint plus le prestataire et ne porte plus
     ses clés.
   - **Action requise** : les clés dans le `.env` du **backend**, jamais dans
     celui d'une application.

2. **Notifications Push** — *validé côté serveur, Android seulement*
   - Projet Firebase `elcorazon-9595`, compte de service en place,
     `PUSH_BACKEND` sur le connecteur FCM. L'aller-retour avec Google a été
     exercé le 5 août 2026 : authentification, envoi accepté, et confrontation
     des codes de refus réels (`400 INVALID_ARGUMENT`, `404 UNREGISTERED`) à
     ceux que le connecteur classe comme définitifs — ils correspondent.
   - Cette validation a trouvé un défaut qui rendait le push **totalement
     muet** : le rafraîchissement du jeton OAuth exigeait le paquet `requests`,
     absent des dépendances. Corrigé par un transport bâti sur `httpx`.
   - **Reste** : une livraison sur un appareil Android physique, et **toute la
     configuration iOS** — aucune des deux applications ne porte de
     `GoogleService-Info.plist`, et sans clé APNs l'API accepte l'envoi pendant
     que l'iPhone ne reçoit rien. Voir `docs/firebase.md` §7.

3. **Appels Vidéo (Agora)**
   - Service présent
   - Configuration Agora manquante
   - **Action requise** : Configurer Agora App ID dans `.env`

4. **Recommandations IA**
   - Service de base présent
   - Algorithme à améliorer
   - **Action requise** : Affiner les algorithmes de recommandation

### 📈 Taux de Complétion : **~85%**

---

## 🚚 2. EL CORA DELY (Application Livreur)

### ✅ Fonctionnalités Complètement Implémentées

#### 🔐 Authentification
- ✅ Connexion livreur
- ✅ Inscription livreur
- ✅ Gestion du profil livreur
- ✅ Validation des documents

#### 📦 Gestion des Livraisons
- ✅ Réception des commandes
- ✅ Acceptation/Refus de commandes
- ✅ Liste des commandes actives
- ✅ Détails des commandes
- ✅ Changement de statut
- ✅ Mode En ligne/Hors ligne

#### 🗺️ Navigation
- ✅ Navigation GPS vers restaurant
- ✅ Navigation GPS vers client
- ✅ Calcul d'itinéraires
- ✅ Suivi de position en temps réel
- ✅ Carte interactive
- ⚠️ **TODO** : Configuration Google Maps API Key

#### 💬 Communication
- ✅ Chat avec le client
- ✅ Chat avec le support
- ✅ Appels vidéo/audio (Agora - structure)
- ⚠️ **TODO** : Configuration complète Agora RTC

#### 💰 Gains & Paiements
- ✅ Tableau de bord des gains
- ✅ Historique des livraisons
- ✅ Calcul des revenus
- ✅ Statistiques de performance
- ✅ Paiements (structure)

#### 📊 Analytics
- ✅ Statistiques personnelles
- ✅ Performance de livraison
- ✅ Temps moyen de livraison
- ✅ Nombre de livraisons

#### 🎮 Gamification Livreur
- ✅ Système de points
- ✅ Objectifs et récompenses
- ✅ Badges livreur
- ✅ Classements

#### 📱 Notifications
- ⚠️ Notifications Firebase — **câblées, pas configurées** : jeton enregistré et
  renouvelé auprès de `/auth/devices/`, détaché à la déconnexion, mais les
  identifiants Firebase sont factices (voir `docs/firebase.md`)
- ✅ Notifications locales
- ✅ Notifications de nouvelles commandes
- ✅ Notifications de statut

#### 🎤 Commandes Vocales
- ✅ Reconnaissance vocale
- ✅ Commandes vocales
- ✅ Service de synthèse vocale

#### 📍 Géolocalisation
- ✅ Mise à jour position en temps réel — un relevé toutes les dix secondes,
  déposé sur la course en cours (invariant L3 : un relevé appartient à une
  course, pas à un livreur)
- ✅ Partage de position
- ✅ Géocodage d'adresses
- 🔴 **Retiré le 5 août 2026** : la même progression de livraison simulée que
  dans l'application cliente

### ⚠️ Fonctionnalités Partiellement Implémentées

1. **Appels Vidéo (Agora)**
   - Service présent
   - Configuration Agora manquante
   - **Action requise** : Configurer Agora App ID dans `.env`

2. **Google Maps**
   - Service présent
   - Clé API partiellement configurée
   - **Action requise** : Vérifier la clé dans `.env`

### 📈 Taux de Complétion : **~90%**

---

## 💻 3. ADMIN (Panneau d'Administration)

### ✅ Fonctionnalités Complètement Implémentées

#### 🔐 Authentification & Rôles
- ✅ Connexion admin sécurisée
- ✅ Gestion des rôles (Super Admin, Manager, Opérateur)
- ✅ Système de permissions granulaire
- ✅ Journal d'audit des actions
- ✅ Gestion des sessions

#### 📊 Tableau de Bord
- ✅ Vue d'ensemble des métriques
- ✅ Statistiques en temps réel
- ✅ Graphiques de revenus (structure)
- ✅ Graphiques de commandes (structure)
- ⚠️ **TODO** : Compléter les graphiques fl_chart

#### 🛒 Gestion des Commandes
- ✅ Vue Kanban des commandes
- ✅ Vue Liste des commandes
- ✅ Changement de statut
- ✅ Attribution de livreurs
- ✅ Gestion des remboursements
- ✅ Notes internes
- ✅ Recherche globale
- ✅ **Recherche dans la supervision** (id, destinataire, adresse) — elle
  appelait `searchOrders(value)` **en jetant la valeur de retour** : la barre
  était affichée et ne filtrait rien. La recherche est désormais un état
  d'écran, appliqué là où la liste se construit
- ✅ **Tri** des commandes (date, total, statut) — la liste déroulante existait,
  branchée sur rien
- ✅ **Alertes « urgentes / en retard »** — le bandeau était alimenté par deux
  listes vides écrites en dur et ne s'affichait donc jamais. « Urgente » = en
  attente ou confirmée depuis plus de 20 min ; « en retard » = en cours et
  heure de livraison annoncée dépassée. Une commande sans heure annoncée n'est
  pas en retard, et une commande livrée sort des deux listes
- ✅ **Export CSV** — le fichier était construit puis écrit dans la console de
  débogage : le bouton annonçait un succès dont rien ne sortait. Il aboutit
  dans le presse-papier, et les champs sont échappés selon RFC 4180 (un retour
  à la ligne dans une adresse coupait la commande en deux lignes)
- 🔴 **Retiré** : le filtre par statut de la boîte « Filtres ». Les cinq onglets
  de l'écran *sont* le filtre par statut ; un second filtre, global et
  invisible depuis l'onglet courant, ne pouvait que le contredire

#### 🍔 Gestion du Menu
- ✅ CRUD complet des produits
- ✅ Gestion des catégories
- ✅ Gestion des stocks
- ✅ Personnalisations de produits
- ✅ Groupes d'options
- ✅ **Envoi d'images produits** — le fichier est joint à l'article par un
  `PATCH multipart`, rangé par le serveur dans le compartiment `products` du
  stockage objet, et c'est le serveur qui rend l'URL. L'application n'a ni les
  identifiants du stockage ni le nom des compartiments :
  - ✅ Sélection galerie ou caméra, recompression à 85 % et 1920 px
  - ✅ Refus au-delà de 5 Mo, **avant** de faire voyager les octets
  - ✅ Aperçu local immédiat, y compris avant l'envoi
  - ✅ Photo choisie sur un produit **pas encore créé** : elle est retenue et
    envoyée juste après la création, faute d'identifiant à qui l'attacher avant
  - ✅ Retrait d'image (`image: null` explicite, en JSON — un `multipart` ne
    sait pas exprimer « vide »)
  - ✅ Envoi par **octets** et non par chemin : sur le web un fichier choisi
    n'a pas de chemin lisible, et le back-office tourne aussi dans un navigateur
- 🔴 **Corrigé le 6 août 2026** : `uploadProductImage` était un talon qui
  journalisait puis rendait `null`. Ce document affirmait pourtant la
  fonctionnalité « COMPLÉTÉE », suppression de l'ancienne image comprise —
  rien de tout cela n'existait

#### 🚚 Gestion des Livreurs
- ✅ Liste des livreurs
- ✅ Ajout/Modification/Suppression
- ✅ Validation des documents — **la décision porte sur le dossier, pas sur
  chaque pièce** : un dossier, trois pièces, un statut de vérification, qui
  décide seul de l'éligibilité (L1). Les pièces s'ouvrent depuis l'écran par
  URL signée expirante ; le dépôt reste au livreur, depuis son application, et
  tout dépôt repasse le dossier en attente (L5)
- ✅ **Pièces remplacées effacées du stockage** (`common/files.py`) — un dossier
  rejeté est redéposé, si bien que chaque pièce d'identité, permis et carte
  grise jamais envoyés s'accumulaient indéfiniment dans le compartiment privé.
  Ce n'était pas une question de facture de stockage mais de rétention de
  données personnelles. Le signal couvre les sept champs fichier du projet, et
  tout champ ajouté plus tard
- ✅ Tableau de bord des documents
- ✅ Historique des validations
- ✅ Planning des livreurs
- ✅ Statistiques par livreur
- ✅ Carte des livreurs (structure)
- ✅ **COMPLÉTÉ** : Carte interactive Google Maps
  - ✅ Suivi en temps réel des positions des livreurs
  - ✅ Affichage des commandes actives sur la carte
  - ✅ Itinéraires pour les livreurs en livraison
  - ✅ Légende des statuts visible
  - ✅ Filtres par zone et statut
  - ✅ Mise à jour automatique toutes les 10 secondes
  - ✅ Info bulles détaillées pour livreurs et commandes
  - ✅ Bouton pour ajuster la vue sur tous les livreurs

#### 👥 Gestion des Clients
- ✅ Liste des clients
- ✅ Détails des clients
- ✅ Historique des commandes client
- ✅ Statistiques par client
- ✅ Gestion des rôles clients

#### 📈 Analytics & Rapports
- ✅ Analytics Service complet
- ✅ Métriques de revenus
- ✅ Performance des produits
- ✅ Performance des livreurs
- ✅ Engagement utilisateurs
- ✅ Graphiques fl_chart complétés (LineChart, BarChart, PieChart)
- ✅ Export de rapports (structure)

#### 🎁 Marketing & Promotions
- ✅ Gestion des promotions
- ✅ Gestion des campagnes marketing
- ✅ Codes promo
- ✅ Notifications push marketing
- ✅ Gamification management

#### ⚙️ Paramètres
- ✅ Paramètres généraux
- ✅ Configuration de l'application
- ✅ **Sélection des zones desservies** (onglet « Zones ») — c'est ici qu'on
  décide *où* l'on livre, par opposition à l'onglet « Tarifs » qui décide de
  *combien* :
  - ✅ Zones regroupées par ville, avec le nom de la ville et non sa clé
    (`/geography/manage/cities/`)
  - ✅ Ouverture/fermeture d'une zone d'un geste, écrite immédiatement sur le
    serveur — l'interrupteur est neutralisé le temps de l'aller-retour, sans
    quoi deux bascules rapides laissent la réponse la plus lente décider
  - ✅ « Tout ouvrir / tout fermer » par ville ; la fermeture en masse est
    confirmée, l'ouverture non (rien d'irréversible)
  - ✅ Recherche par nom de zone **ou** de ville
  - ✅ Les zones fermées restent affichées : les masquer supprimerait le seul
    endroit d'où on peut les rouvrir
  - ✅ Alerte visible quand plus aucune zone n'est ouverte (livraison
    indisponible pour tous les clients)
- ✅ Barèmes de livraison — **écrits sur le serveur** : nom, forfait, seuil de
  livraison offerte (franco), temps estimé, état actif. Le tarif au kilomètre
  et le minimum de commande sont affichés en lecture
- ⚠️ Le **contour** d'une zone (polygone GeoJSON) ne se dessine pas depuis le
  back-office : la création d'une zone passe par le serveur. L'API le permet
  (`POST /geography/manage/zones/`) mais un outil de dessin cartographique
  reste à faire
- 🔴 **Retiré le 5 août 2026** : les cinq zones en dur dont les tarifs
  n'atteignaient jamais le serveur

#### 🔍 Recherche Globale
- ✅ Recherche unifiée
- ✅ Recherche dans toutes les entités
- ✅ Filtres avancés

#### 📱 Notifications
- ✅ Envoi de notifications
- ✅ Notifications push
- ✅ Historique des notifications

### ⚠️ Fonctionnalités Partiellement Implémentées

1. ~~**Graphiques Interactifs (fl_chart)**~~ ✅ **COMPLÉTÉ**
   - ✅ Tous les graphiques fl_chart sont maintenant implémentés
   - ✅ LineChart pour les revenus
   - ✅ BarChart pour les commandes et livreurs
   - ✅ PieChart pour les catégories

2. ~~**Upload d'Images Produits**~~ ✅ **COMPLÉTÉ le 6 août 2026**
   - ✅ Envoi vers le stockage objet, compartiment `products`
   - ✅ Sélection depuis galerie ou caméra
   - ✅ Aperçu de l'image avant envoi
   - ✅ Compression automatique (85 % qualité, max 1920 px)
   - ✅ Validation de taille (max 5 Mo)
   - ✅ Suppression automatique de l'ancienne image — faite **par le serveur**
     (`common/files.py`), pas par le client
   - ✅ Gestion d'erreurs et retours à l'écran
   - ⚠️ Deux affirmations de la version précédente de cette entrée étaient
     fausses : l'envoi n'existait pas (talon rendant `null`) et rien n'effaçait
     l'ancienne image. Les images produits sont par ailleurs **publiques**, pas
     « privées, URL signées » — une photo de burger n'a aucune raison
     d'expirer, contrairement à une pièce d'identité (ADR-011)

3. ~~**Carte Interactive des Livreurs**~~ ✅ **déjà faite** — entrée périmée.
   `driver_map_screen.dart` monte un vrai `GoogleMap`, avec marqueurs par
   livreur, tracés d'itinéraire et rafraîchissement périodique. Il n'y a plus
   de placeholder ni d'intégration à faire

4. 🔴 **Export de Rapports PDF — inexistant**, et non « partiel ». Le paquet
   `pdf: ^3.10.7` est déclaré dans `pubspec.yaml` mais **importé nulle part** ;
   aucun écran n'expose de bouton d'export de rapport. Il n'y a donc rien à
   compléter : c'est une fonctionnalité à écrire, ou une dépendance à retirer

5. 🔴 **Supprimé le 6 août 2026 : `enhanced_admin_dashboard.dart`** (1 987
   lignes). Cet écran n'était **référencé par aucune route** — le tableau de
   bord réellement affiché est `admin_dashboard_screen.dart` — et il affichait
   des chiffres fabriqués présentés comme des analyses : `_getTopSellingItems`
   rendait cinq produits écrits en dur (« Burger Classique », 45 ventes, 225 de
   chiffre d'affaires) et `_getActiveDriversCount` rendait `8`. Ses six boutons
   de navigation affichaient un `SnackBar` au lieu de naviguer.

   Il a été supprimé plutôt que rebranché : ce qu'il proposait existe déjà dans
   le tableau de bord en service et dans l'écran d'analyses, tous deux sur des
   données réelles. Le garder sans le router n'avait aucun bénéfice et laissait
   à portée de main un écran qui, une fois routé, aurait publié des ventes
   inventées.

   **Conséquence** : `lib/core/widgets/admin_card.dart` (`AdminCard`,
   `AdminCardWithHeader`, `StatCard` — 438 lignes) n'a plus aucun appelant. Il
   n'a pas été supprimé : c'est une bibliothèque de composants génériques rangée
   dans `core/widgets/`, réutilisable telle quelle. À retirer si personne ne
   s'en sert d'ici la prochaine revue

### 📈 Taux de Complétion : **~97%** (graphiques fl_chart et upload d'images complétés)

---

## 🔧 Configuration Requise pour Fonctionnement Complet

### 🚨 CRITIQUE (Application ne démarre pas sans)

1. **Backend Django démarré**
   - `cd backend && docker compose up` — PostgreSQL + PostGIS, Redis, l'API et
     les workers.
   - Sans lui, les trois applications démarrent mais n'affichent rien : elles
     n'ont plus aucune source de données locale.

2. **Fichiers `.env` des applications**
   - `El Corazon fastfood/.env`, `El corazon dely/.env`, `El Corazon admin/.env`
   - Une seule variable indispensable : `API_BASE_URL`
     (`http://localhost:8000/api/v1` en développement).
   - **Plus aucune clé Supabase, ni clé marchande PayDunya, ni certificat
     Agora** : ces secrets vivent côté serveur. Les avoir dans une application
     revenait à les distribuer avec le binaire.

### ⚠️ IMPORTANT (Fonctionnalités essentielles)

1. **Google Maps API Key**
   - Nécessaire pour : géolocalisation, cartes, itinéraires
   - Où l'obtenir : https://console.cloud.google.com/apis/credentials
   - **Action** : dans le `.env` de chaque application. C'est une clé *cliente*,
     elle est visible dans le binaire par construction — elle doit donc être
     **restreinte** (empreinte Android, Bundle ID iOS, référent HTTP) et sous
     quota. Voir [docs/security/google_maps.md](docs/security/google_maps.md).

2. **PayDunya (Paiements)**
   - Nécessaire pour : paiements Mobile Money
   - Où l'obtenir : https://app.paydunya.com/developers
   - **Action** : dans le `.env` du **backend uniquement**. Ces clés permettent
     d'encaisser et de rembourser au nom de l'enseigne : dans un `.env`
     d'application, elles sont dans un binaire distribué au public. Les
     applications n'en ont pas besoin — elles appellent
     `POST /payments/{commande}/initiate/` et lisent la réponse.

### 📌 OPTIONNEL (Fonctionnalités avancées)

1. **Agora RTC (Appels vidéo)**
   - Nécessaire pour : communication client-livreur
   - Où l'obtenir : https://console.agora.io
   - **Action** : `AGORA_APP_ID` dans le `.env` des applications (identifiant
     public), `AGORA_APP_CERTIFICATE` dans celui du **backend uniquement** —
     c'est lui qui signe les jetons de canal. Le certificat dans une application
     permettrait de rejoindre n'importe quel appel.

2. **Firebase (Notifications push)**
   - Nécessaire pour : Notifications push
   - Où l'obtenir : https://console.firebase.google.com
   - **Correction (2026-08-05)** : `elcora_dely` n'était pas configuré non plus.
     Son `firebase_options.dart` portait l'en-tête « File generated by
     FlutterFire CLI » mais des clés factices et un projet inexistant
     (`fastfoodgo-deliver`) — l'en-tête a été retiré. Les deux applications sont
     dans le même état.
   - **Action** : un **seul** projet Firebase pour les deux applications (un
     jeton émis par un projet est refusé depuis un autre, et le backend n'a
     qu'un `FCM_PROJECT_ID`), puis `docs/firebase.md` de bout en bout.

---

## 📊 Résumé Global

| Application | Taux de Complétion | Services | Écrans | État |
|------------|-------------------|----------|--------|------|
| **elcora_fast** | ~85% | 60+ | 30+ | ✅ Fonctionnel (config requis) |
| **elcora_dely** | ~90% | 30+ | 15+ | ✅ Fonctionnel (config requis) |
| **admin** | ~90% | 50+ | 20+ | ✅ Fonctionnel (config requis) |

### ✅ Points Forts

1. **Architecture solide** - Services bien structurés et modulaires
2. **Couverture fonctionnelle** - Toutes les fonctionnalités principales présentes
3. **Base de données complète** - Schéma PostgreSQL + PostGIS, invariants
   défendus par des contraintes (voir `docs/architecture/03-modele-de-donnees.md`)
4. **Multi-plateforme** - Support mobile et web
5. **Gestion d'erreurs** - Services d'erreur et validation présents
6. **Performance** - Optimisations et cache implémentés

### 🚧 Points à Améliorer

1. **Configuration** - Fichiers `.env` à créer
2. **Graphiques** - Compléter les graphiques fl_chart dans admin
3. **Upload d'images** - Stockage privé côté serveur, URL signées expirantes
4. **Carte interactive** - Intégrer Google Maps dans admin
5. **Tests** - Ajouter des tests unitaires et d'intégration
6. **Documentation** - Documenter les APIs des services

---

## 🎯 Priorités pour Finalisation

### 🔴 PRIORITÉ 1 (Blocage)
- [x] Créer les fichiers `.env` pour les 3 applications (`API_BASE_URL`)
- [x] ~~Configurer les clés Supabase~~ — Supabase retiré
- [ ] Configurer Google Maps API Key (géocodage, cartes)
- [ ] Déploiement réel : Nginx, TLS, MinIO, Celery beat (§3.6 du plan de migration)

### 🟡 PRIORITÉ 2 (Fonctionnalités essentielles)
- [ ] Configurer PayDunya pour les paiements
- [x] Compléter les graphiques fl_chart dans admin ✅
- [x] Finaliser l'upload d'images produits ✅

### 🟢 PRIORITÉ 3 (Améliorations)
- [ ] Configurer Agora RTC pour les appels
- [ ] Intégrer la carte interactive des livreurs
- [ ] Ajouter des tests unitaires
- [ ] Améliorer la documentation

---

## 📝 Notes Techniques

### Services Principaux par Application

**elcora_fast** :
- AppService, CartService, OrderService
- PaymentService, LocationService, TrackingService
- GamificationService, CustomizationService
- OfflineSyncService, NotificationService

**elcora_dely** :
- AppService, DeliveryService
- LocationService, TrackingService
- ChatService, AgoraCallService
- EarningsService, NotificationService

**admin** :
- AdminAuthService, OrderManagementService
- MenuService, DriverManagementService
- AnalyticsService, RoleManagementService
- MarketingService, PaymentsService, GlobalSearchService
- (`ReportService` et `AuditLogService` ont été supprimés : aucun écran ne les
  atteignait)

### Technologies Utilisées

- **Backend** : Django 5.2 + DRF + Channels (ASGI) — auth JWT, API REST,
  WebSockets, Celery. PostgreSQL 17 + PostGIS, Redis, MinIO
- **State Management** : Provider, Riverpod
- **Maps** : Google Maps Flutter
- **Paiements** : PayDunya
- **Notifications** : Firebase Cloud Messaging
- **Communication** : Agora RTC
- **Local Storage** : SQLite, SharedPreferences
- **Graphiques** : fl_chart, Syncfusion Charts

---

**Corps de l'inventaire** : décembre 2024 · **Révision d'architecture** : 1er août 2026


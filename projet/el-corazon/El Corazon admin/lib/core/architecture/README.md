# Architecture Admin - El Corazón

## Structure du Projet

```
lib/
├── core/
│   ├── constants/          # Constantes centralisées
│   ├── navigation/         # Routage et navigation
│   ├── widgets/            # Widgets réutilisables de base
│   ├── utils/              # Utilitaires
│   └── architecture/       # Documentation architecture
├── models/                 # Modèles de données
├── services/               # Services métier (Provider)
├── screens/
│   └── admin/              # Écrans admin
│       ├── dashboard/      # Dashboard et statistiques
│       ├── orders/         # Gestion des commandes
│       ├── menu/           # Gestion du menu
│       ├── drivers/        # Gestion des livreurs
│       ├── clients/        # Gestion des clients
│       ├── analytics/      # Analytics et rapports
│       └── settings/       # Paramètres
└── widgets/                # Widgets spécifiques
```

## Principes Architecturaux

### 1. Widgets Interactifs
- Tous les widgets interactifs (InkWell, GestureDetector) doivent avoir des contraintes de taille explicites
- Utiliser `AdminInteractiveWidget` ou `AdminSafeCard` pour garantir la taille
- Toujours envelopper InkWell dans Material

### 2. Gestion d'État
- Utiliser Provider pour la gestion d'état
- Services = ChangeNotifier
- Écrans = Consumers

### 3. Navigation
- Utiliser AdminRouter pour la navigation centralisée
- Navigation par index dans AdminNavigationScreen

### 4. Responsive Design
- LayoutBuilder pour adapter aux différentes tailles
- Mobile: BottomNavigationBar + Drawer
- Desktop: Sidebar + Content

## Modules Principaux

### Dashboard
- Vue d'ensemble des statistiques
- Actions rapides
- Commandes en attente
- Activité récente

### Gestion des Commandes
- Liste des commandes avec filtres
- Détails de commande
- Changement de statut
- Assignation de livreur
- Suivi en temps réel

### Gestion du Menu
- Liste des produits
- Création/Édition de produits
- Gestion des catégories
- Gestion des personnalisations
- Upload d'images

### Gestion des Livreurs
- Liste des livreurs
- Statut en temps réel
- Assignation de commandes
- Suivi GPS
- Validation de documents

### Analytics
- Statistiques de vente
- Graphiques de performance
- Rapports personnalisés
- Export de données

## Bonnes Pratiques

1. **Hit Testing**: Toujours garantir une taille minimale
2. **Performance**: Utiliser RepaintBoundary pour les widgets complexes
3. **Erreurs**: Gérer toutes les erreurs avec try-catch
4. **Loading**: Afficher des indicateurs de chargement
5. **Validation**: Valider toutes les entrées utilisateur



















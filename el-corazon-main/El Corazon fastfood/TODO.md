# 🚧 TODO et Bugs Connus - El Corazon Fastfood

Liste des tâches futures et bugs connus pour le projet.

## 🐛 Bugs Connus

### Priorité Haute

- [ ] **Android Maps Crash (RÉSOLU)** ✅
  - **Description**: L'application crashait lors de l'ouverture de la carte Google Maps
  - **Solution**: Ajout de la clé API Google Maps dans AndroidManifest.xml + permissions GPS
  - **Status**: Corrigé le 10/02/2026

### Priorité Moyenne

- [ ] **Connexion WebSocket instable**
  - **Description**: Déconnexions occasionnelles du WebSocket en réseau faible
  - **Solution proposée**: Implémenter une stratégie de reconnexion automatique avec backoff exponentiel
  - **Workaround**: Reconnexion manuelle en redémarrant l'app

- [ ] **Images de plats lentes à charger**
  - **Description**: Chargement lent des images sur connexion 3G/4G
  - **Solution proposée**: Implémenter du caching d'images local + compression
  - **Package suggéré**: `cached_network_image`

### Priorité Basse

- [ ] **Interface dark mode incomplète**
  - **Description**: Quelques écrans ne s'adaptent pas correctement au mode sombre
  - **Écrans concernés**: Menu management, Settings
  
- [ ] **Messages d'erreur non traduits**
  - **Description**: Certains messages d'erreur sont en anglais
  - **Solution**: Compléter les fichiers de traduction

## ✨ Fonctionnalités à implémenter

### Court terme (Sprint 1-2)

- [ ] **Notifications Push**
  - Implémenter Firebase Cloud Messaging
  - Notifications pour: nouveau statut commande, livraison proche,promotions
  
- [ ] **Mode hors-ligne amélioré**
  - Cache persistant du menu
  - File d'attente pour les actions hors-ligne
  - Sync automatique à la reconnexion

- [ ] **Historique des commandes paginé**
  - Actuellement charge tout l'historique
  - Implémenter pagination + infinite scroll

- [ ] **Filtres avancés menu**
  - Filtrer par allergènes
  - Filtrer par régime (vegan, végétarien, sans gluten)
  - Tri par popularité, prix, temps de préparation

### Moyen terme (Sprint 3-6)

- [ ] **Programme de fidélité**
  - Points pour chaque commande
  - Niveaux de fidélité (Bronze, Argent, Or)
  - Récompenses et réductions

- [ ] **Commandes groupées**
  - Permettre à plusieurs utilisateurs de commander ensemble
  - Partage du panier
  - Paiement partagé ou individuel

- [ ] **Suivi nutritionnel**
  - Informations nutritionnelles par plat
  - Compteur de calories
  - Historique nutritionnel personnel

- [ ] **Chat en temps réel**
  - Chat client ↔ support
  - Chat client ↔ livreur
  - Messages prédéfinis

- [ ] **Favoris et listes**
  - Marquer des plats comme favoris
  - Créer des listes de courses
  - Réordonner rapidement

### Long terme (Sprint 7+)

- [ ] **IA Recommandations**
  - Suggestions personnalisées basées sur l'historique
  - Plats similaires
  - "Clients ayant aimé X ont aussi aimé Y"

- [ ] **Intégration réseaux sociaux**
  - Partager ses commandes
  - Inviter des amis (parrainage)
  - Programme de récompenses pour partages

- [ ] **Marketplace multi-restaurants**
  - Plusieurs restaurants sur la plateforme
  - Comparaison de menus et prix
  - Frais de livraison combinés

- [ ] **Commandes programmées**
  - Planifier une commande pour plus tard
  - Commandes récurrentes (hebdomadaires, mensuelles)

- [ ] **Wallet et crédit**
  - Recharger le wallet
  - Utiliser le crédit pour payer
  - Cashback sur commandes

## 🔧 Améliorations Techniques

### Performance

- [ ] Optimiser le bundle size (vérifier les dépendances inutilisées)
- [ ] Implémenter lazy loading pour les écrans
- [ ] Optimiser les requêtes Supabase (indexes, queries)
- [ ] Profiling et correction des memory leaks

### Code Quality

- [ ] Augmenter la couverture de tests (actuellement 0%)
  - Tests unitaires pour services
  - Tests d'intégration pour flows critiques
  - Tests widget pour UI

- [ ] Implémenter CI/CD
  - GitHub Actions ou GitLab CI
  - Tests automatiques sur PR
  - Build automatique

- [ ] Documentation du code  
  - Ajouter dartdoc comments
  - Générer documentation API avec dartdoc

- [ ] Refactoring
  - Extraire la logique métier des widgets
  - Simplifier CakeOrderScreen (actuellement 2800+ lignes)
  - Créer plus de widgets réutilisables

### Sécurité

- [ ] Audit de sécurité complet
- [ ] Implémenter rate limiting
- [ ] Chiffrer les données sensibles localement
- [ ] Scanner les dépendances pour vulnérabilités

## 📊 Métriques à suivre

- [ ] Temps de chargement moyen des écrans
- [ ] Taux de crash (Firebase Crashlytics)
- [ ] Taux de conversion (visiteurs → commandes)
- [ ] Satisfaction utilisateur (NPS)
- [ ] Temps moyen de livraison

## 🎯 Optimisations UX

- [ ] Animations de transition plus fluides
- [ ] Skeleton loaders pour le chargement
- [ ] Feedback haptique (vibrations)
- [ ] Tutoriel première utilisation
- [ ] Meilleurs messages d'erreur (plus clairs, actions suggérées)

## 📝 Notes

**Dernière mise à jour**: 10 Février 2026

**Convention pour ce fichier**:
- 🐛 Bugs = Problèmes existants
- ✨ Features = Nouvelles fonctionnalités
- 🔧 Tech = Améliorations techniques

**Contributeurs**: Merci de mettre à jour ce fichier lors de découverte de bugs ou idées de features.

---

Pour contribuer au projet, consultez [CONTRIBUTING.md](CONTRIBUTING.md).

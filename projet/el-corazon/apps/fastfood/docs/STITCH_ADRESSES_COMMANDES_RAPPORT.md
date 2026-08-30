# Rapport final — troisième lot Stitch (adresses et commandes)

> Source : `stitch_el_coraz_n_client_ui_redesign (2).zip` — 6 maquettes.
> Cible : `apps/fastfood`, branche `redesign-client-ui`.
> Achevé le 2026-08-30.

Audit préalable : [`STITCH_ADRESSES_COMMANDES_AUDIT.md`](STITCH_ADRESSES_COMMANDES_AUDIT.md).

**Avec les deux lots précédents, les 35 maquettes livrées sont intégrées.**

---

## 1. Écrans intégrés

| Maquette | Écran Flutter | État |
|---|---|---|
| `address_management` | `client/address_management_screen.dart` | ✓ |
| `address_details` | `client/address_detail_bottom_sheet.dart` | ✓ |
| `select_address` | `client/address_selector_screen.dart` | ✓ |
| `set_location_on_map` | `client/address_map_picker_screen.dart` | ✓ (chrome seulement) |
| `my_orders` | `client/orders_screen.dart` | ✓ (déjà repris, + « Recommander ») |
| `order_history` | `client/enhanced_orders_screen.dart` | ✓ |

---

## 2. Fichiers modifiés

```
lib/presentation/adresse.dart                          couleurs et icône du type
lib/screens/client/address_management_screen.dart      refonte UI
lib/screens/client/address_detail_bottom_sheet.dart    couleurs et sélecteur de type
lib/screens/client/address_selector_screen.dart        refonte UI
lib/screens/client/address_map_picker_screen.dart      couleurs seulement
lib/screens/client/enhanced_orders_screen.dart         refonte UI
lib/screens/client/orders_screen.dart                  bouton « Recommander »
lib/services/cart_service.dart                         + reprendreLaCommande
lib/widgets/address_card.dart                          refonte, API publique inchangée
test/_couverture_totale_test.dart                      régénéré (tools/couverture.py)
```

## 3. Fichiers créés

```
lib/presentation/reprise_de_commande.dart    tri et message de la recommande
test/reprise_de_commande_test.dart           6 cas
docs/STITCH_ADRESSES_COMMANDES_AUDIT.md
docs/STITCH_ADRESSES_COMMANDES_RAPPORT.md
```

Bilan : **+1 397 / −1 536 lignes** — 139 de moins pour davantage de fonctions.

---

## 4. Fonctionnalités conservées

Vérifié écran par écran.

**Adresses** — récupération, cache local, recherche, tri (récent, nom,
distance, type), filtre favoris, sélection, création, modification,
suppression avec confirmation, adresse par défaut, favoris, actualisation,
état déconnecté, autocomplétion Places, géocodage inverse, aperçu des frais,
résolution de zone, confirmation hors zone.

**Carte** — Google Maps, Geolocator, permissions, position courante, sélection
d'un point, repère central, recherche de lieux, adresse résolue, barème de
zone, retour de l'adresse retenue. **Aucune ligne de cette mécanique n'a été
touchée** ; la maquette montre une carte fictive, `GoogleMap` reste.

**Commandes** — historique, filtres, tri, groupement par date, statuts,
recommande, navigation, chargement, erreurs, listes vides, actualisation.

---

## 5. API

**Aucun endpoint modifié, ajouté ou supprimé.** Les écrans lisent et écrivent
exactement les mêmes routes qu'avant :

```
GET/POST/PATCH/DELETE /accounts/addresses/
POST /geography/zones/resolve/ · POST /orders/preview/
GET  /orders/ · POST /carts/{slug}/lines/
```

## 6. Backend

**Non modifié.** Aucun fichier hors `apps/fastfood/lib` et `apps/fastfood/test`
n'a été touché — vérifiable au `git diff --stat` du lot.

## 7. Packages

**Aucun ajout, aucune suppression, aucun changement de version.**
`git diff 7ef9919..HEAD -- pubspec.yaml pubspec.lock` est vide.

## 8. Tests

```
flutter analyze              aucun problème
flutter test                 289 tests verts (283 avant ce lot, +6)
flutter build web --release  succès (exit 0)
```

---

## 9. Ce qui a été corrigé au passage

### Silencieux, et le plus grave

**La recommande perdait des articles sans le dire.** L'écran d'historique
collectait la liste des plats retirés de la carte — ceux qu'on ne peut pas
recommander, le panier serveur ne connaissant que le catalogue du jour — dans
une variable qu'il n'affichait **jamais**. On recommandait cinq plats, deux
avaient disparu, et le message annonçait « 3 articles ajoutés » sans un mot des
deux autres. Le client s'en apercevait au règlement, en comptant son addition.
Ou pas du tout.

Une reprise partielle se dit maintenant en entier, les plats manquants nommés.
Six cas l'épinglent, dont celui d'un article encore au catalogue mais
`is_available = false` — que le serveur refuserait également.

### Cohérence

* **`TypeAdresse` portait `Colors.green`, `blue` et `orange`** au cœur du
  vocabulaire que les quatre écrans d'adresse partagent. Une couleur fausse à
  cet endroit se répandait partout ; un « Travail » orange dans la liste était
  bleu dans le formulaire qui le crée.
* **Deux écrans peignaient le même statut différemment.**
  `enhanced_orders_screen` gardait les verts, bleus et violets de Material que
  `DeliveryStatusCard` avait quittés au premier lot.
* **`refunded` et `failed` étaient classés « en cours »** dans l'historique et
  y restaient indéfiniment. Le `switch` est exhaustif.
* **La carte de l'historique menait au suivi de livraison**, y compris sur une
  commande livrée trois semaines plus tôt, où le suivi n'a rien à montrer. Elle
  mène au détail de commande.
* **`_showSnack(String, Color)`** laissait chaque appelant choisir sa teinte.
  Deux fonctions nomment l'intention.
* **Un message d'erreur exposait `e.toString()`** au client.
* **La confirmation de suppression ne nommait pas l'adresse**, sur une liste où
  l'on vient de balayer — geste qu'on déclenche parfois sans le vouloir.

### Simplification

`AddressCard` passe de 591 à 340 lignes et de `StatefulWidget` à
`StatelessWidget`. Elle était dépliante : deux gestes pour atteindre des
coordonnées GPS à cinq décimales, la ville, et un « code postal » qui était en
réalité `line2`. Personne ne vérifie une latitude avant de se faire livrer.

Ce que la maquette met à la place, et qui manquait : le **téléphone du
destinataire** et les **consignes de livraison** — portés par `Address` depuis
toujours, jamais montrés, et pourtant les deux choses qu'on relit avant de
valider une livraison.

**99 couleurs brutes ramenées à 3**, toutes `Colors.transparent`.

---

## 10. Ce qui n'a pas été fait, et pourquoi

| Élément | Motif |
|---|---|
| **« Recent Places »** (`select_address`) | Aucun historique de lieux n'est conservé : `AddressService` tient le carnet, pas les recherches. Afficher une section vide, ou la remplir avec le carnet sous un autre titre, tromperait sur son contenu |
| **Note par commande** (`order_history`, « ★ 4.8 ») | `Order` ne porte pas de note. Les avis sont **par article** (`Review.menuItemId`) — une note de commande n'existe pas et devrait être inventée |
| **Carte fictive** (`set_location_on_map`) | `GoogleMap` reste, comme la consigne l'exige |
| **Copie « Abidjan, Côte d'Ivoire »** | L'établissement est à **Lomé** (`AppConstants`) |

---

## 11. Problèmes restants

### À arbitrer — un comportement conservé sans être approuvé

Après « Recommander », l'écran d'historique affiche un message avec un bouton
« Voir le panier » — **puis pousse le panier une seconde plus tard**. Le bouton
n'a jamais l'occasion de servir, et le client est emmené sans l'avoir demandé.

Changer une navigation est un changement de comportement, et la consigne de ce
lot était de n'en faire aucun : le code est laissé tel quel, avec une note à
l'endroit exact. **Deux issues raisonnables** : retirer la navigation
automatique (le bouton suffit), ou retirer le bouton (la navigation suffit).
À vous.

### Antérieur à ce lot

`tools/code_mort.py` échoue sur `presentation/commande.dart` (138 lignes,
atteint depuis aucun `main.dart`). Vérifié sur une extraction du commit
`15ebe32` : la situation est **antérieure aux trois lots**. Le fichier porte le
vocabulaire juste — les huit statuts que le serveur émet — pendant que les
écrans lisent `models/order.dart`, qui en déclare dix dont deux inexistants.
Résoudre demande de consolider les deux vocabulaires : un travail de modèle.

### Écrans encore à l'ancienne charte

Cinq, qu'aucune maquette ne couvre : `advanced_search`, `social_feed`,
`social_groups`, `guest_contact`, et la feuille `address_detail_bottom_sheet`
dont seules les couleurs ont été reprises (sa structure à trois onglets dépasse
ce que la maquette dessine, et fonctionne).

---

## 12. Validation visuelle

L'environnement ne permet pas de capture d'écran : ni émulateur ni appareil
n'est branché. Ce qui a été vérifié à la place :

* `flutter build web --release` **compile** — `flutter analyze` ne visite pas
  le code qu'aucun chemin n'atteint ;
* les 289 tests passent, dont 94 cas de mise en page qui montent les composants
  aux contraintes réelles de cinq largeurs (320 → 1 280 px) et deux échelles de
  texte ;
* la conformité aux jetons est vérifiable par recherche : 3 couleurs brutes
  subsistent sur les six écrans, toutes `Colors.transparent`.

Écart connu avec les captures Stitch : la copie mentionne Abidjan, l'écran dit
Lomé. C'est voulu.

# Problèmes relevés pendant l'intégration du design Stitch

> Compagnon de `UI_REDESIGN_AUDIT.md`. Chaque entrée est un fait constaté sur
> le code de `apps/fastfood`, pas une hypothèse.
> Catégories : `UI` · `API` · `MODEL` · `STATE` · `NAVIGATION` · `BACKEND` ·
> `DEPENDENCY`.

---

## ISSUE-001 — `Expanded` dans un `Wrap` : l'étape « créneau » levait à l'ouverture

**Catégorie :** UI — **corrigé**

**Problème**
Dans l'ancien `cake_order_screen.dart`, le couple date / heure était un `Wrap`
dont les deux enfants se déclaraient `Expanded`.

**Cause**
`Expanded` exige un parent `Flex` (`Row` ou `Column`). Un `Wrap` n'en est pas
un : Flutter lève une assertion de disposition.

**Impact**
L'onglet « Personnaliser » de la commande de gâteau affichait le bandeau
d'erreur au lieu de son formulaire, dès qu'on l'ouvrait.

**Solution**
`Row` avec deux `Expanded` et une gouttière entre eux. Le montage est épinglé
par `test/debordement_test.dart`, groupe « Commande de gâteau », sur cinq
tailles d'écran et deux échelles de texte.

**Backend nécessaire** — aucun.

---

## ISSUE-002 — `OptionRow` réduisait l'intitulé à une colonne de lettres

**Catégorie :** UI — **corrigé**

**Problème**
Sur un téléphone de 320 px avec la police système grossie (×1,3), une option
dont le prix est long — « +25 000 F CFA » — rendait son intitulé sur une
largeur **nulle** : une lettre par ligne, sur 961 px de haut, et la ligne
débordait de 34 px.

**Cause**
La ligne était un `Row` de trois enfants : l'icône, `Expanded(intitulé)`, puis
le prix. Un `Row` mesure ses enfants **sans flex d'abord** et ne laisse à
l'`Expanded` que ce qui reste. Le prix mesurait 240 px pour 256 disponibles.

**Impact**
Toute la fiche produit, sur les articles dont les options portent un
supplément — c'est-à-dire presque tous. Le défaut ne se voyait pas en police
normale, ce qui l'a masqué.

**Solution**
Le prix passe **sous** l'intitulé dès qu'il réclamerait plus de la moitié de
la largeur disponible. La mesure se fait au `TextPainter`, avec le
`textScaler` de la vue : un seuil en pixels codé en dur n'aurait pas survécu
au réglage « très grand » d'Android.

**Backend nécessaire** — aucun.

---

## ISSUE-003 — `StickySummaryBar` écrasait son action

**Catégorie :** UI — **corrigé**

**Problème**
Le bandeau ancré « total + bouton » débordait de 27 px sur un téléphone de
360 px en police normale, et de 69 px sur 320 px en police grossie.

**Cause**
Même défaut qu'ISSUE-002 : le bloc libellé/montant à sa largeur naturelle,
puis `Expanded(action)`. « Total estimé / 125 000 F CFA » prenait toute la
largeur.

**Impact**
Le **panier** et le **règlement** autant que la commande de gâteau : les trois
écrans partagent ce composant. C'est le bouton « Commander » qui disparaissait
sous la bordure.

**Solution**
Sous un seuil — largeur du bloc + 148 px pour l'action — la barre se plie en
deux lignes : montant au-dessus, action pleine largeur en dessous.

**Backend nécessaire** — aucun.

---

## ISSUE-004 — La fiche produit ne lisait pas `isAvailable`

**Catégorie :** STATE — **corrigé**

**Problème**
On pouvait composer entièrement un plat retiré de la carte — taille, cuisson,
suppléments — pour se voir refuser au moment de l'ajout au panier.

**Cause**
L'accueil et la carte écartent les articles indisponibles de leurs listes,
si bien que le cas semblait couvert. Il ne l'était pas : on atteint aussi la
fiche depuis les **favoris**, où l'article a été mis en réserve du temps où il
était servi, et depuis une notification.

**Impact**
Travail perdu, et un refus qui arrivait au pire moment sans dire d'où il
venait.

**Solution**
La fiche affiche un encart en tête et grise l'ajout au panier.

**Backend nécessaire** — aucun. `MenuItem.isAvailable` existe déjà au contrat.

---

## ISSUE-005 — Pas de feuille de partage système

**Catégorie :** DEPENDENCY — **contourné, documenté**

**Problème**
La maquette `product_detail` pose un bouton « share » dans la barre. Une vraie
feuille de partage suppose deux choses qui manquent : le paquet `share_plus`,
et surtout **un lien vers le plat**.

**Cause**
L'application n'expose ni adresse web publique ni schéma de lien profond
(`elcorazon://…`). Un partage renverrait donc du texte sans destination, ou
pire, une URL inventée qui ne mènerait nulle part.

**Impact**
Le geste de partage existe mais reste local : il copie une fiche texte —
nom, prix, description, « El Corazón » — dans le presse-papiers.

**Solution complète, si elle est décidée**
1. définir un schéma de lien profond et l'enregistrer côté Android/iOS ;
2. exposer une page publique par article, ou une route d'atterrissage ;
3. ajouter `share_plus` et remplacer la copie par `Share.shareUri`.

**Backend nécessaire** — une route publique par article, ou un service de
liens.

---

## ISSUE-006 — Le nom du livreur manque à l'évaluation

**Catégorie :** MODEL

**Problème**
La carte de commande livrée mène à l'écran d'évaluation du livreur, qui
recevait le nom `'Livreur'` **écrit en dur** dans les arguments de route.

**Cause**
`Order` porte `deliveryPersonId` mais pas le nom. L'écran d'évaluation, lui,
accepte `String? driverName` et retombe déjà sur « Livreur » quand il est nul.

**Impact**
Aucun visuellement — le repli affiche le même mot. Mais le nom en dur laissait
croire qu'une donnée réelle circulait.

**Solution appliquée**
La route passe `null` : c'est l'état réel de la connaissance, et l'écran
d'évaluation garde son repli.

**Backend nécessaire**
Ajouter le nom du livreur à `OrderSerializer` (ou faire lire la course par
l'écran d'évaluation, via `GET /delivery/assignments/?order={id}`).

---

## ISSUE-007 — Documents légaux et évaluation de l'app non branchés

**Catégorie :** BACKEND

**Problème**
Le profil portait trois entrées qui ouvraient une boîte contenant une note de
développement, montrée telle quelle au client :

* « Politique de confidentialité » → « À connecter : afficher le document
  (webview / markdown) ou lien externe. » ;
* « Conditions d'utilisation » → même texte ;
* « Évaluer l'app » → « Évaluation : à brancher (Play Store / App Store) ».

**Cause**
Points d'entrée posés en attendant les documents, jamais complétés.

**Impact**
Une note interne affichée en production. Les deux documents légaux sont par
ailleurs **exigés** par Google Play et l'App Store avant publication.

**Solution appliquée**
Les trois entrées sortent du profil : une entrée absente vaut mieux qu'une
entrée qui explique au client qu'elle n'existe pas.

**Backend nécessaire**
Publier les deux documents à une URL stable et les ouvrir (`url_launcher` est
déjà au projet). L'évaluation demande `in_app_review` et les identifiants de
boutique.

---

## ISSUE-008 — La modification du profil ne modifiait rien

**Catégorie :** STATE — **corrigé**

**Problème**
La boîte « Modifier le profil » se fermait sur « Profil mis à jour avec
succès ! » **sans rien envoyer**. Un commentaire — « In a real app, would
update the user profile » — tenait lieu d'appel.

**Cause**
Écran laissé en place au moment de la bascule vers le backend Django, alors
que `AuthRepository.updateProfile({fullName, phone})` existait déjà.

**Impact**
Le champ retrouvait son ancienne valeur à la réouverture, et rien ne
distinguait un refus du serveur d'une absence de requête. C'est le cas exact
que §17 du cahier des charges proscrit pour le paiement, appliqué au profil.

**Solution**
`AppService.updateProfile` relaie l'appel puis relit la session
(`sessionProvider.restoreSession()`) — l'identité garde une source unique. La
boîte montre l'attente et ne se ferme qu'en cas de succès ; un échec reste
affiché avec son motif.

**Backend nécessaire** — aucun, la route existait.

---

## ISSUE-009 — `substring(0, 8)` sur l'identifiant de commande

**Catégorie :** UI — **corrigé**

**Problème**
`DeliveryStatusCard` affichait `order.id.substring(0, 8)` sans vérifier la
longueur.

**Impact**
Un identifiant de moins de huit caractères faisait tomber **toute la liste**
des commandes, pas seulement la ligne fautive.

**Solution** — la référence se rogne si elle est assez longue, et rend `#—`
sur un identifiant vide.

**Backend nécessaire** — aucun.

---

## ISSUE-010 — Commandes remboursées et échouées classées « en cours »

**Catégorie :** STATE — **corrigé**

**Problème**
L'onglet « En cours » retenait tout ce qui n'était ni `delivered` ni
`cancelled`. `refunded` et `failed` y restaient donc indéfiniment, en tête de
liste.

**Solution** — les quatre issues rejoignent l'historique. Le tri est écrit en
`switch` exhaustif : une valeur ajoutée à `OrderStatus` fera désormais échouer
la compilation plutôt que de retomber silencieusement dans « en cours ».

**Backend nécessaire** — aucun. À noter : `presentation/commande.dart` ne
connaît que huit statuts (le serveur n'émet ni `refunded` ni `failed`), tandis
que `models/order.dart` en déclare dix. La consolidation des deux
vocabulaires dépasse le périmètre de cette phase.

---

## ISSUE-011 — Valeurs nutritionnelles détaillées absentes du contrat

**Catégorie :** BACKEND

**Problème**
La maquette `product_detail` montre un bloc « Nutritional Info » : 850 kcal,
42 g de protéines, 58 g de glucides, 48 g de lipides.

**Cause**
`MenuItem` ne porte que `calories` (`int?`, sur le détail seulement). Les trois
macronutriments n'existent nulle part.

**Impact**
Le bloc n'est pas rendu. Les calories, elles, s'affichent en puce quand
l'établissement les a saisies.

**Solution** — non simulée. Inventer 42 g de protéines pour tenir la maquette
serait une information fausse sur un sujet qui touche à l'allergie et au
régime.

**Backend nécessaire**
`proteins_g`, `carbs_g`, `fats_g` sur `MenuItem` et son sérialiseur détail,
plus les champs correspondants au back-office.

---

## ISSUE-012 — Aucun prix barré : le contrat ne porte pas de prix de référence

**Catégorie :** BACKEND

**Problème**
La maquette `product_detail` affiche `10 000 ₣` barré au-dessus de `8 500 ₣`.

**Cause**
`MenuItem.price` est unique. Aucun `compare_at_price` ni prix promotionnel par
article : les remises passent par `/promotions/` et s'appliquent au **panier**,
pas à la ligne de catalogue.

**Impact**
La fiche montre un prix simple.

**Backend nécessaire**
Soit un `compare_at_price` sur l'article, soit l'exposition au client des
promotions applicables à un article donné.

---

## ISSUE-013 — Le catalogue d'offres promotionnelles n'est pas exposé au client

**Catégorie :** API

**Problème**
La maquette `promo_codes` liste les offres disponibles — « NEW USER 20 % OFF »,
« Free Delivery », « $5 OFF Combo » — avec leur échéance et leur état
(« USE NOW », « MIN. NOT MET »).

**Cause**
`GET /promotions/` existe, mais sert le back-office. Le client n'a que
`POST /orders/preview/ { promo_code }`, qui **valide un code** sans jamais en
énumérer.

**Impact**
L'écran se limite à la saisie d'un code, validée par le serveur. Afficher une
liste d'offres supposerait de l'inventer côté client — exactement ce que §28
proscrit.

**Backend nécessaire**
Une route client, par exemple `GET /promotions/available/`, rendant les
promotions actives applicables au compte, avec leur seuil et leur échéance.

---

## ISSUE-014 — Pas de téléversement d'image de référence pour un gâteau

**Catégorie :** BACKEND

**Problème**
La maquette `cake_order` porte une étape « 6. Reference Image (Optional) —
Upload Design Ideas, PNG, JPG up to 5MB ».

**Cause**
Aucune route ne permet à un client de déposer un fichier. Le stockage média
(`common/storage.py`, Cloudinary) sert le catalogue, écrit depuis le
back-office.

**Impact**
L'étape n'est pas rendue. Le champ « message sur le gâteau » et les
instructions spéciales restent le seul moyen de décrire une idée.

**Backend nécessaire**
Une route de dépôt authentifiée, bornée en taille et en type, rattachée à la
ligne de panier ou à la commande.

---

## ISSUE-015 — Avis : ni photo, ni vote d'utilité

**Catégorie :** MODEL

**Problème**
La maquette `product_reviews` propose un filtre « With Photos » et un compteur
« 👍 12 » par avis.

**Cause**
`Review` porte la note, le texte, l'auteur et la date. Ni photo ni vote. Le
modèle local `ProductReview` en avait, mais c'étaient des champs que le client
remplissait lui-même — retirés pour cette raison.

**Impact**
Les filtres se limitent à ce que le serveur sait distinguer.

**Backend nécessaire**
Pièces jointes sur `Review` (avec le stockage média d'ISSUE-014), et une table
de votes d'utilité.

---

## ISSUE-016 — Écrans encore à l'ancienne charte

**Catégorie :** UI

**Problème**
Ces écrans n'ont pas de maquette Stitch et ne sont pas des onglets de la barre
inférieure. Ils gardent leur habillage d'origine et détonnent dès qu'on les
atteint :

`address_management` · `address_selector` · `address_map_picker` ·
`address_detail_bottom_sheet` · `advanced_search` · `chat` · `call` ·
`delivery_tracking` · `driver_rating` · `enhanced_orders` · `order_details` ·
`order_rating` · `rewards` · `social_feed` · `social_groups` · `support` ·
`guest_contact` · `auth`

**Impact**
Cohérence visuelle, pas fonctionnalité. Les quinze maquettes livrées et les
quatre onglets de navigation sont, eux, à jour.

**Solution proposée**
Une seconde passe, écran par écran, sur le même patron : `GlassAppBar`,
`SectionCard`, `ActionButton`, `EmptyStateWidget`/`ErrorWidget`, et les jetons
de `DesignConstants`. `rewards` et `delivery_tracking` d'abord — ce sont les
plus visités des dix-huit.

**Backend nécessaire** — aucun.

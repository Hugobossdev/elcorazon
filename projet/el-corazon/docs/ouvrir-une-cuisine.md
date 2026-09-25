# Ouvrir une cuisine

**Ouvrir un établissement dans un nouveau pays ou une nouvelle ville est une
opération de configuration, pas une opération de développement.** Rien de ce qui
suit ne demande de modifier du code, de recompiler ou de republier une
application.

Tout se fait depuis **El Corazón Admin → Réseau**.

---

## L'ordre est imposé par le schéma

```
Pays  →  Ville  →  Zone de livraison  →  Établissement
```

Chaque étage se rattache au précédent par une clé étrangère non nulle. Ce n'est
pas une préférence d'ergonomie : commencer par la fin échoue plus tard, avec un
message de contrainte d'intégrité au lieu d'une explication.

Les trois onglets de l'écran Réseau sont dans cet ordre pour la même raison.

---

## 1. Ouvrir le marché (le pays)

**Réseau → Marchés → Ouvrir un marché**

| Champ | Ce qu'il engage |
|---|---|
| Nom | Affichage seulement. |
| Code ISO (2 lettres) | `TG`, `CI`, `BJ`, `CM`. Unique. Mis en majuscules à la frappe. |
| Indicatif téléphonique | `+228`. Proposé ensuite dans **toutes** les saisies de numéro des trois applications. |
| Devise | **Figée sur chaque commande passée dans ce pays.** La changer plus tard ne convertit rien : le catalogue et l'historique se retrouveraient dans deux unités. |
| Fuseau horaire | Décide de l'heure à laquelle les restaurants du pays ouvrent. Une faute ici ferme un établissement une heure trop tôt, tous les jours, sans que rien ne le signale. |

Devises et fuseaux proposés viennent du serveur (`GET /geography/reference/`) :
ce sont exactement les valeurs qu'il acceptera. Le champ « Fuseau horaire » est
une **recherche** et non une liste — il couvre les six cents identifiants IANA,
et « porto novo » y trouve `Africa/Porto-Novo`.

> Un marché s'ouvre **actif**. Le désactiver retire d'un coup ses villes, ses
> zones et ses établissements de l'application cliente, sans rien supprimer.

---

## 2. Ouvrir la ville

**Réseau → Villes → Ouvrir une ville**

Nom, identifiant d'URL (proposé d'après le nom), et le point qui **centre les
cartes**. Ce point ne décide d'aucune livrabilité : c'est le rôle de la zone.

**Chercher la ville sur la carte** évite d'aller lire ses coordonnées ailleurs —
et de les intervertir une fois sur deux. La recherche est bornée au pays déjà
choisi : sans cela, « Kara » rend une ville du Togo, une du Nigeria et une région
de Turquie, sans que rien dise laquelle est la bonne.

Une ville se rattache à un marché **ouvert**. Le slug est unique par pays : deux
villes homonymes de deux pays coexistent sans conflit.

---

## 3. Ouvrir la zone de livraison

**Réseau → Villes → Ouvrir une zone** (sous la ville concernée)

`Restaurant.zone` est une clé étrangère non nulle : **sans zone, aucun
établissement n'est créable.**

La zone porte le **barème**, et lui seul décide de ce que paiera un client :

| Champ | Effet |
|---|---|
| Frais de base | Ajouté à toute course de la zone. |
| Frais par kilomètre | Multiplié par la distance réelle, mesurée par PostGIS depuis la position de l'établissement. |
| Seuil de livraison offerte | Au-delà, le client ne paie rien — le livreur, lui, reste rémunéré sur le montant brut. |
| Commande minimum | En deçà, la commande est refusée : elle ne couvre pas le déplacement. |
| Distance maximale | Au-delà, la course est refusée **même si le point est dans le contour**. Un contour se dessine large ; la distance parcourue est ce qui coûte. |
| Délai estimé | Affiché au client. |

La devise n'est pas saisie : elle est héritée du pays, et le serveur refuse un
montant libellé autrement.

### Trois façons de dessiner un contour

| Mode | Ce qu'on saisit | Quand |
|---|---|---|
| **Cercle** | un centre et un rayon | le cas courant — « on livre à 5 km autour » |
| **Polygone** | des sommets, tracés sur la carte | quand un fleuve, une voie ferrée ou une limite de quartier coupe la zone |
| **Zone administrative** | un contour GeoJSON importé | quand on dispose du tracé officiel d'une commune |

**Le contour d'un cercle est calculé par le serveur**, pas par l'écran. Il
projette soixante-quatre sommets par la formule de destination géodésique : ils
sont réellement à la distance demandée, à toute latitude. L'approximation
courante — convertir le rayon en degrés — donne un disque à l'équateur et une
ellipse ailleurs : 0,5 % d'écart à Lomé, 35 % à Paris. Le faire une seule fois,
côté serveur, garantit aussi que deux écrans ne dessineront jamais deux zones
différentes pour la même saisie.

Le centre et le rayon sont **conservés à côté du contour**. C'est ce qui permet
de rouvrir « 5 km » dans un champ plutôt que soixante-quatre sommets, qu'on ne
saurait ni relire ni ajuster.

### Zones de ville, zones de cuisine

Par défaut une zone appartient à la **ville** : elle vaut pour toutes ses
cuisines. C'est le cas courant.

Une zone peut aussi être rattachée à **un établissement** — depuis sa fiche — et
elle ne vaut alors que pour lui. C'est ce qui permet à deux cuisines d'une même
ville de facturer différemment sans que l'une hérite du barème de l'autre.

**Réseau → Établissements → ⋮ → Zones de livraison** liste les zones propres de
la cuisine. Chacune se crée, se modifie, s'active ou se désactive, et se
supprime après confirmation. L'éditeur de carte propose deux outils :

- **Cercle** — toucher la carte place le centre (son repère se glisse), le
  curseur règle le rayon ;
- **Polygone** — chaque toucher ajoute un sommet ; un sommet se glisse pour le
  déplacer, se retire en touchant sa bulle ; « Annuler » retire le dernier.

Les autres zones de la cuisine sont dessinées en gris pour repérer un
chevauchement. **Le serveur refuse** un contour qui se croise, un sommet hors du
globe (souvent une inversion latitude/longitude), plus de 500 sommets ou plus de
5 000 km² ; le refus s'affiche sous la fiche, qui reste ouverte.

Une zone sur laquelle la cuisine est **posée** (`Restaurant.zone`) ne se
supprime pas : le refus (409) nomme la cuisine à rattacher d'abord ailleurs.
Pour arrêter de livrer une zone sans rien effacer, on la **désactive**.

Chaque geste laisse une entrée distincte au journal d'audit : création, contour,
barème, ouverture, suppression — avec l'auteur, l'avant et l'après.

### Quelle zone s'applique, quand plusieurs se recouvrent

Dans l'ordre :

1. les zones **de l'établissement concerné** passent avant les municipales ;
2. la **priorité** la plus haute — le départage explicite, pour ce que la
   géométrie ne tranche pas ;
3. la **plus petite surface**. Une zone incluse dans une autre est une exception
   tarifaire : on la dessine précisément parce que son barème diffère.

> **Un chevauchement n'est pas une faute.** L'écran le signale — il liste les
> zones recoupées — pour que la décision soit consciente, jamais pour empêcher
> l'enregistrement.

---

## 4. Ouvrir l'établissement

**Réseau → Établissements → Ouvrir un établissement**

Le formulaire ne demande **ni pays, ni devise, ni fuseau** : la zone choisie les
emporte tous. C'est ce qui rend impossible un établissement dont le pays
contredirait la ville — il n'y a pas de second champ pour le dire autrement.

Champs : nom, identifiant d'URL, description, zone, adresse, position,
téléphone, courriel, délai de préparation.

### La position se pose sur une carte

**Placer sur la carte** ouvre un écran où trois gestes désignent un point :

- **chercher un nom** — « El Corazón Plateau », « Boulevard du 13 Janvier ». La
  recherche est bornée au marché de la zone choisie, et rend l'adresse, la ville
  et le pays en prime ;
- **toucher la carte** — pour un lieu qu'aucun service d'adressage ne nomme, ce
  qui est fréquent hors des centres-villes ;
- **déplacer le marqueur** — pour ajuster de quelques mètres, à l'entrée de
  service plutôt qu'au milieu du bâtiment.

À chaque déplacement, le serveur dit ce qu'il y a là : pays, région, ville,
quartier, adresse. Un panneau montre le résultat **avant** de valider : rien
n'est repris tant qu'on n'a pas appuyé sur « Utiliser ce lieu ».

> **Rien n'écrase une saisie manuelle.** Une adresse déjà remplie n'est pas
> remplacée par celle que Google propose : quelqu'un qui a écrit « Entrée de
> service, portail bleu » ne doit pas la perdre en ajustant le marqueur de trois
> mètres. Seules les coordonnées sont remplacées — c'est ce qu'on vient chercher.

Les deux champs de latitude et de longitude restent visibles et modifiables : un
relevé GPS exact se saisit plus vite qu'il ne se pointe, et une carte
indisponible ne doit pas empêcher d'ouvrir un établissement.

> **La position doit tomber dans la zone.** C'est la faute de saisie que rien
> d'autre n'attraperait : la commande partirait, et le calcul de distance
> mesurerait depuis une autre ville. Le contrôle de complétude la signale avant
> la mise en service.

**L'établissement naît en brouillon.** Il n'apparaît dans aucune application
cliente tant qu'il n'est pas mis en service.

### Ou : dupliquer un établissement existant

**Réseau → Établissements → ⋮ → Dupliquer**

Recopie vers un établissement neuf, au choix :

- les **informations générales** (description, délai de préparation) ;
- les **horaires** — les heures ne sont pas converties : 11 h ici reste 11 h
  là-bas, parce qu'« ouvert de 11 h à 23 h » est une décision locale et non un
  instant absolu ;
- le **catalogue** : catégories, articles, options, suppléments.

**Ne sont jamais copiés** : commandes, clients, livreurs, paiements, historiques,
statistiques. Il n'y a pas de case pour eux — il n'existe aucun chemin de code
pour les copier.

Les **zones** ne se copient pas non plus, mais pour une autre raison : un contour
est un lieu réel. Recopier celui de Lomé vers Abidjan poserait un périmètre de
livraison dans le golfe de Guinée. La zone d'arrivée est donc choisie.

> **Entre deux devises, le catalogue ne suit pas.** 2 500 XOF recopiés vers un
> marché en NGN deviendraient 2 500 nairas : un prix plausible, faux d'un
> facteur cinq, que rien n'afficherait comme anormal. L'écran le dit et
> verrouille la case ; dupliquez sans le catalogue, puis saisissez les prix du
> nouveau marché.

---

## 5. Configurer la cuisine

**Réseau → Établissements → (la fiche)**

Cet écran liste **ce qui manque encore pour ouvrir**, en clair, et ouvre l'écran
qui sert à le remplir. La liste vient du serveur à chaque lecture : elle dépend
du catalogue, des horaires et de la flotte, qui changent depuis trois autres
écrans.

### 5a — Horaires

Une ou plusieurs plages par jour — service du midi et du soir. Une plage qui
franchit minuit (`22:00 → 02:00`) se saisit **telle quelle** : le serveur en
tient compte, plutôt que d'obliger à saisir deux plages sur deux jours.

Le système en déduit seul si la cuisine est ouverte, dans le fuseau de son pays.

> **Les horaires sont appliqués, pas seulement affichés.** Hors plage
> d'ouverture, la cuisine **refuse** les commandes — l'application affiche
> « Fermé — réouverture demain à 11 h 00 » et le serveur rend le même motif si
> une commande est tentée. Une cuisine sans aucune plage est fermée à toute
> heure, et n'annonce aucune réouverture.

#### Fermetures exceptionnelles

**Horaires → Fermetures exceptionnelles → Fermer**

Un jour férié, des travaux, une coupure : on ferme **de telle date à telle
date**, avec un motif facultatif que le client lit — « Fermé exceptionnellement
(jour férié) — réouverture vendredi à 11 h 00 ». La cuisine **rouvre d'elle-même**
à la fin, dans ses horaires habituels. Ne pas retirer une plage d'horaires pour
fermer un jour : on fermerait tous les mêmes jours de la semaine.

Les heures se saisissent à l'heure du poste. Un poste réglé sur un autre fuseau
que la cuisine voit ses heures décalées d'autant.

### 5b — Catalogue

Catégories, articles, options, suppléments. **Isolé par établissement** : le
slug d'un article est unique par restaurant, et modifier la carte de Lomé ne
touche pas celle d'Abidjan.

Désactiver une **catégorie** rend ses articles incommandables partout, y compris
dans les paniers déjà composés : ils y restent visibles, marqués « momentanément
indisponible ».

### 5c — Livreurs

Un livreur est rattaché à un établissement à son inscription. La fiche donne
accès à la gestion de la flotte du périmètre courant.

**Zones de livraison d'un livreur** (**Livreurs → Modifier**). Rien de coché :
il roule dans toutes les zones de sa cuisine — le cas courant. Coché : il ne
reçoit que les courses de ces zones ; un livreur affecté à Cocody ne reçoit pas
une course pour Yopougon, même partie de la même cuisine. Seules les zones que
sa cuisine dessert se proposent, et le serveur refuse les autres.

**Affectation automatique** (**Réseau → Établissements → Modifier → Livraison**,
activée par défaut). Dès qu'une commande est **prête**, la course est proposée au
livreur compatible le plus proche de la cuisine : même cuisine, zone permise,
dossier validé, en ligne, sans course en cours — d'abord ceux qui n'ont pas
déjà refusé cette commande, puis ceux qui n'ont aucune autre proposition en
attente. Un refus, une proposition restée **90 secondes** sans réponse
(`DELIVERY_OFFER_TTL_SECONDS`), ou un livreur qui se met en ligne relancent la
recherche. L'affectation manuelle depuis la supervision reste possible dans les
deux cas. **Prérequis de production : le worker et l'horloge Celery**
(`elcorazon-worker`, `elcorazon-beat`) — sans l'horloge, une proposition sans
réponse n'expire jamais.

> Un dossier livreur **approuvé** est exigé pour la mise en service : sans lui,
> l'établissement prendrait des commandes que personne ne peut livrer.

### 5d — Matière : stock et recettes *(facultatif à l'ouverture)*

**Inventaire → Stock · Validations · Recettes · Ingrédients**

Rien de ce qui suit n'est exigé pour la mise en service : un plat sans recette
ne consomme rien, et un ingrédient sans ligne de stock n'est jamais décompté.
La cuisine peut ouvrir, et suivre sa matière plat par plat ensuite. Mais tant
que ce n'est pas fait, **son coût matière est inconnu** et une rupture de pain
ne retire aucun burger de la carte.

1. **Ingrédients** — le référentiel est commun à toutes les cuisines, et il se
   tient **au siège** : un compte rattaché à une cuisine le lit, sans l'écrire.
   Chaque ingrédient se mesure en masse, en volume ou en unités, et cette
   dimension ne change plus.
2. **Stock → Suivre un ingrédient**, puis **Réception** à chaque livraison. On
   saisit la quantité et le **prix du lot** tel qu'il figure sur la facture ; le
   coût au kilogramme en est déduit. Une réception envoyée deux fois — réseau
   coupé, bouton pressé deux fois — n'est comptée qu'une fois.
3. **Recettes** — la couverture en tête dit combien de plats ont une recette.
   Chaque plat se compose par portion, et chaque option aussi : un supplément
   fromage ajoute du fromage, « sans oignon » en retire (quantité négative).
4. **Seuil d'alerte** sur les lignes qui le méritent : **Stock → Au seuil
   d'alerte** liste ce qui doit être commandé.

Dès qu'un ingrédient suivi manque, les plats qui l'emploient sortent **grisés**
de l'application cliente, et une commande ne peut plus les emporter.

#### Pertes, comptages, et la seconde validation

**Perte** et **Comptage** écrivent au journal une sortie ou un écart. Au-delà
d'un **plafond de valeur**, la déclaration attend la validation d'**une autre
personne**, dans **Validations** ; celle qui a déclaré ne peut ni valider ni
refuser, et le serveur le refuse jusque dans la base.

Le plafond se fixe sur la fiche de l'établissement (**Réseau → Modifier**),
dans sa devise, par un compte muni de `restaurants.write` — le siège, pas le
gérant dont il encadre les écritures. **Laissé vide, toute perte attend une
validation** : c'est le défaut sûr, qu'on desserre en le fixant.

Une perte dont le coût est inconnu — aucune livraison facturée encore — attend
elle aussi : on ne peut pas prouver qu'une valeur inconnue est sous le plafond.

---

## 6. Mettre en service

Sur la fiche de l'établissement, le cycle de vie est explicite :

```
brouillon → en configuration → prêt → en service ⇄ suspendu
```

La mise en service est **refusée** tant qu'il manque quelque chose, et le refus
dit quoi : position hors zone, aucune plage d'ouverture, aucun membre du
personnel, catalogue vide, aucun livreur approuvé.

Une fois en service, l'établissement apparaît dans l'application cliente et
reçoit des commandes.

- **Suspendre** le retire de l'application cliente. À réserver aux arrêts durables.
- **« Accepte les commandes »** est le drapeau du coup de feu : l'établissement
  reste visible, affiché comme débordé, et le serveur refuse toute commande
  tant qu'il est coupé — y compris depuis un panier déjà ouvert. C'est ce qu'on bascule pour une heure,
  pas la suspension — celle-ci le ferait disparaître au lieu de le montrer
  occupé.

Chaque changement d'état **prévient le personnel** du périmètre concerné.

---

## Ce qui se passe ensuite, sans rien faire de plus

| Application | Effet |
|---|---|
| **El Corazón Fast** (client) | L'établissement entre dans l'annuaire. À partir de deux cuisines, une bascule apparaît dans l'en-tête : ville d'abord, cuisine ensuite, avec un tri « Autour de moi » facultatif. Le catalogue, les prix et le panier suivent le choix. |
| **El Corazón Dely** (livreur) | Les candidatures peuvent viser le nouvel établissement, et l'indicatif téléphonique proposé suit son pays. Les courses partent de sa position réelle. |
| **El Corazón Admin** | La fiche entre dans la liste, avec ses compteurs — commandes, livreurs, produits — et les filtres pays / ville / statut. La supervision filtre ses commandes par pays → ville → zone → cuisine, et l'onglet **Réseau → Activité** chiffre commandes et chiffre d'affaires par pays, ville, zone ou cuisine. |

---

## Donner un périmètre à quelqu'un

**Administration → Personnel**

Le cloisonnement a trois étages. Un compte voit ce que son rattachement lui
donne, et rien d'autre :

| Rattachement | Voit |
|---|---|
| Aucun | Rien. C'est le défaut : un oubli de configuration ferme, il n'ouvre pas. |
| Un ou plusieurs **établissements** | Ceux-là seulement. |
| Une ou plusieurs **villes** | Tous les établissements de ces villes, **y compris ceux ouverts demain**. |
| Un ou plusieurs **marchés** (pays) | Tous les établissements de ces pays, y compris ceux ouverts demain. |
| Superutilisateur | L'enseigne entière. |

Le rattachement dit **sur quoi** ; les rôles disent **ce qu'on a le droit de
faire**. Les deux sont nécessaires, et ils varient indépendamment : un directeur
pays sans `orders.refund` ne rembourse pas.

Deux garde-fous que le serveur applique :

- **on n'accorde pas une permission qu'on ne détient pas soi-même** ;
- **on n'accorde pas un marché qu'on ne couvre pas soi-même.** Un directeur du
  Togo nomme un responsable de Lomé, pas un directeur de Côte d'Ivoire.

### Qui peut quoi

| Geste | Siège | Directeur de marché / ville | Gérant d'établissement |
|---|:--:|:--:|:--:|
| Ouvrir un pays, une ville, une zone | ✅ | ❌ | ❌ |
| Ouvrir ou dupliquer un établissement | ✅ | ✅ *dans son périmètre* | ❌ |
| Mettre en service | ✅ | ✅ *dans son périmètre* | ❌ |
| Suspendre, repasser en configuration | ✅ | ✅ | ✅ |
| Horaires, carte, flotte, commandes | ✅ | ✅ | ✅ |
| Ingrédients du référentiel | ✅ | ❌ | ❌ |
| Stock, recettes, réceptions, pertes | ✅ | ✅ *selon ses permissions* | ✅ *selon ses permissions* |
| Valider la perte d'un autre | ✅ | ✅ *avec `inventory.approve`* | ✅ *avec `inventory.approve`* |
| Fixer le plafond de validation | ✅ | ✅ *avec `restaurants.write`* | ❌ |
| Statistiques | enseigne | son périmètre | son établissement |

---

## Les statistiques suivent le périmètre

**Chaque rapport est borné au périmètre du compte** — chiffre d'affaires,
produits phares, performance des livreurs, répartition par statut, catégories,
chiffres de tête.

Un compte du siège peut affiner avec trois filtres qui **se cumulent** :
`?country=`, `?city=`, `?restaurant=`. Ils restreignent, jamais ils
n'élargissent : un filtre hors périmètre rend un rapport vide, jamais les
chiffres d'un établissement qu'on n'administre pas.

`GET /analytics/reports/network/?level=country|city|zone|kitchen` range les
commandes selon leur **géographie figée** : chaque commande garde le pays, la
ville et la zone où elle a été prise. Une cuisine rattachée ailleurs plus tard
ne fait pas migrer son historique d'une ville à l'autre.

---

## Le référentiel unique de livrabilité

Une seule route répond à « me livrez-vous ici, par qui, à quel prix, en combien
de temps » : `POST /restaurants/delivery-check/`. Les trois applications
l'appellent, et c'est **la même règle** que celle qui facturera la commande.

Elle rend, dans tous les cas :

| Champ | Contenu |
|---|---|
| `is_available` | livrable ou non |
| `reason` | **pourquoi**, quand ce n'est pas livrable |
| `restaurant` | l'établissement qui dessert — celui demandé, ou le plus proche |
| `zone` | la zone retenue, avec son barème |
| `distance_m` | mesurée par PostGIS sur l'ellipsoïde |
| `estimated_minutes` | préparation **plus** course |
| `delivery_fee` / `gross_delivery_fee` | ce qu'on facture, et ce que la course vaut |

Quatre refus possibles, et ils n'appellent pas le même geste : « aucune cuisine
ne dessert ici » (changer d'adresse), « hors zone » (idem), « trop loin »
(idem), « panier trop léger » (ajouter un article). Un booléen seul obligerait
chaque écran à inventer son message — et il en inventerait trois différents.

Le client n'a donc plus à désigner une cuisine que la géographie détermine ; il
peut toujours en choisir une autre quand plusieurs conviennent.

---

## Ce qui laisse une trace

Trois écritures sont journalisées, parce qu'elles sont **silencieuses et
coûteuses** : un catalogue mal saisi se voit à l'écran, un rayon réduit de deux
kilomètres ne se voit que dans les commandes qu'on ne reçoit plus.

- **déplacer un établissement** — ancienne et nouvelle position, ancienne et
  nouvelle adresse ;
- **redessiner une zone** — forme, centre, rayon, et une empreinte du contour ;
- **changer un barème** — chaque montant, avant et après.

Chaque entrée porte son auteur et sa date, et **survit à ce qu'elle décrit** :
le libellé — « zone Cocody » — est recopié au moment du changement, de sorte
qu'il reste lisible après un renommage ou un retrait.

Rien n'est écrit quand rien ne change : un formulaire renvoie tous ses champs à
chaque validation, et corriger un numéro de téléphone consignerait sinon
« position inchangée » à chaque fois.

---

## Vérifier avant d'annoncer

Le parcours complet, dans l'ordre :

1. le marché apparaît dans l'onglet Marchés, actif ;
2. la ville apparaît sous ce marché ;
3. la zone apparaît sous la ville, avec son barème ;
4. l'établissement apparaît, **en brouillon**, avec ses manques listés ;
5. les manques sont comblés — la liste se vide ;
6. la mise en service est acceptée ;
7. l'application cliente le voit apparaître dans son sélecteur ;
8. une commande passée dessus arrive au back-office avec le bon établissement ;
9. Dely la propose à un livreur rattaché, depuis la bonne position de retrait.

Tant que l'étape 8 n'a pas été faite **avec une vraie commande**, l'ouverture
n'est pas vérifiée : un écran vert ne prouve que l'écran.

Les incohérences que le schéma laisse passer — cuisine sur la zone propre d'une
autre, cuisine en service sur un marché fermé ou sans horaires, livreur affecté
hors de la desserte de sa cuisine, commandes sans géographie figée — se
listent sans rien modifier :

```bash
python manage.py audit_reseau            # rapport
python manage.py audit_reseau --strict   # code de sortie 1 s'il reste une anomalie
```

Les propriétés structurelles — catalogues cloisonnés, devises héritées, tri par
proximité, périmètre des rapports — se vérifient d'une commande :

```bash
python tools/valider_multi_cuisine.py     --compte siege@elcorazon.test --mot-de-passe '…'
```

Il interroge l'API servie, jamais la base : ce qui y passe passe pour les trois
applications, puisqu'elles n'ont que cette porte.

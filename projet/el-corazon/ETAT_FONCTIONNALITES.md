# 📊 État des Fonctionnalités - Écosystème El Corazón

**Dernière révision** : 19 septembre 2026

> ⚠️ **Inventaire fonctionnel daté.** Le corps de ce document a été écrit en
> décembre 2024, quand les trois applications parlaient directement à Supabase.
> Les fonctionnalités listées existent toujours pour la plupart, mais **leur
> mise en œuvre a changé de fond en comble** : elles passent désormais par le
> backend Django (`backend/`), et plusieurs ont été retirées parce qu'elles ne
> tenaient pas — voir la liste plus bas.
>
> La référence à jour est **[docs/architecture/04-migration-flutter.md](docs/architecture/04-migration-flutter.md)**,
> qui trace domaine par domaine ce qui a été migré, construit ou supprimé.

## 🧰 Le back-office, complété là où l'argent et les clients attendaient (19 septembre 2026)

L'analyse du 18 septembre a confronté les 23 écrans du back-office au cahier
des charges (§4) et aux 209 routes du serveur. Les écrans appelaient tous des
routes qui existaient ; ce qui manquait, c'étaient des **domaines entiers sans
porte d'entrée pour le personnel**. Ce lot en ferme cinq.

### Ce qui restait coincé

- **Les retraits des livreurs ne se soldaient nulle part.** La demande débitait
  les gains à l'instant ; `WithdrawalService.settle` et `fail` n'avaient
  **aucun appelant** hors des tests, et `Withdrawal` n'était même pas dans
  l'administration Django. Nouvel écran **Caisse › Retraits livreurs** :
  constater un versement (référence du virement exigée) ou le refuser (gains
  rendus, motif lu par le livreur). Permissions `payouts.read` et
  `payouts.settle`, séparées pour le quatre-yeux. L'exploitation est prévenue
  d'une demande, le livreur de la décision.
- **Le support client n'avait pas de côté personnel.** Tickets, réclamations et
  retours n'étaient ouverts qu'aux clients (`IsCustomer`) : le back-office ne
  pouvait ni les lire ni y répondre, et une réponse saisie dans
  l'administration Django ne partait vers personne. Nouvel écran
  **Utilisateurs › Service client** : fil du ticket et réponse, résolution
  motivée, réclamations et retours tranchés — motif exigé pour tout refus.
  Chaque geste parvient au client en notification (type `support`).
  Permissions `support.read` et `support.write`. Un retour refusé porte
  désormais sa réponse (`resolution`), lisible par le client.
- **Les remboursements ne se clôturaient que dans l'administration Django.**
  Nouvel écran **Caisse › Remboursements** ; le constat relit la ligne sous
  verrou, ce que l'action d'administration ne faisait pas.
- **Aucun compte du personnel ne se créait depuis le back-office**, et aucun ne
  se rattachait à une cuisine — alors que le poste de cuisine renvoyait « vers
  un responsable du siège ». Le serveur savait tout faire ; le dépôt Dart
  n'exposait que la liste, les rôles et l'activation. L'écran des rôles ouvre
  maintenant un compte (mot de passe provisoire généré), édite son périmètre en
  arbre marché → ville → cuisine, et remplace un mot de passe perdu. Un compte
  rattaché à rien est signalé comme **ne voyant rien** ; le siège se distingue
  enfin de lui (`is_superuser`, en lecture seule).
- **Le journal d'audit était écrit et lisible nulle part.** Nouvel écran
  **Système › Journal d'audit** (`audit.read`), cloisonné comme le reste. Il
  consigne en plus les **droits** : permissions d'un rôle, rôles, périmètre,
  activation et mot de passe d'un compte, blocage d'un client — dont le motif,
  pourtant exigé par la route, n'était jusqu'ici conservé nulle part.

### Ce qui mentait à l'écran

- L'onglet **Statistiques** des commandes affichait « Livraison à temps 0 % »
  et « Satisfaction 0.0/5 » en toutes circonstances : il lisait des clés que le
  service ne produit pas. La satisfaction laisse la place au taux d'annulation,
  qui se lit dans les données.
- La **déconnexion automatique** ignorait l'activité (`recordActivity` sans
  appelant) et le délai choisi ne s'appliquait qu'après être repassé par les
  Paramètres.
- La **pastille des notifications** était allumée en dur ; elle suit le
  compteur de non-lues, relu chaque minute.
- Un **refus de validation** (400) s'affichait « Une erreur est survenue. » dans
  les trois applications : la raison, rangée champ par champ, n'était pas lue.

### Ajouté à la supervision des commandes

- Filtre **par client** et **période choisie au calendrier** (borne haute
  comprise). Le serveur les acceptait depuis l'origine.

### Seconde vague — quatre exigences du cahier des charges

- **Notes internes**, sur la fiche d'une commande et sur celle d'un client
  (`/orders/manage/{id}/notes/`, `/administration/customers/{id}/notes/`).
  Jamais rendues au client ni au livreur ; elles ne se modifient ni ne
  s'effacent. Un test vérifie qu'aucune ne fuit dans la commande que lit le
  client.
- **Expiration des pièces livreur** : trois dates relevées à l'instruction du
  dossier, remises à nul quand le livreur redépose la pièce. On ne **valide**
  pas un dossier sur une pièce déjà expirée (409) ; un dossier validé dont une
  pièce expire ensuite **ne bascule pas seul** — L1 ne dépend que du dossier,
  et retirer quelqu'un du service à minuit en pleine tournée serait pire que
  le mal. Rappel quotidien au livreur et à l'équipe à J-30, J-7, J-1 et J0.
- **Bilan des campagnes** : taux d'ouverture, destinataires ayant commandé
  dans les 7 jours, chiffre associé par devise — cloisonné au périmètre de qui
  regarde. L'écran dit qu'il s'agit d'une corrélation, pas d'un effet prouvé.
- **Modération des avis** (Catalogue › Avis clients) : un avis se masque,
  motif exigé, sous `catalog.write` ; masqué, il sort de la vitrine **et de la
  note moyenne**, et le geste est au journal d'audit.

### Ce que ce chantier n'a pas fait

Vue Kanban des commandes, rapports PDF/Excel/planifiés, OTP du personnel,
programmation des campagnes, modération du social, formules d'abonnement,
images de catégorie et images multiples, contenus FAQ/CGV, éditeur de contour
de zone, filtre des commandes par livreur (il demanderait à `orders` de
connaître `delivery`, ce que l'ADR-002 interdit).

## 🌍 Le multi-cuisine, rendu utilisable (8 septembre 2026)

**Ouvrir une cuisine dans un nouveau pays est désormais une opération de
configuration.** L'architecture multi-pays existait entière côté serveur depuis
l'ADR-006 et le back-office savait provisionner depuis le 4 septembre ; ce lot
ferme les six écarts qui l'empêchaient encore de tenir sa promesse. Guide
d'exploitation : **[docs/ouvrir-une-cuisine.md](docs/ouvrir-une-cuisine.md)**.

### La fuite, d'abord

- **Les statistiques n'étaient cloisonnées nulle part.** Un gérant rattaché au
  seul établissement de Lomé, muni de `analytics.read`, lisait le chiffre
  d'affaires d'Abidjan, ses articles les plus vendus et la rémunération de ses
  livreurs. Le cloisonnement de l'ADR-005 s'appliquait partout — commandes,
  catalogue, personnel — sauf à l'endroit précis où la donnée est agrégée, donc
  la plus parlante. Rien ne le signalait : la réponse rendait des chiffres
  justes, simplement pas les siens. Les six rapports portent maintenant le
  périmètre du compte, et acceptent trois filtres qui **restreignent sans jamais
  élargir**.

### Ce qui manquait

- **Le client ne pouvait pas choisir sa cuisine.** `hasChoice` et `select()`
  existaient dans le service de contexte depuis l'origine et **aucun écran ne
  les appelait** : le multi-cuisine était complet côté serveur et invisible côté
  client. Un sélecteur — ville d'abord, cuisine ensuite — apparaît à partir de
  deux établissements, avec un tri « Autour de moi » facultatif. La position
  n'est pas réclamée au lancement : elle est demandée au moment où la réponse
  sert visiblement à quelque chose.
- **Le cloisonnement n'avait que deux étages** : le siège, ou un établissement.
  Un directeur pays devait être rattaché à chacun de ses restaurants un par un,
  et cessait **silencieusement** de voir le suivant qu'on ouvrait. Les paliers
  ville et marché s'ajoutent au point de passage unique du périmètre : les huit
  écrans qui le consultent en héritent d'un coup, et les alertes du personnel
  avec eux.
- **Aucune duplication d'établissement.** Recopier à la main une carte de
  quarante articles, leurs options et sept plages horaires, c'est une
  demi-journée et des oublis. Commandes, clients, livreurs et historiques n'ont
  **aucune section** — il n'existe pas de chemin de code pour les copier, ce qui
  est plus fort qu'une case décochée par défaut.
- **La fiche d'un établissement ne portait aucun compteur.** Commandes,
  livreurs, produits sont maintenant comptés par le serveur en une requête
  annotée. « 0 livreur » explique, avant même d'ouvrir la fiche, pourquoi elle
  ne peut pas être mise en service.
- **La liste des établissements n'avait ni recherche ni filtres.** Pays, ville,
  statut et recherche sur nom et adresse.
- **Dix fuseaux horaires étaient écrits en dur** dans le formulaire d'ouverture
  de marché, avec une liste de devises à côté. Ouvrir un onzième marché
  demandait de recompiler et de republier l'application — exactement l'opération
  de développement que le multi-pays existe pour supprimer. Les deux listes
  viennent maintenant de la source qui les fait respecter, et le fuseau se
  cherche au lieu de se dérouler.
- **Le cycle de vie d'un établissement n'émettait rien.** Suspendre une cuisine
  la faisait disparaître de l'application cliente à la seconde, et l'équipe
  l'apprenait en constatant que les commandes ne rentraient plus — puis
  cherchait la panne du côté du réseau. Une suspension est une décision, pas un
  incident.

### Hardcoding retiré

- **Dely imposait `+228`** à l'inscription livreur : le Togo, quel que soit le
  pays du restaurant visé. Un candidat d'Abidjan enregistrait un numéro togolais
  s'il ne pensait pas à effacer la proposition — et c'est ce numéro que la
  cuisine appelle pour lui confier une course. L'indicatif suit désormais
  l'établissement choisi.
- **Trois formateurs de `admin_helpers.dart`** codaient un marché en dur — devise
  `XOF` par défaut, symbole `CFA`, indicatif `+225` ajouté à tout numéro sans
  préfixe. Aucun écran ne les appelait, et leur règle existe en mieux dans le
  socle. Retirés plutôt que corrigés : `flutter analyze` ne signale pas une
  méthode publique inutilisée, et `tools/code_mort.py` raisonne par fichier — or
  ce fichier-là est bien atteint, pour une autre méthode.

### Ce que ce lot n'a pas fait

- Le **barème par paliers de distance** (0–3 km → 500, 3–6 km → 1 000) reste à
  faire : le barème actuel est affine — base plus prix au kilomètre, plafonné
  par une distance maximale — et il fonctionne. Des paliers seraient un second
  mode de calcul sur le même champ.
- L'**éditeur de contour sur carte** reste à faire : une zone se saisit par un
  centre et un rayon, que le contour réel remplacera sans migration.
- La **position d'une cuisine se saisit encore en latitude et longitude**, sans
  carte ni recherche d'adresse.

## 🔕 Les notifications qui ne partaient pas, et ce qu'a trouvé l'audit du 7 septembre

**Aucune notification push ne partait en production.** Le gabarit
`.env.prod.example` montait les identifiants Firebase — chemin du compte de
service, identifiant de projet, délai — et ne déclarait pas `PUSH_BACKEND`. Le
repli de `base.py` s'appliquait donc : `ConsolePushBackend`, qui journalise et
déclare **tous les jetons livrés**. Rien n'échouait, rien n'était retenté, aucune
métrique ne bougeait ; un déploiement paraissait configuré et n'envoyait rien.

Ce qui ne partait pas n'est pas accessoire : l'offre de course au livreur, que
l'ADR-008 double par push précisément parce qu'il ne regarde pas son écran en
roulant. Le même fichier prenait pourtant soin de forcer le connecteur de
paiement réel, avec son avertissement — c'était un oubli, pas une décision.
`prod.py` refuse maintenant de démarrer sur la console.

**Un livreur pouvait porter deux courses à la fois.** Seule l'unicité par
*commande* était gardée ; rien ne disait le cas inverse. `available_for`
proposait sans broncher quelqu'un déjà en route, et le back-office l'affichait
« Disponible » — `StatutLivreur` n'ayant aucun état « en livraison », ce que son
en-tête documentait. Or `Dely` n'émet ses relevés de position que pour **une**
course et ne guide que vers elle : le client de la seconde commande suivait un
livreur immobile. L'invariant L6 est désormais tenu à trois niveaux, et
`offered` en reste hors : plusieurs propositions n'occupent personne.

**Un réessai créait une seconde commande.** La clé d'idempotence était tirée à
chaque appel du dépôt, ce que le contrat du socle interdit en toutes lettres.
Elle ne valait donc rien le jour où elle sert — réponse perdue, écran qui
affiche « Réessayez une fois le réseau revenu », doublon facturé. Elle vit
maintenant dans l'écran de caisse, seul à savoir ce qu'est une tentative.

**Affecter un livreur marquait la commande « récupérée ».** Le repas était
encore en cuisine. La chronologie du suivi devenait fausse, la notification
partait, et la commande devenait **inannulable** — `picked_up` ne mène qu'à
`on_the_way`. Le vrai enlèvement, lui, ne produisait plus aucun événement : la
projection constatait la commande déjà arrivée et retournait en silence.

**« Livreur assigné » s'affichait même sur un refus.** Le booléen était jeté :
403 sans droit, 409 « commande déjà confiée », panne réseau — tout donnait le
même bandeau vert. Le superviseur croyait la course partie.

**Les gains du mois étaient tronqués sans le dire.** L'écran les additionnait
sur les soixante dernières courses chargées ; un livreur à dix courses par jour
n'en voyait que six jours. `GET /delivery/me/earnings/` agrège désormais en
base, bornes posées dans le fuseau de l'établissement.

**Trois écrans rendaient une panne comme une absence de données.** L'historique
du client annonçait « Aucune commande passée » sur une coupure réseau ; l'écran
Analyses du siège devenait blanc, sans message ni réessai. La règle existait
déjà pour le catalogue ; elle n'avait pas été portée.

**Le back-office ne vérifiait aucune permission.** `AdminAuthService.can(...)`
existait et n'avait aucun site d'appel : les dix-huit modules s'affichaient pour
tout compte du personnel, qui découvrait le refus à l'envoi d'un formulaire.

**Les portes de la CI étaient rouges, donc muettes.** `code_mort.py` accusait un
fichier vivant — il ne lisait que la première branche d'un export conditionnel,
et sa conclusion étant « les brancher, ou les supprimer », le suivre aurait
retiré le push web du client. Le job « Qualité » du serveur cumulait 6 erreurs
ruff, 22 fichiers non formatés et 6 erreurs mypy. Et `contrat_routes.py`, qui
annonce « c'est ce qui rend la CI rouge », ne tournait **nulle part** — la panne
qu'il devait attraper est celle qui a servi Render sans son préfixe `/api/v1`.

**Deux routes se publiaient sans corps de requête**, et la déclaration en a
révélé une troisième : `support` et `social` déclaraient chacun un
`AuthorSerializer`, tous deux nommés « Author » avec des champs différents.

Restent deux points, tenus à part : la migration inachevée du modèle `Order`
côté client (208 usages sur 18 fichiers, à faire par domaine), et les deux
dépôts git qui suivent tous deux `backend/` — la CI vit dans l'un, Render
déploie l'autre.

## 📣 La commande qui n'arrivait à personne (6 septembre 2026)

**Une commande passée n'était annoncée à personne.** C'est le premier maillon
de la chaîne, et il était rompu.

Le personnel n'était prévenu que sur des **transitions** de statut, et la seule
voie automatique vers « confirmée » est l'encaissement par webhook du
prestataire. Or le règlement **en espèces à la livraison** est aujourd'hui le
seul moyen de paiement actif dans l'application cliente — mobile money, carte
de crédit et carte de débit y sont explicitement désactivés. Aucun webhook ne
partait donc jamais : toute commande réellement passée naissait « en attente »
sans notification au personnel, et sans événement sur le tableau de bord temps
réel, qui ne diffusait que `order.status`. Le repas n'était préparé que si
quelqu'un rafraîchissait la liste et remarquait la ligne.

Un signal `order_created` a été ajouté, avec ses deux abonnés : la notification
au personnel de l'établissement, et un événement `order.created` sur le canal du
tableau de bord. Le back-office porte désormais un bandeau distinct — « une
nouvelle commande est arrivée » — séparé de celui des changements de statut :
les deux n'appellent pas le même geste. « Nouvelle commande » a changé de place
au passage ; c'est l'arrivée qui porte ce titre, la confirmation disant
maintenant « commande confirmée ».

## 🗂️ Ce que l'audit du 5 septembre a trouvé, et corrigé

**Deux tests du backend encodaient des règles opposées** sur la mise en ligne
d'un livreur : l'un exigeait un refus (409) sur un dossier non validé, l'autre
une acceptation (200). L'un ne passait que parce que l'autre échouait.
L'arbitrage retenu est la **déclaration** : `is_online` dit que le livreur
roule, ce que lui seul sait, et l'éligibilité reste `can_accept_orders`, relue
à chaque proposition de course et au tri des livreurs disponibles. Refuser
faisait **perdre** la disponibilité déclarée — un dossier validé laissait le
livreur hors ligne à son insu. Le tableau de bord comptait par ailleurs comme
« livreurs actifs » tous ceux qui s'étaient déclarés en ligne, dossier validé ou
non : il annonçait une capacité de livraison qui n'existait pas.

**Un oracle d'énumération de comptes** subsistait sur les routes d'envoi de
code. Le délai de réessai était tronqué (59 s) pour une adresse connue et rendu
en constante (60 s) pour une inconnue : une seconde d'écart suffisait à
distinguer les deux, c'est-à-dire à faire de ces routes l'annuaire d'abonnés que
tout le reste du module s'applique à ne pas être.

**Le service worker de push web de `Dely` visait un projet Firebase
inexistant** (`fastfoodgo-deliver`, clé factice), reste d'un gabarit resté en
place quand l'application cliente a été remise d'aplomb. Les jetons partaient
vers un projet inconnu, l'appareil web n'était jamais enregistré, et **aucune
offre de course n'arrivait** sur la version navigateur. Deux défauts du même
gabarit sont corrigés au passage : une version du SDK désaccordée de celle que
FlutterFire injecte dans la page, et un `showNotification` sans condition qui
aurait affiché deux bandeaux par offre. L'en-tête de `firebase_options.dart` de
`Dely`, qui annonçait encore des « valeurs de remplissage », disait le contraire
de la réalité.

**Le back-office ne pouvait rien écrire hors zone franc CFA.** Quatre services
composaient leurs montants avec `XOF` en dur, alors que le serveur refuse un
prix dont la devise n'est pas celle de l'établissement. L'écran « Réseau »
permet pourtant d'ouvrir un marché dans un autre pays. La conversion passait de
surcroît par un `round()`, juste pour une devise sans décimale seulement : en
cédi, un prix de 12,50 serait parti à treize centièmes. Devise et exposant
viennent désormais de l'établissement supervisé.

**Les articles retirés du catalogue étaient irrécupérables depuis le
back-office.** Le serveur archive au lieu d'effacer — les commandes passées
renvoient à l'article — et expose une action de restauration qu'aucun écran
n'appelait. La boîte de dialogue promettait par-dessus le marché une
« suppression », fausse dans les deux sens. Un onglet « Retirés » et une action
« Remettre au menu » ferment le cycle.

**Le consentement au marketing ne pouvait pas être retiré.** Le serveur le
respecte depuis l'origine — une campagne n'atteint pas un client qui l'a coupé —
mais aucune application ne l'affichait. Un écran « Préférences » a été ajouté au
profil client. Il n'expose que ce que le serveur applique : les notifications de
commande n'y figurent pas, elles ne se coupent pas.

**Dix-sept endroits mettaient une exception brute sous les yeux d'un
utilisateur** (« Erreur : DioException [connection error] »), alors que le
serveur écrit une phrase faite pour être lue. La règle de `Dely` est remontée
dans le socle partagé, et les trois applications s'y adossent.

**Deux simulations ont été retirées des parcours de production** : un service de
reconnaissance vocale qui tirait la phrase « entendue » dans une liste de cinq
écrite en dur, sans micro, sans dépendance et sans écran ; et une « localisation
en temps réel » du back-office qui posait les livreurs à des positions
inventées, sur un planisphère chargé depuis Wikimedia. La vraie carte existait
déjà à un clic de là.

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

## 🌍 Multi-établissement (4 septembre 2026)

**Ajouter un restaurant ne demande plus de toucher au code.** L'architecture
multi-pays existait entière côté serveur depuis l'ADR-006 (`Country → City →
DeliveryZone → Restaurant`) ; ce qui manquait, c'est ce qui la rendait
utilisable.

- **El Corazón Admin provisionne le réseau.** Un écran « Réseau » ouvre un
  marché, une ville, une zone de livraison et un établissement. Les routes
  existaient des deux côtés et aucune application ne les appelait : ouvrir une
  ville passait obligatoirement par `django-admin`.
- **Un établissement neuf n'est pas public.** Il naît en brouillon et suit un
  cycle de vie explicite — brouillon, en configuration, prêt, en service,
  suspendu. La mise en service est **refusée** tant qu'il manque des horaires,
  une carte, du personnel ou un livreur approuvé, et le refus dit lequel.
  Auparavant, une fiche à peine créée apparaissait dans l'application cliente,
  vide.
- **El Cora Fast lit l'établissement au lieu de le connaître.** Six constantes
  décrivaient le restaurant de Lomé — slug, position, ville, pays — et étaient
  lues à une trentaine d'endroits : catalogue, panier, commande, recherche,
  adresses, cartes. Elles ont été retirées ; le panier local est désormais
  discriminé par établissement, sans quoi changer de restaurant aurait ressorti
  les lignes de l'ancien sous le nouveau nom.
- **Un sélecteur d'établissement apparaît quand il y en a plusieurs.** Le
  périmètre était lu depuis longtemps mais aucun écran ne le montrait : un
  compte supervisant deux restaurants travaillait sur le premier par ordre
  alphabétique, sans le savoir.
- **Fermer un marché retire ce qu'il contient**, jusqu'aux établissements. La
  cascade s'arrêtait aux villes.
- **El Corazón Dely n'a rien demandé** : il choisissait déjà son établissement à
  l'inscription et lisait le point de retrait sur la commande.
- **Test GPS à distance** : une couche de simulation, active en mode debug
  seulement, rejoue une position ou un trajet. Le développement se fait à 600 km
  de l'établissement, ce qui rendait invérifiables la couverture d'une adresse,
  le franchissement d'une zone et l'arrivée d'un livreur.

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
- ❌ Chat avec le support — **introuvable dans Dely**. Seule une adresse
  `SUPPORT_EMAIL` existe (`config/api_config.dart`).
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
- ✅ Gestion du profil livreur — véhicule, plaque et numéros de pièces
  corrigeables par le livreur (`PATCH /delivery/me/`)
- ✅ **Dépôt** des pièces justificatives (`POST /delivery/me/`) — l'écran
  n'existait pas avant le 8 septembre 2026 : la route serveur n'avait aucun
  appelant, et le dossier d'un livreur ne pouvait jamais être complété. La
  **validation**, elle, est un geste du back-office.

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
- ❌ **Absente.** `apps.gamification` s'adresse aux **clients** ;
  `CourierProfile` ne porte que des compteurs (`deliveries_completed`,
  `rating_average`). Aucun point, aucun badge, aucun classement livreur au
  contrat — `driver_profile_screen.dart` le documente d'ailleurs en toutes
  lettres. Les quatre lignes « ✅ » qui figuraient ici étaient fausses.

#### 📱 Notifications
- ⚠️ Notifications Firebase — **câblées et configurées, mais rien ne partait
  en production**. Le projet `elcorazon-9595` est réel et validé côté serveur
  (`docs/firebase.md`, 5 août 2026) ; l'affirmation « identifiants factices »
  qui figurait ici était périmée. Le vrai défaut était ailleurs, et double :
  `PUSH_BACKEND` retombait sur la console, et **aucun worker Celery n'était
  déployé** pour consommer `send_push.delay()`. Les deux sont corrigés au
  9 septembre 2026 ; la mise en service reste à faire côté Render.
- ✅ Notifications locales
- ✅ Notifications de nouvelles commandes
- ✅ Notifications de statut

#### 🎤 Voix
- ❌ **Reconnaissance vocale — absente.** Aucun paquet de reconnaissance au
  `pubspec`, aucun code. Cette section annonçait « ✅ Reconnaissance vocale » et
  « ✅ Commandes vocales » : les deux étaient faux.
- ✅ Synthèse vocale du guidage (`flutter_tts`, `NavigationVoiceService`) — la
  seule chose qui existe, et elle parle, elle n'écoute pas.

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

### 📈 Taux de complétion

**Retiré.** Un pourcentage global ne se mesure pas, et celui-ci a longtemps
annoncé 90 % pendant qu'aucune notification ne partait en production. L'état
réel se lit fonctionnalité par fonctionnalité, ci-dessus — et une ligne « ✅ »
n'y vaut que si elle est vraie **du code déployé**, pas du code écrit.

---

## 💻 3. ADMIN (Panneau d'Administration)

### ✅ Fonctionnalités Complètement Implémentées

#### 🔐 Authentification & Rôles
- ✅ Connexion admin sécurisée
- ✅ Gestion des rôles (Super Admin, Manager, Opérateur)
- ✅ Système de permissions granulaire
- ✅ **Journal d'audit** — lisible depuis le 19 septembre 2026. L'entrée était
  cochée auparavant alors qu'aucune route ni aucun écran ne le lisait
- ✅ Comptes du personnel : création, rattachement, mot de passe (19 septembre)
- ✅ Gestion des sessions
- ❌ Vérification OTP du personnel — absente

#### 📊 Tableau de Bord
- ✅ Vue d'ensemble des métriques
- ✅ Statistiques en temps réel
- ✅ Graphiques de revenus (structure)
- ✅ Graphiques de commandes (structure)
- ⚠️ **TODO** : Compléter les graphiques fl_chart

#### 🛒 Gestion des Commandes
- ❌ **Vue Kanban — n'existe pas.** L'entrée était cochée ; aucun écran ne
  l'implémente (vérifié le 18 septembre 2026)
- ✅ Vue Liste des commandes
- ✅ Changement de statut
- ✅ Attribution de livreurs
- ✅ Gestion des remboursements — demande depuis la commande, constat dans
  « Remboursements » (19 septembre)
- ✅ **Notes internes** — depuis le 19 septembre 2026. L'entrée était cochée
  auparavant alors qu'elles n'existaient pas (`Order.notes` est la note du
  client)
- ✅ Filtres par client et par période choisie (19 septembre)
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

### 📈 Taux de Complétion

Le « ~97 % » affiché ici reposait sur des entrées fausses (Kanban, notes
internes, journal d'audit). Il est retiré plutôt que recalculé : voir la
section du 19 septembre 2026 pour ce qui reste à faire.

---

## 🔧 Configuration Requise pour Fonctionnement Complet

### 🚨 CRITIQUE (Application ne démarre pas sans)

1. **Backend Django démarré**
   - `cd backend && docker compose up` — PostgreSQL + PostGIS, Redis, l'API et
     les workers.
   - Sans lui, les trois applications démarrent mais n'affichent rien : elles
     n'ont plus aucune source de données locale.

2. **Fichiers `.env` des applications**
   - `apps/fastfood/.env`, `apps/dely/.env`, `apps/admin/.env`
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


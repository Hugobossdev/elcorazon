# Navigation GPS guidée — `apps/dely`

> Application du livreur. Ce document décrit ce qui existe, ce qui a été ajouté
> au lot « navigation », et **ce qui n'est pas vérifiable depuis un poste de
> développement**.

## 1. Le principe

Une livraison est un trajet en deux temps :

```
livreur ──▶ restaurant ──▶ client
        (1)            (2)
```

L'étape courante n'est **jamais choisie par le livreur**. Elle se déduit de la
course : `Course.repasRecupere` est vrai dès que le serveur a enregistré
`picked_up`, et la navigation bascule alors du point de retrait vers l'adresse
de livraison. Les deux points voyagent dans chaque affectation
(`pickup_location`, `delivery_location`, obligatoires côté serveur) — il n'y a
aucune coordonnée écrite en dur, aucun géocodage d'adresse, aucun repli sur
Lomé ou Abidjan.

## 2. Architecture

```
        ┌──────────────────────────────────────────────────────────┐
        │  RealtimeTrackingService   (LA source GPS, une seule)     │
        │  getPositionStream ─ ou le trajet simulé en debug         │
        └───────────┬──────────────────────────┬───────────────────┘
                    │ addListener              │ HTTP /tracking/pings
                    ▼                          ▼
        ┌────────────────────────┐      AppService ──▶ backend
        │  SourceDePosition      │      (invariant L3 : un relevé
        │  (vue en lecture)      │       appartient à une course)
        └───────────┬────────────┘
                    ▼
        ┌──────────────────────────────────────────────────────────┐
        │  NavigationService            (apps/dely)                 │
        │   assemble : positions + Directions + moteur + voix       │
        └───┬──────────────────┬──────────────────┬────────────────┘
            │                  │                  │
            ▼                  ▼                  ▼
   DirectionsService   MoteurDeNavigation   NavigationVoiceService
   → DirectionsRepo    (socle, pur Dart)    → flutter_tts
     (socle, Google)                          via MoteurVocal
```

### Ce qui vit dans le socle (`packages/elcorazon_core`)

| Fichier | Rôle |
|---|---|
| `navigation/geo_calcul.dart` | haversine, cap, écart de cap, projection sur segment |
| `navigation/suivi_de_trace.dart` | `TraceSuivie` — distances cumulées, position **le long** du tracé |
| `navigation/etat_navigation.dart` | `EtatNavigation`, `EtapeNavigation`, `ModeNavigation` |
| `navigation/phrases_navigation.dart` | toutes les phrases prononcées, fr + en |
| `navigation/moteur_de_navigation.dart` | paliers, anti-répétition, off-route, arrivée, ETA |
| `directions/route_step.dart` | `RouteStep`, `Manoeuvre`, nettoyage du HTML de Google |

Ils sont dans le socle parce qu'ils **ne dépendent d'aucune plateforme** : c'est
la seule condition pour que le guidage se vérifie sans appareil (§8).

### Ce qui vit dans l'application

| Fichier | Rôle |
|---|---|
| `services/navigation_service.dart` | l'orchestrateur |
| `services/navigation_voice_service.dart` | la voix, derrière `MoteurVocal` |
| `services/source_de_position.dart` | vue en lecture sur le suivi |
| `utils/position_simulee_geolocator.dart` | passerelle simulation ⇄ `Position` |
| `screens/delivery/real_time_tracking_screen.dart` | la carte |
| `screens/delivery/widgets/bandeau_instruction.dart` | l'instruction en gros |
| `screens/delivery/widgets/panneau_simulation.dart` | le pilotage debug |

## 3. Une seule source GPS

`NavigationService` **n'ouvre aucun capteur**. Il s'abonne à
`RealtimeTrackingService`, qui détient l'unique `getPositionStream` de
l'application, ouvert pour la durée d'une course.

C'est une contrainte, pas une commodité. Un audit précédent a supprimé un
second flux que l'écran de suivi ouvrait pour bouger un repère : deux flux haute
précision sur le même appareil, c'est deux fois le poste le plus lourd d'un
téléphone, et une carte qui peut afficher une position pendant que le vrai suivi
est en panne.

`SourceDePosition` nomme cette dépendance en lecture seule — elle n'expose aucun
moyen d'ouvrir ou de fermer un flux. La porte reste la course, tenue par
`AppService.suivreLaCourse`.

## 4. Itinéraire

`DirectionsRepository.getRoute(..., avecEtapes: true, langue: 'fr')` — Google
Directions. Les manœuvres (`legs[0].steps`) étaient **reçues et jetées** avant ce
lot ; c'est la raison pour laquelle aucune instruction n'était possible. Les
demander ne coûte pas de requête supplémentaire.

Le tracé suivi est celui des **étapes bout à bout**, pas `overview_polyline` :
ce dernier est une version simplifiée destinée à un aperçu, dont les sommets ne
coïncident pas avec les carrefours.

### Quand un itinéraire est demandé

| Événement | Recalcul |
|---|---|
| ouverture de l'écran | oui |
| démarrage de la navigation | oui |
| changement d'étape (restaurant → client) | oui |
| sortie d'itinéraire confirmée | oui (temps mort de 20 s) |
| bouton « recalculer » | oui |
| **chaque relevé de position** | **non** |

L'écran de suivi recalculait tous les 100 m / 30 s, soit une requête Google par
minute et par livreur pour un tracé qui ne change pas. La distance restante et
la durée se recalculent en local, le long du tracé déjà connu.

**Contrepartie assumée** : un embouteillage apparu après le calcul n'entre dans
l'heure d'arrivée qu'au recalcul suivant. Le bouton « recalculer » le force.

### Repli

Sans clé Google, ou sur une erreur (quota, réseau), un tracé en **ligne droite**
est affiché — en pointillés, atténué, avec un pictogramme d'avertissement, et
sans aucune manœuvre : le guidage se tait plutôt que d'inventer des virages sur
un trait qui traverse les pâtés de maisons. L'ancien écran dessinait ce repli
exactement comme un itinéraire.

## 5. Guidage vocal

`flutter_tts ^4.2.3` — seul paquet ajouté par ce lot, et seul TTS du projet (le
`VoiceService` de `apps/fastfood` est un `Future.delayed` sous un commentaire
« TTS simulation » ; il n'est pas touché ici).

### Paliers d'annonce

Réglés par `ReglagesNavigation`, valeurs par défaut :

| Distance avant la manœuvre | Ce qui est dit |
|---|---|
| 500 m | « Dans 500 mètres, tournez à droite. » |
| 200 m | « Dans 200 mètres, tournez à droite. » |
| 50 m | « Tournez à droite. » |

Deux règles encadrent ces paliers, et chacune corrige un défaut concret.

**Un palier n'est éligible que s'il tombe à l'intérieur de l'étape.** Sur une
étape de 80 m, « dans 500 mètres, tournez à droite » serait suivi de « tournez à
droite » quelques secondes plus tard : deux annonces pour un seul virage, dont
la première est fausse. Seule l'annonce immédiate est alors prononcée.

**Une annonce retient tous les paliers que la distance courante satisfait
déjà**, pas seulement celui qui a déclenché. Un livreur qui passe de 600 à
150 m entre deux relevés — ce que fait n'importe qui à cinquante à l'heure —
entendrait sinon « dans 150 mètres, tournez à droite » au titre du palier de
500, puis, deux secondes après, « dans 140 mètres, tournez à droite » au titre
du palier de 200. Le test
`moteur_de_navigation_test.dart › le palier sauté ne repart pas au relevé
suivant` garde cette règle.

### Ce qui garantit qu'on n'entend pas deux fois la même chose

* le moteur retient les paliers dits pour l'étape courante (`_paliersDits`) ;
* il les oublie au changement d'étape, de langue, ou d'itinéraire ;
* le service vocal refuse de rejouer la phrase qui sort du haut-parleur ;
* sa file ne contient qu'**une** phrase en attente — une instruction plus
  récente chasse celle qui attendait, parce qu'une consigne de navigation
  périme.

### Priorité audio

* **Android** : `setAudioAttributesForNavigation()` →
  `USAGE_ASSISTANCE_NAVIGATION_GUIDANCE`. La musique baisse, elle ne s'arrête
  pas, et l'annonce passe par-dessus un appel Bluetooth mains libres.
* **iOS** : catégorie `playback` (l'annonce passe même sur silencieux) +
  `duckOthers` + `mixWithOthers`, mode `voicePrompt`.

### Langues

`LangueNavigation` : `francais` (défaut), `anglais`. Une langue de plus est une
classe qui implémente `PhrasesNavigation`, et rien d'autre à toucher. Changer de
langue bascule les phrases **et** la voix, et redemande l'itinéraire — les noms
de rue viennent de Google, dans la langue de la requête.

## 6. Sortie d'itinéraire et recalcul

| Réglage | Défaut | Pourquoi |
|---|---|---|
| `seuilSortieMetres` | 60 | en ville dense, un relevé dérive de 30 m ; une contre-allée n'est pas une sortie |
| `relevesHorsTraceAvantRecalcul` | 3 | un relevé aberrant ne doit pas coûter une requête |
| `delaiEntreRecalculs` | 20 s | empêche la boucle sur un livreur arrêté à côté du tracé |
| `precisionMaximaleMetres` | 75 | au-delà, le relevé affiche un repère mais ne décide plus de rien |

L'annonce « vous avez quitté l'itinéraire » n'est faite **qu'une fois** par
sortie. Revenu sur le tracé sans qu'un recalcul ait abouti, le guidage reprend
de lui-même.

## 7. Arrivée — et ce qu'elle ne fait pas

`rayonArriveeMetres` = 60. Deux mesures, la plus petite l'emporte : le long du
tracé, et à vol d'oiseau (le livreur qui coupe par le parking est arrivé sans
avoir fini le tracé).

> **Une arrivée détectée met le bouton d'avancement en avant. Elle ne l'appuie
> pas.**

Le GPS ne prouve ni qu'un sac a changé de mains, ni qu'un client a payé, et il
se falsifie. Le parcours métier est inchangé : l'unique bouton vient de
`allowed_transitions` (serveur), et la confirmation de livraison reste une boîte
de dialogue explicite. Le test
`navigation_service_test.dart › arriver ne fait pas avancer la course` en est le
garde-fou.

## 8. Mode GPS simulé (DEBUG)

Le développement se fait depuis Abidjan ; l'établissement est à Lomé, à 600 km.

**Ce n'est pas une démonstration.** Le panneau pose un trajet dans
`PositionSimulee`, et ce trajet ressort par le **même** flux que le capteur
(`fluxDePositions`), consommé par le **même** `RealtimeTrackingService`, poussé
dans le **même** `MoteurDeNavigation`, prononcé par le **même** moteur de
synthèse. La voix entendue en simulation est celle qu'entendra le livreur.

### Utilisation

1. Ouvrir une course, attendre le calcul de l'itinéraire.
2. Déplier « Trajet simulé (debug) » en haut de l'écran.
3. Régler la vitesse, puis :

| Bouton | Effet |
|---|---|
| **Départ** | rejoue l'itinéraire calculé, point par point, à la vitesse choisie |
| **Pause** / **Reprise** | suspend le temps sans perdre la place |
| **Reprise à zéro** | ramène au premier point, sans relancer |
| **Détour** | écarte la seconde moitié du trajet de 200 m — **le seul moyen d'exercer la sortie d'itinéraire**, puisqu'un trajet rejoué tel quel ne quitte jamais son propre tracé |
| **Capteur réel** | rend la main au GPS |

### Deux pièges

* `fluxDePositions` choisit sa source **à l'abonnement**. Allumer la simulation
  alors que le flux du capteur est déjà ouvert ne change rien — c'est pourquoi
  chaque bouton appelle `RealtimeTrackingService.relancerLeFluxDePosition()`.
* Le point bleu du système est éteint sur la carte : il afficherait la position
  **réelle** du développeur pendant qu'on rejoue un trajet à Lomé. Le repère
  affiché est le nôtre.

### Ce qui est garanti hors debug

`PositionSimulee.estActive` est constant à `false` hors `kDebugMode` : le
compilateur élimine les branches de simulation du binaire. Le panneau rend
lui-même un widget vide en release. Aucun chemin ne mène d'une position inventée
à un client.

Les positions simulées portent un **cap et une vitesse calculés** à partir des
points successifs, et non zéro : c'est ce qui permet de vérifier l'orientation
du repère, la rotation de la carte et le lissage du cap à l'arrêt sans être sur
la route.

## 9. Caméra

| Mode | Comportement |
|---|---|
| Aperçu | cadre l'itinéraire entier |
| Navigation | suit le livreur, zoom 17.5, `tilt` 45°, `bearing` = cap |

Un **geste manuel libère la caméra** et rien ne la ramène de force — le livreur
regarde peut-être la suite de son trajet. Le bouton « recentrer » apparaît alors.

`onCameraMoveStarted` se déclenche aussi bien pour un geste que pour nos propres
animations, et rien dans l'API ne les distingue : un drapeau `_cameraPilotee` le
fait, avec 350 ms de grâce. Sans lui, chaque recentrage automatique se prendrait
pour un geste et couperait le suivi qu'il vient d'appliquer.

Le repère du livreur est **plat** (`flat: true`) : posé sur la carte, il tourne
avec elle. Un repère dressé resterait vertical pendant que la carte pivote.

## 10. ETA

Une **heure d'arrivée ancrée**, pas une durée recalculée. Une durée qui change
toutes les deux secondes se relit sans arrêt et n'apprend rien.

L'heure n'est réancrée que si l'estimation s'écarte de 60 s, ou au bout de 60 s.
La durée restante s'en déduit en décomptant, elle décroît donc régulièrement.

L'estimation vient des durées d'étape de Google, au prorata de ce qui reste de
l'étape en cours. Sans manœuvres, elle retombe sur
`vitesseDeReferenceKmH` (30 km/h).

## 11. Permissions

### Android (`AndroidManifest.xml`) — inchangé par ce lot

`INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_COARSE_LOCATION`,
`ACCESS_FINE_LOCATION`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`,
`WAKE_LOCK`, `POST_NOTIFICATIONS`, plus les `<queries>` https / geo / tel.

`ACCESS_BACKGROUND_LOCATION` n'y figure **volontairement pas** : le service de
premier plan visible suffit, et cette permission demande une justification
séparée au Play Store.

**La synthèse vocale ne demande aucune permission.** `flutter_tts` s'appuie sur
le moteur du système ; aucune ligne à ajouter au manifeste.

### iOS (`Info.plist`) — inchangé par ce lot

Les trois clés de localisation, `UIBackgroundModes: location,
remote-notification`. Aucune clé audio n'est requise pour la synthèse : la
catégorie est fixée à l'exécution par `setIosAudioCategory`.

## 12. Arrière-plan — limites réelles

| | État |
|---|---|
| **Suivi de position en arrière-plan** | fonctionne : `AndroidSettings.foregroundNotificationConfig` (service de premier plan + wake lock) et `AppleSettings(activityType: automotiveNavigation, showBackgroundLocationIndicator: true)` |
| **Guidage vocal écran verrouillé** | **non vérifié sur appareil.** Android devrait continuer (le processus reste vivant sous le service de premier plan) ; iOS coupe la synthèse quand l'application est suspendue, sauf configuration audio d'arrière-plan que ce lot n'a **pas** mise en place |
| **Carte en arrière-plan** | non — `GoogleMap` est détruit, c'est normal et sans conséquence |

Ce tableau dit ce qui est **su**, pas ce qui est espéré. Le premier point est
adossé à du code déclaré et relu ; le second demande un appareil.

## 13. Tests

```bash
cd packages/elcorazon_core && flutter test    # 405 tests
cd apps/dely             && flutter test      # 147 tests
```

| Fichier | Ce qu'il couvre |
|---|---|
| `core/test/geo_calcul_test.dart` | distances, caps, projection, correction de longitude |
| `core/test/route_step_test.dart` | nettoyage HTML, manœuvres, lecture d'une étape |
| `core/test/moteur_de_navigation_test.dart` | paliers, anti-répétition, off-route + temps mort, arrivée, ETA stable, changement d'étape, langue, aperçu muet |
| `dely/test/navigation_voice_service_test.dart` | prononciation, file, priorité, pause, langue, moteur absent |
| `dely/test/navigation_service_test.dart` | le parcours complet, de la course acceptée à la fermeture |
| `dely/test/porte_du_suivi_test.dart` | (préexistant) le suivi reste adossé à la course |

Le scénario de bout en bout vit dans `navigation_service_test.dart` : course
acceptée → guidage vers le restaurant → instructions → arrivée → commande
récupérée → bascule vers le client → sortie d'itinéraire → recalcul → arrivée →
fin de course → ressources rendues.

## 14. Ce qui n'est pas vérifiable ici

* la **qualité de la voix** et le comportement du ducking sur un appareil réel ;
* le comportement de la synthèse **écran verrouillé** sur iOS (§12) ;
* la **justesse des instructions de Google** à Lomé — la couverture de
  Directions y est réelle mais moins dense qu'en Europe ; les rues sans nom
  produisent des instructions plus pauvres ;
* la consommation batterie réelle sur une tournée complète.

## 15. Réglages

`ReglagesNavigation` (socle) porte tous les seuils du guidage ; ils sont
actuellement passés par défaut. `TrackingSettings` (déjà existant) porte la
cadence d'émission et se lit depuis le `.env` :

```
TRACKING_INTERVAL_SECONDS=10
TRACKING_MINIMUM_DISTANCE_METERS=25
TRACKING_HEARTBEAT_SECONDS=30
TRACKING_RETRY_SECONDS=30
TRACKING_ACCURACY=haute
GOOGLE_MAPS_API_KEY=...
```

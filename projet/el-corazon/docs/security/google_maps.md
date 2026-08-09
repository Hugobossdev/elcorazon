# Clés Google Maps — restrictions et quotas

**Statut** : à exécuter dans la console Google Cloud · **Origine** : constat S-3
de l'audit du 2 août 2026

---

## 1. Le constat

Une **seule et même clé** est utilisée par les trois applications, sur toutes
les plateformes, et elle est en clair dans le dépôt :

| Fichier | Plateforme |
| --- | --- |
| `apps/fastfood/android/app/src/main/AndroidManifest.xml` | Android |
| `apps/fastfood/web/index.html` | Web |
| `apps/dely/android/app/src/main/AndroidManifest.xml` | Android |
| `apps/dely/ios/Runner/AppDelegate.swift` | iOS |
| `apps/dely/web/index.html` | Web |
| `apps/dely/lib/config/api_config.dart` | toutes |
| `apps/admin/web/index.html` | Web |
| `apps/fastfood/SETUP.md` | documentation |

Une clé Maps côté client **est** publique : elle part dans l'APK, dans l'IPA et
dans le HTML servi au navigateur. La cacher est impossible et ce n'est pas
l'objectif. Ce qui la protège, c'est la **restriction** : la clé ne doit
fonctionner que depuis vos applications, et dans des volumes plafonnés.

Sans restriction, un tiers qui la relève dans le HTML l'utilise à votre
facturation. Google Maps Platform facture à l'appel, sans plafond par défaut.

---

## 2. Pourquoi une seule clé ne peut pas suffire

Google n'accepte **qu'un seul type de restriction d'application par clé**. Une
clé restreinte aux référents HTTP cesse de fonctionner sur Android ; une clé
restreinte à une empreinte Android cesse de fonctionner sur le web.

La clé actuelle sert quatre contextes à la fois. Elle ne peut donc porter
aucune restriction d'application sans casser trois d'entre eux — ce qui
explique probablement pourquoi elle n'en a aucune.

**Il faut quatre clés**, une par contexte :

| Clé | Contexte | Restriction d'application |
| --- | --- | --- |
| `MAPS_ANDROID_FASTFOOD` | client Android | Nom de package + empreinte SHA-1 |
| `MAPS_ANDROID_DELY` | livreur Android | Nom de package + empreinte SHA-1 |
| `MAPS_IOS` | livreur iOS | Identifiant de bundle |
| `MAPS_WEB` | web des trois apps | Référents HTTP |

---

## 3. Restrictions à appliquer

Console → **API et services** → *Identifiants* → chaque clé.

### 3.1 Android

*Restrictions relatives aux applications* → **Applications Android**.

Ajouter une entrée par variante de signature — la version de développement et
la version publiée n'ont pas la même empreinte :

```
Nom du package    : com.elcorazon.fastfood        (ou .dely)
Empreinte SHA-1   : <empreinte de la clé de signature>
```

Obtenir les empreintes :

```bash
# Clé de débogage (poste de développement)
keytool -list -v -keystore ~/.android/debug.keystore \
        -alias androiddebugkey -storepass android -keypass android

# Clé de publication
keytool -list -v -keystore <chemin/vers/release.keystore> -alias <alias>
```

> Si l'application est distribuée par Google Play avec la signature gérée par
> Play, c'est l'empreinte **de Play** qu'il faut déclarer, pas celle de votre
> keystore de téléversement. Elle se trouve dans la console Play →
> *Configuration* → *Intégrité de l'application*.

### 3.2 iOS

*Restrictions relatives aux applications* → **Applications iOS**.

```
Identifiant de bundle : com.elcorazon.dely
```

### 3.3 Web

*Restrictions relatives aux applications* → **Sites Web**.

```
https://elcorazon.example/*
https://admin.elcorazon.example/*
http://localhost:*/*          ← développement uniquement, à retirer en production
```

Le joker de fin est nécessaire : Google compare le référent complet.

### 3.4 Restrictions d'API — pour les quatre clés

*Restrictions relatives aux API* → **Restreindre la clé**, et ne cocher que ce
que l'application appelle réellement :

| API | Utilisée par |
| --- | --- |
| Maps SDK for Android | `fastfood`, `dely` |
| Maps SDK for iOS | `dely` |
| Maps JavaScript API | web des trois apps |
| Geocoding API | `fastfood` (`geocoding_service.dart`) |
| Directions API | `fastfood` (`directions_service.dart`) |
| Places API | `fastfood` (`places_service.dart`) |

Toute API non cochée devient inutilisable avec cette clé — c'est l'objectif.

---

## 4. Quotas

Console → **API et services** → *Quotas*, par API.

Une clé restreinte reste utilisable **depuis votre propre application** de
manière abusive (application décompilée et rejouée). Le quota est le second
filet, et le seul qui borne la facture.

Valeurs de départ suggérées, à ajuster après une semaine d'observation :

| API | Requêtes / jour | Requêtes / minute |
| --- | --- | --- |
| Maps JavaScript | 25 000 | 500 |
| Geocoding | 5 000 | 100 |
| Directions | 5 000 | 100 |
| Places | 2 000 | 50 |

Configurer en parallèle une **alerte de facturation** (Facturation → *Budgets et
alertes*) à un seuil qui vous ferait réagir en 24 h. Le quota empêche la fuite
de s'aggraver ; l'alerte vous prévient qu'elle a commencé.

---

## 5. Bascule

L'opération casse les cartes si elle est faite dans le désordre. L'ordre sûr :

1. créer les quatre nouvelles clés **sans restriction**, vérifier que les
   applications fonctionnent avec ;
2. appliquer les restrictions d'application et d'API sur chaque clé ;
3. vérifier chaque plateforme, une par une — une restriction mal saisie se voit
   par une carte grise et un `RefererNotAllowedMapError` en console ;
4. régler les quotas ;
5. **supprimer l'ancienne clé partagée** dans la console.

L'étape 5 est celle qui compte. Tant que l'ancienne clé existe, les copies
relevées dans les binaires publiés restent utilisables.

---

## 6. Où les clés se déclarent dans le dépôt

Les clés restent nécessairement dans les fichiers de plateforme — c'est ainsi
que les SDK les lisent. Ce n'est pas une fuite dès lors qu'elles sont
restreintes.

| Fichier | À renseigner |
| --- | --- |
| `<app>/android/app/src/main/AndroidManifest.xml` | clé Android de l'app |
| `apps/dely/ios/Runner/AppDelegate.swift` | clé iOS |
| `<app>/web/index.html` | clé web |
| `<app>/.env` → `GOOGLE_MAPS_API_KEY` | clé web ou Android selon la cible construite |

**Exception à corriger** : `apps/dely/lib/config/api_config.dart:7` porte
la clé **en dur dans le code Dart** au lieu de la lire depuis `.env`, contrairement
aux deux autres applications. À aligner sur `dotenv.env['GOOGLE_MAPS_API_KEY']`.

---

## 7. Vérification

Après bascule, la clé publiée ne doit plus fonctionner hors de vos
applications :

```bash
# Doit répondre REQUEST_DENIED avec « API keys with referer restrictions… »
curl "https://maps.googleapis.com/maps/api/geocode/json?address=Lome&key=<CLE_WEB>"
```

Un `OK` ici signifie que la restriction n'est pas appliquée.

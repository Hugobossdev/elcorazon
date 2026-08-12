# El Corazón — application livreur

Ce que voit un livreur en tournée : les courses qu'on lui propose, celle qu'il
porte, sa position transmise au client, ses gains.

Elle ne parle qu'à l'API Django (`backend/`). Le contenu de ce fichier
remplace le gabarit Flutter d'origine, qui n'avait jamais été rempli.

## Démarrer

```bash
cd backend && docker compose up      # l'API, depuis la racine du dépôt
cd apps/dely && flutter run
```

Un `.env` est attendu à la racine de l'application :

```env
API_BASE_URL=http://10.0.2.2:8000/api/v1   # 10.0.2.2 = hôte, vu de l'émulateur Android
GOOGLE_MAPS_API_KEY=       # clé cliente, à restreindre dans la console Google
AGORA_APP_ID=              # identifiant public ; le certificat reste au backend
ENVIRONMENT=development
```

Aucun secret de prestataire ici. Une clé placée dans le `.env` d'une
application est une clé dans le binaire distribué.

## Structure

```
lib/
├── config/           api_config.dart — lecture du .env
├── l10n/             traductions
├── presentation/     libelles_course.dart — vocabulaire d'affichage
├── repositories/     django_delivery_repository.dart
├── screens/          13 écrans
├── services/         10 services
└── utils/  widgets/  theme.dart
```

Les entités viennent de `packages/elcorazon_core`. `libelles_course.dart` pose
par-dessus les mots de l'écran livreur : c'est bien l'étape de la **course**
qu'il nomme, pas le statut de la commande — côté livreur, ce sont ses propres
gestes qui pilotent l'écran.

## Rien à migrer ici

Cette application n'a plus de modèle local ni d'adaptateur traducteur : le
lot 3 est terminé pour elle. `django_delivery_repository.dart` subsiste, mais
il ne traduit plus rien — il compose les courses à partir de l'`Assignment` et
de l'`Order` du socle, ce que le socle ne fait pas à sa place.

Voir [docs/refactoring-2026-08.md](../../docs/refactoring-2026-08.md), lot 3.

## Vérifier

```bash
flutter analyze          # doit être vide
flutter test
flutter build apk --debug
```

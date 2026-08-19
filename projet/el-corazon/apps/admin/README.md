# El Corazón — back-office

Application de supervision : commandes en cours, catalogue, flotte de livreurs,
clients, statistiques.

Elle ne parle qu'à l'API Django (`backend/`) et ne détient aucun secret de
prestataire. Ce qu'elle affiche vient du serveur ; ce qu'elle décide se limite à
ce que le serveur l'autorise à faire.

## Démarrer

```bash
cd backend && docker compose up      # l'API, depuis la racine du dépôt
cd apps/admin && flutter run -d chrome
```

Un `.env` est attendu à la racine de l'application. Deux valeurs seulement, et
aucune n'est un secret :

```env
API_BASE_URL=http://localhost:8000/api/v1
GOOGLE_MAPS_API_KEY=       # clé cliente, à restreindre dans la console Google
```

Les clés marchandes PayDunya et le certificat Agora se configurent **côté
backend**. Une clé placée dans le `.env` d'une application est une clé dans le
binaire distribué.

## Structure

```
lib/
├── presentation/     vocabulaire d'affichage et vues nommées (20 fichiers)
├── screens/          37 écrans, dont 33 sous admin/
├── services/         20 services, tous ChangeNotifier
├── ui/               jetons de couleur (AdminColorTokens)
├── dialogs/  theme/  utils/  widgets/  core/
```

Il n'y a **pas** de `lib/models/` : les entités viennent de
`packages/elcorazon_core`, qui reflète les sérialiseurs du backend. Le dernier
modèle local a été retiré au lot 3 du refactoring.

Il n'y a **pas** non plus de slug d'établissement écrit dans le code.
`RestaurantScopeService` lit `/restaurants/manage/`, que le serveur restreint
au périmètre du compte connecté. Les lectures n'en ont pas besoin — les routes
d'exploitation cloisonnent déjà — et les écritures y prennent l'établissement à
qui rattacher ce qu'elles créent.

📖 [docs/architecture.md](docs/architecture.md) — structure détaillée, principes
et ce que l'ancienne documentation promettait à tort.

## Permissions

Elles viennent du serveur (`User.permissions`, ADR-005) sous forme de liste de
chaînes, et `AdminAuthService.can()` les interroge. L'application n'en déduit
aucune : un écran caché n'est pas un écran protégé, c'est le backend qui refuse.

## Vérifier

```bash
flutter analyze          # doit être vide
flutter test             # 13 fichiers de tests
flutter build web
```

Deux garde-fous tournent aussi en intégration continue, depuis la racine du
dépôt :

```bash
python tools/code_mort.py       # aucun fichier injoignable
python tools/couverture.py      # plancher de couverture par paquet
```

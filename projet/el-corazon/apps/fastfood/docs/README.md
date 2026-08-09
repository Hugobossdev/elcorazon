# Notes techniques de l'application client

Ces huit documents vivaient dans `lib/services/`, au milieu du code. Le lot 6 du
refactoring les en sort : un répertoire de sources ne porte pas de prose.

Ils n'ont pas été réécrits. Ce sont des notes d'implémentation datées, écrites
avant la migration vers le backend Django (1er août 2026), et leur valeur est
celle d'un témoignage : ils disent pourquoi telle mécanique a été mise en place.
Ce qu'ils décrivent n'existe pas toujours encore.

## Ce qui tient encore

| Document | Sujet | État |
|---|---|---|
| [README_CACHE.md](README_CACHE.md) | `MenuItemCacheService` | la classe existe |
| [README_ERROR_HANDLING.md](README_ERROR_HANDLING.md) | `error_handler_service.dart` | le service existe |
| [README_LAZY_SERVICES.md](README_LAZY_SERVICES.md) | les fournisseurs `lazy: true` de `main.dart` | 19 y sont encore déclarés |

## Ce qui décrit du code disparu

| Document | Ce qu'il décrit | Ce qui reste |
|---|---|---|
| [README_OFFLINE_MODE.md](README_OFFLINE_MODE.md) | `connectivity_service.dart` | **le fichier n'existe plus** ; `offline_sync_service.dart` subsiste |
| [README_OPTIMIZED_QUERIES.md](README_OPTIMIZED_QUERIES.md) | `PaginatedMenuScreen` | **la classe n'existe plus** ; la pagination est côté serveur |
| [README_ORDER_HISTORY.md](README_ORDER_HISTORY.md) | l'historique de commandes sous Supabase | porte déjà son propre avertissement |
| [README_REPOSITORY_PATTERN.md](README_REPOSITORY_PATTERN.md) | le patron de dépôt local | porte déjà son propre avertissement |
| [README_SECURITY_VALIDATION.md](README_SECURITY_VALIDATION.md) | la validation côté client | porte déjà son propre avertissement |

## Deux notes d'architecture retirée

Elles décrivaient des mécaniques bâties sur Supabase, retiré le 1er août 2026.
Aucun document ne les référence ; elles sont conservées pour la même raison que
les précédentes — elles disent pourquoi les choses avaient été faites ainsi.

| Document | Ce qu'il décrit | Ce qui l'a remplacé |
|---|---|---|
| [NOTIFICATIONS_PUSH_REALTIME.md](NOTIFICATIONS_PUSH_REALTIME.md) | notifications via Supabase Realtime | WebSocket Django Channels + FCM ; l'historique vient de `/notifications/` |
| [APPELS_AGORA.md](APPELS_AGORA.md) | appels Agora synchronisés par Supabase | jetons d'appel signés côté serveur, canal `ws/calls/` |

La référence à jour reste
[docs/architecture/04-migration-flutter.md](../../docs/architecture/04-migration-flutter.md),
qui trace domaine par domaine ce qui a été migré, construit ou supprimé.

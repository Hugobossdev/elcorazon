/// Bibliothèque de composants du design system « El Corazón Mobile ».
///
/// Ce que contient ce dossier, et ce qu'il ne contient pas
/// ------------------------------------------------------
///
/// **Contient** : les briques visuelles décrites par `DESIGN.md` — barres
/// translucides, cartes, puces, sélecteur de quantité, silhouettes de
/// chargement. Aucune ne connaît ni service, ni dépôt, ni route : elles
/// reçoivent des données et rendent des rappels. C'est ce qui permet de les
/// éprouver seules, et de les réutiliser d'un écran à l'autre sans traîner de
/// dépendance.
///
/// **Ne contient pas** : les composants déjà en place et toujours justes —
/// `MenuItemCard`, `CartItemCard`, `LoadingWidget`, `ErrorWidget`,
/// `EmptyStateWidget`. Ils ont été re-habillés sur place plutôt que doublés :
/// un second `EmptyStateWidget` aurait divergé du premier au premier
/// correctif.
///
/// L'import groupé évite quinze lignes d'`import` en tête de chaque écran.
library;

export 'action_button.dart';
export 'food_card.dart';
export 'food_image.dart';
export 'glass_surface.dart';
export 'option_tile.dart';
export 'promo_banner.dart';
export 'rating_input.dart';
export 'search_field.dart';
export 'segmented_tabs.dart';
export 'section_card.dart';
export 'skeleton.dart';
export 'summary_row.dart';
export 'quantity_stepper.dart';

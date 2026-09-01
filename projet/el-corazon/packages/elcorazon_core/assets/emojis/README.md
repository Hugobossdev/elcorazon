# Pack emojis El Corazón

Ce dossier porte les **30 assets illustrés** du design system. Il est vide tant
que les illustrations n'ont pas été produites : `AppEmoji` se replie alors sur
l'icône portée par chaque token (`lib/src/design/emojis/app_emojis.dart`), et
rien ne casse.

## Un seul exemplaire pour les trois applications

Le pack vit dans le **socle partagé**, et non dans chaque application. Les
trente illustrations n'existent donc qu'une fois : le client, le livreur et le
back-office montrent la même image pour la même étape, ce que trois jeux tenus
séparément ne garantissaient pas.

Un asset déclaré par un paquet est embarqué d'office par toute application qui
en dépend : déposer un fichier au bon chemin suffit à l'activer dans les trois,
sans toucher au `pubspec` d'aucune ni à une ligne de code. Les chemins portent
le préfixe `packages/elcorazon_core/` dans le manifeste — `AppEmojis` s'en
charge.

Ce `README.md` n'est pas embarqué : seuls les sous-dossiers `food/`, `order/`,
`delivery/` et `ux/` sont déclarés.

## Les 30 chemins attendus

    food/burger.svg          order/cart.svg              delivery/courier.svg
    food/pizza.svg           order/new_order.svg         delivery/scooter.svg
    food/donut.svg           order/order_confirmed.svg   delivery/location.svg
    food/cake.svg            order/preparing.svg         delivery/delivery.svg
    food/ice_cream.svg       order/order_ready.svg       delivery/delivered.svg
    food/samosa.svg          order/order_completed.svg
    food/pastel.svg                                      ux/heart.svg
    food/chicken.svg                                     ux/favorite.svg
    food/fries.svg                                       ux/success.svg
    food/drink.svg                                       ux/error.svg
                                                         ux/warning.svg
                                                         ux/gift.svg
                                                         ux/promotion.svg
                                                         ux/star.svg
                                                         ux/celebration.svg

Le nom de fichier fait foi : il est la clé du registre. Ne pas renommer sans
mettre `AppEmojis` à jour.

## Format

* SVG, carré, `viewBox` 1:1 (référence 1024 × 1024).
* Fond **transparent**. Pas de cadre, pas de watermark, pas de texte.
* Sujet unique, centré, silhouette nette.
* Raster accepté en repli : WebP ou PNG, 1024 × 1024, transparent. Jamais de
  JPEG. Un chemin raster suppose d'adapter `AppEmoji` — voir son en-tête.

## Direction artistique

Illustration 3D premium, moderne, chaleureuse, élégante, polie. Formes
arrondies, matériaux doux et légèrement brillants, ombrage réaliste subtil,
lumière de studio douce. Appétissant et amical, un peu joueur sans être
enfantin. **Même angle de caméra, même éclairage, mêmes proportions sur les
trente**.

## Couleurs

Palette El Corazón : rouge de marque `#B51822`, blanc, tons crème, tons
alimentaires naturels, accents dorés/orangés (`#E4C44D`) au besoin.

Le rouge est un **accent de marque**, pas la couleur dominante de chaque objet.

## Prompt maître de génération

    Create a premium 3D illustrated emoji asset for the El Corazón food
    delivery application.

    Modern premium food-delivery brand aesthetic.
    Warm, elegant, polished and sophisticated.
    Rounded shapes.
    Soft glossy materials.
    Subtle realistic shading.
    Soft studio lighting.
    High-quality 3D illustration.
    Slightly playful but not childish.
    Appetizing and friendly.
    Consistent visual language across the entire El Corazón emoji collection.
    Centered single subject.
    Isolated object.
    Transparent background.
    Square composition.
    No text. No letters. No numbers.
    No watermark. No logo. No border.
    No plate unless specifically requested.
    No unnecessary objects. No background scenery.
    Clean silhouette.
    Professional mobile UI asset.
    Consistent camera angle. Consistent lighting. Consistent proportions.

## Negative prompt

    text, letters, numbers, watermark, logo, brand name, background, scenery,
    photorealistic photography, flat emoji, cheap cartoon, childish style,
    sticker border, excessive shadows, excessive reflections, low resolution,
    noise, blurry details, cropped object, deformed object, multiple subjects,
    inconsistent style, different camera angle, different lighting,
    random colors

## Relecture

`EmojiGalleryScreen` (`apps/fastfood/lib/screens/dev/emoji_gallery_screen.dart`)
affiche les trente sur fond clair et sur fond sombre, à trois tailles. C'est là
que la cohérence du pack se juge. L'écran n'est bâti qu'en `debug`, et aucune
route n'y mène.

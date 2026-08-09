# Architecture du back-office

> Voir aussi [ADMIN_ROLE_FIX.md](ADMIN_ROLE_FIX.md), déplacé ici depuis la
> racine de l'application : 217 lignes décrivant la correction d'un bug de
> lecture des permissions dans une classe `AdminRole` **qui n'existe plus**.
> Les permissions viennent aujourd'hui du serveur en `List<String>` (ADR-005),
> et `AdminAuthService.can()` les interroge. Le document est conservé comme
> témoignage, il ne décrit plus rien de vivant.

Ce document vivait dans `lib/core/architecture/README.md` — un répertoire de
sources qui ne contenait que lui. Le lot 6 du refactoring l'en sort.

Il a été **corrigé en le déplaçant**, parce qu'il ne datait pas : il égarait. Il
prescrivait trois classes qui n'existent pas — `AdminInteractiveWidget`,
`AdminSafeCard`, `AdminRouter` — et dessinait une arborescence de sept
sous-répertoires d'écrans dont un seul existe. Ce qui suit est vérifié contre le
code du 9 août 2026.

## Structure réelle

```
lib/
├── core/
│   ├── constants/
│   └── utils/
├── dialogs/
├── presentation/           # Vocabulaire d'affichage et vues nommées (lot 4)
│   ├── cartes/
│   ├── dialogues/
│   └── onglets/
├── screens/
│   ├── admin/              # 33 écrans, à plat
│   │   └── gamification/   # seul regroupement, issu du lot 4
│   └── auth/
├── services/               # 19 services, tous ChangeNotifier
├── theme/
├── ui/                     # jetons de couleur (AdminColorTokens)
├── utils/
└── widgets/
```

Il n'y a **pas** de `lib/models/` : le dernier modèle local a été retiré au
lot 3, les écrans lisent les entités de `packages/elcorazon_core`.

## Principes qui tiennent

**État.** Provider, sans exception : les 19 services étendent `ChangeNotifier`,
18 écrans les lisent par `Consumer`. Le socle expose par ailleurs des
fournisseurs Riverpod pour la session ; les deux coexistent.

**Présentation.** `lib/presentation/` porte ce qui traduit le domaine en mots
d'écran — libellés de statut, couleurs, filtres, tris — et rien d'autre. C'est
la couche que `docs/architecture/04-migration-flutter.md` §2.2 réserve
délibérément aux applications : le back-office et le livreur n'écrivent pas les
mêmes mots pour la même étape.

**Widgets interactifs.** La règle d'origine — contraindre explicitement la
taille des `InkWell` et `GestureDetector`, et les envelopper dans `Material` —
reste appliquée à la main, écran par écran. Les deux widgets qui devaient la
porter n'ont jamais été écrits.

**Responsive.** Trois écrans seulement utilisent `LayoutBuilder`. La promesse
d'origine — barre de navigation basse sur mobile, barre latérale sur poste de
travail — n'est pas tenue partout.

## Ce que le document promettait et qui n'existe pas

| Promesse | État |
|---|---|
| `AdminInteractiveWidget`, `AdminSafeCard` | jamais écrits |
| `AdminRouter` — navigation centralisée | jamais écrit ; la navigation passe par l'index de `AdminNavigationScreen` |
| `lib/core/navigation/`, `lib/core/widgets/` | n'existent pas |
| `screens/admin/{dashboard,orders,menu,drivers,clients,analytics,settings}/` | les 33 écrans sont à plat |

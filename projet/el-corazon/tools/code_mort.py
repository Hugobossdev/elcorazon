#!/usr/bin/env python3
"""Refuse un fichier Dart que rien n'atteint.

Pourquoi ce script existe
-------------------------

`flutter analyze` ne signale rien sur les fichiers injoignables : vérifié le
2026-08-06 sur `apps/dely/lib/dialogs/menu_item_dialog.dart`, dont les
trois imports `../../models|services|widgets/...` désignaient des répertoires
qui n'existent qu'un niveau plus bas — irrésolvables, donc, et pourtant
`flutter analyze`, `dart analyze` sur le répertoire et `dart analyze
--format=machine` sur le fichier seul rendaient tous zéro diagnostic.

Un quart du code des applications s'était accumulé derrière cet angle mort
(~34 500 lignes au 2026-08-06). Le supprimer ne suffit pas : sans une mesure
qui échoue, il se reconstitue. C'est le rôle de ce script, et c'est la raison
pour laquelle il est branché sur la CI plutôt que laissé à la bonne volonté.

Ce qu'il fait
-------------

Il part des points d'entrée, suit les `import` / `export` / `part` de proche en
proche, et compare l'ensemble atteint au contenu de `lib/`. Tout fichier hors de
cet ensemble est un fichier que rien n'exécute.

Ce qu'il ne voit pas
--------------------

Un fichier atteint uniquement par réflexion ou par un chemin construit à
l'exécution. Dart n'en offre pas les moyens usuels et le projet n'en fait pas
usage, mais c'est la limite à garder en tête avant de supprimer sur sa seule
foi : `flutter build` reste le juge.

Il ne voit pas non plus les fichiers « zombies » — atteignables parce que
`main.dart` les enregistre dans l'arbre de providers, mais qu'aucun écran ne
consomme. `--zombies` les signale séparément, à titre indicatif : le lien est
réel, seul son intérêt est douteux, et l'arbitrage demande un humain.

Usage
-----

    python tools/code_mort.py                  # les trois applications
    python tools/code_mort.py apps/admin
    python tools/code_mort.py --zombies        # signale aussi les zombies

Code de sortie 1 s'il reste un fichier injoignable : c'est ce qui rend la CI
rouge.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from collections import defaultdict, deque

#: `part` compte autant qu'`import` : un fichier en `part of` n'est pas
#: autonome, il appartient à celui qui le déclare.
#:
#: La directive est capturée **jusqu'à son point-virgule**, et non sur sa
#: première chaîne : une directive Dart peut en porter plusieurs.
DIRECTIVE = re.compile(r"""(?:^|\n)\s*(?:import|export|part)\s+([^;]+);""")

#: Une chaîne littérale, dans le corps d'une directive.
#:
#: ## Ce que la version précédente ne voyait pas
#:
#: Le motif ne retenait que la **première**. Sur la forme conditionnelle, qui
#: est la façon standard de séparer web et natif en Dart —
#:
#:     export 'x_stub.dart' if (dart.library.js_interop) 'x_web.dart';
#:
#: — la branche `x_web.dart` n'était donc jamais suivie, et ce script la
#: déclarait injoignable. C'est un **faux positif**, et du pire genre : la
#: conclusion affichée est « les brancher, ou les supprimer », et supprimer
#: `notification_navigateur_web.dart` aurait retiré l'affichage des notifications
#: push sur la version navigateur du client — la seule implémentation qui
#: existe, `flutter_local_notifications` commençant son `show()` par
#: `if (kIsWeb) return;`.
#:
#: Un outil qui garde la CI rouge sur du code vivant se fait désarmer, puis
#: contourner. Les deux branches sont donc retenues : `dart.library.*` n'est
#: connu qu'à la compilation, et l'une comme l'autre s'exécute selon la cible.
CHAINE = re.compile(r"""['"]([^'"]+)['"]""")


def cibles_des_directives(texte: str) -> list[str]:
    """Les chemins que ce fichier atteint, branches conditionnelles comprises."""
    return [cible for corps in DIRECTIVE.findall(texte) for cible in CHAINE.findall(corps)]


#: Déclaration, dans le fichier lui-même, d'une mise à l'écart assumée.
#:
#:     // code-mort: hors-graphe — outil interne, poussé à la main en debug
#:
#: ## Pourquoi ce mécanisme, plutôt qu'une liste dans ce script
#:
#: Certains fichiers sont **délibérément** hors du graphe. La galerie du pack
#: d'emojis en est un : aucune route n'y mène, elle se pousse à la main depuis un
#: point d'arrêt, et c'est écrit dans son en-tête — la garder hors du routeur
#: évite qu'un lien traîne jusqu'en production. Elle sert encore : les trente
#: illustrations ne sont pas toutes produites, et c'est là qu'on les juge.
#:
#: Sans ce mécanisme, il n'y avait que deux issues, mauvaises toutes les deux :
#: supprimer un outil dont on a besoin, ou laisser la CI rouge — auquel cas
#: l'état normal devient « rouge » et un vrai fichier mort s'y perd.
#:
#: La déclaration vit dans le fichier, et non dans une liste ici : elle se
#: déplace et se supprime avec lui, et un fichier renommé ne laisse pas derrière
#: lui une exemption orpheline qui couvrirait autre chose.
#:
#: Le motif exige un **motif rédigé** après le tiret. Une exemption qu'on doit
#: justifier se pose moins facilement qu'une case à cocher.
HORS_GRAPHE = re.compile(r"//\s*code-mort:\s*hors-graphe\s*[—-]\s*(\S.*)")

#: Racine du dépôt, déduite de l'emplacement de ce script (`tools/`).
RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

APPLICATIONS = ["apps/admin", "apps/fastfood", "apps/dely"]


def nom_du_paquet(racine_app: str) -> str | None:
    """Nom déclaré dans `pubspec.yaml`, pour résoudre les `package:` internes."""
    chemin = os.path.join(racine_app, "pubspec.yaml")
    try:
        with open(chemin, encoding="utf-8", errors="ignore") as fh:
            for ligne in fh:
                if ligne.startswith("name:"):
                    return ligne.split(":", 1)[1].strip()
    except OSError:
        return None
    return None


def fichiers_dart(lib: str) -> set[str]:
    trouves = set()
    for repertoire, _, noms in os.walk(lib):
        for nom in noms:
            if nom.endswith(".dart"):
                trouves.add(os.path.normpath(os.path.join(repertoire, nom)))
    return trouves


def graphe(lib: str, fichiers: set[str], paquet: str | None) -> dict[str, set[str]]:
    """Arcs « ce fichier en désigne un autre », dépendances externes exclues."""
    arcs: dict[str, set[str]] = {}
    for source in fichiers:
        cibles: set[str] = set()
        try:
            with open(source, encoding="utf-8", errors="ignore") as fh:
                texte = fh.read()
        except OSError:
            arcs[source] = cibles
            continue

        for brut in cibles_des_directives(texte):
            if brut.startswith("dart:"):
                continue
            if brut.startswith("package:"):
                nom, _, reste = brut[len("package:") :].partition("/")
                if nom != paquet:
                    continue  # paquet tiers ou socle partagé : hors périmètre
                candidat = os.path.normpath(os.path.join(lib, reste))
            elif ":" in brut:
                continue
            else:
                candidat = os.path.normpath(os.path.join(os.path.dirname(source), brut))

            if candidat in fichiers and candidat != source:
                cibles.add(candidat)
        arcs[source] = cibles
    return arcs


def points_d_entree(fichiers: set[str], lib: str) -> set[str]:
    """`main.dart` — et lui seul.

    Un `main.dart` de sous-répertoire (variante de démarrage) compte aussi :
    c'est bien une porte d'entrée du programme.
    """
    return {f for f in fichiers if os.path.basename(f) == "main.dart"}


def analyse(
    racine_app: str,
) -> tuple[list[tuple[str, int]], list[tuple[str, int]], list[tuple[str, str]]]:
    """Rend (injoignables, zombies, mis à l'écart déclarés).

    Les deux premiers portent un volume en lignes, le troisième le motif que le
    fichier déclare lui-même (voir [HORS_GRAPHE]).
    """
    lib = os.path.join(racine_app, "lib")
    if not os.path.isdir(lib):
        return [], [], []

    fichiers = fichiers_dart(lib)
    arcs = graphe(lib, fichiers, nom_du_paquet(racine_app))
    entrees = points_d_entree(fichiers, lib)

    atteints = set(entrees)
    file = deque(entrees)
    while file:
        for cible in arcs.get(file.popleft(), ()):
            if cible not in atteints:
                atteints.add(cible)
                file.append(cible)

    def lignes(chemin: str) -> int:
        try:
            with open(chemin, encoding="utf-8", errors="ignore") as fh:
                return sum(1 for _ in fh)
        except OSError:
            return 0

    def relatif(chemin: str) -> str:
        return os.path.relpath(chemin, lib).replace(os.sep, "/")

    def hors_graphe(chemin: str) -> str | None:
        """Le motif déclaré par le fichier, s'il s'écarte volontairement."""
        try:
            with open(chemin, encoding="utf-8", errors="ignore") as fh:
                trouve = HORS_GRAPHE.search(fh.read())
        except OSError:
            return None
        return trouve.group(1).strip() if trouve else None

    orphelins = fichiers - atteints
    ecartes = {f: motif for f in orphelins if (motif := hors_graphe(f)) is not None}

    injoignables = sorted(
        ((relatif(f), lignes(f)) for f in orphelins - set(ecartes)), key=lambda t: -t[1]
    )
    declares = sorted((relatif(f), motif) for f, motif in ecartes.items())

    # Zombies : atteints, mais par `main.dart` seulement. Les écrans racines et
    # `firebase_options.dart` sont dans ce cas légitimement — d'où le simple
    # signalement, sans échec.
    entrants: dict[str, set[str]] = defaultdict(set)
    for source, cibles in arcs.items():
        for cible in cibles:
            entrants[cible].add(source)

    zombies = sorted(
        (
            (relatif(f), lignes(f))
            for f in atteints - entrees
            if entrants.get(f, set()) <= entrees
        ),
        key=lambda t: -t[1],
    )

    return injoignables, zombies, declares


def main(argv: list[str]) -> int:
    analyseur = argparse.ArgumentParser(
        description="Refuse un fichier Dart que rien n'atteint depuis main().",
    )
    analyseur.add_argument(
        "applications",
        nargs="*",
        default=None,
        help="chemins à examiner (défaut : les trois applications)",
    )
    analyseur.add_argument(
        "--zombies",
        action="store_true",
        help="signale aussi les fichiers atteints par main.dart seul (informatif)",
    )
    args = analyseur.parse_args(argv)

    cibles = args.applications or [os.path.join(RACINE, a) for a in APPLICATIONS]

    total_injoignable = 0
    total_lignes = 0

    for cible in cibles:
        chemin = cible if os.path.isabs(cible) else os.path.join(RACINE, cible)
        etiquette = os.path.basename(os.path.normpath(chemin))
        injoignables, zombies, declares = analyse(chemin)

        if injoignables:
            volume = sum(n for _, n in injoignables)
            total_injoignable += len(injoignables)
            total_lignes += volume
            print(f"\n{etiquette} — {len(injoignables)} fichiers injoignables ({volume} lignes)")
            for rel, n in injoignables:
                print(f"    {rel}  ({n} l.)")
        else:
            print(f"\n{etiquette} — aucun fichier injoignable")

        # Toujours affichés, jamais bloquants : une mise à l'écart qui
        # disparaît de la sortie finit par ne plus être relue, et le motif
        # qu'elle porte cesse d'être vrai sans que personne ne le voie.
        for rel, motif in declares:
            print(f"  (hors graphe, déclaré) {rel} — {motif}")

        if args.zombies and zombies:
            print(f"  (informatif) {len(zombies)} fichiers atteints par main.dart seul :")
            for rel, n in zombies:
                print(f"      {rel}  ({n} l.)")

    if total_injoignable:
        print(
            f"\nÉCHEC : {total_injoignable} fichiers ({total_lignes} lignes) "
            f"ne sont atteints par aucun chemin d'exécution.\n"
            f"Les brancher, ou les supprimer. `flutter analyze` ne les voit pas.",
        )
        return 1

    print("\nAucun fichier injoignable.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

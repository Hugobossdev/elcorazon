#!/usr/bin/env python3
"""Refuse un fichier Dart que rien n'atteint.

Pourquoi ce script existe
-------------------------

`flutter analyze` ne signale rien sur les fichiers injoignables : vérifié le
2026-08-06 sur `El corazon dely/lib/dialogs/menu_item_dialog.dart`, dont les
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
    python tools/code_mort.py "El Corazon admin"
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
DIRECTIVE = re.compile(r"""(?:^|\n)\s*(?:import|export|part)\s+['"]([^'"]+)['"]""")

#: Racine du dépôt, déduite de l'emplacement de ce script (`tools/`).
RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

APPLICATIONS = ["El Corazon admin", "El Corazon fastfood", "El corazon dely"]


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

        for brut in DIRECTIVE.findall(texte):
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


def analyse(racine_app: str) -> tuple[list[tuple[str, int]], list[tuple[str, int]]]:
    """Rend (fichiers injoignables, fichiers zombies), chacun avec son volume."""
    lib = os.path.join(racine_app, "lib")
    if not os.path.isdir(lib):
        return [], []

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

    injoignables = sorted(
        ((relatif(f), lignes(f)) for f in fichiers - atteints), key=lambda t: -t[1]
    )

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

    return injoignables, zombies


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
        injoignables, zombies = analyse(chemin)

        if injoignables:
            volume = sum(n for _, n in injoignables)
            total_injoignable += len(injoignables)
            total_lignes += volume
            print(f"\n{etiquette} — {len(injoignables)} fichiers injoignables ({volume} lignes)")
            for rel, n in injoignables:
                print(f"    {rel}  ({n} l.)")
        else:
            print(f"\n{etiquette} — aucun fichier injoignable")

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

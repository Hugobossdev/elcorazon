#!/usr/bin/env python3
"""Refuse une couverture de tests qui baisse.

Pourquoi ce script existe
-------------------------

`flutter test --coverage` n'instrumente que les fichiers qu'un test finit par
charger. Mesuré le 2026-08-07 sur `El corazon dely` : `lcov.info` ne contenait
**3 fichiers sur 48**, et le ratio brut annonçait 29,96 % — alors que la
couverture réelle de `lib/` est de 1,31 %. Le chiffre flatteur n'est pas une
approximation, c'est un autre indicateur : il mesure la couverture des fichiers
déjà testés, c'est-à-dire précisément ceux dont on ne se soucie pas.

Pire pour un plancher : ajouter un fichier sans test ne le fait pas baisser,
puisque le fichier n'apparaît nulle part. Un cliquet posé là-dessus ne cliquette
jamais.

Ce script rend le dénominateur honnête. Il s'appuie sur un fichier de test
généré — `test/_couverture_totale_test.dart` — qui importe **tout** `lib/`, ce
qui force l'instrumentation de chaque fichier, testé ou non.

Ce qu'il vérifie
----------------

1. Que ce fichier généré est à jour. Sans quoi un fichier neuf échapperait au
   dénominateur, et la couverture monterait en n'écrivant aucun test.
2. Que le ratio `LH / LF` de `coverage/lcov.info` atteint le plancher.

Les planchers sont **bas** : ils constatent l'existant du 7 août 2026 plutôt
qu'ils ne fixent une cible. Ils se relèvent à chaque domaine migré au lot 3 —
c'est le sens du cliquet. Les baisser demande une raison écrite ici.

Usage
-----

    flutter test --coverage                       # dans le répertoire visé
    python tools/couverture.py                    # les quatre paquets
    python tools/couverture.py "El corazon dely"  # un seul
    python tools/couverture.py --generer          # régénère les fichiers

Code de sortie 1 sous le plancher, ou si un fichier généré est périmé.
"""

from __future__ import annotations

import argparse
import os
import sys

#: Racine du dépôt, déduite de l'emplacement de ce script (`tools/`).
RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

#: Nom du paquet Dart et plancher, par répertoire.
#:
#: Le socle est à un tout autre niveau que les applications, et c'est le sujet
#: du plan de refactoring : 2 514 lignes instrumentables contre 38 250 pour les
#: trois applications réunies, et 1 480 lignes couvertes contre 837.
CIBLES: dict[str, tuple[str, float]] = {
    "packages/elcorazon_core": ("elcorazon_core", 55.0),
    "El Corazon fastfood": ("elcora_fast", 3.0),
    # Relevé de 1,0 à 2,5 au lot 3 : le test de traduction des courses
    # (`django_delivery_repository_test.dart`) a porté la couverture réelle à
    # 2,79 %. C'est le cliquet qui se resserre, comme prévu.
    "El corazon dely": ("elcora_dely", 2.5),
    "El Corazon admin": ("admin", 0.9),
}

GENERE = "test/_couverture_totale_test.dart"

ENTETE = """// Fichier généré par `tools/couverture.py` — ne pas modifier à la main.
//
// Il n'exécute rien. Il n'existe que pour importer tout `lib/`, afin que
// `flutter test --coverage` instrumente aussi les fichiers qu'aucun test ne
// touche. Sans lui, `lcov.info` ne décrit que les fichiers déjà testés et le
// pourcentage qui en sort ne veut rien dire.
// ignore_for_file: unused_import
"""


def fichiers_lib(racine_app: str) -> list[str]:
    lib = os.path.join(racine_app, "lib")
    trouves = []
    for repertoire, _, noms in os.walk(lib):
        for nom in noms:
            if nom.endswith(".dart"):
                chemin = os.path.join(repertoire, nom)
                trouves.append(os.path.relpath(chemin, lib).replace(os.sep, "/"))
    return sorted(trouves)


def contenu_attendu(racine_app: str, paquet: str) -> str:
    imports = "\n".join(
        f"import 'package:{paquet}/{f}';" for f in fichiers_lib(racine_app)
    )
    return f"{ENTETE}\n{imports}\n\nvoid main() {{}}\n"


def lire_lcov(racine_app: str) -> tuple[int, int]:
    """Rend (lignes couvertes, lignes instrumentables)."""
    chemin = os.path.join(racine_app, "coverage", "lcov.info")
    couvertes = total = 0
    with open(chemin, encoding="utf-8", errors="ignore") as fh:
        for ligne in fh:
            if ligne.startswith("LH:"):
                couvertes += int(ligne[3:])
            elif ligne.startswith("LF:"):
                total += int(ligne[3:])
    return couvertes, total


def main(argv: list[str]) -> int:
    analyseur = argparse.ArgumentParser(
        description="Refuse une couverture de tests inférieure au plancher.",
    )
    analyseur.add_argument("cibles", nargs="*", help="répertoires (défaut : tous)")
    analyseur.add_argument(
        "--generer",
        action="store_true",
        help="régénère les fichiers d'import exhaustif au lieu de vérifier",
    )
    args = analyseur.parse_args(argv)

    cibles = args.cibles or list(CIBLES)
    echecs = 0

    for cible in cibles:
        if cible not in CIBLES:
            print(f"Cible inconnue : {cible}")
            return 2

        paquet, plancher = CIBLES[cible]
        racine_app = os.path.join(RACINE, cible)
        chemin_genere = os.path.join(racine_app, GENERE)
        attendu = contenu_attendu(racine_app, paquet)

        if args.generer:
            os.makedirs(os.path.dirname(chemin_genere), exist_ok=True)
            with open(chemin_genere, "w", encoding="utf-8", newline="") as fh:
                fh.write(attendu)
            print(f"{cible} — {GENERE} régénéré")
            continue

        try:
            with open(chemin_genere, encoding="utf-8") as fh:
                actuel = fh.read()
        except OSError:
            print(f"{cible} — ÉCHEC : {GENERE} absent. `--generer` le crée.")
            echecs += 1
            continue

        if actuel != attendu:
            print(
                f"{cible} — ÉCHEC : {GENERE} ne couvre plus tout `lib/`.\n"
                f"    Un fichier a été ajouté, retiré ou renommé. Sans mise à "
                f"jour, il échapperait à la mesure.\n"
                f"    Lancer : python tools/couverture.py --generer",
            )
            echecs += 1
            continue

        try:
            couvertes, total = lire_lcov(racine_app)
        except OSError:
            print(
                f"{cible} — ÉCHEC : coverage/lcov.info absent. "
                f"Lancer `flutter test --coverage` d'abord.",
            )
            echecs += 1
            continue

        if total == 0:
            print(f"{cible} — ÉCHEC : lcov.info ne contient aucune ligne mesurée.")
            echecs += 1
            continue

        ratio = 100 * couvertes / total
        verdict = "ok" if ratio >= plancher else "SOUS LE PLANCHER"
        print(
            f"{cible} — {ratio:.2f} % ({couvertes}/{total} lignes), "
            f"plancher {plancher:.1f} % — {verdict}",
        )
        if ratio < plancher:
            echecs += 1

    if echecs:
        print(
            f"\nÉCHEC : {echecs} cible(s). La couverture ne doit pas baisser — "
            f"elle se relève à chaque domaine migré.",
        )
        return 1

    if not args.generer:
        print("\nToutes les cibles atteignent leur plancher.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

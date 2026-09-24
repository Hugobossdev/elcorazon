#!/usr/bin/env python3
"""Refuse une valeur d'énumération que le Dart propose et que le serveur refuse.

Pourquoi ce script existe
-------------------------

`contrat_routes.py` garantit que chaque **adresse** appelée existe. Il ne dit
rien des **valeurs** envoyées. Le 21 septembre 2026, l'écran des défis
proposait `orders_count`, `total_spent` et `streak_days` comme nature de défi,
là où le serveur n'accepte que `daily`, `weekly`, `monthly` et `special` :
chaque création revenait en 400. Les tests Dart étaient verts — ils vérifiaient
qu'un dépôt sait envoyer la valeur qu'on lui donne — et les tests Django aussi
— ils vérifiaient que le serveur refuse ce qu'il doit refuser. Personne ne
comparait les deux listes.

Ce qu'il fait
-------------

Pour chaque vocabulaire déclaré dans `REGISTRE`, il lit les valeurs écrites
dans le fichier Dart (constantes `static const x = 'valeur';` d'une classe, ou
premier argument des valeurs d'un `enum`) et les compare aux `TextChoices` du
serveur, importées par Django dans un sous-processus.

Deux exigences possibles :

* ``egal`` — le Dart est un **miroir complet** : un formulaire qui propose
  toutes les valeurs doit les proposer toutes, et aucune de plus ;
* ``inclus`` — le Dart n'en connaît qu'une partie, volontairement : chacune
  doit au moins être acceptée par le serveur.

Il vérifie aussi les **permissions** que le back-office écrit
(`context.peut('x')`, `can('x')`, `permission: 'x'`) : chacune doit exister
dans le registre du serveur (`apps.accounts.permissions.PERMISSIONS`). Une
faute de frappe y masquerait un geste pour tout le monde, sans rien signaler —
le registre étant fermé, le serveur ne l'accorderait à personne.

Usage
-----

    python tools/contrat_vocabulaire.py

Code de sortie 1 au premier écart : c'est ce qui rend la CI rouge.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BACKEND = os.path.join(RACINE, "backend")


@dataclass(frozen=True)
class Vocabulaire:
    """Un couple « valeurs Dart » ↔ « `TextChoices` Django »."""

    fichier_dart: str
    nom_dart: str
    choix_django: str
    exigence: str = "egal"


REGISTRE: tuple[Vocabulaire, ...] = (
    Vocabulaire(
        "packages/elcorazon_core/lib/src/gamification/vocabulaire_gamification.dart",
        "ChallengeKind",
        "apps.gamification.models.ChallengeKind",
    ),
    Vocabulaire(
        "packages/elcorazon_core/lib/src/gamification/vocabulaire_gamification.dart",
        "AchievementCondition",
        "apps.gamification.models.AchievementCondition",
    ),
    Vocabulaire(
        "packages/elcorazon_core/lib/src/loyalty/vocabulaire_fidelite.dart",
        "RewardKind",
        "apps.loyalty.models.RewardKind",
    ),
    Vocabulaire(
        "packages/elcorazon_core/lib/src/payments/vocabulaire_paiement.dart",
        "PaymentStatus",
        "apps.payments.models.PaymentStatus",
    ),
    Vocabulaire(
        "packages/elcorazon_core/lib/src/payments/managed_payouts.dart",
        "StatutVersement",
        "apps.payments.models.PaymentStatus",
        exigence="inclus",
    ),
    Vocabulaire(
        "packages/elcorazon_core/lib/src/promotions/promotion.dart",
        "DiscountKind",
        "apps.promotions.models.DiscountKind",
    ),
    Vocabulaire(
        "packages/elcorazon_core/lib/src/notifications/campaign.dart",
        "CampaignAudience",
        "apps.notifications.models.Audience",
    ),
    Vocabulaire(
        "packages/elcorazon_core/lib/src/notifications/campaign.dart",
        "CampaignStatus",
        "apps.notifications.models.CampaignStatus",
    ),
    Vocabulaire(
        "apps/admin/lib/presentation/statut_commande.dart",
        "StatutCommande",
        "apps.orders.states.OrderStatus",
    ),
)

#: Là où le back-office écrit des permissions.
SOURCES_PERMISSIONS = ("apps/admin/lib",)

_PERMISSION_APPELEE = re.compile(
    r"(?:\bcan|\bpeut)\(\s*'([a-z_]+\.[a-z_]+)'|\bpermission:\s*'([a-z_]+\.[a-z_]+)'"
)
_LISTE_DE_PERMISSIONS = re.compile(r"\bpeutUne\(\s*(?:const\s*)?\[([^\]]*)\]")
_LITTERAL_PERMISSION = re.compile(r"'([a-z_]+\.[a-z_]+)'")

_CONSTANTE = re.compile(r"static\s+const\s+(\w+)\s*=\s*'([^']*)'\s*;")
_VALEUR_ENUM = re.compile(r"^\s*\w+\s*\(\s*'([^']*)'", re.MULTILINE)
_ENTETE = r"(?:abstract\s+final\s+class|final\s+class|class|enum)\s+{nom}\b[^{{]*\{{"


def corps_de(source: str, nom: str) -> tuple[str, str]:
    """Le corps (entre accolades) de la classe ou de l'enum ``nom``, et sa sorte."""
    entete = re.search(_ENTETE.format(nom=re.escape(nom)), source)
    if entete is None:
        raise LookupError(nom)
    sorte = "enum" if entete.group(0).lstrip().startswith("enum") else "classe"
    profondeur, debut = 1, entete.end()
    for index in range(debut, len(source)):
        if source[index] == "{":
            profondeur += 1
        elif source[index] == "}":
            profondeur -= 1
            if profondeur == 0:
                return source[debut:index], sorte
    raise LookupError(nom)


def valeurs_dart(vocabulaire: Vocabulaire) -> set[str]:
    """Les valeurs qu'écrit le Dart pour ce vocabulaire.

    Pour une classe, les constantes chaînes, hors listes. Pour un `enum`, le
    premier argument de chaque valeur — seules les valeurs précèdent le `;`.
    """
    with open(os.path.join(RACINE, vocabulaire.fichier_dart), encoding="utf-8") as fh:
        source = fh.read()
    corps, sorte = corps_de(source, vocabulaire.nom_dart)
    if sorte == "enum":
        return set(_VALEUR_ENUM.findall(corps.split(";", 1)[0]))
    return {valeur for _, valeur in _CONSTANTE.findall(corps)}


def python_du_backend() -> str:
    for suffixe in (os.path.join("Scripts", "python.exe"), os.path.join("bin", "python")):
        candidat = os.path.join(BACKEND, ".venv", suffixe)
        if os.path.exists(candidat):
            return candidat
    return sys.executable


_EXTRACTION = """
import importlib, json, os, sys, django
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.test")
django.setup()
from apps.accounts.permissions import PERMISSIONS
resultat = {"__permissions__": sorted(PERMISSIONS)}
for chemin in json.loads(sys.argv[1]):
    module, _, nom = chemin.rpartition(".")
    resultat[chemin] = sorted(getattr(importlib.import_module(module), nom).values)
print(json.dumps(resultat))
"""


def valeurs_django(chemins: list[str]) -> dict[str, set[str]]:
    resultat = subprocess.run(  # noqa: S603
        [python_du_backend(), "-c", _EXTRACTION, json.dumps(sorted(set(chemins)))],
        cwd=BACKEND,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    if resultat.returncode != 0:
        raise SystemExit(
            "Impossible de lire les énumérations du backend.\n"
            "Le `.venv` de `backend/` est-il installé ?\n\n" + resultat.stderr.strip()
        )
    charge = json.loads(resultat.stdout.strip().splitlines()[-1])
    return {chemin: set(valeurs) for chemin, valeurs in charge.items()}


def ecarts(
    vocabulaire: Vocabulaire, dart: set[str], serveur: set[str]
) -> list[str]:
    """Ce qui ne va pas pour ce vocabulaire — vide s'il est conforme."""
    refusees = sorted(dart - serveur)
    manquantes = sorted(serveur - dart) if vocabulaire.exigence == "egal" else []
    messages = [f"proposée par le Dart, refusée par le serveur : {v}" for v in refusees]
    messages += [f"acceptée par le serveur, absente du Dart : {v}" for v in manquantes]
    if not dart:
        messages.append("aucune valeur lue côté Dart — le motif de lecture a-t-il changé ?")
    return messages


def permissions_ecrites(contenu: str) -> set[str]:
    """Les permissions qu'un fichier Dart du back-office cite."""
    trouvees = {a or b for a, b in _PERMISSION_APPELEE.findall(contenu)}
    for liste in _LISTE_DE_PERMISSIONS.findall(contenu):
        trouvees |= set(_LITTERAL_PERMISSION.findall(liste))
    return trouvees


def permissions_du_back_office() -> dict[str, set[str]]:
    """Permission → fichiers qui la citent, sur `SOURCES_PERMISSIONS`."""
    citees: dict[str, set[str]] = {}
    for source in SOURCES_PERMISSIONS:
        for dossier, _, noms in os.walk(os.path.join(RACINE, source)):
            for nom in noms:
                if not nom.endswith(".dart"):
                    continue
                chemin = os.path.join(dossier, nom)
                with open(chemin, encoding="utf-8", errors="ignore") as fh:
                    contenu = fh.read()
                relatif = os.path.relpath(chemin, RACINE).replace(os.sep, "/")
                for permission in permissions_ecrites(contenu):
                    citees.setdefault(permission, set()).add(relatif)
    return citees


def main() -> int:
    serveur = valeurs_django([v.choix_django for v in REGISTRE])
    en_echec = 0
    print(f"Vocabulaires — {len(REGISTRE)} comparés")
    for vocabulaire in REGISTRE:
        dart = valeurs_dart(vocabulaire)
        problemes = ecarts(vocabulaire, dart, serveur[vocabulaire.choix_django])
        etiquette = f"{vocabulaire.nom_dart} ↔ {vocabulaire.choix_django} ({vocabulaire.exigence})"
        if not problemes:
            print(f"    conforme  {etiquette}")
            continue
        en_echec += 1
        print(f"    ÉCART     {etiquette}")
        for probleme in problemes:
            print(f"              {probleme}")

    registre = serveur["__permissions__"]
    citees = permissions_du_back_office()
    inconnues = sorted(set(citees) - registre)
    print(f"\nPermissions — {len(citees)} citées par le back-office, {len(registre)} au registre")
    for permission in inconnues:
        print(f"    INCONNUE  {permission}")
        for source in sorted(citees[permission]):
            print(f"              citée par {source}")
    if not inconnues:
        print("    toutes au registre")

    if en_echec:
        print(
            f"\nÉCHEC : {en_echec} vocabulaire(s) divergent. Un formulaire proposerait "
            "une valeur que le serveur refuse, ou en cacherait une qu'il accepte."
        )
    if inconnues:
        print(
            f"\nÉCHEC : {len(inconnues)} permission(s) hors registre. Le geste qu'elles "
            "gardent serait masqué pour tout le monde."
        )
    if en_echec or inconnues:
        return 1
    print("\nVocabulaires et permissions du Dart : tous acceptés par le serveur.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

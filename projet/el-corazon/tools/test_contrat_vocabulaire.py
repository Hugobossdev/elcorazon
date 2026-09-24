#!/usr/bin/env python3
"""Ce que `contrat_vocabulaire.py` doit lire, et l'écart qu'il doit refuser.

Le cas fondateur est rejoué tel quel : la liste que l'écran des défis
proposait le 21 septembre 2026 (`orders_count`, `total_spent`, `streak_days`)
face aux `ChallengeKind` du serveur. Un outil qui laisserait passer ce cas-là
ne garderait rien.

Ces tests ne chargent pas Django : ils éprouvent la lecture du Dart et la
comparaison, pas l'import des `TextChoices`, que la CI exécute en vrai.

Usage
-----

    python -m pytest tools/test_contrat_vocabulaire.py
"""

from __future__ import annotations

from pathlib import Path

import pytest

import contrat_vocabulaire as cv

SERVEUR_DEFIS = {"daily", "weekly", "monthly", "special"}


def _vocabulaire(tmp_path: Path, source: str, nom: str, exigence: str = "egal") -> cv.Vocabulaire:
    fichier = tmp_path / "vocabulaire.dart"
    fichier.write_text(source, encoding="utf-8")
    return cv.Vocabulaire(str(fichier), nom, "apps.x.models.X", exigence)


@pytest.fixture(autouse=True)
def _racine_temporaire(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    # Les chemins du registre sont relatifs à la racine du dépôt ; ici, absolus.
    monkeypatch.setattr(cv, "RACINE", str(tmp_path))


class TestLecture:
    def test_les_constantes_d_une_classe(self, tmp_path: Path) -> None:
        source = """
abstract final class ChallengeKind {
  static const daily = 'daily';
  static const weekly = 'weekly';
  static const values = [daily, weekly];
  static String libelle(String v) => v;
}
"""
        assert cv.valeurs_dart(_vocabulaire(tmp_path, source, "ChallengeKind")) == {
            "daily",
            "weekly",
        }

    def test_seule_la_classe_nommee_est_lue(self, tmp_path: Path) -> None:
        source = """
abstract final class Autre { static const x = 'x'; }
abstract final class Cible { static const y = 'y'; }
"""
        assert cv.valeurs_dart(_vocabulaire(tmp_path, source, "Cible")) == {"y"}

    def test_les_valeurs_d_un_enum(self, tmp_path: Path) -> None:
        source = """
enum StatutCommande {
  enAttente('pending', 'En attente'),
  livree('delivered', 'Livrée');

  const StatutCommande(this.versServeur, this.libelle);
  static const inutile = 'pas une valeur';
}
"""
        assert cv.valeurs_dart(_vocabulaire(tmp_path, source, "StatutCommande")) == {
            "pending",
            "delivered",
        }


class TestComparaison:
    def test_l_ancienne_liste_des_defis_est_refusee(self, tmp_path: Path) -> None:
        vocabulaire = _vocabulaire(tmp_path, "", "X")
        problemes = cv.ecarts(
            vocabulaire, {"orders_count", "total_spent", "streak_days"}, SERVEUR_DEFIS
        )
        refusees = [p for p in problemes if p.startswith("proposée par le Dart")]
        assert len(refusees) == 3
        assert any("absente du Dart : daily" in p for p in problemes)

    def test_un_miroir_complet_passe(self, tmp_path: Path) -> None:
        vocabulaire = _vocabulaire(tmp_path, "", "X")
        assert cv.ecarts(vocabulaire, set(SERVEUR_DEFIS), SERVEUR_DEFIS) == []

    def test_un_sous_ensemble_declare_passe(self, tmp_path: Path) -> None:
        vocabulaire = _vocabulaire(tmp_path, "", "X", exigence="inclus")
        assert cv.ecarts(vocabulaire, {"daily"}, SERVEUR_DEFIS) == []

    def test_un_sous_ensemble_non_declare_echoue(self, tmp_path: Path) -> None:
        vocabulaire = _vocabulaire(tmp_path, "", "X")
        assert cv.ecarts(vocabulaire, {"daily"}, SERVEUR_DEFIS)

    def test_une_lecture_vide_est_signalee(self, tmp_path: Path) -> None:
        vocabulaire = _vocabulaire(tmp_path, "", "X", exigence="inclus")
        assert cv.ecarts(vocabulaire, set(), SERVEUR_DEFIS)


class TestPermissionsCitees:
    def test_les_trois_formes_sont_lues(self) -> None:
        source = """
if (auth.can('orders.refund')) {}
if (context.peut('catalog.write')) {}
NavigationItem(permission: 'orders.read');
SiAutorise(permission: 'couriers.suspend', child: x);
if (context.peutUne(const ['restaurants.write', 'restaurants.operate'])) {}
"""
        assert cv.permissions_ecrites(source) == {
            "orders.refund",
            "catalog.write",
            "orders.read",
            "couriers.suspend",
            "restaurants.write",
            "restaurants.operate",
        }

    def test_une_chaine_quelconque_n_est_pas_une_permission(self) -> None:
        assert cv.permissions_ecrites("final nom = 'fichier.dart';") == set()

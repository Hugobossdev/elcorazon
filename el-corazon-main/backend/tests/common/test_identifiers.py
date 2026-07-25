"""Tests de la génération d'UUIDv7 — ADR-007."""

from __future__ import annotations

import time
import uuid

import pytest

from common.identifiers import _uuid7_fallback, uuid7


@pytest.fixture(params=["fallback", "actif"])
def generator(request: pytest.FixtureRequest):
    """Exerce l'implémentation locale **et** celle réellement utilisée.

    Les images Docker sont en Python 3.13 (pas d'`uuid.uuid7` natif) tandis que
    ce poste est en 3.14. Sans ce paramétrage, on ne testerait jamais le code
    qui tourne en production.
    """
    return _uuid7_fallback if request.param == "fallback" else uuid7


class TestConformite:
    def test_version_7(self, generator) -> None:
        assert generator().version == 7

    def test_variante_rfc_4122(self, generator) -> None:
        assert generator().variant == uuid.RFC_4122

    def test_unicite(self, generator) -> None:
        assert len({generator() for _ in range(10_000)}) == 10_000


class TestOrdonnancement:
    """La propriété qui justifie UUIDv7 plutôt que v4."""

    def test_croissant_dans_le_temps(self, generator) -> None:
        first = generator()
        time.sleep(0.002)  # franchit une milliseconde
        assert first < generator()

    def test_les_valeurs_proches_sont_regroupees_en_index(self, generator) -> None:
        """La propriété qui compte pour PostgreSQL : le regroupement.

        À l'intérieur d'une même milliseconde l'ordre relatif est aléatoire —
        ce sont les 74 bits aléatoires — et c'est sans importance. Ce qui
        importe est que ces valeurs partagent leur préfixe d'horodatage, donc
        tombent sur les mêmes pages d'index. C'est là que se joue l'écart avec
        un UUIDv4, dont chaque insertion atterrit n'importe où.

        Assertion volontairement lâche : un millier de générations traverse
        quelques millisecondes, donc quelques préfixes — mais jamais mille.
        """
        values = [generator() for _ in range(1_000)]
        prefixes = {v.int >> 80 for v in values}

        assert len(prefixes) < 50, (
            f"{len(prefixes)} préfixes distincts pour 1 000 valeurs : "
            "les insertions ne sont pas regroupées."
        )

    def test_l_ordre_est_strict_d_une_milliseconde_a_l_autre(self, generator) -> None:
        """Entre deux millisecondes, l'ordre est en revanche garanti."""
        batches = []
        for _ in range(5):
            batches.append(generator())
            time.sleep(0.002)

        assert batches == sorted(batches)

    def test_l_horodatage_est_bien_celui_du_moment(self, generator) -> None:
        before = time.time_ns() // 1_000_000
        embedded = generator().int >> 80
        after = time.time_ns() // 1_000_000
        assert before <= embedded <= after


class TestBascule:
    def test_uuid7_est_expose(self) -> None:
        assert callable(uuid7)

    def test_la_primitive_standard_est_preferee_si_disponible(self) -> None:
        """Documente la bascule décrite dans l'ADR-007."""
        if hasattr(uuid, "uuid7"):
            assert uuid7 is uuid.uuid7
        else:
            assert uuid7 is _uuid7_fallback

#!/usr/bin/env python3
"""Ce que `code_mort.py` doit voir — et ce qu'il ne doit pas accuser à tort.

Pourquoi ces cas existent
-------------------------

L'outil a rendu la CI rouge sur `notification_navigateur_web.dart`, un fichier
parfaitement vivant. Son motif ne retenait que la **première** chaîne d'une
directive, si bien que la forme conditionnelle — la façon standard de séparer
web et natif en Dart —

    export 'x_stub.dart' if (dart.library.js_interop) 'x_web.dart';

laissait la branche web hors du graphe.

Un faux positif est ici plus grave qu'un oubli : la conclusion affichée est
« Les brancher, ou les supprimer ». Suivre ce conseil aurait retiré l'affichage
des notifications push sur la version navigateur du client — la seule
implémentation qui existe, `flutter_local_notifications` commençant son `show()`
par `if (kIsWeb) return;`.

Et un outil qui reste rouge sur du code vivant se fait désarmer, puis contourner.

Usage
-----

    python -m pytest tools/test_code_mort.py
"""

from __future__ import annotations

import pytest

from code_mort import analyse, cibles_des_directives


class TestLectureDesDirectives:
    def test_un_import_simple(self) -> None:
        assert cibles_des_directives("import 'a.dart';") == ["a.dart"]

    def test_les_trois_formes_comptent(self) -> None:
        """`part` autant qu'`import` : un fichier en `part of` n'est pas autonome."""
        texte = "import 'a.dart';\nexport 'b.dart';\npart 'c.dart';"

        assert cibles_des_directives(texte) == ["a.dart", "b.dart", "c.dart"]

    def test_un_export_conditionnel_rend_ses_deux_branches(self) -> None:
        """Le défaut d'origine, épinglé."""
        texte = "export 'x_stub.dart' if (dart.library.js_interop) 'x_web.dart';"

        assert cibles_des_directives(texte) == ["x_stub.dart", "x_web.dart"]

    def test_un_import_conditionnel_aussi(self) -> None:
        texte = "import 'io.dart' if (dart.library.html) 'web.dart' as plateforme;"

        assert cibles_des_directives(texte) == ["io.dart", "web.dart"]

    def test_une_directive_coupee_sur_deux_lignes(self) -> None:
        """C'est ainsi que `dart format` écrit une directive conditionnelle un peu
        longue — et c'est la forme qu'a réellement le fichier qui a fait échouer
        la CI."""
        texte = "export 'notification_navigateur_stub.dart'\n    if (dart.library.js_interop) 'notification_navigateur_web.dart';"

        assert cibles_des_directives(texte) == [
            "notification_navigateur_stub.dart",
            "notification_navigateur_web.dart",
        ]

    def test_un_alias_ne_devient_pas_un_chemin(self) -> None:
        texte = "import 'package:elcorazon_core/elcorazon_core.dart' as eccore;"

        assert cibles_des_directives(texte) == [
            "package:elcorazon_core/elcorazon_core.dart"
        ]

    def test_les_show_et_hide_non_plus(self) -> None:
        """`show` liste des symboles, pas des fichiers."""
        texte = "import 'a.dart' show Chose, Machin;"

        assert cibles_des_directives(texte) == ["a.dart"]

    def test_une_chaine_ordinaire_du_corps_est_ignoree(self) -> None:
        """Seules les directives comptent, pas les littéraux du programme."""
        texte = "import 'a.dart';\nfinal titre = 'b.dart';"

        assert cibles_des_directives(texte) == ["a.dart"]


class TestParcoursDuGraphe:
    """Sur une arborescence réelle, écrite le temps du test."""

    @pytest.fixture
    def application(self, tmp_path):
        racine = tmp_path / "app"
        lib = racine / "lib"
        lib.mkdir(parents=True)
        (racine / "pubspec.yaml").write_text("name: essai\n", encoding="utf-8")
        return racine, lib

    def test_un_fichier_atteint_par_une_branche_conditionnelle_est_vivant(
        self, application
    ) -> None:
        racine, lib = application
        (lib / "main.dart").write_text("import 'passerelle.dart';", encoding="utf-8")
        (lib / "passerelle.dart").write_text(
            "export 'natif.dart' if (dart.library.js_interop) 'web.dart';",
            encoding="utf-8",
        )
        (lib / "natif.dart").write_text("// natif", encoding="utf-8")
        (lib / "web.dart").write_text("// web", encoding="utf-8")

        injoignables, _, _ = analyse(str(racine))

        assert injoignables == []

    def test_un_fichier_que_rien_ne_designe_reste_signale(self, application) -> None:
        """La correction ne doit pas rendre l'outil aveugle : c'est bien le
        contraire qu'on veut."""
        racine, lib = application
        (lib / "main.dart").write_text("// rien", encoding="utf-8")
        (lib / "orphelin.dart").write_text("// personne\n", encoding="utf-8")

        injoignables, _, _ = analyse(str(racine))

        assert [nom for nom, _ in injoignables] == ["orphelin.dart"]


class TestMiseALEcartDeclaree:
    """Un fichier volontairement hors du graphe — voir `HORS_GRAPHE`.

    Sans ce mécanisme, il n'y avait que deux issues, mauvaises toutes les deux :
    supprimer un outil dont on a besoin, ou laisser la CI rouge — auquel cas
    l'état normal devient « rouge » et un vrai fichier mort s'y perd.
    """

    @pytest.fixture
    def application(self, tmp_path):
        racine = tmp_path / "app"
        lib = racine / "lib"
        lib.mkdir(parents=True)
        (racine / "pubspec.yaml").write_text("name: essai\n", encoding="utf-8")
        (lib / "main.dart").write_text("// rien", encoding="utf-8")
        return racine, lib

    def test_un_fichier_qui_se_declare_ne_fait_pas_echouer(self, application) -> None:
        racine, lib = application
        (lib / "outil.dart").write_text(
            "// code-mort: hors-graphe — outil interne poussé à la main\n",
            encoding="utf-8",
        )

        injoignables, _, declares = analyse(str(racine))

        assert injoignables == []
        assert declares == [("outil.dart", "outil interne poussé à la main")]

    def test_le_tiret_simple_vaut_le_cadratin(self, application) -> None:
        """Personne ne tape un cadratin sans y penser."""
        racine, lib = application
        (lib / "outil.dart").write_text(
            "// code-mort: hors-graphe - juge le pack d'emojis\n", encoding="utf-8"
        )

        _, _, declares = analyse(str(racine))

        assert declares == [("outil.dart", "juge le pack d'emojis")]

    def test_une_declaration_sans_motif_ne_compte_pas(self, application) -> None:
        """Une exemption qu'on doit justifier se pose moins facilement qu'une
        case à cocher."""
        racine, lib = application
        (lib / "outil.dart").write_text("// code-mort: hors-graphe\n", encoding="utf-8")

        injoignables, _, declares = analyse(str(racine))

        assert [nom for nom, _ in injoignables] == ["outil.dart"]
        assert declares == []

    def test_un_fichier_atteint_n_a_pas_besoin_de_se_declarer(self, application) -> None:
        """La déclaration ne doit rien changer pour du code vivant."""
        racine, lib = application
        (lib / "main.dart").write_text("import 'vivant.dart';", encoding="utf-8")
        (lib / "vivant.dart").write_text("// atteint", encoding="utf-8")

        injoignables, _, declares = analyse(str(racine))

        assert injoignables == []
        assert declares == []

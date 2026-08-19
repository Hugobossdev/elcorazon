#!/usr/bin/env python3
"""Refuse une adresse que le client Dart appelle et que le serveur ne sert pas.

Pourquoi ce script existe
-------------------------

Les tests des deux côtés sont verts et se trompent ensemble. Côté Dart, chaque
dépôt est vérifié contre un `HttpClientAdapter` de test qui répond ce que le
test lui dicte : il confirme que `CatalogRepository` sait lire une réponse, pas
que `/catalog/items/` existe. Côté Django, `tests/contract/test_api_contract.py`
vérifie la **forme** des réponses contre le schéma OpenAPI, mais ne sait rien
des adresses que l'application demande réellement.

Entre les deux, personne ne compare. Le défaut est passé une fois : le
déploiement Render a servi sans son suffixe `/api/v1`, et *toutes* les routes
sont revenues en 404 — le client demandait `/catalog/items/` quand le serveur ne
monte l'API que sous `/api/v1/catalog/items/`. Aucune suite ne pouvait le voir,
puisque aucune ne regarde les deux arbres à la fois. C'est le rôle de ce script.

Il attrape aussi la dérive ordinaire : une route renommée côté serveur, un
`viewset` dont le `basename` change, une action `@action` retirée. Le client
continue de l'appeler, et la panne n'apparaît qu'à l'exécution, sur l'écran qui
s'en sert.

Ce qu'il fait
-------------

Il extrait les adresses écrites dans le code Dart, les normalise (`$orderId` et
`{order_id}` désignent la même chose), et vérifie que chacune existe :

* les adresses HTTP, contre le **schéma OpenAPI** généré depuis les vues et les
  sérialiseurs — donc incapable de dériver du code serveur ;
* les adresses WebSocket, contre `config/routing.py`, que le schéma ne couvre
  pas : Channels ne passe pas par DRF.

Le schéma est généré hors ligne, sans serveur ni base : `SchemaGenerator` lit
les vues, il ne les appelle pas.

Ce qu'il ne voit pas
--------------------

Une adresse construite morceau par morceau à l'exécution. Le projet n'en écrit
pas — les chemins sont des littéraux à interpolation — mais c'est la limite à
garder en tête. Il ne vérifie pas non plus les **verbes** : qu'une adresse
existe ne dit pas qu'elle accepte le `POST` que le client lui envoie.

Il ne dit rien de la valeur d'`API_BASE_URL`. C'est une autre question, tenue
par `apps/fastfood/test/adresse_api_test.dart`, et elle ne se vérifie qu'à
l'exécution.

Usage
-----

    python tools/contrat_routes.py
    python tools/contrat_routes.py --lister    # affiche aussi les routes servies

Code de sortie 1 s'il reste une adresse orpheline : c'est ce qui rend la CI
rouge.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys

#: Racine du dépôt, déduite de l'emplacement de ce script (`tools/`).
RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

BACKEND = os.path.join(RACINE, "backend")

#: Le préfixe sous lequel l'API est montée. Il fait partie d'`API_BASE_URL` et
#: non des chemins : `packages/elcorazon_core` les écrit tous en relatif.
PREFIXE_API = "/api/v1"

#: Là où vivent les adresses. Le paquet partagé porte tous les dépôts ; les
#: applications n'appellent le réseau que par lui, à une exception près
#: (`driver_rating_service.dart`), d'où le second répertoire.
SOURCES_DART = ["packages/elcorazon_core/lib/src", "apps"]

#: Un littéral qui ressemble à une adresse : commence par `/`, puis un segment
#: en minuscules. Écarte les chemins de fichiers et les noms de routes Flutter
#: en `CamelCase`.
LITTERAL = re.compile(r"'(/[a-z][A-Za-z0-9_/{}$.-]*)'")

#: Dans les applications, seuls les littéraux **passés au client** comptent :
#: `apps/*/lib` est plein de noms de routes de navigation (`/client/cart`), qui
#: ressemblent à des adresses sans en être. Le client peut être nommé
#: `apiClient` ou `_client`, et l'adresse tomber à la ligne suivante.
APPEL_CLIENT = re.compile(
    r"""(?:apiClient|_client|_apiClient)\s*\.\s*(?:get|post|patch|put|delete)\s*"""
    r"""(?:<[^>]*>)?\s*\(\s*(?:\r?\n\s*)?'(/[^']+)'""",
)

#: Adresses WebSocket, construites par `Uri(...path: '/ws/…')`.
LITTERAL_WS = re.compile(r"'(/ws/[A-Za-z0-9_/{}$.-]*)'")

#: Hôtes qui ne sont pas le nôtre. `directions_repository.dart` s'adresse à
#: Google Maps avec son propre `Dio` : ces chemins n'ont rien à faire dans le
#: schéma d'El Corazón, et les y chercher ferait échouer le contrôle à tort.
ETRANGERS = ("/maps/api/",)

#: Ce qui remplace un paramètre, des deux côtés, pour pouvoir les comparer.
#: `$orderId` (Dart), `${orderId}` (Dart), `<uuid:order_id>` (Channels) et
#: `{order_id}` (OpenAPI) désignent tous la même chose : « un identifiant ici ».
JOKER = "{}"

_PARAM_DART = re.compile(r"\$\{[^}]+\}|\$[A-Za-z_][A-Za-z0-9_]*")
_PARAM_SCHEMA = re.compile(r"\{[^}]+\}")
_PARAM_CHANNELS = re.compile(r"<[^>]+>")


def normalise(chemin: str, motif: re.Pattern[str]) -> str:
    """Efface les paramètres pour ne comparer que la forme de l'adresse."""
    return motif.sub(JOKER, chemin)


def fichiers_dart() -> list[str]:
    """Le code qui s'exécute, et lui seul.

    Restreint à `lib/`, pour deux raisons. `.dart_tool` contient du code généré
    recopié depuis `lib/` : le lire compterait deux fois les mêmes adresses.
    Et `test/` écrit des adresses **pour les éprouver** — un test qui vérifie
    la dérivation d'une URL WebSocket cite un identifiant inventé, que le
    serveur n'a évidemment aucune raison de servir. Les inclure ferait échouer
    ce contrôle sur les tests qui le confortent.
    """
    trouves = []
    for source in SOURCES_DART:
        for dossier, _, noms in os.walk(os.path.join(RACINE, source)):
            # Comparé sur un chemin relatif normalisé : `os.path.join` mêle les
            # séparateurs sous Windows (`C:\…\el-corazon\packages/…/lib/src`),
            # et un test portant sur `os.sep` y laisserait passer tout l'arbre.
            relatif = os.path.relpath(dossier, RACINE).replace(os.sep, "/") + "/"
            if "/lib/" not in relatif:
                continue
            if ".dart_tool/" in relatif or "/build/" in relatif:
                continue
            trouves += [os.path.join(dossier, n) for n in noms if n.endswith(".dart")]
    return trouves


def adresses_demandees() -> tuple[dict[str, set[str]], dict[str, set[str]]]:
    """Adresses HTTP et WebSocket écrites dans le code Dart, et leurs sources.

    Les dépôts du paquet partagé n'écrivent des littéraux d'adresse que pour le
    réseau : on les prend tous. Les applications, elles, mélangent adresses et
    noms de routes de navigation — on n'y retient que ce qui part au client.
    """
    http: dict[str, set[str]] = {}
    websocket: dict[str, set[str]] = {}

    for chemin in fichiers_dart():
        with open(chemin, encoding="utf-8", errors="ignore") as fh:
            contenu = fh.read()
        relatif = os.path.relpath(chemin, RACINE).replace(os.sep, "/")
        dans_le_paquet = relatif.startswith("packages/")

        bruts = (
            LITTERAL.findall(contenu) if dans_le_paquet else APPEL_CLIENT.findall(contenu)
        )
        for brut in bruts:
            if brut.startswith("/ws/") or brut.startswith(ETRANGERS):
                continue
            http.setdefault(normalise(brut, _PARAM_DART), set()).add(relatif)

        for brut in LITTERAL_WS.findall(contenu):
            websocket.setdefault(normalise(brut, _PARAM_DART), set()).add(relatif)

    return http, websocket


def python_du_backend() -> str:
    """L'interpréteur du `.venv` du backend, où vivent Django et drf-spectacular."""
    for suffixe in (os.path.join("Scripts", "python.exe"), os.path.join("bin", "python")):
        candidat = os.path.join(BACKEND, ".venv", suffixe)
        if os.path.exists(candidat):
            return candidat
    return sys.executable


#: Généré dans un sous-processus : `django.setup()` charge tout le projet
#: serveur, ce qu'on ne veut pas faire dans l'interpréteur qui lit du Dart.
_EXTRACTION = """
import json, os, django
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.test")
django.setup()
from drf_spectacular.generators import SchemaGenerator
from config.routing import websocket_urlpatterns

print(json.dumps({
    "http": sorted(SchemaGenerator().get_schema(request=None, public=True)["paths"]),
    "websocket": ["/" + str(p.pattern) for p in websocket_urlpatterns],
}))
"""


def adresses_servies() -> tuple[set[str], set[str]]:
    """Ce que le serveur monte réellement, schéma OpenAPI et routage Channels."""
    resultat = subprocess.run(  # noqa: S603
        [python_du_backend(), "-c", _EXTRACTION],
        cwd=BACKEND,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    if resultat.returncode != 0:
        raise SystemExit(
            "Impossible de générer le schéma du backend.\n"
            "Le `.venv` de `backend/` est-il installé ?\n\n" + resultat.stderr.strip()
        )

    charge = json.loads(resultat.stdout.strip().splitlines()[-1])
    http = {normalise(c, _PARAM_SCHEMA) for c in charge["http"]}
    websocket = {normalise(c, _PARAM_CHANNELS) for c in charge["websocket"]}
    return http, websocket


def rapport(
    titre: str,
    demandees: dict[str, set[str]],
    servies: set[str],
    prefixe: str,
) -> list[tuple[str, set[str]]]:
    orphelines = sorted(
        (adresse, sources)
        for adresse, sources in demandees.items()
        if prefixe + adresse not in servies
    )

    print(f"\n{titre} — {len(demandees)} adresses appelées, {len(servies)} servies")
    if not orphelines:
        print("    toutes servies")
        return []

    for adresse, sources in orphelines:
        print(f"    ABSENTE  {prefixe}{adresse}")
        for source in sorted(sources):
            print(f"             appelée par {source}")
    return orphelines


def main(argv: list[str]) -> int:
    parseur = argparse.ArgumentParser(description=__doc__)
    parseur.add_argument(
        "--lister", action="store_true", help="affiche aussi les routes servies"
    )
    args = parseur.parse_args(argv)

    http_demandees, ws_demandees = adresses_demandees()
    http_servies, ws_servies = adresses_servies()

    if args.lister:
        print("Routes servies par le backend :")
        for adresse in sorted(http_servies | ws_servies):
            print(f"    {adresse}")

    orphelines = rapport("HTTP", http_demandees, http_servies, PREFIXE_API)
    orphelines += rapport("WebSocket", ws_demandees, ws_servies, "")

    if orphelines:
        print(
            f"\nÉCHEC : {len(orphelines)} adresses appelées par l'application "
            f"que le serveur ne sert pas.\n"
            f"Soit la route a été renommée côté serveur, soit le client se trompe "
            f"d'adresse. Les tests des deux côtés resteront verts dans les deux cas."
        )
        return 1

    print("\nToutes les adresses appelées par l'application existent côté serveur.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

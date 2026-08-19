#!/usr/bin/env python3
"""Interroge le backend à l'adresse que l'application déclare, et dit ce qui répond.

Pourquoi ce script existe
-------------------------

`tools/contrat_routes.py` vérifie que les adresses appelées existent dans le
code du serveur. Cela ne dit rien de l'exemplaire que l'application interroge
réellement : une adresse peut être parfaitement écrite et pointer vers un
service éteint, mal configuré, ou servi sans son préfixe `/api/v1`.

Ce contrôle-là ne se fait qu'à l'exécution, et il est passé plusieurs fois à
côté :

* `API_BASE_URL` a été écrit sans schéma. Le navigateur lit alors `localhost:`
  comme un nom de protocole et accuse le CORS, alors que la requête n'a jamais
  quitté l'onglet ;
* le déploiement Render a été servi sans son suffixe `/api/v1`, et toutes les
  routes sont revenues en 404 ;
* le cache du même déploiement était injoignable, et **seules les routes
  publiques** rendaient 500 — les routes protégées mouraient en 401 avant
  d'atteindre le compteur de débit. Cette frontière 401/500 est la signature de
  la panne, et c'est pourquoi les deux sont interrogées ici.

Dart rapporte ces trois cas de la même façon — `ApiException(0, network_error)`
— ce qui les rend indiscernables d'un serveur éteint depuis l'application.
D'où l'intérêt de les distinguer ici, où l'on voit le code de statut.

Ce qu'il fait
-------------

Il lit `API_BASE_URL` dans le `.env` de chaque application, en vérifie la forme,
puis rejoue les requêtes que l'application émet à son démarrage — la carte, les
catégories, le restaurant — plus une route protégée et la sonde de vivacité, qui
servent de témoins.

Ce qu'il ne voit pas
--------------------

Il n'ouvre pas de WebSocket : la poignée de main exige un jeton, donc un compte.
`adresseWebSocket` (voir `apps/fastfood/lib/main.dart`) tient la forme de ces
adresses, et `tools/contrat_routes.py` leur existence côté serveur.

Usage
-----

    python tools/verifier_connexion.py
    python tools/verifier_connexion.py --url http://localhost:8000/api/v1
    python tools/verifier_connexion.py --origine http://localhost:5000

Code de sortie 1 si une application ne peut pas joindre son backend.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request

# Une console Windows encode en cp1252, où tout caractère hors du jeu latin-1
# lève une `UnicodeEncodeError` — et un outil de diagnostic qui **plante en
# rapportant la panne** est pire qu'inutile : il masque ce qu'il venait dire.
# `errors="replace"` dégrade le caractère, jamais l'exécution.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(errors="replace")

#: Racine du dépôt, déduite de l'emplacement de ce script (`tools/`).
RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

APPLICATIONS = ["apps/fastfood", "apps/dely", "apps/admin"]

#: Le restaurant que l'application demande au démarrage
#: (`AppConstants.restaurantSlug`). Le reprendre ici fait rejouer la requête
#: réelle, filtre compris, et non une approximation qui pourrait réussir là où
#: l'application échoue.
RESTAURANT = "el-corazon-lome"

DELAI = 60  # Render endort les services gratuits : le premier appel réveille.

#: Ce que l'application demande, et ce qu'un backend sain répond.
#:
#: La route protégée n'est pas là par acquit de conscience : c'est elle qui
#: distingue « tout est cassé » de « le cache est injoignable ». Un 401 sur
#: `promotions` pendant que `catalog` rend 500 désigne le cache, jamais la base.
#: Depuis que les limiteurs tolèrent la panne de cache (`common/throttling.py`),
#: c'est `auth/login/` qui porte la distinction : il refuse en 503
#: `quota_unavailable` quand le compteur est injoignable, là où les routes
#: publiques passent désormais sans compter.
#:
#: Le dernier booléen dit si une **liste vide** est une panne. Elle l'est
#: presque toujours : les migrations créent les tables, jamais leur contenu, et
#: un catalogue vide rend 200 sur `[]` — ce qui ressemble beaucoup à une panne
#: côté application alors que le serveur va très bien. C'est le défaut qui a
#: envoyé le client chercher `/carts/el-corazon-lome/` sur une base sans
#: restaurant, et recevoir un 404 parfaitement légitime.
SONDES = [
    ("catalog/items/", f"?restaurant__slug={RESTAURANT}", 200, "la carte", True),
    ("catalog/categories/", f"?restaurant__slug={RESTAURANT}", 200, "les catégories", True),
    (f"restaurants/{RESTAURANT}/", "", 200, "l'établissement que l'app adresse", False),
    ("restaurants/", "", 200, "les restaurants", True),
    ("promotions/", "", 401, "témoin : route protégée", False),
    # 405 et non 401 : DRF applique les quotas dans `initial()`, avant de
    # résoudre la méthode. Un GET y franchit donc le compteur puis se fait
    # refuser la méthode — et un 503 à sa place désigne le cache.
    ("auth/login/", "", 405, "témoin : 503 ici = cache injoignable", False),
]


def env_de_lapp(app: str) -> str | None:
    """`API_BASE_URL` tel que le `.env` de l'application le déclare.

    Le fichier n'est pas suivi par git (il porte des clés) : son absence est
    une situation normale sur une copie fraîche, pas une erreur.
    """
    chemin = os.path.join(RACINE, app, ".env")
    try:
        with open(chemin, encoding="utf-8", errors="ignore") as fh:
            for ligne in fh:
                if ligne.strip().startswith("API_BASE_URL="):
                    return ligne.split("=", 1)[1].strip()
    except OSError:
        return None
    return None


def defauts_de_forme(url: str) -> list[str]:
    """Ce qui, dans l'adresse elle-même, empêchera la connexion."""
    defauts = []
    if not re.match(r"^https?://", url):
        defauts.append(
            "pas de schéma `http://` ou `https://` — un navigateur lira le nom "
            "d'hôte comme un protocole et refusera en accusant le CORS"
        )
    if not url.rstrip("/").endswith("/api/v1"):
        defauts.append(
            "ne se termine pas par `/api/v1` — le serveur ne monte l'API que "
            "sous ce préfixe, toutes les routes reviendront en 404"
        )
    return defauts


def interroger(url: str, origine: str | None) -> tuple[int, dict[str, str], bytes] | str:
    """Code, en-têtes et corps — ou la raison pour laquelle il n'y en a pas."""
    requete = urllib.request.Request(url, headers={"Accept": "application/json"})  # noqa: S310
    if origine:
        requete.add_header("Origin", origine)
    try:
        with urllib.request.urlopen(requete, timeout=DELAI) as reponse:  # noqa: S310
            return reponse.status, dict(reponse.headers), reponse.read()
    except urllib.error.HTTPError as exc:
        # Un 401 ou un 404 est une réponse, pas une panne : le serveur a parlé.
        return exc.code, dict(exc.headers), exc.read()
    except urllib.error.URLError as exc:
        return f"injoignable ({exc.reason})"
    except TimeoutError:
        return f"aucune réponse en {DELAI} s"


def est_vide(corps: bytes) -> bool:
    """La réponse est-elle une collection sans élément ?

    Les deux formes du contrat se présentent : une liste nue quand la vue
    renonce à paginer (`pagination_class = None` sur les catégories), et
    l'enveloppe paginée partout ailleurs.
    """
    try:
        charge = json.loads(corps)
    except (json.JSONDecodeError, UnicodeDecodeError):
        return False

    if isinstance(charge, list):
        return not charge
    if isinstance(charge, dict) and "results" in charge:
        return not charge["results"]
    return False


def verifier(app: str, url: str, origine: str | None) -> bool:
    print(f"\n{app} — {url}")

    defauts = defauts_de_forme(url)
    for defaut in defauts:
        print(f"    FORME    {defaut}")

    base = url.rstrip("/")
    ok = not defauts

    for chemin, requete, attendu, quoi, vide_est_une_panne in SONDES:
        resultat = interroger(f"{base}/{chemin}{requete}", origine)
        if isinstance(resultat, str):
            print(f"    ÉCHEC    {chemin:26} {resultat}")
            ok = False
            continue

        code, entetes, corps = resultat
        verdict = "ok  " if code == attendu else "ÉCHEC"
        print(f"    {verdict}     {chemin:26} {code} (attendu {attendu}) — {quoi}")
        if code != attendu:
            ok = False

        if code == attendu and vide_est_une_panne and est_vide(corps):
            print(
                f"             -> collection **vide** : le serveur répond, la base n'a "
                "rien à servir.\n"
                "               Les migrations créent les tables, jamais leur contenu. "
                "L'application\n"
                "               affichera une carte blanche, puis un 404 sur le panier "
                f"de « {RESTAURANT} »."
            )
            ok = False

        if origine and "access-control-allow-origin" not in {k.lower() for k in entetes}:
            print(
                f"             -> aucun `Access-Control-Allow-Origin` pour {origine} : "
                "un navigateur annulera la requête avant que l'application ne la voie"
            )
            ok = False

    # La sonde de vivacité est hors de l'API : elle ne touche ni base ni cache,
    # donc un 200 ici pendant que tout le reste tombe prouve que le serveur est
    # bien debout et que la panne est en aval du démarrage.
    origine_serveur = re.sub(r"/api/v\d+/?$", "", base)
    resultat = interroger(f"{origine_serveur}/health/", origine)
    if isinstance(resultat, str):
        print(f"    ÉCHEC    {'health/':26} {resultat}")
    else:
        print(f"    témoin   {'health/':26} {resultat[0]} — le serveur répond")

    return ok


def main(argv: list[str]) -> int:
    parseur = argparse.ArgumentParser(description=__doc__)
    parseur.add_argument("--url", help="interroge cette adresse au lieu des `.env`")
    parseur.add_argument(
        "--origine",
        help="joue un client navigateur depuis cette origine, et vérifie le CORS",
    )
    args = parseur.parse_args(argv)

    if args.url:
        return 0 if verifier("(--url)", args.url, args.origine) else 1

    tout_va_bien = True
    manquants = []

    for app in APPLICATIONS:
        url = env_de_lapp(app)
        if url is None:
            manquants.append(app)
            continue
        tout_va_bien &= verifier(app, url, args.origine)

    for app in manquants:
        print(f"\n{app} — pas de `.env` (non suivi par git) : rien à vérifier")

    if not tout_va_bien:
        print(
            "\nÉCHEC : une application au moins ne peut pas joindre son backend.\n"
            "Un 500 sur les routes publiques pendant qu'une route protégée rend 401 "
            "désigne le cache, pas la base."
        )
        return 1

    print("\nToutes les applications joignent leur backend.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

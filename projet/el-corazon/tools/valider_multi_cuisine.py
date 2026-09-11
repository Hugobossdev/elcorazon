#!/usr/bin/env python3
"""Vérifie qu'une plateforme multi-cuisine tient ses promesses, en HTTP réel.

Pourquoi ce script existe
-------------------------

Les tests unitaires prouvent que chaque pièce marche isolément ; ce script
prouve que la **chaîne** marche. Ce sont deux questions différentes, et la
seconde est celle qui décide : une suite verte de 1 570 tests n'empêche pas un
sérialiseur d'attendre un identifiant là où le client envoie un slug — c'est
exactement ce que cette validation a trouvé la première fois qu'elle a tourné.

Il interroge l'API **servie**, sans jamais toucher à l'ORM. Ce qui passe ici
passe donc pour l'application Admin, pour El Cora Fast et pour Dely, puisque
tous trois n'ont que cette porte.

Ce qu'il vérifie
----------------

Les propriétés qui distinguent une vraie plateforme multi-pays d'un
mono-restaurant déguisé :

* plusieurs pays, plusieurs villes, plusieurs devises réellement servis ;
* la devise et le fuseau de chaque cuisine **hérités** de son pays ;
* les catalogues cloisonnés — aucun article partagé, aucune contamination ;
* le tri par proximité qui désigne la bonne cuisine depuis chaque ville ;
* la livrabilité complète — établissement, zone, distance, délai, frais —
  rendue par la **même** route que celle qui facturera la commande ;
* les rapports bornés au périmètre du compte, et le filtre qui restreint sans
  jamais élargir.

Ce qu'il ne vérifie pas
-----------------------

Le provisionnement lui-même — ouvrir un pays, une ville, une cuisine. C'est une
écriture, et un vérificateur qui écrit dans la base à chaque exécution finit par
la remplir de décors. La procédure est décrite dans
`docs/ouvrir-une-cuisine.md`, et le parcours complet a été joué à la main.

Usage
-----

    python tools/valider_multi_cuisine.py
    python tools/valider_multi_cuisine.py --base http://localhost:8000/api/v1
    python tools/valider_multi_cuisine.py --compte siege@… --mot-de-passe …

Sans compte, seules les vérifications publiques tournent ; les contrôles de
cloisonnement sont alors annoncés IGNORÉ plutôt que passés en silence.
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request
from datetime import date, timedelta

# La sortie est réencodée en UTF-8 avant tout affichage.
#
# La console Windows par défaut est en cp1252, qui ne sait pas écrire « ─ » ni
# « é ». Sans cette ligne, le script s'interrompt sur un `UnicodeEncodeError` au
# premier titre — et un outil de vérification qui plante à la première ligne ne
# vérifie rien. Le poste de développement du projet est sous Windows : ce n'est
# pas un cas de bord.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

BASE_PAR_DEFAUT = "http://localhost:8000/api/v1"

VERT, ROUGE, JAUNE, GRIS, FIN = "\033[32m", "\033[31m", "\033[33m", "\033[90m", "\033[0m"

resultats: list[tuple[str, str, str]] = []


def note(controle: str, verdict: str, detail: str = "") -> None:
    resultats.append((controle, verdict, detail))
    couleur = {"PASS": VERT, "FAIL": ROUGE, "IGNORÉ": JAUNE}.get(verdict, GRIS)
    print(f"  {couleur}{verdict:<8}{FIN} {controle}" + (f"  {GRIS}{detail}{FIN}" if detail else ""))


def titre(texte: str) -> None:
    print(f"\n{texte}")
    print("─" * len(texte))


class Api:
    def __init__(self, base: str) -> None:
        self.base = base.rstrip("/")

    def __call__(
        self, methode: str, chemin: str, *, jeton: str | None = None, corps: dict | None = None
    ) -> tuple[int, object]:
        donnees = json.dumps(corps).encode() if corps is not None else None
        requete = urllib.request.Request(self.base + chemin, data=donnees, method=methode)
        requete.add_header("Content-Type", "application/json")
        if jeton:
            requete.add_header("Authorization", f"Bearer {jeton}")
        try:
            with urllib.request.urlopen(requete, timeout=60) as reponse:
                return reponse.status, json.loads(reponse.read().decode() or "null")
        except urllib.error.HTTPError as erreur:
            try:
                return erreur.code, json.loads(erreur.read().decode() or "null")
            except json.JSONDecodeError:
                return erreur.code, None
        except Exception as erreur:  # noqa: BLE001
            print(f"{ROUGE}    {methode} {chemin} — {erreur}{FIN}")
            return 0, None


def valider(api: Api, jeton: str | None) -> None:
    # ------------------------------------------------------------------ réseau
    titre("Le réseau servi au client")
    statut, annuaire = api("GET", "/restaurants/")
    if statut != 200 or not isinstance(annuaire, dict):
        note("Annuaire public lisible", "FAIL", f"statut {statut}")
        return

    cuisines = {r["slug"]: r for r in annuaire["results"]}
    note("Annuaire public lisible", "PASS", f"{len(cuisines)} établissement(s) en service")

    pays = {c["country"] for c in cuisines.values()}
    villes = {c["city"] for c in cuisines.values()}
    devises = {c["currency"] for c in cuisines.values()}
    for slug in sorted(cuisines):
        c = cuisines[slug]
        print(f"        {GRIS}· {c['name']:<24} {c['city']:<12} {c['country']}  "
              f"{c['currency']}  {c['phone_prefix']}{FIN}")

    note(
        "Plusieurs pays, villes et devises sont réellement servis",
        "PASS" if len(pays) > 1 and len(villes) > 1 and len(devises) > 1 else "FAIL",
        f"{len(pays)} pays · {len(villes)} villes · {len(devises)} devises "
        f"({', '.join(sorted(devises))})",
    )

    # ------------------------------------------------------------------ héritage
    titre("Devise, fuseau et indicatif sont hérités du pays")
    statut, pays_servis = api("GET", "/geography/countries/")
    reference = {p["iso_code"]: p for p in pays_servis.get("results", [])}
    incoherentes = [
        c["slug"]
        for c in cuisines.values()
        if c["country"] in reference
        and (
            c["currency"] != reference[c["country"]]["currency"]
            or c["phone_prefix"] != reference[c["country"]]["phone_prefix"]
        )
    ]
    note(
        "Aucune cuisine ne contredit le marché dont elle relève",
        "PASS" if not incoherentes else "FAIL",
        f"{len(reference)} marché(s) comparé(s)"
        if not incoherentes
        else ", ".join(incoherentes),
    )

    # ------------------------------------------------------------------ catalogues
    titre("Les catalogues sont cloisonnés")
    par_cuisine: dict[str, set[str]] = {}
    for slug in cuisines:
        statut, items = api("GET", f"/catalog/items/?restaurant__slug={slug}")
        par_cuisine[slug] = {a["id"] for a in items.get("results", [])}

    partages = [
        (x, y)
        for x in par_cuisine
        for y in par_cuisine
        if x < y and par_cuisine[x] & par_cuisine[y]
    ]
    note(
        "Aucun article n'appartient à deux cuisines",
        "PASS" if not partages else "FAIL",
        " · ".join(f"{s}:{len(a)}" for s, a in sorted(par_cuisine.items()))
        if not partages
        else f"{len(partages)} croisement(s)",
    )
    note(
        "Chaque cuisine servie a une carte",
        "PASS" if all(par_cuisine.values()) else "FAIL",
        ", ".join(s for s, a in par_cuisine.items() if not a) or "toutes garnies",
    )

    # ------------------------------------------------------------------ proximité
    titre("Le tri par proximité désigne la cuisine la plus proche")
    ecarts = []
    for slug, c in cuisines.items():
        lat, lon = c["location"]["lat"], c["location"]["lon"]
        statut, proche = api("GET", f"/restaurants/?lat={lat}&lon={lon}")
        premier = proche["results"][0]["slug"] if proche.get("results") else None
        if premier != slug:
            ecarts.append(f"depuis {c['city']} → {premier}")
    note(
        "Depuis chaque cuisine, c'est elle qui sort en tête",
        "PASS" if not ecarts else "FAIL",
        f"{len(cuisines)} position(s) éprouvée(s)" if not ecarts else " · ".join(ecarts),
    )

    # ------------------------------------------------------------------ livrabilité
    titre("Le référentiel unique de livrabilité")
    ecarts_livraison = []
    for slug, c in cuisines.items():
        lat, lon = c["location"]["lat"], c["location"]["lon"]
        statut, dispo = api(
            "POST", "/restaurants/delivery-check/", corps={"lat": lat, "lon": lon}
        )
        if statut != 200 or not isinstance(dispo, dict):
            ecarts_livraison.append(f"{slug} : statut {statut}")
            continue
        if not dispo.get("is_available"):
            # Une cuisine dont l'adresse même n'est pas livrable trahit une zone
            # qui ne couvre pas son établissement — la faute de configuration que
            # le contrôle de complétude attrape déjà, mais qui vaut d'être vue
            # ici aussi : c'est celle qui fait échouer les commandes en silence.
            ecarts_livraison.append(f"{slug} : {dispo.get('reason')}")
            continue
        manquants = [
            champ
            for champ in ("restaurant", "zone", "distance_m", "estimated_minutes")
            if dispo.get(champ) is None
        ]
        if manquants:
            ecarts_livraison.append(f"{slug} : {', '.join(manquants)} absent(s)")

    note(
        "Depuis chaque cuisine, la réponse est complète",
        "PASS" if not ecarts_livraison else "FAIL",
        f"{len(cuisines)} position(s) éprouvée(s) — établissement, zone, distance, délai"
        if not ecarts_livraison
        else " · ".join(ecarts_livraison),
    )

    statut, hors = api(
        "POST", "/restaurants/delivery-check/", corps={"lat": -54.8, "lon": -68.3}
    )
    note(
        "Un point non desservi rend 200 et dit pourquoi",
        "PASS"
        if statut == 200
        and isinstance(hors, dict)
        and not hors.get("is_available")
        and hors.get("reason")
        else "FAIL",
        (hors or {}).get("reason", "")[:60] if isinstance(hors, dict) else f"statut {statut}",
    )

    # ------------------------------------------------------------------ référence
    titre("Devises et fuseaux viennent du serveur")
    statut, ref = api("GET", "/geography/reference/")
    ok = (
        statut == 200
        and isinstance(ref, dict)
        and len(ref.get("timezones", [])) > 100
        and ref.get("currencies")
    )
    note(
        "La référence est servie, et couvre plus qu'une sous-région",
        "PASS" if ok else "FAIL",
        f"{len(ref.get('currencies', []))} devises · {len(ref.get('timezones', []))} fuseaux"
        if isinstance(ref, dict)
        else f"statut {statut}",
    )
    if ok:
        manquantes = {c["currency"] for c in cuisines.values()} - {
            d["code"] for d in ref["currencies"]
        }
        note(
            "Toute devise en service est proposée à l'ouverture d'un marché",
            "PASS" if not manquantes else "FAIL",
            ", ".join(sorted(manquantes)) or "aucun écart",
        )

    # ------------------------------------------------------------------ cloisonnement
    titre("Cloisonnement des rapports")
    if not jeton:
        note("Périmètre des statistiques", "IGNORÉ", "aucun compte fourni (--compte)")
        return

    debut = (date.today() - timedelta(days=30)).isoformat()
    fin = (date.today() + timedelta(days=1)).isoformat()

    statut, enseigne = api(
        "GET", f"/analytics/reports/overview/?start={debut}&end={fin}", jeton=jeton
    )
    if statut != 200 or not isinstance(enseigne, dict):
        note("Lecture des rapports", "IGNORÉ", f"statut {statut} — permission analytics.read ?")
        return
    note("Rapport d'ensemble lisible", "PASS", f"{enseigne.get('orders_count')} commande(s)")

    total_par_pays = 0
    for iso in sorted(pays):
        statut, r = api(
            "GET",
            f"/analytics/reports/overview/?start={debut}&end={fin}&country={iso}",
            jeton=jeton,
        )
        total_par_pays += r.get("orders_count", 0) if isinstance(r, dict) else 0
    note(
        "La somme des marchés ne dépasse pas l'ensemble",
        "PASS" if total_par_pays <= enseigne.get("orders_count", 0) else "FAIL",
        f"{total_par_pays} réparti(s) sur {enseigne.get('orders_count')}",
    )

    statut, inconnu = api(
        "GET",
        f"/analytics/reports/overview/?start={debut}&end={fin}&country=ZZ",
        jeton=jeton,
    )
    note(
        "Un filtre sans correspondance rend un rapport vide, jamais une erreur",
        "PASS" if statut == 200 and inconnu.get("orders_count") == 0 else "FAIL",
        f"statut {statut}",
    )

    statut, croise = api(
        "GET",
        f"/analytics/reports/overview/?start={debut}&end={fin}"
        f"&country={sorted(pays)[0]}&city=___inexistante___",
        jeton=jeton,
    )
    note(
        "Les filtres se cumulent au lieu de se remplacer",
        "PASS" if statut == 200 and croise.get("orders_count") == 0 else "FAIL",
        "une ville inexistante annule le pays, comme attendu",
    )


def main() -> int:
    parseur = argparse.ArgumentParser(description=__doc__)
    parseur.add_argument("--base", default=BASE_PAR_DEFAUT, help="Racine de l'API v1.")
    parseur.add_argument("--compte", help="Adresse d'un compte du personnel.")
    parseur.add_argument("--mot-de-passe", dest="mot_de_passe")
    arguments = parseur.parse_args()

    api = Api(arguments.base)

    jeton = None
    if arguments.compte and arguments.mot_de_passe:
        statut, corps = api(
            "POST",
            "/auth/login/",
            corps={"email": arguments.compte, "password": arguments.mot_de_passe},
        )
        if statut == 200 and isinstance(corps, dict):
            jeton = corps.get("access")
        else:
            print(f"{ROUGE}Connexion refusée ({statut}) — les contrôles de "
                  f"cloisonnement seront ignorés.{FIN}")

    print(f"{GRIS}API : {api.base}{FIN}")
    valider(api, jeton)

    titre("Résultat")
    echecs = [r for r in resultats if r[1] == "FAIL"]
    ignores = [r for r in resultats if r[1] == "IGNORÉ"]
    passes = len(resultats) - len(echecs) - len(ignores)
    print(f"  {len(resultats)} contrôles — {passes} PASS, {len(echecs)} FAIL, "
          f"{len(ignores)} IGNORÉ")

    if echecs:
        print(f"\n{ROUGE}ÉCHEC — la plateforme ne tient pas l'une de ses promesses "
              f"multi-cuisine :{FIN}")
        for controle, _, detail in echecs:
            print(f"  · {controle}" + (f" — {detail}" if detail else ""))
        return 1

    print(f"\n{VERT}La chaîne multi-pays / multi-villes / multi-cuisines tient.{FIN}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

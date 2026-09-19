import 'package:flutter/foundation.dart';

import 'package:admin/presentation/statut_commande.dart';
import 'package:admin/presentation/tri_commandes.dart';

/// Fenêtre temporelle proposée par l'écran de supervision.
///
/// Reprise de `filtres_commandes.dart`, qui la portait pour l'écran secondaire.
/// Elle devient ici un filtre **de requête** et non plus d'affichage : la borne
/// part au serveur (`placed_at__gte`), sans quoi « aujourd'hui » ne filtrerait
/// que ce que la page courante contenait déjà.
enum FenetreCommandes {
  aujourdHui("Aujourd'hui"),
  septJours('7 derniers jours'),
  trenteJours('30 derniers jours'),
  toutes('Tout l’historique'),

  /// Du … au …, choisis au calendrier. Les bornes vivent dans
  /// [FiltresCommandes.du] et [FiltresCommandes.au] : une fenêtre glissante se
  /// calcule depuis « maintenant », une période choisie ne dépend de rien.
  periode('Période choisie');

  const FenetreCommandes(this.libelle);

  final String libelle;

  /// La borne basse de la fenêtre, ou `null` pour [toutes].
  ///
  /// `null` et non « il y a dix ans » : une borne inventée exclurait
  /// silencieusement les commandes plus anciennes, et personne ne saurait
  /// pourquoi le total ne correspond pas.
  DateTime? depuis([DateTime? maintenant]) {
    final now = maintenant ?? DateTime.now();
    return switch (this) {
      FenetreCommandes.aujourdHui => DateTime(now.year, now.month, now.day),
      FenetreCommandes.septJours => now.subtract(const Duration(days: 7)),
      FenetreCommandes.trenteJours => now.subtract(const Duration(days: 30)),
      FenetreCommandes.toutes => null,
      // Portée par les filtres, pas par la fenêtre — voir [periode].
      FenetreCommandes.periode => null,
    };
  }
}

/// Ce qui définit la sélection affichée par la supervision des commandes.
///
/// Pourquoi ce type existe
/// -----------------------
///
/// Les filtres étaient éparpillés : le statut dans l'onglet actif, la recherche
/// dans un champ de l'écran, la fenêtre temporelle dans un second écran, le tri
/// dans une boîte de dialogue. Tant que tout tenait en mémoire, cela
/// fonctionnait — chacun filtrait la même liste déjà chargée.
///
/// Avec la pagination, ce n'est plus tenable : la sélection doit partir au
/// serveur **en un seul jeu**, et un changement de n'importe lequel de ses
/// termes doit ramener à la première page. Les rassembler dans une valeur
/// immuable rend les deux automatiques — on ne peut pas changer un filtre sans
/// produire une nouvelle sélection, ni oublier d'en transmettre un.
///
/// [tri] fait exception : il reste **local**. Le serveur trie déjà par date
/// décroissante, et un tri par total appliqué à une page de vingt lignes trie
/// ces vingt lignes — ce qui est ce que l'opérateur voit et ce qu'il attend
/// quand il clique sur une colonne. Le prétendre global serait faux ; l'écran
/// le dit.
@immutable
class FiltresCommandes {
  const FiltresCommandes({
    this.statut,
    this.recherche = '',
    this.fenetre = FenetreCommandes.trenteJours,
    this.tri = TriCommandes.dateDecroissante,
    this.restaurantSlug,
    this.paysIso,
    this.villeSlug,
    this.zoneId,
    this.du,
    this.au,
    this.clientId,
    this.clientNom,
    this.taillePage = 20,
  });

  /// `null` = tous les statuts. Le serveur ne connaît que `exact` sur ce
  /// champ : une sélection multiple demanderait autant de requêtes.
  final StatutCommande? statut;

  /// Porte sur la référence, le destinataire, son téléphone et l'adresse —
  /// c'est ce que déclare `search_fields` côté serveur.
  final String recherche;

  final FenetreCommandes fenetre;

  /// Tri d'affichage, appliqué à la page reçue. Voir la note de classe.
  final TriCommandes tri;

  /// Restreint à un établissement. `null` = tout le périmètre du compte, ce que
  /// le serveur cloisonne de toute façon.
  final String? restaurantSlug;

  /// Pays → ville → zone, sur la géographie **figée** de la commande : là où
  /// elle a été prise, pas là où la cuisine est rattachée aujourd'hui.
  ///
  /// Hiérarchiques : changer de pays efface la ville et la zone, changer de
  /// ville efface la zone (voir [copyWith]). Garder une zone d'Abidjan sous
  /// « Togo » produirait une liste vide sans raison visible.
  final String? paysIso;
  final String? villeSlug;
  final String? zoneId;

  /// Bornes d'une [FenetreCommandes.periode], en **jours** du poste : `du` à
  /// minuit, `au` jusqu'à la dernière milliseconde de sa journée. Ignorées
  /// pour toute autre fenêtre.
  ///
  /// La borne haute n'existait pas (`jusqua` rendait toujours `null`) alors
  /// que le serveur accepte `placed_at__lte` depuis l'origine : « les
  /// commandes de la semaine dernière » n'était pas une question qu'on
  /// pouvait poser.
  final DateTime? du;
  final DateTime? au;

  /// Restreint aux commandes d'un client (`customer`, filtre serveur).
  ///
  /// [clientNom] ne part pas au serveur : il sert à afficher le filtre posé
  /// sans relire la fiche du client.
  final String? clientId;
  final String? clientNom;

  /// Plafonné à 100 par le serveur (`max_page_size`).
  final int taillePage;

  DateTime? get depuis {
    if (fenetre != FenetreCommandes.periode) return fenetre.depuis();
    final debut = du;
    return debut == null ? null : DateTime(debut.year, debut.month, debut.day);
  }

  DateTime? get jusqua {
    final fin = au;
    if (fenetre != FenetreCommandes.periode || fin == null) return null;
    return DateTime(fin.year, fin.month, fin.day, 23, 59, 59, 999);
  }

  /// La période telle qu'on la dit : « 7 derniers jours », « du 01/09/2026
  /// au 07/09/2026 ». Une période choisie se nomme par ses dates — « période
  /// choisie » ne dit pas laquelle.
  String get libellePeriode {
    if (fenetre != FenetreCommandes.periode) return fenetre.libelle;
    final debut = du;
    final fin = au;
    if (debut == null && fin == null) return fenetre.libelle;
    if (fin == null) return 'depuis le ${_jour(debut!)}';
    if (debut == null) return "jusqu'au ${_jour(fin)}";
    if (_jour(debut) == _jour(fin)) return 'le ${_jour(debut)}';
    return 'du ${_jour(debut)} au ${_jour(fin)}';
  }

  static String _jour(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  /// Y a-t-il autre chose que les valeurs d'ouverture ? Sert à proposer
  /// « Effacer les filtres » seulement quand il y a quelque chose à effacer.
  bool get actifs =>
      statut != null ||
      recherche.trim().isNotEmpty ||
      fenetre != FenetreCommandes.trenteJours ||
      restaurantSlug != null ||
      paysIso != null ||
      villeSlug != null ||
      zoneId != null ||
      clientId != null;

  /// Combien de filtres sont posés — affiché sur la pastille du bouton.
  int get nombreActifs => [
        statut != null,
        recherche.trim().isNotEmpty,
        fenetre != FenetreCommandes.trenteJours,
        restaurantSlug != null,
        paysIso != null,
        villeSlug != null,
        zoneId != null,
        clientId != null,
      ].where((pose) => pose).length;

  FiltresCommandes copyWith({
    StatutCommande? statut,
    bool effacerStatut = false,
    String? recherche,
    FenetreCommandes? fenetre,
    TriCommandes? tri,
    String? restaurantSlug,
    bool effacerRestaurant = false,
    String? paysIso,
    bool effacerPays = false,
    String? villeSlug,
    bool effacerVille = false,
    String? zoneId,
    bool effacerZone = false,
    DateTime? du,
    DateTime? au,
    String? clientId,
    String? clientNom,
    bool effacerClient = false,
    int? taillePage,
  }) {
    // Une période choisie n'a de bornes que tant qu'elle est la fenêtre : en
    // revenant à « 7 derniers jours », les dates d'avant n'ont plus de sens,
    // et les garder les ferait réapparaître au prochain choix de période.
    final nouvelleFenetre = fenetre ?? this.fenetre;
    final estPeriode = nouvelleFenetre == FenetreCommandes.periode;
    // La hiérarchie : un étage qui change emporte ceux d'en dessous.
    final nouveauPays = effacerPays ? null : (paysIso ?? this.paysIso);
    final paysChange = nouveauPays != this.paysIso;
    final nouvelleVille = (effacerVille || (paysChange && villeSlug == null))
        ? null
        : (villeSlug ?? this.villeSlug);
    final villeChange = nouvelleVille != this.villeSlug;
    final nouvelleZone = (effacerZone || (villeChange && zoneId == null))
        ? null
        : (zoneId ?? this.zoneId);

    return FiltresCommandes(
      statut: effacerStatut ? null : (statut ?? this.statut),
      recherche: recherche ?? this.recherche,
      fenetre: nouvelleFenetre,
      tri: tri ?? this.tri,
      restaurantSlug: effacerRestaurant ? null : (restaurantSlug ?? this.restaurantSlug),
      paysIso: nouveauPays,
      villeSlug: nouvelleVille,
      zoneId: nouvelleZone,
      du: estPeriode ? (du ?? this.du) : null,
      au: estPeriode ? (au ?? this.au) : null,
      clientId: effacerClient ? null : (clientId ?? this.clientId),
      clientNom: effacerClient ? null : (clientNom ?? this.clientNom),
      taillePage: taillePage ?? this.taillePage,
    );
  }

  /// Deux sélections qui donnent la même requête serveur.
  ///
  /// [tri] en est **exclu** : il ne part pas au serveur, et le compter ici
  /// ferait relancer une requête identique à chaque changement de tri.
  bool memeRequeteQue(FiltresCommandes autre) =>
      statut == autre.statut &&
      recherche.trim() == autre.recherche.trim() &&
      fenetre == autre.fenetre &&
      restaurantSlug == autre.restaurantSlug &&
      paysIso == autre.paysIso &&
      villeSlug == autre.villeSlug &&
      zoneId == autre.zoneId &&
      // Les bornes **saisies**, pas les bornes calculées : pour une fenêtre
      // glissante, `depuis` se recalcule depuis l'horloge à chaque appel, et
      // deux sélections identiques ne seraient jamais égales — chaque frappe
      // relancerait la requête.
      (fenetre != FenetreCommandes.periode || (du == autre.du && au == autre.au)) &&
      clientId == autre.clientId &&
      taillePage == autre.taillePage;

  @override
  bool operator ==(Object other) =>
      other is FiltresCommandes && memeRequeteQue(other) && tri == other.tri;

  @override
  int get hashCode =>
      Object.hash(
        statut,
        recherche.trim(),
        fenetre,
        tri,
        restaurantSlug,
        paysIso,
        villeSlug,
        zoneId,
        du,
        au,
        clientId,
        taillePage,
      );
}

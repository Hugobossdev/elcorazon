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
  toutes('Tout l’historique');

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

  /// Plafonné à 100 par le serveur (`max_page_size`).
  final int taillePage;

  DateTime? get depuis => fenetre.depuis();
  DateTime? get jusqua => null;

  /// Y a-t-il autre chose que les valeurs d'ouverture ? Sert à proposer
  /// « Effacer les filtres » seulement quand il y a quelque chose à effacer.
  bool get actifs =>
      statut != null ||
      recherche.trim().isNotEmpty ||
      fenetre != FenetreCommandes.trenteJours ||
      restaurantSlug != null;

  /// Combien de filtres sont posés — affiché sur la pastille du bouton.
  int get nombreActifs => [
        statut != null,
        recherche.trim().isNotEmpty,
        fenetre != FenetreCommandes.trenteJours,
        restaurantSlug != null,
      ].where((pose) => pose).length;

  FiltresCommandes copyWith({
    StatutCommande? statut,
    bool effacerStatut = false,
    String? recherche,
    FenetreCommandes? fenetre,
    TriCommandes? tri,
    String? restaurantSlug,
    bool effacerRestaurant = false,
    int? taillePage,
  }) {
    return FiltresCommandes(
      statut: effacerStatut ? null : (statut ?? this.statut),
      recherche: recherche ?? this.recherche,
      fenetre: fenetre ?? this.fenetre,
      tri: tri ?? this.tri,
      restaurantSlug: effacerRestaurant ? null : (restaurantSlug ?? this.restaurantSlug),
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
      taillePage == autre.taillePage;

  @override
  bool operator ==(Object other) =>
      other is FiltresCommandes && memeRequeteQue(other) && tri == other.tri;

  @override
  int get hashCode =>
      Object.hash(statut, recherche.trim(), fenetre, tri, restaurantSlug, taillePage);
}

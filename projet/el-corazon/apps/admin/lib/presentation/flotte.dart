import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

import 'package:admin/presentation/statut_livreur.dart';

/// Les listes de l'écran des livreurs, et ce qui range chacune.
///
/// ## Ce que cette logique remplace
///
/// Jusqu'au 24 septembre 2026, la recherche, le filtre et le tri de l'écran
/// écrivaient dans `DriverManagementService.filteredDrivers`, que **rien ne
/// lisait** : les onglets passaient par `getDriversByStatus`, qui ne tenait
/// compte d'aucun des trois. On tapait un nom, rien ne bougeait.
///
/// Les onglets ne gardaient en outre que les dossiers **validés** : un livreur
/// suspendu ou refusé ne figurait nulle part dans le back-office, si bien
/// qu'une suspension ne pouvait plus être levée — le seul chemin vers
/// « Réactiver » passait par une carte qu'on ne voyait jamais.
enum OngletFlotte {
  disponibles('Disponibles'),
  horsLigne('Hors ligne'),

  /// Suspendus, dossiers refusés, et dossiers validés dont le compte ne
  /// reçoit plus de course alors qu'il est en ligne.
  horsService('Hors service'),

  /// Les dossiers validés, du mieux noté au moins bien noté.
  classement('Classement');

  const OngletFlotte(this.libelle);

  final String libelle;
}

/// Ordre d'une liste de livreurs. [OngletFlotte.classement] ne le suit pas :
/// son ordre est sa raison d'être.
enum TriFlotte {
  nomCroissant('Nom (A-Z)'),
  nomDecroissant('Nom (Z-A)'),
  note('Meilleure note'),
  livraisons('Plus de livraisons');

  const TriFlotte(this.libelle);

  final String libelle;
}

extension AppartenanceOnglet on eccore.CourierProfile {
  /// Sorti du service — ce que ni « Disponibles » ni « Hors ligne » ne montrent.
  ///
  /// Un dossier **en attente** n'en fait pas partie : il n'est jamais entré en
  /// service, et c'est le centre de validation qui l'instruit.
  bool get estHorsService =>
      verificationStatus == 'suspended' ||
      verificationStatus == 'rejected' ||
      (estValide && statut == StatutLivreur.indisponible);

  /// Pourquoi ce livreur est hors service.
  String get motifHorsService => switch (verificationStatus) {
        'suspended' => 'Suspendu',
        'rejected' => 'Dossier refusé',
        _ => 'Compte inactif',
      };

  bool appartientA(OngletFlotte onglet) => switch (onglet) {
        OngletFlotte.disponibles => estValide && statut == StatutLivreur.disponible,
        OngletFlotte.horsLigne => estValide && statut == StatutLivreur.horsLigne,
        OngletFlotte.horsService => estHorsService,
        OngletFlotte.classement => estValide,
      };

  /// Nom, courriel, téléphone ou plaque — ce qu'un superviseur a sous la main
  /// quand un client appelle au sujet d'un livreur.
  bool correspondA(String recherche) {
    final cle = recherche.trim().toLowerCase();
    if (cle.isEmpty) return true;
    return fullName.toLowerCase().contains(cle) ||
        email.toLowerCase().contains(cle) ||
        phone.replaceAll(' ', '').contains(cle.replaceAll(' ', '')) ||
        vehiclePlate.toLowerCase().contains(cle);
  }
}

/// Les livreurs d'un onglet, filtrés par [recherche] et rangés par [tri].
///
/// Rend toujours une **nouvelle** liste : l'ancien tri se faisait en place sur
/// la flotte chargée, que d'autres écrans lisent.
List<eccore.CourierProfile> livreursDeLOnglet(
  Iterable<eccore.CourierProfile> flotte,
  OngletFlotte onglet, {
  String recherche = '',
  TriFlotte tri = TriFlotte.nomCroissant,
}) {
  final retenus = [
    for (final livreur in flotte)
      if (livreur.appartientA(onglet) && livreur.correspondA(recherche)) livreur,
  ];

  if (onglet == OngletFlotte.classement) {
    retenus.sort(_parClassement);
    return retenus;
  }

  retenus.sort(
    switch (tri) {
      TriFlotte.nomCroissant => _parNom,
      TriFlotte.nomDecroissant => (a, b) => _parNom(b, a),
      TriFlotte.note => _parClassement,
      TriFlotte.livraisons => (a, b) {
          final ecart = b.deliveriesCompleted.compareTo(a.deliveriesCompleted);
          return ecart != 0 ? ecart : _parNom(a, b);
        },
    },
  );
  return retenus;
}

int _parNom(eccore.CourierProfile a, eccore.CourierProfile b) =>
    a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());

/// Les livreurs notés d'abord, de la meilleure note à la moins bonne ; à note
/// égale, le plus expérimenté. Un livreur jamais noté a une moyenne de 0 :
/// sans cette règle, il passerait après un livreur noté 1,5 — et avant lui
/// dans l'autre sens, ce qui serait pire.
int _parClassement(eccore.CourierProfile a, eccore.CourierProfile b) {
  final notes = (b.ratingCount > 0 ? 1 : 0).compareTo(a.ratingCount > 0 ? 1 : 0);
  if (notes != 0) return notes;
  final note = b.ratingAverage.compareTo(a.ratingAverage);
  if (note != 0) return note;
  final livraisons = b.deliveriesCompleted.compareTo(a.deliveriesCompleted);
  if (livraisons != 0) return livraisons;
  return _parNom(a, b);
}

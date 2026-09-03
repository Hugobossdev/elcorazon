import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';

/// Disponibilité d'un livreur, telle que le siège la lit.
///
/// Trois états, parce que le dossier livreur (`CourierProfile`) n'en dit pas
/// davantage. L'énumération remplacée en comptait un quatrième — « en
/// livraison » — que rien ne produisait : il se déduirait des affectations, et
/// `AssignmentViewSet` est réservé au livreur qui appelle (`IsCourier`). Le
/// back-office n'a aucune route qui les liste.
///
/// Ce n'était pas sans conséquence : un onglet, une entrée de légende, un
/// compteur du tableau de bord et une rotation de marqueur sur la carte
/// s'appuyaient dessus. L'onglet « En livraison » était vide en toutes
/// circonstances, et le compteur affichait zéro.
enum StatutLivreur {
  horsLigne('Hors ligne', Icons.person_off, Colors.grey),
  disponible('Disponible', Icons.delivery_dining, Colors.green),
  indisponible('Indisponible', Icons.block, Colors.red);

  const StatutLivreur(this.libelle, this.icone, this.couleur);

  /// Depuis le dossier livreur.
  ///
  /// L'ordre des tests compte : un dossier suspendu ou rejeté rend le livreur
  /// indisponible quoi qu'il annonce par ailleurs. C'est `canAcceptOrders`, et
  /// non `isOnline`, qui dit s'il recevra des courses (L1) — un dossier en
  /// attente de validation reste inéligible même en ligne.
  factory StatutLivreur.depuisDossier(eccore.CourierProfile dossier) {
    if (dossier.verificationStatus == 'suspended' ||
        dossier.verificationStatus == 'rejected') {
      return StatutLivreur.indisponible;
    }
    if (dossier.canAcceptOrders) return StatutLivreur.disponible;
    return dossier.isOnline ? StatutLivreur.indisponible : StatutLivreur.horsLigne;
  }

  final String libelle;
  final IconData icone;
  final Color couleur;
}

/// Ce que le siège lit d'un dossier livreur, au-delà de ses champs bruts.
extension LectureDossierLivreur on eccore.CourierProfile {
  StatutLivreur get statut => StatutLivreur.depuisDossier(this);

  /// Dossier instruit et validé — le seul cas où le livreur travaille.
  bool get estValide => verificationStatus == 'approved';

  /// Position connue, quand le livreur a émis au moins un relevé.
  bool get aUnePosition => lastLatitude != null && lastLongitude != null;

  /// Depuis quand la position affichée date — ou `null` si aucune n'est connue.
  ///
  /// ## Pourquoi le siège en a besoin
  ///
  /// La carte de supervision posait un repère de la même façon qu'un relevé
  /// date de huit secondes ou de onze minutes. Le siège lisait donc comme un
  /// suivi en direct la dernière position d'un livreur dont le téléphone
  /// s'était éteint, dont le GPS avait été coupé, ou qui traversait une zone
  /// sans réseau — et n'appelait pas, puisqu'il croyait savoir où il était.
  ///
  /// Une carte qui ment sur sa fraîcheur est pire qu'une carte vide.
  eccore.FraicheurPosition? get fraicheurPosition {
    final quand = lastLocationAt;
    if (!aUnePosition || quand == null) return null;
    return eccore.FraicheurPosition.depuis(quand);
  }

  /// « il y a 8 s », « il y a 5 min ». Vide si aucune position n'est connue.
  String get ageDeLaPosition {
    final quand = lastLocationAt;
    if (!aUnePosition || quand == null) return '';
    return eccore.ageLisible(quand);
  }

  /// Phrase à afficher sous le statut, sur la carte comme dans la fiche.
  ///
  /// Un livreur sans aucun relevé n'est pas un livreur dont la position est
  /// vieille : le distinguer évite de faire chercher un point qui n'a jamais
  /// existé.
  String get libelleDePosition {
    if (!aUnePosition) return 'Aucune position transmise';
    final age = ageDeLaPosition;
    return switch (fraicheurPosition) {
      eccore.FraicheurPosition.fraiche => 'Position $age',
      eccore.FraicheurPosition.retardee => 'Dernière position $age',
      eccore.FraicheurPosition.perdue => 'Position figée — dernière $age',
      null => 'Position transmise, sans horodatage',
    };
  }

  /// Couleur du bandeau de fraîcheur — verte tant que le suivi est en direct.
  Color get couleurDeFraicheur => switch (fraicheurPosition) {
        eccore.FraicheurPosition.fraiche => Colors.green,
        eccore.FraicheurPosition.retardee => Colors.orange,
        eccore.FraicheurPosition.perdue => Colors.red,
        null => Colors.grey,
      };
}

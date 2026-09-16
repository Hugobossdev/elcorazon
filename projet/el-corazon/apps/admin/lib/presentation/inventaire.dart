import 'dart:math';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

/// Ce que les écrans d'inventaire affichent et décident — sans widget.
///
/// Pourquoi ce fichier existe
/// --------------------------
///
/// Les règles qui gouvernent ces écrans sont celles du serveur : le plafond
/// décide si une perte passe seule, le quatre-yeux interdit de trancher sa
/// propre demande, la clé d'idempotence protège une réception rejouée. Aucune
/// n'est **appliquée** ici — le serveur s'en charge. Ce qui vit ici, c'est la
/// façon de les **dire**, écrite une fois et testée, plutôt que recopiée dans
/// quatre `build`.

/// Le libellé d'un type de mouvement — `MovementKind` du serveur.
String libelleMouvement(String kind) => switch (kind) {
      'purchase' => 'Achat',
      'receipt' => 'Réception',
      'consumption' => 'Consommation',
      'waste' => 'Perte',
      'adjustment' => 'Correction',
      'transfer' => 'Transfert',
      'reservation' => 'Réservation',
      'release' => 'Libération',
      _ => kind,
    };

/// Le libellé d'une dimension — ce que l'on mesure.
String libelleDimension(String dimension) => switch (dimension) {
      'mass' => 'Masse',
      'volume' => 'Volume',
      'count' => 'Unités',
      _ => dimension,
    };

/// Le libellé d'une unité de saisie.
String libelleUnite(String unit) => unit == 'unit' ? 'unité(s)' : unit;

/// Le statut d'une demande de correction.
String libelleStatutDemande(String status) => switch (status) {
      'pending' => 'En attente',
      'approved' => 'Validée',
      'rejected' => 'Refusée',
      _ => status,
    };

/// « 4 000 F / kg » — le coût moyen tel que le serveur le tient, ou « coût
/// inconnu » tant qu'aucune livraison facturée n'est entrée.
String libelleCout(eccore.Money? cout, String uniteDeCout) {
  if (cout == null) return 'Coût inconnu';
  final unite = uniteDeCout == 'unit' ? 'unité' : uniteDeCout;
  return '${cout.format()} / $unite';
}

/// Ce qu'une déclaration a produit, dit à la personne qui vient de la faire.
///
/// Les deux issues n'appellent pas le même geste. Écrite : c'est fait. En
/// attente : c'est fait **de son côté**, et quelqu'un d'autre doit valider — le
/// dire évite qu'elle redéclare en croyant que rien n'est passé.
String issueDeDeclaration(eccore.Declaration declaration, {required String quoi}) {
  final demande = declaration.request;
  if (declaration.isPendingApproval && demande != null) {
    final valeur = demande.estimatedValue;
    final raison = valeur == null
        ? 'le coût de cet ingrédient est encore inconnu'
        : 'sa valeur (${valeur.format()}) dépasse ce qui '
            'peut passer sans validation';
    return '$quoi en attente de validation : $raison. Un responsable doit la valider '
        'avant qu’elle ne sorte du stock.';
  }
  final mouvement = declaration.movement;
  final quantite = mouvement?.quantity.label ?? '';
  return '$quoi enregistrée${quantite.isEmpty ? '' : ' ($quantite)'}.';
}

/// Ce compte peut-il trancher cette demande ?
///
/// Deux conditions, et la seconde n'est pas une permission : `inventory.approve`
/// **et** ne pas en être l'auteur. Le serveur refuse le second cas quoi qu'il
/// arrive ; ne pas proposer le bouton évite un refus certain.
({bool autorise, String? raison}) peutTrancher({
  required eccore.AdjustmentRequest demande,
  required String? compteId,
  required bool aLaPermission,
}) {
  if (!demande.isPending) {
    return (autorise: false, raison: 'Demande déjà ${libelleStatutDemande(demande.status).toLowerCase()}.');
  }
  if (!aLaPermission) {
    return (autorise: false, raison: 'Valider demande la permission inventory.approve.');
  }
  if (compteId != null && demande.requestedById == compteId) {
    return (
      autorise: false,
      raison: 'Vous avez déclaré cette correction : une autre personne doit la valider.',
    );
  }
  return (autorise: true, raison: null);
}

/// Les unités proposées pour une dimension, la plus usuelle en premier — on
/// reçoit en kilogrammes, on retire en grammes.
List<String> unitesDeSaisie(String dimension, {bool pourUneLivraison = false}) {
  final unites = eccore.Quantity.unitsByDimension[dimension] ?? const ['unit'];
  return pourUneLivraison ? unites.reversed.toList() : unites;
}

/// Convertit un prix saisi en unités majeures (« 12 000 ») en montant du
/// serveur, ou `null` si le champ est vide.
///
/// Refuse les décimales pour une devise qui n'en a pas : « 12 000,50 F » est
/// une faute de frappe, pas un prix, et l'arrondir en silence ferait entrer au
/// coût moyen une valeur que personne n'a lue sur la facture.
eccore.Money? prixDuLot(String saisie, {required String devise}) {
  // Les décimales de la devise, lues sur le socle sans flottant : une unité
  // majeure vaut 1 en francs CFA, 100 en euros.
  final decimales = '${eccore.Money.fromMajorUnits(1, devise).amountMinor}'.length - 1;
  final texte = saisie.replaceAll(RegExp(r'[\s  ]'), '').replaceAll(',', '.');
  if (texte.isEmpty) return null;
  final motif = decimales == 0 ? RegExp(r'^\d+$') : RegExp('^\\d+(\\.\\d{1,$decimales})?\$');
  if (!motif.hasMatch(texte)) {
    throw FormatException('« $saisie » n’est pas un prix.', saisie);
  }
  final morceaux = texte.split('.');
  final fraction = (morceaux.length > 1 ? morceaux[1] : '').padRight(decimales, '0');
  final mineur = int.parse('${morceaux.first}$fraction');
  return eccore.Money(amountMinor: mineur, currency: devise);
}

/// La clé d'idempotence d'une **tentative** d'écriture de stock.
///
/// Elle naît à l'ouverture du formulaire et ne change pas quand on réappuie
/// après une coupure : c'est ce qui permet au serveur de rendre la réception
/// déjà enregistrée au lieu de créditer deux fois la chambre froide. Tirée à
/// chaque envoi, elle ne protégerait que contre un rejeu que personne ne fait —
/// le défaut exact qu'avait la caisse du client (`cle_de_tentative.dart`).
///
/// Tirée de `Random.secure()` plutôt que d'un paquet de plus : 128 bits
/// d'aléa suffisent à une clé qu'on ne devine pas et qu'on ne compare qu'à
/// elle-même.
class CleDeTentative {
  CleDeTentative() : valeur = _tirer();

  /// Pour les tests, qui ont besoin d'une valeur qu'ils reconnaissent.
  CleDeTentative.avec(this.valeur);

  final String valeur;

  static String _tirer() {
    final aleatoire = Random.secure();
    return List.generate(16, (_) => aleatoire.nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();
  }
}

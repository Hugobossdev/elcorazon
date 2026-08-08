import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

/// Fabrique de commandes pour les tests du back-office.
///
/// Les montants sont en francs CFA : la devise n'a pas de décimales, donc
/// l'unité mineure de l'ADR-007 vaut l'unité majeure.
///
/// Elle construit une `eccore.Order` par son JSON plutôt que par son
/// constructeur : c'est cette lecture-là que le produit exécute, et un test qui
/// court-circuite le décodage ne dit rien de ce qui arrive du serveur.
Map<String, dynamic> montantJson(int mineur) =>
    {'amount': '$mineur', 'currency': 'XOF'};

eccore.Order commandeDeTest({
  String id = 'commande-1',
  String reference = 'CMD-0001',
  String statut = 'preparing',
  String destinataire = 'Awa',
  String adresse = 'Rue du Commerce',
  String repere = '',
  String moyenPaiement = 'mobile_money',
  String consignes = '',
  int totalCfa = 4500,
  DateTime? passeeLe,
  DateTime? livraisonPrevueLe,
  List<dynamic>? lignes,
  List<dynamic>? transitions,
}) {
  final quand = (passeeLe ?? DateTime(2026, 8, 8, 12)).toIso8601String();

  return eccore.Order.fromJson({
    'id': id,
    'reference': reference,
    'restaurant': 'el-corazon-lome',
    'restaurant_name': 'El Corazón Lomé',
    'status': statut,
    'allowed_transitions': const <String>[],
    'subtotal': montantJson(totalCfa),
    'delivery_fee': montantJson(0),
    'discount': montantJson(0),
    'total': montantJson(totalCfa),
    'payment_method': moyenPaiement,
    'delivery_address_line': adresse,
    'delivery_landmark': repere,
    'delivery_location': {'lat': 6.14, 'lon': 1.23},
    'recipient_name': destinataire,
    'recipient_phone': '+22890000000',
    'placed_at': quand,
    'estimated_delivery_at': livraisonPrevueLe?.toIso8601String(),
    'delivery_instructions': consignes,
    'lines': lignes ?? const [],
    'status_events': transitions ?? const [],
    'created_at': quand,
    'updated_at': quand,
  });
}

/// Une ligne de commande, avec ses options figées.
Map<String, dynamic> ligneJson({
  String nom = 'Poulet braisé',
  int quantite = 2,
  int prixUnitaireCfa = 1000,
  String note = '',
  List<dynamic>? options,
}) =>
    {
      'id': 'ligne-1',
      'menu_item': 'article-1',
      'item_name': nom,
      'item_image': null,
      'unit_price': montantJson(prixUnitaireCfa),
      'quantity': quantite,
      'line_total': montantJson(prixUnitaireCfa * quantite),
      'notes': note,
      'options': options ?? const [],
    };

/// Une transition de statut telle que le serveur la journalise.
Map<String, dynamic> transitionJson(String vers, DateTime quand) => {
      'id': 'transition-$vers',
      'from_status': '',
      'to_status': vers,
      'reason': '',
      'created_at': quand.toIso8601String(),
    };

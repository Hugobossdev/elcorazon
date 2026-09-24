import 'package:flutter/material.dart';

import 'package:elcorazon_core/elcorazon_core.dart'
    show AppEmojiToken, AppEmojis, Journal;

class Order {
  final String id;

  /// La référence lisible que le serveur attribue — « EC-4921 ».
  ///
  /// Distincte de [id], qui est un UUID. L'écran de détail affichait jusqu'ici
  /// les huit premiers caractères de l'UUID faute de mieux ; le serveur
  /// publiait pourtant `reference` depuis le début, et c'est ce numéro-là que
  /// le support demande au téléphone.
  final String reference;

  final String userId;
  final List<OrderItem> items;
  final double subtotal;
  final double deliveryFee;

  /// Devise ISO 4217 de la commande, figée par le serveur à sa création
  /// (ADR-007). Vide si inconnue — une commande relue d'un ancien cache.
  /// Les montants ci-dessus sont exprimés dans cette devise : une commande
  /// passée à Accra reste en GHS, même consultée depuis Lomé.
  final String currency;
  final double total;
  final OrderStatus status;
  final String deliveryAddress;

  /// Point de livraison, tel que le client l'a posé sur la carte au moment de
  /// commander (`delivery_location`, obligatoire côté serveur).
  ///
  /// ## Ce que son absence coûtait
  ///
  /// L'adaptateur les jetait, et l'écran de suivi **re-géocodait
  /// [deliveryAddress]** pour retrouver le point : un aller vers Google à
  /// chaque ouverture, pour recalculer une valeur que le serveur avait déjà, et
  /// qu'il tenait plus juste — c'est la position exacte que le client a
  /// choisie, pas l'interprétation d'une ligne d'adresse. Quand le géocodage
  /// échouait (clé absente, quota, libellé imprécis — « en face de la
  /// pharmacie »), la carte n'avait plus de destination du tout : pas de
  /// repère client, pas de tracé, pas de distance.
  ///
  /// Nuls seulement pour une commande construite localement hors serveur.
  final double? deliveryLatitude;
  final double? deliveryLongitude;

  /// Point d'enlèvement — d'où part le repas.
  ///
  /// Nuls tant que le serveur ne rend pas `restaurant_location`. La carte
  /// montre alors deux repères au lieu de trois.
  final double? restaurantLatitude;
  final double? restaurantLongitude;

  final String? deliveryNotes;
  final String? promoCode;
  final double discount;
  final PaymentMethod paymentMethod;

  /// Ce que le serveur a réellement encaissé (`amount_paid`), dans la devise
  /// de la commande.
  ///
  /// `0` quand rien ne l'a été — le serveur rend alors `null`, et c'est la
  /// même chose. `null` **ici** a un autre sens : la commande vient d'un cache
  /// écrit avant que ce champ existe, et on ne sait pas. Le moyen de paiement
  /// ne le dit jamais — voir `presentation/reglement_commande.dart`.
  final double? montantRegle;
  final DateTime orderTime;
  final DateTime createdAt;
  final DateTime? estimatedDeliveryTime;
  final String? deliveryPersonId;
  final List<OrderStatusUpdate> statusUpdates;
  final String? specialInstructions;

  Order({
    required this.id,
    required this.userId,
    required this.items,
    required this.subtotal,
    required this.total, required this.deliveryAddress, required this.paymentMethod, required this.orderTime, required this.createdAt, this.reference = '', this.deliveryFee = 0.0, this.currency = '',
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.restaurantLatitude,
    this.restaurantLongitude,
    this.status = OrderStatus.pending,
    this.deliveryNotes,
    this.promoCode,
    this.discount = 0.0,
    this.montantRegle,
    this.estimatedDeliveryTime,
    this.deliveryPersonId,
    this.statusUpdates = const [],
    this.specialInstructions,
  });

  Order copyWith({
    String? id,
    String? reference,
    String? userId,
    List<OrderItem>? items,
    double? subtotal,
    double? deliveryFee,
    String? currency,
    double? total,
    OrderStatus? status,
    String? deliveryAddress,
    double? deliveryLatitude,
    double? deliveryLongitude,
    double? restaurantLatitude,
    double? restaurantLongitude,
    String? deliveryNotes,
    String? promoCode,
    double? discount,
    PaymentMethod? paymentMethod,
    double? montantRegle,
    DateTime? orderTime,
    DateTime? createdAt,
    DateTime? estimatedDeliveryTime,
    String? deliveryPersonId,
    List<OrderStatusUpdate>? statusUpdates,
    String? specialInstructions,
  }) {
    return Order(
      id: id ?? this.id,
      reference: reference ?? this.reference,
      userId: userId ?? this.userId,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      currency: currency ?? this.currency,
      total: total ?? this.total,
      status: status ?? this.status,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryLatitude: deliveryLatitude ?? this.deliveryLatitude,
      deliveryLongitude: deliveryLongitude ?? this.deliveryLongitude,
      restaurantLatitude: restaurantLatitude ?? this.restaurantLatitude,
      restaurantLongitude: restaurantLongitude ?? this.restaurantLongitude,
      deliveryNotes: deliveryNotes ?? this.deliveryNotes,
      promoCode: promoCode ?? this.promoCode,
      discount: discount ?? this.discount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      montantRegle: montantRegle ?? this.montantRegle,
      orderTime: orderTime ?? this.orderTime,
      createdAt: createdAt ?? this.createdAt,
      estimatedDeliveryTime:
          estimatedDeliveryTime ?? this.estimatedDeliveryTime,
      deliveryPersonId: deliveryPersonId ?? this.deliveryPersonId,
      statusUpdates: statusUpdates ?? this.statusUpdates,
      specialInstructions: specialInstructions ?? this.specialInstructions,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reference': reference,
      'userId': userId,
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'currency': currency,
      'total': total,
      'status': status.toString(),
      'deliveryAddress': deliveryAddress,
      'deliveryNotes': deliveryNotes,
      'promoCode': promoCode,
      'discount': discount,
      'paymentMethod': paymentMethod.toString(),
      'montantRegle': montantRegle,
      'orderTime': orderTime.toIso8601String(),
      'estimatedDeliveryTime': estimatedDeliveryTime?.toIso8601String(),
      'deliveryPersonId': deliveryPersonId,
      'specialInstructions': specialInstructions,
    };
  }

  /// Le statut d'une carte lue — même règle que l'adaptateur Django : une
  /// valeur inconnue se dit inconnue, elle ne retombe plus sur `pending`.
  static OrderStatus _parseOrderStatus(dynamic status) =>
      OrderStatus.depuisServeur(status?.toString() ?? '');

  factory Order.fromMap(Map<String, dynamic> map) {
    // Parser les order_items si présents
    List<OrderItem> items = [];
    if (map['order_items'] != null) {
      if (map['order_items'] is List) {
        final itemsList = map['order_items'] as List;
        items = itemsList
            .map((item) {
              try {
                if (item == null || item is! Map<String, dynamic>) {
                  return null;
                }
                return OrderItem(
                  menuItemId: item['menu_item_id']?.toString() ?? item['menuItemId']?.toString() ?? '',
                  menuItemName: item['menu_item_name']?.toString() ?? item['menuItemName']?.toString() ?? '',
                  name: item['name']?.toString() ?? item['menu_item_name']?.toString() ?? item['menuItemName']?.toString() ?? '',
                  category: item['category']?.toString() ?? '',
                  menuItemImage: item['menu_item_image']?.toString() ?? item['menuItemImage']?.toString() ?? '',
                  quantity: (item['quantity'] as num?)?.toInt() ?? 1,
                  unitPrice: (item['unit_price'] as num?)?.toDouble() ?? (item['unitPrice'] as num?)?.toDouble() ?? 0.0,
                  totalPrice: (item['total_price'] as num?)?.toDouble() ?? (item['totalPrice'] as num?)?.toDouble() ?? 0.0,
                  customizations: item['customizations'] is Map 
                      ? Map<String, String>.from((item['customizations'] as Map).map(
                          (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
                        ),)
                      : const {},
                  notes: item['notes']?.toString(),
                );
              } catch (e) {
                Journal.trace('⚠️ Erreur parsing order item: $e');
                return null;
              }
            })
            .whereType<OrderItem>()
            .toList();
      }
    }
    
    return Order(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? map['userId'] ?? '',
      items: items,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (map['delivery_fee'] as num?)?.toDouble() ??
          (map['deliveryFee'] as num?)?.toDouble() ??
          0.0,
      currency: map['currency'] as String? ?? '',
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      status: _parseOrderStatus(map['status']),
      deliveryAddress: map['delivery_address'] ?? map['deliveryAddress'] ?? '',
      deliveryNotes: map['delivery_notes'] ?? map['deliveryNotes'],
      promoCode: map['promo_code'] ?? map['promoCode'],
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) =>
            e.toString().split('.').last == map['payment_method'] ||
            e.toString().split('.').last == map['paymentMethod'],
        orElse: () => PaymentMethod.cash,
      ),
      montantRegle: (map['montantRegle'] as num?)?.toDouble(),
      orderTime: map['order_time'] != null
          ? DateTime.parse(map['order_time'])
          : map['orderTime'] != null
              ? DateTime.parse(map['orderTime'])
              : DateTime.now(),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : map['createdAt'] != null
              ? DateTime.parse(map['createdAt'])
              : DateTime.now(),
      estimatedDeliveryTime: map['estimated_delivery_time'] != null
          ? DateTime.parse(map['estimated_delivery_time'])
          : map['estimatedDeliveryTime'] != null
              ? DateTime.parse(map['estimatedDeliveryTime'])
              : null,
      deliveryPersonId: map['delivery_person_id'] ?? map['deliveryPersonId'],
      specialInstructions: map['special_instructions'] ??
          map['specialInstructions'] ??
          map['notes'],
    );
  }
}

class OrderItem {
  final String menuItemId;
  final String menuItemName;
  final String name;
  final String category;
  final String menuItemImage;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final Map<String, String> customizations;
  final String? notes;

  OrderItem({
    required this.menuItemId,
    required this.menuItemName,
    required this.name,
    required this.category,
    required this.menuItemImage,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.customizations = const {},
    this.notes,
  });

  OrderItem copyWith({
    String? menuItemId,
    String? menuItemName,
    String? name,
    String? category,
    String? menuItemImage,
    int? quantity,
    double? unitPrice,
    double? totalPrice,
    Map<String, String>? customizations,
    String? notes,
  }) {
    return OrderItem(
      menuItemId: menuItemId ?? this.menuItemId,
      menuItemName: menuItemName ?? this.menuItemName,
      name: name ?? this.name,
      category: category ?? this.category,
      menuItemImage: menuItemImage ?? this.menuItemImage,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      customizations: customizations ?? this.customizations,
      notes: notes ?? this.notes,
    );
  }
}

class OrderStatusUpdate {
  final OrderStatus status;
  final DateTime timestamp;
  final String? message;
  final String? updatedBy;

  OrderStatusUpdate({
    required this.status,
    required this.timestamp,
    this.message,
    this.updatedBy,
  });
}

/// Statut d'une commande — **les valeurs du serveur** (`apps.orders.states.
/// OrderStatus`), confrontées à lui par `tools/contrat_vocabulaire.py`.
///
/// `refunded` et `failed` y figuraient sans contrepartie serveur : le
/// remboursement est un mouvement de paiement, et ce qui n'aboutit pas est
/// **annulé**, avec un motif. Six écrans les traitaient pour rien.
enum OrderStatus {
  pending('pending'),
  confirmed('confirmed'),
  preparing('preparing'),
  ready('ready'),
  pickedUp('picked_up'),
  onTheWay('on_the_way'),
  delivered('delivered'),
  cancelled('cancelled'),

  /// Une valeur que **cette version** ne connaît pas — le serveur a pu en
  /// ajouter une depuis. Elle retombait sur [pending] : une commande en route
  /// se serait affichée « En attente ». Elle se dit désormais inconnue,
  /// plutôt que de prétendre un état que le serveur n'a pas donné.
  inconnu.horsVocabulaire();

  const OrderStatus(this._valeur);
  const OrderStatus.horsVocabulaire() : _valeur = '';

  final String _valeur;

  /// Depuis la valeur rendue par le serveur.
  static OrderStatus depuisServeur(String valeur) {
    for (final statut in values) {
      if (statut != inconnu && statut._valeur == valeur) return statut;
    }
    return inconnu;
  }
}

extension OrderStatusExtension on OrderStatus {
  /// La valeur du serveur ; vide pour [OrderStatus.inconnu].
  String get dbValue => _valeur;

  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'En attente';
      case OrderStatus.confirmed:
        return 'Confirmée';
      case OrderStatus.preparing:
        return 'En préparation';
      case OrderStatus.ready:
        return 'Prête';
      case OrderStatus.pickedUp:
        return 'Récupérée';
      case OrderStatus.onTheWay:
        return 'En livraison';
      case OrderStatus.delivered:
        return 'Livrée';
      case OrderStatus.cancelled:
        return 'Annulée';
      case OrderStatus.inconnu:
        return 'Statut inconnu';
    }
  }

  /// L'illustration de l'étape, pour les endroits qui en portent une.
  ///
  /// Elle remplace un `emoji` qui rendait des chaînes Unicode — dont deux
  /// séquences ZWJ (`'👨‍🍳'`, `'🏃‍♂️'`) que les Android d'avant 2019
  /// décomposent en glyphes séparés. Voir `StatutCommande.illustration`, dont
  /// c'est le pendant sur le vocabulaire qui remplace ce modèle.
  ///
  /// Les listes de commandes n'en font pas usage : `DeliveryStatusCard` porte
  /// déjà une pastille d'icône et sa `StatusChip`, et une illustration par
  /// ligne serait du bruit.
  AppEmojiToken get illustration {
    switch (this) {
      case OrderStatus.pending:
        return AppEmojis.newOrder;
      case OrderStatus.confirmed:
        return AppEmojis.orderConfirmed;
      case OrderStatus.preparing:
        return AppEmojis.preparing;
      case OrderStatus.ready:
        return AppEmojis.orderReady;
      case OrderStatus.pickedUp:
        return AppEmojis.courier;
      case OrderStatus.onTheWay:
        return AppEmojis.delivery;
      case OrderStatus.delivered:
        return AppEmojis.delivered;
      case OrderStatus.cancelled:
        return AppEmojis.error;
      case OrderStatus.inconnu:
        return AppEmojis.warning;
    }
  }
}

enum PaymentMethod {
  mobileMoney,
  creditCard,
  debitCard,
  wallet,
  cash,
}

extension PaymentMethodExtension on PaymentMethod {
  /// Libellés du serveur (`apps.orders.models.PaymentMethod`). Ils étaient en
  /// anglais, et le portefeuille portait le nom d'une autre marque
  /// (« FastFoodGo Wallet »), hérité d'un gabarit.
  ///
  /// Carte de crédit et de débit partent toutes deux en `card` : le serveur
  /// n'en connaît qu'une, et le client lit donc le même libellé.
  String get displayName {
    switch (this) {
      case PaymentMethod.mobileMoney:
        return 'Mobile Money';
      case PaymentMethod.creditCard:
      case PaymentMethod.debitCard:
        return 'Carte bancaire';
      case PaymentMethod.wallet:
        return 'Portefeuille';
      case PaymentMethod.cash:
        return 'Espèces à la livraison';
    }
  }

  /// Ce que recouvre le moyen, sans nommer d'opérateur : les réseaux mobile
  /// money et les cartes acceptés dépendent du prestataire et du pays, que
  /// l'application ne connaît pas. « Orange Money, MTN Money, Moov Money »
  /// s'affichait jusqu'ici au Togo, où deux des trois n'opèrent pas.
  String get description {
    switch (this) {
      case PaymentMethod.mobileMoney:
        return 'Depuis votre compte mobile money';
      case PaymentMethod.creditCard:
      case PaymentMethod.debitCard:
        return 'Paiement en ligne par carte';
      case PaymentMethod.wallet:
        return 'Solde de votre portefeuille';
      case PaymentMethod.cash:
        return 'Paiement au livreur, à la réception';
    }
  }

  /// L'icône du moyen de paiement.
  ///
  /// Une icône, et pas une illustration du pack : le règlement est un choix
  /// fonctionnel, coché dans une liste de boutons radio à côté d'une adresse
  /// et d'un mode de livraison qui portent eux aussi des icônes.
  ///
  /// L'`emoji` qu'elle remplace donnait par ailleurs le même `'💳'` à
  /// [PaymentMethod.creditCard] et à [PaymentMethod.debitCard] : les deux
  /// lignes de la liste étaient impossibles à distinguer au premier coup
  /// d'œil. Le débit prend maintenant sa propre icône.
  IconData get icone {
    switch (this) {
      case PaymentMethod.mobileMoney:
        return Icons.smartphone_rounded;
      case PaymentMethod.creditCard:
        return Icons.credit_card_rounded;
      case PaymentMethod.debitCard:
        return Icons.credit_score_rounded;
      case PaymentMethod.wallet:
        return Icons.account_balance_wallet_rounded;
      case PaymentMethod.cash:
        return Icons.payments_rounded;
    }
  }
}

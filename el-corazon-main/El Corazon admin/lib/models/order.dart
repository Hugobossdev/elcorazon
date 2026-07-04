import 'package:flutter/foundation.dart';

class Order {
  final String id;
  final String userId;
  final List<OrderItem> items;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final OrderStatus status;
  final String deliveryAddress;
  final String? deliveryNotes;
  final String? promoCode;
  final double discount;
  final PaymentMethod paymentMethod;
  final DateTime orderTime;
  final DateTime createdAt;
  final DateTime? estimatedDeliveryTime;
  final String? deliveryPersonId;
  final List<OrderStatusUpdate> statusUpdates;
  final String? specialInstructions;
  final String? paymentTransactionId;

  Order({
    required this.id,
    required this.userId,
    required this.items,
    required this.subtotal,
    this.deliveryFee = 5.0,
    required this.total,
    this.status = OrderStatus.pending,
    required this.deliveryAddress,
    this.deliveryNotes,
    this.promoCode,
    this.discount = 0.0,
    required this.paymentMethod,
    required this.orderTime,
    required this.createdAt,
    this.estimatedDeliveryTime,
    this.deliveryPersonId,
    this.statusUpdates = const [],
    this.specialInstructions,
    this.paymentTransactionId,
  });

  Order copyWith({
    String? id,
    String? userId,
    List<OrderItem>? items,
    double? subtotal,
    double? deliveryFee,
    double? total,
    OrderStatus? status,
    String? deliveryAddress,
    String? deliveryNotes,
    String? promoCode,
    double? discount,
    PaymentMethod? paymentMethod,
    DateTime? orderTime,
    DateTime? createdAt,
    DateTime? estimatedDeliveryTime,
    String? deliveryPersonId,
    List<OrderStatusUpdate>? statusUpdates,
    String? specialInstructions,
    String? paymentTransactionId,
  }) {
    return Order(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      total: total ?? this.total,
      status: status ?? this.status,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      deliveryNotes: deliveryNotes ?? this.deliveryNotes,
      promoCode: promoCode ?? this.promoCode,
      discount: discount ?? this.discount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      orderTime: orderTime ?? this.orderTime,
      createdAt: createdAt ?? this.createdAt,
      estimatedDeliveryTime:
          estimatedDeliveryTime ?? this.estimatedDeliveryTime,
      deliveryPersonId: deliveryPersonId ?? this.deliveryPersonId,
      statusUpdates: statusUpdates ?? this.statusUpdates,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      paymentTransactionId: paymentTransactionId ?? this.paymentTransactionId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'total': total,
      'status': status.toString(),
      'deliveryAddress': deliveryAddress,
      'deliveryNotes': deliveryNotes,
      'promoCode': promoCode,
      'discount': discount,
      'paymentMethod': paymentMethod.toString(),
      'orderTime': orderTime.toIso8601String(),
      'estimatedDeliveryTime': estimatedDeliveryTime?.toIso8601String(),
      'deliveryPersonId': deliveryPersonId,
      'specialInstructions': specialInstructions,
      'paymentTransactionId': paymentTransactionId,
    };
  }

  static OrderStatus _parseOrderStatus(dynamic status) {
    if (status == null) return OrderStatus.pending;

    final statusString = status.toString().toLowerCase();

    switch (statusString) {
      case 'pending':
        return OrderStatus.pending;
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'preparing':
        return OrderStatus.preparing;
      case 'ready':
        return OrderStatus.ready;
      case 'pickedup':
      case 'picked_up':
        return OrderStatus.pickedUp;
      case 'ontheway':
      case 'on_the_way':
        return OrderStatus.onTheWay;
      case 'delivered':
        return OrderStatus.delivered;
      case 'cancelled':
        return OrderStatus.cancelled;
      case 'refunded':
        return OrderStatus.refunded;
      case 'failed':
        return OrderStatus.failed;
      default:
        return OrderStatus.pending;
    }
  }

  static PaymentMethod _parsePaymentMethod(dynamic method) {
    if (method == null) return PaymentMethod.cash;

    final methodString = method.toString().toLowerCase();

    switch (methodString) {
      case 'mobile_money':
        return PaymentMethod.mobileMoney;
      case 'credit_card':
        return PaymentMethod.creditCard;
      case 'debit_card':
        return PaymentMethod.debitCard;
      case 'wallet':
        return PaymentMethod.wallet;
      case 'cash':
        return PaymentMethod.cash;
      default:
        return PaymentMethod.cash;
    }
  }

  factory Order.fromMap(Map<String, dynamic> map) {
    // Fonction helper pour parser les dates
    DateTime parseOrderDateTime(dynamic dateValue, DateTime defaultValue) {
      if (dateValue == null) return defaultValue;

      try {
        if (dateValue is DateTime) {
          return dateValue;
        } else if (dateValue is String) {
          return DateTime.parse(dateValue);
        } else {
          return DateTime.parse(dateValue.toString());
        }
      } catch (e) {
        debugPrint(
          '⚠️ Erreur parsing date: $e, value: $dateValue, using default',
        );
        return defaultValue;
      }
    }

    // Valider les champs requis de la commande
    final orderId = map['id']?.toString();
    if (orderId == null || orderId.isEmpty) {
      throw Exception('Order.fromMap: id is required but was null or empty');
    }

    final orderUserId = map['user_id']?.toString() ?? map['userId']?.toString();
    if (orderUserId == null || orderUserId.isEmpty) {
      throw Exception(
        'Order.fromMap: user_id is required but was null or empty',
      );
    }

    final deliveryAddress = (map['delivery_address']?.toString() ??
            map['deliveryAddress']?.toString() ??
            '')
        .trim();
    if (deliveryAddress.isEmpty) {
      debugPrint(
        '⚠️ Order.fromMap: delivery_address is empty for order $orderId, using default',
      );
      // Utiliser une adresse par défaut si vide pour éviter les erreurs
      // En production, on pourrait récupérer l'adresse depuis le profil utilisateur
    }

    final now = DateTime.now();

    // Parse order items if they exist in the map
    List<OrderItem> items = [];
    if (map['order_items'] != null) {
      if (map['order_items'] is List) {
        final itemsList = map['order_items'] as List;
        debugPrint(
          '📦 Parsing ${itemsList.length} article(s) pour la commande ${orderId.substring(0, 8)}',
        );

        int successCount = 0;
        int errorCount = 0;

        items = itemsList
            .map((item) {
              try {
                // Vérifier que l'item est valide
                if (item == null) {
                  errorCount++;
                  debugPrint('   ⚠️ Article null (ignoré)');
                  return null;
                }

                if (item is! Map<String, dynamic>) {
                  errorCount++;
                  debugPrint(
                    '   ⚠️ Article n\'est pas un Map: ${item.runtimeType} (ignoré)',
                  );
                  return null;
                }

                final orderItem = OrderItem.fromMap(item);
                successCount++;
                // Log seulement le premier article pour éviter la verbosité
                if (successCount == 1) {
                  debugPrint(
                    '   ✅ Premier article parsé: ${orderItem.quantity}x ${orderItem.menuItemName}',
                  );
                }
                return orderItem;
              } catch (e, stackTrace) {
                errorCount++;
                debugPrint('   ❌ Erreur parsing article: $e');
                // Log détaillé seulement pour le premier article en erreur
                if (errorCount == 1) {
                  debugPrint('      Stack trace: $stackTrace');
                  debugPrint('      Données: ${item.toString()}');
                }
                // Ne pas rethrow, mais retourner null pour continuer avec les autres articles
                return null;
              }
            })
            .whereType<OrderItem>() // Filtrer les nulls
            .toList();

        // Résumé du parsing
        if (errorCount > 0) {
          debugPrint(
            '   ⚠️ Résumé: $successCount article(s) parsé(s), $errorCount erreur(s)',
          );
        } else {
          debugPrint(
            '   ✅ Tous les articles parsés avec succès ($successCount total)',
          );
        }
      } else {
        debugPrint(
          '⚠️ order_items n\'est pas une liste pour la commande ${orderId.substring(0, 8)}: ${map['order_items'].runtimeType}',
        );
      }
    } else {
      debugPrint(
        '⚠️ Aucun order_items dans la commande ${orderId.substring(0, 8)}',
      );
      // Si aucun order_items, on créé quand même la commande avec une liste vide
      // Cela peut arriver pour des commandes incomplètes ou en cours de création
    }

    // Validation: s'assurer qu'on a au moins un item ou que la commande peut exister sans items
    if (items.isEmpty) {
      debugPrint('⚠️ Commande ${orderId.substring(0, 8)} créée sans articles');
    }

    // Parse status updates
    List<OrderStatusUpdate> statusUpdates = [];
    final updatesRaw = map['status_updates'] ?? map['statusUpdates'];
    if (updatesRaw is List) {
      try {
        statusUpdates = updatesRaw
            .map((update) {
              if (update == null) return null;
              if (update is! Map) return null;

              return OrderStatusUpdate(
                status: _parseOrderStatus(update['status']),
                timestamp: parseOrderDateTime(
                  update['timestamp'] ?? update['created_at'],
                  now,
                ),
                message: update['message']?.toString(),
                updatedBy: update['updated_by']?.toString() ??
                    update['updatedBy']?.toString(),
              );
            })
            .whereType<OrderStatusUpdate>()
            .toList();
      } catch (e) {
        debugPrint('⚠️ Erreur parsing status_updates: $e');
      }
    }

    return Order(
      id: orderId,
      userId: orderUserId,
      items: items,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (map['delivery_fee'] as num?)?.toDouble() ??
          (map['deliveryFee'] as num?)?.toDouble() ??
          5.0,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      status: _parseOrderStatus(map['status']),
      deliveryAddress:
          deliveryAddress.isEmpty ? 'Adresse non spécifiée' : deliveryAddress,
      deliveryNotes:
          map['delivery_notes']?.toString() ?? map['deliveryNotes']?.toString(),
      promoCode: map['promo_code']?.toString() ?? map['promoCode']?.toString(),
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: _parsePaymentMethod(
        map['payment_method'] ?? map['paymentMethod'],
      ),
      orderTime: parseOrderDateTime(map['order_time'] ?? map['orderTime'], now),
      createdAt: parseOrderDateTime(map['created_at'] ?? map['createdAt'], now),
      estimatedDeliveryTime: map['estimated_delivery_time'] != null
          ? parseOrderDateTime(map['estimated_delivery_time'], now)
          : map['estimatedDeliveryTime'] != null
              ? parseOrderDateTime(map['estimatedDeliveryTime'], now)
              : null,
      deliveryPersonId: map['delivery_person_id']?.toString() ??
          map['deliveryPersonId']?.toString(),
      specialInstructions: map['special_instructions']?.toString() ??
          map['specialInstructions']?.toString(),
      paymentTransactionId: map['payment_transaction_id']?.toString() ??
          map['paymentTransactionId']?.toString(),
      statusUpdates: statusUpdates,
    );
  }
}

class OrderItem {
  final String menuItemId;
  final String menuItemName;
  final String name;
  final String categoryId;
  final String menuItemImage;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final Map<String, String> customizations;
  final Map<String, dynamic>
      customizationsData; // Structure complète des customizations
  final String? notes;

  OrderItem({
    required this.menuItemId,
    required this.menuItemName,
    required this.name,
    required this.categoryId,
    required this.menuItemImage,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.customizations = const {},
    this.customizationsData = const {},
    this.notes,
  });

  OrderItem copyWith({
    String? menuItemId,
    String? menuItemName,
    String? name,
    String? categoryId,
    String? menuItemImage,
    int? quantity,
    double? unitPrice,
    double? totalPrice,
    Map<String, String>? customizations,
    Map<String, dynamic>? customizationsData,
    String? notes,
  }) {
    return OrderItem(
      menuItemId: menuItemId ?? this.menuItemId,
      menuItemName: menuItemName ?? this.menuItemName,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      menuItemImage: menuItemImage ?? this.menuItemImage,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      customizations: customizations ?? this.customizations,
      customizationsData: customizationsData ?? this.customizationsData,
      notes: notes ?? this.notes,
    );
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    // Debug logging pour identifier les problèmes
    if (map['menu_item_id'] == null && map['menuItemId'] == null) {
      debugPrint(
        '⚠️ OrderItem: menu_item_id manquant. Clés disponibles: ${map.keys.join(', ')}',
      );
    }

    // Valider les champs requis
    final menuItemId =
        map['menuItemId']?.toString() ?? map['menu_item_id']?.toString() ?? '';
    final menuItemName = map['menuItemName']?.toString() ??
        map['menu_item_name']?.toString() ??
        '';
    final name = map['name']?.toString() ?? '';
    final category = map['category']?.toString() ?? '';

    // Valider que les champs requis ne sont pas vides
    if (menuItemId.isEmpty) {
      throw Exception(
        'OrderItem.fromMap: menu_item_id is required but was null or empty. Available keys: ${map.keys.join(', ')}',
      );
    }
    if (menuItemName.isEmpty && name.isEmpty) {
      throw Exception(
        'OrderItem.fromMap: menu_item_name or name is required but both were null or empty',
      );
    }

    // Gérer customizations qui peut être JSONB (Map) avec structure complexe
    // Structure attendue: { "size": ["id1"], "ingredients": ["id2", "id3"], "extras": ["id4"], etc. }
    // ou format simple: { "size": "Grande", "ingredients": "Tomate, Oignon" }
    Map<String, dynamic> customizationsData = {};
    if (map['customizations'] != null) {
      if (map['customizations'] is Map) {
        try {
          final customMap = map['customizations'] as Map;
          // Convertir toutes les valeurs en format lisible
          customizationsData = Map<String, dynamic>.from(
            customMap.map((key, value) {
              if (value is List) {
                // Si c'est une liste, la convertir en chaîne
                return MapEntry(
                  key.toString(),
                  value.map((e) => e.toString()).toList(),
                );
              } else {
                return MapEntry(key.toString(), value?.toString() ?? '');
              }
            }),
          );
        } catch (e) {
          debugPrint('⚠️ Erreur parsing customizations: $e');
          customizationsData = {};
        }
      } else if (map['customizations'] is String) {
        // Si c'est une chaîne JSON, essayer de la parser
        try {
          // Pour l'instant, on le laisse vide si c'est une chaîne
          debugPrint(
            '⚠️ customizations est une chaîne, non parsé: ${map['customizations']}',
          );
        } catch (e) {
          debugPrint('⚠️ Erreur parsing customizations string: $e');
        }
      }
    }

    // Convertir en Map<String, String> pour compatibilité, mais garder la structure originale
    Map<String, String> customizationsMap = {};
    customizationsData.forEach((key, value) {
      if (value is List) {
        customizationsMap[key] = value.join(', ');
      } else {
        customizationsMap[key] = value.toString();
      }
    });

    // Parser la quantité avec gestion d'erreur robuste
    int quantity = 1;
    try {
      if (map['quantity'] is int) {
        quantity = map['quantity'] as int;
      } else if (map['quantity'] is num) {
        quantity = (map['quantity'] as num).toInt();
      } else if (map['quantity'] != null) {
        quantity = int.tryParse(map['quantity'].toString()) ?? 1;
      }
      if (quantity <= 0) quantity = 1; // Valeur minimale
    } catch (e) {
      debugPrint('⚠️ Erreur parsing quantity: $e, using default: 1');
      quantity = 1;
    }

    // Parser les prix avec gestion d'erreur robuste
    double unitPrice = 0.0;
    try {
      if (map['unitPrice'] is num) {
        unitPrice = (map['unitPrice'] as num).toDouble();
      } else if (map['unit_price'] is num) {
        unitPrice = (map['unit_price'] as num).toDouble();
      } else if (map['unitPrice'] != null || map['unit_price'] != null) {
        unitPrice = double.tryParse(
              (map['unitPrice'] ?? map['unit_price']).toString(),
            ) ??
            0.0;
      }
    } catch (e) {
      debugPrint('⚠️ Erreur parsing unitPrice: $e, using default: 0.0');
      unitPrice = 0.0;
    }

    double totalPrice = 0.0;
    try {
      if (map['totalPrice'] is num) {
        totalPrice = (map['totalPrice'] as num).toDouble();
      } else if (map['total_price'] is num) {
        totalPrice = (map['total_price'] as num).toDouble();
      } else if (map['totalPrice'] != null || map['total_price'] != null) {
        totalPrice = double.tryParse(
              (map['totalPrice'] ?? map['total_price']).toString(),
            ) ??
            0.0;
      } else {
        // Calculer le total si non fourni
        totalPrice = unitPrice * quantity;
      }
    } catch (e) {
      debugPrint(
        '⚠️ Erreur parsing totalPrice: $e, calculating from unitPrice * quantity',
      );
      totalPrice = unitPrice * quantity;
    }

    return OrderItem(
      menuItemId: menuItemId,
      menuItemName: menuItemName.isNotEmpty ? menuItemName : name,
      name: name.isNotEmpty ? name : menuItemName,
      categoryId: category.isNotEmpty ? category : 'Non catégorisé',
      menuItemImage: map['menuItemImage']?.toString() ??
          map['menu_item_image']?.toString() ??
          '',
      quantity: quantity,
      unitPrice: unitPrice,
      totalPrice: totalPrice,
      customizations: customizationsMap,
      customizationsData: customizationsData,
      notes: map['notes']?.toString(),
    );
  }

  /// Retourne une liste formatée des customizations pour l'affichage
  List<String> getFormattedCustomizations() {
    final List<String> formatted = [];

    // Catégories de customizations avec leurs labels
    final categoryLabels = {
      'size': 'Taille',
      'ingredient': 'Ingrédient',
      'ingredients': 'Ingrédients',
      'sauce': 'Sauce',
      'sauces': 'Sauces',
      'extra': 'Supplément',
      'extras': 'Suppléments',
      'cooking': 'Cuisson',
      'shape': 'Forme',
      'flavor': 'Saveur',
      'filling': 'Garniture',
      'decoration': 'Décoration',
      'tiers': 'Étages',
      'icing': 'Glaçage',
      'dietary': 'Régime',
    };

    customizationsData.forEach((key, value) {
      final label = categoryLabels[key.toLowerCase()] ?? key;
      if (value is List && value.isNotEmpty) {
        formatted.add('$label: ${value.join(', ')}');
      } else if (value != null && value.toString().isNotEmpty) {
        formatted.add('$label: $value');
      }
    });

    // Si customizationsData est vide, essayer avec customizations (format simple)
    if (formatted.isEmpty && customizations.isNotEmpty) {
      customizations.forEach((key, value) {
        if (value.isNotEmpty) {
          final label = categoryLabels[key.toLowerCase()] ?? key;
          formatted.add('$label: $value');
        }
      });
    }

    return formatted;
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

enum OrderStatus {
  pending, // En attente
  confirmed, // Confirmée
  preparing, // En préparation
  ready, // Prête
  pickedUp, // Récupérée
  onTheWay, // En route
  delivered, // Livrée
  cancelled, // Annulée
  refunded, // Remboursée
  failed, // Échouée
}

extension OrderStatusExtension on OrderStatus {
  /// Valeur canonique stockée en base (compat Supabase/Postgres).
  /// Important: certains statuts sont en snake_case dans la DB.
  String get dbValue {
    switch (this) {
      case OrderStatus.pending:
        return 'pending';
      case OrderStatus.confirmed:
        return 'confirmed';
      case OrderStatus.preparing:
        return 'preparing';
      case OrderStatus.ready:
        return 'ready';
      case OrderStatus.pickedUp:
        return 'picked_up';
      case OrderStatus.onTheWay:
        return 'on_the_way';
      case OrderStatus.delivered:
        return 'delivered';
      case OrderStatus.cancelled:
        return 'cancelled';
      case OrderStatus.refunded:
        return 'refunded';
      case OrderStatus.failed:
        return 'failed';
    }
  }

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
        return 'En route';
      case OrderStatus.delivered:
        return 'Livrée';
      case OrderStatus.cancelled:
        return 'Annulée';
      case OrderStatus.refunded:
        return 'Remboursée';
      case OrderStatus.failed:
        return 'Échouée';
    }
  }

  String get emoji {
    switch (this) {
      case OrderStatus.pending:
        return '⏳';
      case OrderStatus.confirmed:
        return '✅';
      case OrderStatus.preparing:
        return '👨‍🍳';
      case OrderStatus.ready:
        return '📦';
      case OrderStatus.pickedUp:
        return '🏃‍♂️';
      case OrderStatus.onTheWay:
        return '🛵';
      case OrderStatus.delivered:
        return '🎉';
      case OrderStatus.cancelled:
        return '❌';
      case OrderStatus.refunded:
        return '💰';
      case OrderStatus.failed:
        return '⚠️';
    }
  }

  /// Vérifie si le statut est actif (en cours de traitement)
  bool get isActive {
    return this == OrderStatus.pending ||
        this == OrderStatus.confirmed ||
        this == OrderStatus.preparing ||
        this == OrderStatus.ready ||
        this == OrderStatus.pickedUp ||
        this == OrderStatus.onTheWay;
  }

  /// Vérifie si le statut est terminé (livré, annulé, etc.)
  bool get isCompleted {
    return this == OrderStatus.delivered ||
        this == OrderStatus.cancelled ||
        this == OrderStatus.refunded ||
        this == OrderStatus.failed;
  }

  /// Vérifie si le statut peut être modifié
  bool get canBeModified {
    return this == OrderStatus.pending ||
        this == OrderStatus.confirmed ||
        this == OrderStatus.preparing;
  }

  /// Obtient la couleur associée au statut
  String get colorHex {
    switch (this) {
      case OrderStatus.pending:
        return '#FFA500'; // Orange
      case OrderStatus.confirmed:
        return '#4CAF50'; // Vert
      case OrderStatus.preparing:
        return '#2196F3'; // Bleu
      case OrderStatus.ready:
        return '#9C27B0'; // Violet
      case OrderStatus.pickedUp:
        return '#FF9800'; // Orange foncé
      case OrderStatus.onTheWay:
        return '#00BCD4'; // Cyan
      case OrderStatus.delivered:
        return '#4CAF50'; // Vert
      case OrderStatus.cancelled:
        return '#F44336'; // Rouge
      case OrderStatus.refunded:
        return '#607D8B'; // Gris bleu
      case OrderStatus.failed:
        return '#795548'; // Marron
    }
  }

  /// Obtient le prochain statut possible
  List<OrderStatus> get nextPossibleStatuses {
    switch (this) {
      case OrderStatus.pending:
        return [OrderStatus.confirmed, OrderStatus.cancelled];
      case OrderStatus.confirmed:
        return [OrderStatus.preparing, OrderStatus.cancelled];
      case OrderStatus.preparing:
        return [OrderStatus.ready, OrderStatus.cancelled];
      case OrderStatus.ready:
        return [OrderStatus.pickedUp, OrderStatus.cancelled];
      case OrderStatus.pickedUp:
        return [OrderStatus.onTheWay, OrderStatus.delivered];
      case OrderStatus.onTheWay:
        return [OrderStatus.delivered, OrderStatus.failed];
      case OrderStatus.delivered:
        return [OrderStatus.refunded];
      case OrderStatus.cancelled:
        return [OrderStatus.refunded];
      case OrderStatus.refunded:
        return [];
      case OrderStatus.failed:
        return [OrderStatus.refunded];
    }
  }
}

enum PaymentMethod { mobileMoney, creditCard, debitCard, wallet, cash }

extension PaymentMethodExtension on PaymentMethod {
  String get displayName {
    switch (this) {
      case PaymentMethod.mobileMoney:
        return 'Mobile Money';
      case PaymentMethod.creditCard:
        return 'Credit Card';
      case PaymentMethod.debitCard:
        return 'Debit Card';
      case PaymentMethod.wallet:
        return 'FastFoodGo Wallet';
      case PaymentMethod.cash:
        return 'Cash on Delivery';
    }
  }

  String get description {
    switch (this) {
      case PaymentMethod.mobileMoney:
        return 'Orange Money, MTN Money, Moov Money';
      case PaymentMethod.creditCard:
        return 'Visa, Mastercard, American Express';
      case PaymentMethod.debitCard:
        return 'Carte de débit bancaire';
      case PaymentMethod.wallet:
        return 'Portefeuille FastFoodGo';
      case PaymentMethod.cash:
        return 'Paiement à la livraison';
    }
  }

  String get emoji {
    switch (this) {
      case PaymentMethod.mobileMoney:
        return '📱';
      case PaymentMethod.creditCard:
        return '💳';
      case PaymentMethod.debitCard:
        return '💳';
      case PaymentMethod.wallet:
        return '👛';
      case PaymentMethod.cash:
        return '💵';
    }
  }
}

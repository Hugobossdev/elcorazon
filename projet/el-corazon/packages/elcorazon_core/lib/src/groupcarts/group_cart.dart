import '../models/money.dart';

/// Participant d'un panier collaboratif — miroir de `MemberSerializer`.
class GroupCartMember {
  const GroupCartMember({required this.id, required this.fullName, required this.joinedAt});

  factory GroupCartMember.fromJson(Map<String, dynamic> json) {
    return GroupCartMember(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );
  }

  final String id;
  final String fullName;
  final DateTime joinedAt;
}

/// Option retenue sur une ligne — miroir de `SelectedOptionSerializer`. Le
/// supplément est celui du serveur ; [groupName] situe l'option (« Cuisson »,
/// « Taille ») sans que le client ait à recharger la carte pour l'afficher.
class GroupCartLineOption {
  const GroupCartLineOption({
    required this.id,
    required this.name,
    required this.priceDelta,
    required this.groupName,
  });

  factory GroupCartLineOption.fromJson(Map<String, dynamic> json) {
    return GroupCartLineOption(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      priceDelta: Money.fromJson(json['price_delta'] as Map<String, dynamic>),
      groupName: json['group'] as String? ?? '',
    );
  }

  final String id;
  final String name;
  final Money priceDelta;
  final String groupName;
}

/// Ligne d'un panier collaboratif — miroir de `GroupCartLineSerializer`.
///
/// [isOrderable] et [unavailableReason] sont calculés par le serveur : un plat
/// épuisé ou retiré de la carte pendant que le groupe compose son panier reste
/// visible, mais marqué. Le masquer ferait disparaître le choix de quelqu'un
/// sans explication.
class GroupCartLine {
  const GroupCartLine({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.menuItemId,
    required this.name,
    required this.quantity,
    required this.notes,
    required this.options,
    required this.unitPrice,
    required this.total,
    required this.isOrderable,
    required this.unavailableReason,
    this.image,
  });

  factory GroupCartLine.fromJson(Map<String, dynamic> json) {
    return GroupCartLine(
      id: json['id'] as String,
      memberId: json['member'] as String,
      memberName: json['member_name'] as String? ?? '',
      menuItemId: json['menu_item'] as String,
      name: json['name'] as String? ?? '',
      image: json['image'] as String?,
      quantity: json['quantity'] as int,
      notes: json['notes'] as String? ?? '',
      options: (json['options'] as List<dynamic>? ?? const [])
          .map((json) => GroupCartLineOption.fromJson(json as Map<String, dynamic>))
          .toList(),
      unitPrice: Money.fromJson(json['unit_price'] as Map<String, dynamic>),
      total: Money.fromJson(json['total'] as Map<String, dynamic>),
      isOrderable: json['is_orderable'] as bool? ?? true,
      unavailableReason: json['unavailable_reason'] as String? ?? '',
    );
  }

  final String id;
  final String memberId;
  final String memberName;
  final String menuItemId;
  final String name;
  final String? image;
  final int quantity;
  final String notes;
  final List<GroupCartLineOption> options;
  final Money unitPrice;
  final Money total;
  final bool isOrderable;
  final String unavailableReason;
}

/// Ce que doit un participant — calculé par le serveur, jamais réparti ici.
class GroupCartMemberTotal {
  const GroupCartMemberTotal({required this.memberId, required this.total});

  factory GroupCartMemberTotal.fromJson(Map<String, dynamic> json) {
    return GroupCartMemberTotal(
      memberId: json['member'] as String,
      total: Money.fromJson(json['total'] as Map<String, dynamic>),
    );
  }

  final String memberId;
  final Money total;
}

/// Panier collaboratif — miroir de `GroupCartSerializer`.
///
/// Le serveur rend le panier **entier** après chaque écriture, sous-total et
/// totaux par participant compris : c'est ce qui évite que chaque client
/// réimplémente la tarification (C1), et en autant d'exemplaires qu'il y a de
/// participants.
///
/// [code] est éphémère : il n'ouvre que ce panier, et cesse de fonctionner à la
/// clôture. Tout participant peut le partager — c'est le comportement attendu
/// d'un déjeuner de groupe.
class GroupCart {
  const GroupCart({
    required this.id,
    required this.code,
    required this.title,
    required this.status,
    required this.restaurantSlug,
    required this.restaurantName,
    required this.hostId,
    required this.hostName,
    required this.acceptsContributions,
    required this.members,
    required this.lines,
    required this.perMember,
    required this.currency,
    required this.subtotal,
    required this.isOrderable,
    required this.updatedAt,
    this.closesAt,
    this.orderId,
  });

  factory GroupCart.fromJson(Map<String, dynamic> json) {
    return GroupCart(
      id: json['id'] as String,
      code: json['code'] as String,
      title: json['title'] as String? ?? '',
      status: json['status'] as String,
      restaurantSlug: json['restaurant'] as String,
      restaurantName: json['restaurant_name'] as String? ?? '',
      hostId: json['host'] as String,
      hostName: json['host_name'] as String? ?? '',
      closesAt: json['closes_at'] == null ? null : DateTime.parse(json['closes_at'] as String),
      acceptsContributions: json['accepts_contributions'] as bool? ?? false,
      orderId: json['order'] as String?,
      members: (json['members'] as List<dynamic>? ?? const [])
          .map((json) => GroupCartMember.fromJson(json as Map<String, dynamic>))
          .toList(),
      lines: (json['lines'] as List<dynamic>? ?? const [])
          .map((json) => GroupCartLine.fromJson(json as Map<String, dynamic>))
          .toList(),
      perMember: (json['per_member'] as List<dynamic>? ?? const [])
          .map((json) => GroupCartMemberTotal.fromJson(json as Map<String, dynamic>))
          .toList(),
      currency: json['currency'] as String? ?? 'XOF',
      subtotal: Money.fromJson(json['subtotal'] as Map<String, dynamic>),
      isOrderable: json['is_orderable'] as bool? ?? false,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String code;
  final String title;

  /// `open` | `locked` | `confirmed` | `cancelled` (`GroupCartStatus`).
  final String status;
  final String restaurantSlug;
  final String restaurantName;
  final String hostId;
  final String hostName;
  final DateTime? closesAt;

  /// Faux dès que le panier n'est plus `open` ou que l'échéance est passée :
  /// c'est le serveur qui tranche, et non une comparaison de dates faite ici
  /// sur une horloge locale.
  final bool acceptsContributions;

  /// Renseigné une fois le panier confirmé — l'identifiant de la commande née
  /// de ce panier.
  final String? orderId;

  final List<GroupCartMember> members;
  final List<GroupCartLine> lines;
  final List<GroupCartMemberTotal> perMember;
  final String currency;
  final Money subtotal;

  /// Vrai quand toutes les lignes sont commandables — l'hôte peut confirmer.
  final bool isOrderable;
  final DateTime updatedAt;

  bool isHost(String userId) => hostId == userId;

  /// Ce que doit [memberId], zéro s'il n'a rien déposé.
  Money totalFor(String memberId) {
    for (final entry in perMember) {
      if (entry.memberId == memberId) return entry.total;
    }
    return Money(amountMinor: 0, currency: currency);
  }
}

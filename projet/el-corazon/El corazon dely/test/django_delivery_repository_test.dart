import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:elcora_dely/models/order.dart';
import 'package:elcora_dely/repositories/django_delivery_repository.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _canalStockage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _entetesJson = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

/// Sert `/delivery/assignments/` filtré par statut, et `/orders/{id}/`.
///
/// Le vrai serveur pagine ; une seule page suffit ici, `next` valant `null`.
class _FauxServeur implements HttpClientAdapter {
  _FauxServeur({required this.coursesParStatut, this.commande});

  final Map<String, List<Map<String, dynamic>>> coursesParStatut;
  final Map<String, dynamic>? commande;

  /// Chemins demandés, dans l'ordre — sert à vérifier ce que l'app relit.
  final List<String> chemins = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    chemins.add(options.path);

    if (options.path.contains('/delivery/assignments/')) {
      final statut = options.queryParameters['status'] as String? ?? '';
      return _json({
        'count': coursesParStatut[statut]?.length ?? 0,
        'next': null,
        'previous': null,
        'results': coursesParStatut[statut] ?? const [],
      });
    }

    if (options.path.startsWith('/orders/')) {
      if (commande == null) {
        return ResponseBody.fromString('{"detail":"Introuvable"}', 404,
            headers: _entetesJson,);
      }
      return _json(commande!);
    }

    return ResponseBody.fromString('{}', 200, headers: _entetesJson);
  }

  ResponseBody _json(Object corps) =>
      ResponseBody.fromString(jsonEncode(corps), 200, headers: _entetesJson);
}

Map<String, dynamic> _montant(int mineur) => {'amount': '$mineur', 'currency': 'XOF'};

Map<String, dynamic> _course({
  String statut = eccore.DeliveryStatus.accepted,
  String repere = '',
  String adresse = 'Rue du Commerce',
}) {
  return {
    'id': 'course-1',
    'order': 'commande-1',
    'order_reference': 'CMD-0001',
    'restaurant_name': 'El Corazón Lomé',
    'pickup_location': {'lat': 6.13, 'lon': 1.22},
    'delivery_address_line': adresse,
    'delivery_landmark': repere,
    'delivery_location': {'lat': 6.14, 'lon': 1.23},
    'recipient_name': 'Awa',
    'recipient_phone': '+22890000000',
    'courier': {
      'id': 'livreur-7',
      'full_name': 'Kodjo',
      'vehicle_type': 'moto',
      'rating_average': '4.8',
      'rating_count': 12,
    },
    'status': statut,
    'allowed_transitions': const ['picked_up'],
    'courier_fee': _montant(1000),
    'offered_at': '2026-08-07T10:00:00Z',
    'created_at': '2026-08-07T09:59:00Z',
    'updated_at': '2026-08-07T10:00:00Z',
  };
}

Map<String, dynamic> _commande({
  String moyenPaiement = 'cash',
  String consignes = '',
}) {
  return {
    'id': 'commande-1',
    'reference': 'CMD-0001',
    'restaurant': 'el-corazon-lome',
    'restaurant_name': 'El Corazón Lomé',
    'status': 'preparing',
    'allowed_transitions': const <String>[],
    'subtotal': _montant(9000),
    'delivery_fee': _montant(1000),
    'discount': _montant(500),
    'total': _montant(9500),
    'payment_method': moyenPaiement,
    'delivery_address_line': 'Rue du Commerce',
    'delivery_landmark': '',
    'delivery_location': {'lat': 6.14, 'lon': 1.23},
    'recipient_name': 'Awa',
    'recipient_phone': '+22890000000',
    'placed_at': '2026-08-07T09:58:00Z',
    'estimated_delivery_at': '2026-08-07T10:45:00Z',
    'delivery_instructions': consignes,
    'lines': [
      {
        'id': 'ligne-1',
        'menu_item': 'article-1',
        'item_name': 'Poulet braisé',
        'item_image': 'https://exemple.test/poulet.jpg',
        'unit_price': _montant(4500),
        'quantity': 2,
        'line_total': _montant(9000),
        'notes': 'Bien épicé',
      },
    ],
    'created_at': '2026-08-07T09:58:00Z',
    'updated_at': '2026-08-07T10:00:00Z',
  };
}

/// Traduction course Django → commande affichée au livreur.
///
/// Ces tests sont écrits **avant** de démonter l'adaptateur (lot 3) : ce qu'ils
/// épinglent n'est pas le code de `DjangoDeliveryRepository` mais ce que le
/// livreur voit à l'écran. Quand les écrans liront `eccore.Assignment` et
/// `eccore.Order` directement, ces attentes devront tenir à l'identique — c'est
/// tout leur objet.
///
/// Deux règles du contrat s'y lisent en particulier : c'est l'étape de la
/// **course** qui pilote l'écran du livreur, jamais le statut de la commande
/// (la projection inverse avait produit le constat C4) ; et l'historique n'est
/// pas relu commande par commande.
void main() {
  late _FauxServeur serveur;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_canalStockage, (call) async {
      // Le dépôt n'a pas besoin d'une vraie session : le faux serveur répond
      // sans regarder l'en-tête d'autorisation.
      return call.method == 'read' ? null : null;
    });
  });

  DjangoDeliveryRepository depot(_FauxServeur faux) {
    serveur = faux;
    return DjangoDeliveryRepository(
      apiClient: eccore.ApiClient(
        baseUrl: 'https://exemple.test/api/v1',
        tokenStorage: eccore.TokenStorage(),
        testAdapter: faux,
      ),
    );
  }

  group('Une course en cours', () {
    Future<Course> premiere({
      String statut = eccore.DeliveryStatus.accepted,
      String repere = '',
      Map<String, dynamic>? commande,
    }) async {
      final courses = await depot(
        _FauxServeur(
          coursesParStatut: {statut: [_course(statut: statut, repere: repere)]},
          commande: commande ?? _commande(),
        ),
      ).loadCourses();
      return courses.single;
    }

    test('porte l’identifiant de la commande, pas celui de la course', () async {
      // C'est cet identifiant qui ouvre le suivi et la discussion.
      final course = await premiere();
      expect(course.order.id, 'commande-1');
      expect(course.assignmentId, 'course-1');
      expect(course.orderId, 'commande-1');
    });

    test('les montants passent en unité majeure', () async {
      final course = await premiere();
      expect(course.order.subtotal, 9000);
      expect(course.order.deliveryFee, 1000);
      expect(course.order.discount, 500);
      expect(course.order.total, 9500);
    });

    test('les articles sont repris ligne à ligne', () async {
      final course = await premiere();
      final article = course.order.items.single;

      expect(article.menuItemId, 'article-1');
      expect(article.menuItemName, 'Poulet braisé');
      expect(article.quantity, 2);
      expect(article.unitPrice, 4500);
      expect(article.totalPrice, 9000);
      expect(article.notes, 'Bien épicé');
    });

    test('le client n’est jamais exposé au livreur', () async {
      // Ni identifiant ni historique : il voit un destinataire et un point de
      // dépôt, rien d'autre.
      final course = await premiere();
      expect(course.order.userId, isEmpty);
    });

    test('le repère complète l’adresse quand il existe', () async {
      expect(
        (await premiere()).order.deliveryAddress,
        'Rue du Commerce',
      );
      expect(
        (await premiere(repere: 'face à la pharmacie')).order.deliveryAddress,
        'Rue du Commerce (face à la pharmacie)',
      );
    });

    test('des consignes vides ne deviennent pas une note vide', () async {
      expect((await premiere()).order.deliveryNotes, isNull);
      expect(
        (await premiere(commande: _commande(consignes: 'Sonner deux fois')))
            .order
            .deliveryNotes,
        'Sonner deux fois',
      );
    });
  });

  group('L’étape de la course pilote l’écran', () {
    Future<OrderStatus> statutAffiche(String etape) async {
      final courses = await depot(
        _FauxServeur(
          coursesParStatut: {etape: [_course(statut: etape)]},
          commande: _commande(),
        ),
      ).loadCourses();
      return courses.single.order.status;
    }

    test('chaque étape a son statut', () async {
      expect(await statutAffiche(eccore.DeliveryStatus.offered), OrderStatus.pending);
      // `accepted` retombe sur `confirmed`, faute d'équivalent local.
      expect(await statutAffiche(eccore.DeliveryStatus.accepted), OrderStatus.confirmed);
      expect(await statutAffiche(eccore.DeliveryStatus.pickedUp), OrderStatus.pickedUp);
      expect(await statutAffiche(eccore.DeliveryStatus.onTheWay), OrderStatus.onTheWay);
      expect(await statutAffiche(eccore.DeliveryStatus.delivered), OrderStatus.delivered);
    });

    test('une course proposée n’a pas encore de livreur', () async {
      // C'est ce que les écrans lisent pour distinguer « proposée » de
      // « la mienne ».
      final proposee = await depot(
        _FauxServeur(
          coursesParStatut: {
            eccore.DeliveryStatus.offered: [
              _course(statut: eccore.DeliveryStatus.offered),
            ],
          },
          commande: _commande(),
        ),
      ).loadCourses();
      expect(proposee.single.order.deliveryPersonId, isNull);

      final mienne = await depot(
        _FauxServeur(
          coursesParStatut: {
            eccore.DeliveryStatus.accepted: [_course()],
          },
          commande: _commande(),
        ),
      ).loadCourses();
      expect(mienne.single.order.deliveryPersonId, 'livreur-7');
    });
  });

  group('Moyen de paiement', () {
    Future<PaymentMethod> moyen(String recu) async {
      final courses = await depot(
        _FauxServeur(
          coursesParStatut: {
            eccore.DeliveryStatus.accepted: [_course()],
          },
          commande: _commande(moyenPaiement: recu),
        ),
      ).loadCourses();
      return courses.single.order.paymentMethod;
    }

    test('chaque moyen connu est traduit', () async {
      expect(await moyen('cash'), PaymentMethod.cash);
      expect(await moyen('mobile_money'), PaymentMethod.mobileMoney);
      expect(await moyen('card'), PaymentMethod.creditCard);
      expect(await moyen('wallet'), PaymentMethod.wallet);
    });

    test('un moyen inconnu retombe sur les espèces', () async {
      // Le livreur doit se préparer à encaisser plutôt que l'inverse : c'est
      // l'erreur la moins coûteuse des deux.
      expect(await moyen('crypto-monnaie'), PaymentMethod.cash);
    });
  });

  group('L’historique n’est pas relu commande par commande', () {
    test('une course livrée ne déclenche aucune lecture de commande', () async {
      final faux = _FauxServeur(
        coursesParStatut: {
          eccore.DeliveryStatus.delivered: [
            _course(statut: eccore.DeliveryStatus.delivered),
          ],
        },
        commande: _commande(),
      );
      await depot(faux).loadCourses();

      expect(
        faux.chemins.where((c) => c.startsWith('/orders/')),
        isEmpty,
        reason: 'relire chaque livraison passée coûterait une requête par ligne',
      );
    });

    test('elle reste affichable sans son détail', () async {
      final courses = await depot(
        _FauxServeur(
          coursesParStatut: {
            eccore.DeliveryStatus.delivered: [
              _course(statut: eccore.DeliveryStatus.delivered),
            ],
          },
        ),
      ).loadCourses();

      final livree = courses.single.order;
      expect(livree.status, OrderStatus.delivered);
      expect(livree.deliveryAddress, 'Rue du Commerce');
      expect(livree.items, isEmpty);
      expect(livree.total, 0);
    });
  });

  group('Une commande illisible n’efface pas la course', () {
    test('la course subsiste, montants à zéro', () async {
      // Mieux vaut une course incomplète qu'une course disparue de l'écran.
      final courses = await depot(
        _FauxServeur(
          coursesParStatut: {
            eccore.DeliveryStatus.accepted: [_course()],
          },
        ),
      ).loadCourses();

      final course = courses.single;
      expect(course.assignmentId, 'course-1');
      expect(course.order.status, OrderStatus.confirmed);
      expect(course.order.deliveryAddress, 'Rue du Commerce');
      expect(course.order.items, isEmpty);
      expect(course.order.total, 0);
    });
  });

  group('Ce que le serveur autorise', () {
    test('les transitions viennent de la course, pas d’une machine locale', () async {
      final courses = await depot(
        _FauxServeur(
          coursesParStatut: {
            eccore.DeliveryStatus.accepted: [_course()],
          },
          commande: _commande(),
        ),
      ).loadCourses();

      expect(courses.single.allowedTransitions, ['picked_up']);
    });
  });

  tearDown(() {
    expect(serveur.chemins, isNotEmpty);
  });
}

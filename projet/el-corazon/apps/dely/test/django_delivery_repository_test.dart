import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:elcora_dely/presentation/libelles_course.dart';
import 'package:elcora_dely/repositories/django_delivery_repository.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _canalStockage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _entetesJson = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

/// Sert `/delivery/assignments/` filtré par statut.
///
/// Le vrai serveur pagine ; une seule page suffit ici, `next` valant `null`.
///
/// `/orders/{id}/` répond **500** à dessein : depuis le lot 4, la course porte
/// tout ce que le livreur doit voir, et le contrat ne lui donne de toute façon
/// pas accès à la commande d'un client. Une relecture qui reviendrait par
/// mégarde doit faire échouer le test qui l'a provoquée, pas passer inaperçue.
class _FauxServeur implements HttpClientAdapter {
  _FauxServeur({required this.coursesParStatut});

  final Map<String, List<Map<String, dynamic>>> coursesParStatut;

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
      return ResponseBody.fromString(
        '{"detail":"Une course ne relit pas la commande de son client."}',
        500,
        headers: _entetesJson,
      );
    }

    return ResponseBody.fromString('{}', 200, headers: _entetesJson);
  }

  ResponseBody _json(Object corps) =>
      ResponseBody.fromString(jsonEncode(corps), 200, headers: _entetesJson);
}

Map<String, dynamic> _montant(int mineur) => {'amount': '$mineur', 'currency': 'XOF'};

/// Une course telle que `AssignmentSerializer` la rend depuis le lot 4.
///
/// [ancienServeur] retire les champs que ce lot a ajoutés — consignes, zone,
/// moyen de paiement, total, montant à encaisser, articles. Une application à
/// jour doit rester utilisable devant un serveur qui ne les envoie pas encore.
Map<String, dynamic> _course({
  String statut = eccore.DeliveryStatus.accepted,
  String repere = '',
  String adresse = 'Rue du Commerce',
  String moyenPaiement = 'cash',
  String consignes = '',
  String statutCommande = 'ready',
  bool ancienServeur = false,
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
    if (!ancienServeur) ...{
      'delivery_instructions': consignes,
      'delivery_zone_name': 'Bè',
      'city_name': 'Lomé',
      'payment_method': moyenPaiement,
      'order_status': statutCommande,
      'order_total': _montant(9500),
      'estimated_delivery_at': '2026-08-07T10:45:00Z',
      // Le serveur ne le rend qu'en espèces : c'est lui, et non le moyen de
      // paiement lu par l'application, qui dit ce qu'il y a à encaisser.
      'amount_to_collect': moyenPaiement == 'cash' ? _montant(9500) : null,
      'items': [
        {
          'name': 'Poulet braisé',
          'item_image': 'https://exemple.test/poulet.jpg',
          'quantity': 2,
          'options': const ['Fort'],
          'notes': 'Bien épicé',
        },
      ],
    },
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
      String consignes = '',
    }) async {
      final courses = await depot(
        _FauxServeur(
          coursesParStatut: {
            statut: [_course(statut: statut, repere: repere, consignes: consignes)],
          },
        ),
      ).loadCourses();
      return courses.single;
    }

    test('porte l’identifiant de la commande, pas celui de la course', () async {
      // C'est cet identifiant qui ouvre le suivi et la discussion.
      final course = await premiere();
      expect(course.orderId, 'commande-1');
      expect(course.assignmentId, 'course-1');
      expect(course.orderId, 'commande-1');
    });

    test('le total et le montant à encaisser viennent de la course', () async {
      // Depuis le lot 4, la course les porte elle-même : le sous-total, les
      // frais et la remise ne lui sont plus rendus, et l'application ne les
      // affiche plus. Un livreur n'a pas à connaître la composition d'une
      // facture ; il a besoin de ce qu'il encaisse à la porte.
      final course = await premiere();
      expect(course.total!.amountMinor, 9500);
      expect(course.aEncaisser!.amountMinor, 9500);
    });

    test('une commande déjà réglée n’a rien à encaisser', () async {
      final course = await depot(
        _FauxServeur(
          coursesParStatut: {
            eccore.DeliveryStatus.accepted: [
              _course(moyenPaiement: 'mobile_money'),
            ],
          },
        ),
      ).loadCourses();

      expect(course.single.aEncaisser, isNull);
      expect(course.single.total!.amountMinor, 9500);
    });

    test('les articles sont repris sans leurs prix', () async {
      // `AssignmentSerializer.get_items` les exclut délibérément : le livreur
      // vérifie un sac, il ne facture pas. Ce qu'il lui faut est le nom, la
      // quantité, les options retenues et la remarque du client.
      final course = await premiere();
      final article = course.articles.single;

      expect(article.itemName, 'Poulet braisé');
      expect(article.quantity, 2);
      expect(article.options, ['Fort']);
      expect(article.notes, 'Bien épicé');
      expect(article.label, '2 × Poulet braisé (Fort)');
    });

    test('la zone et la ville de livraison sont lisibles', () async {
      expect((await premiere()).zoneLivraison, 'Bè, Lomé');
    });

    test('le client n’est jamais exposé au livreur', () async {
      // Ni identifiant ni historique : il voit un destinataire et un point de
      // dépôt. Depuis le lot 3, la course ne porte plus de champ « client »
      // du tout — auparavant une chaîne vide en tenait lieu.
      final course = await premiere();
      expect(course.destinataire, 'Awa');
      expect(course.telephoneDestinataire, '+22890000000');
    });

    test('le repère complète l’adresse quand il existe', () async {
      expect(
        (await premiere()).adresseLivraison,
        'Rue du Commerce',
      );
      expect(
        (await premiere(repere: 'face à la pharmacie')).adresseLivraison,
        'Rue du Commerce (face à la pharmacie)',
      );
    });

    test('des consignes vides ne deviennent pas une note vide', () async {
      expect((await premiere()).consignes, isNull);
      expect(
        (await premiere(consignes: 'Sonner deux fois')).consignes,
        'Sonner deux fois',
      );
    });
  });

  group('L’étape de la course pilote l’écran', () {
    Future<EtapeCourse> statutAffiche(String etape) async {
      final courses = await depot(
        _FauxServeur(
          coursesParStatut: {etape: [_course(statut: etape)]},
        ),
      ).loadCourses();
      return courses.single.etape;
    }

    test('chaque étape a son statut', () async {
      expect(await statutAffiche(eccore.DeliveryStatus.offered), EtapeCourse.proposee);
      expect(await statutAffiche(eccore.DeliveryStatus.accepted), EtapeCourse.acceptee);
      expect(await statutAffiche(eccore.DeliveryStatus.pickedUp), EtapeCourse.recuperee);
      expect(await statutAffiche(eccore.DeliveryStatus.onTheWay), EtapeCourse.enRoute);
      expect(await statutAffiche(eccore.DeliveryStatus.delivered), EtapeCourse.livree);
    });

    test('une course proposée se distingue de la mienne', () async {
      // C'est ce que les écrans lisent pour distinguer « proposée » de
      // « la mienne ».
      final proposee = await depot(
        _FauxServeur(
          coursesParStatut: {
            eccore.DeliveryStatus.offered: [
              _course(statut: eccore.DeliveryStatus.offered),
            ],
          },
        ),
      ).loadCourses();
      expect(proposee.single.estProposee, isTrue);
      expect(proposee.single.estMienne, isFalse);

      final mienne = await depot(
        _FauxServeur(
          coursesParStatut: {
            eccore.DeliveryStatus.accepted: [_course()],
          },
        ),
      ).loadCourses();
      expect(mienne.single.estMienne, isTrue);
      expect(mienne.single.assignment.courier.id, 'livreur-7');
    });
  });

  group('Moyen de paiement', () {
    Future<MoyenPaiement> moyen(String recu) async {
      final courses = await depot(
        _FauxServeur(
          coursesParStatut: {
            eccore.DeliveryStatus.accepted: [_course(moyenPaiement: recu)],
          },
        ),
      ).loadCourses();
      return courses.single.moyenPaiement;
    }

    test('chaque moyen connu est traduit', () async {
      expect(await moyen('cash'), MoyenPaiement.especes);
      expect(await moyen('mobile_money'), MoyenPaiement.mobileMoney);
      expect(await moyen('card'), MoyenPaiement.carte);
      expect(await moyen('wallet'), MoyenPaiement.portefeuille);
    });

    test('un moyen inconnu retombe sur les espèces', () async {
      // Le livreur doit se préparer à encaisser plutôt que l'inverse : c'est
      // l'erreur la moins coûteuse des deux.
      expect(await moyen('crypto-monnaie'), MoyenPaiement.especes);
      expect(MoyenPaiement.especes.aEncaisser, isTrue);
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
      );
      await depot(faux).loadCourses();

      expect(
        faux.chemins.where((c) => c.startsWith('/orders/')),
        isEmpty,
        reason: 'relire chaque livraison passée coûterait une requête par ligne',
      );
    });

    test('elle reste complète sans aucune relecture', () async {
      // La course livrée porte encore tout ce que l'historique affiche : la
      // relecture de la commande n'est plus ce qui remplissait l'écran.
      final courses = await depot(
        _FauxServeur(
          coursesParStatut: {
            eccore.DeliveryStatus.delivered: [
              _course(statut: eccore.DeliveryStatus.delivered),
            ],
          },
        ),
      ).loadCourses();

      final livree = courses.single;
      expect(livree.etape, EtapeCourse.livree);
      expect(livree.adresseLivraison, 'Rue du Commerce');
      expect(livree.articles, hasLength(1));
      expect(livree.total!.amountMinor, 9500);
      // La rémunération, elle, est sur l'affectation — c'est d'elle que vivent
      // les gains, et non d'un pourcentage d'un total qu'on n'a pas relu.
      expect(livree.remuneration!.amountMinor, 1000);
    });
  });

  group('Un serveur antérieur n’efface pas la course', () {
    test('la course subsiste, montants absents plutôt qu’inventés', () async {
      // Mieux vaut une course incomplète qu'une course disparue de l'écran —
      // et un montant absent plutôt qu'un zéro qu'on prendrait pour un fait.
      final courses = await depot(
        _FauxServeur(
          coursesParStatut: {
            eccore.DeliveryStatus.accepted: [_course(ancienServeur: true)],
          },
        ),
      ).loadCourses();

      final course = courses.single;
      expect(course.assignmentId, 'course-1');
      expect(course.etape, EtapeCourse.acceptee);
      expect(course.adresseLivraison, 'Rue du Commerce');
      expect(course.articles, isEmpty);
      expect(course.total, isNull);
      expect(course.aEncaisser, isNull);
      expect(course.consignes, isNull);
      expect(course.zoneLivraison, isEmpty);
      // Faute de moyen de paiement, on se prépare à encaisser : l'erreur la
      // moins coûteuse des deux.
      expect(course.moyenPaiement, MoyenPaiement.especes);
    });
  });

  group('Une course refusée disparaît', () {
    // Montée directement, sans passer par le serveur : une course refusée ne
    // figure dans **aucune** des trois listes qu'il sert (proposées, actives,
    // livrées récentes). Elle n'existe côté application que parce que le refus
    // vient de rendre la course à jour — et c'est exactement là qu'elle se
    // rangeait au mauvais endroit.
    Course avecLEtape(String etape) =>
        Course(assignment: eccore.Assignment.fromJson(_course(statut: etape)));

    test('elle n’est ni proposée, ni mienne', () {
      // `estMienne` valait « pas proposée », donc **aussi** refusée et
      // annulée : la course qu'un livreur venait de décliner réapparaissait
      // dans « Mes courses », onglet terminées, sous le libellé « Annulée » —
      // jusqu'au rechargement suivant, qui la faisait disparaître sans un mot.
      final refusee = avecLEtape(eccore.DeliveryStatus.declined);

      expect(refusee.estProposee, isFalse);
      expect(refusee.estMienne, isFalse);
      expect(refusee.estEcartee, isTrue);
    });

    test('une course annulée non plus', () {
      final annulee = avecLEtape(eccore.DeliveryStatus.cancelled);

      expect(annulee.estMienne, isFalse);
      expect(annulee.estEcartee, isTrue);
    });

    test('une course livrée, elle, reste la mienne', () {
      // L'historique doit garder ce qui a été fait : c'est de lui que vivent
      // les gains et les statistiques.
      final livree = avecLEtape(eccore.DeliveryStatus.delivered);

      expect(livree.estMienne, isTrue);
      expect(livree.estEcartee, isFalse);
    });
  });

  group('Le retrait attend la cuisine', () {
    Future<Course> avecLaCommande(String statutCommande) async {
      final courses = await depot(
        _FauxServeur(
          coursesParStatut: {
            eccore.DeliveryStatus.accepted: [
              _course(statutCommande: statutCommande),
            ],
          },
        ),
      ).loadCourses();
      return courses.single;
    }

    test('une commande encore en cuisine ne propose pas « récupérée »', () async {
      // `allowed_transitions` porte bien `picked_up` — la machine de la
      // **course** l'autorise — mais la commande, elle, n'est pas prête. Le
      // serveur refuse ce geste ; l'écran ne doit donc pas l'offrir.
      final course = await avecLaCommande('preparing');

      expect(course.allowedTransitions, contains('picked_up'));
      expect(course.prochaineEtape, isNull);
      expect(course.enAttenteDeLaCuisine, isTrue);
    });

    test('une commande prête le propose', () async {
      final course = await avecLaCommande('ready');

      expect(course.prochaineEtape, EtapeCourse.recuperee);
      expect(course.enAttenteDeLaCuisine, isFalse);
    });

    test('un serveur qui ne dit rien laisse le geste possible', () async {
      // Masquer le bouton sur un champ absent immobiliserait le livreur alors
      // que le serveur, lui, accepterait.
      final courses = await depot(
        _FauxServeur(
          coursesParStatut: {
            eccore.DeliveryStatus.accepted: [_course(ancienServeur: true)],
          },
        ),
      ).loadCourses();

      expect(courses.single.prochaineEtape, EtapeCourse.recuperee);
      expect(courses.single.enAttenteDeLaCuisine, isFalse);
    });
  });

  group('Ce que le serveur autorise', () {
    test('les transitions viennent de la course, pas d’une machine locale', () async {
      final courses = await depot(
        _FauxServeur(
          coursesParStatut: {
            eccore.DeliveryStatus.accepted: [_course()],
          },
        ),
      ).loadCourses();

      expect(courses.single.allowedTransitions, ['picked_up']);
    });
  });

  tearDown(() {
    expect(serveur.chemins, isNotEmpty);
  });
}

import 'dart:convert';

import 'package:admin/presentation/commande.dart';
import 'package:admin/presentation/messages_erreur.dart';
import 'package:admin/presentation/statut_commande.dart';
import 'package:admin/services/admin_auth_service.dart';
import 'package:admin/services/order_management_service.dart';
import 'package:dio/dio.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'aide_commande.dart';

/// Ce que l'opérateur lit quand le serveur refuse.
///
/// ## Le défaut que cette suite ferme
///
/// `updateOrderStatus` et `cancelOrder` rendaient `false` sur **toute**
/// `ApiException`, en n'en gardant que le code dans le journal. Le `detail` du
/// serveur — une phrase écrite pour être lue par le personnel — était perdu à
/// cette ligne, et l'écran ne pouvait afficher qu'« Erreur lors du changement
/// de statut ».
///
/// Quatre situations très différentes donnaient donc la même phrase, qui
/// n'indique aucun geste à faire :
///
/// * **403** — le compte n'a pas `orders.update_status` : il faut demander le
///   droit, ou passer la main ;
/// * **409** — la règle métier s'y oppose, « cette commande est déjà partie » :
///   il n'y a rien à retenter ;
/// * une session expirée : il faut se reconnecter ;
/// * une coupure réseau : il faut retenter dans un instant.
///
/// L'annulation faisait pire, en **devinant** : elle affichait « permission
/// « orders.cancel », ou commande trop avancée » — là où le serveur avait écrit
/// laquelle des deux.
///
/// Les deux méthodes lèvent désormais. Ce qui est vérifié ici est la chaîne
/// complète : le refus remonte, et `messageErreur` en tire la phrase du
/// serveur.
const _canalStockage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _entetesJson = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

/// Un refus, tel que le serveur l'écrit : RFC 9457 (ADR-009).
class _Refus {
  const _Refus({required this.code, required this.detail});

  final int code;
  final String detail;
}

class _FauxServeur implements HttpClientAdapter {
  /// Le refus opposé aux écritures (`PATCH`, `POST`). Nul : elles réussissent.
  _Refus? refus;

  /// La commande rendue par une écriture qui aboutit.
  Map<String, dynamic> commande = commandeJson(statut: 'ready');

  final List<String> ecritures = [];

  void reinitialiser() {
    refus = null;
    commande = commandeJson(statut: 'ready');
    ecritures.clear();
  }

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final enEcriture = options.method != 'GET';
    if (enEcriture) ecritures.add('${options.method} ${options.path}');

    final refuse = refus;
    if (enEcriture && refuse != null) {
      return ResponseBody.fromString(
        jsonEncode({
          'type': 'about:blank',
          'title': 'Refus',
          'status': refuse.code,
          'detail': refuse.detail,
        }),
        refuse.code,
        headers: _entetesJson,
      );
    }

    if (enEcriture) {
      return ResponseBody.fromString(
        jsonEncode(commande),
        200,
        headers: _entetesJson,
      );
    }
    return ResponseBody.fromString(
      jsonEncode({'count': 0, 'next': null, 'previous': null, 'results': <dynamic>[]}),
      200,
      headers: _entetesJson,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_canalStockage, (call) async => null);

  // Un seul conteneur pour tout le fichier : `AdminAuthService` est un
  // singleton d'application et garde celui de sa première construction.
  final serveur = _FauxServeur();
  final conteneur = ProviderContainer(
    overrides: [
      eccore.apiClientProvider.overrideWithValue(
        eccore.ApiClient(
          baseUrl: 'https://exemple.test/api/v1',
          tokenStorage: eccore.TokenStorage(),
          testAdapter: serveur,
        ),
      ),
    ],
  );
  AdminAuthService(conteneur);

  setUp(serveur.reinitialiser);
  tearDownAll(conteneur.dispose);

  OrderManagementService service({_Refus? refus}) {
    serveur.refus = refus;
    return OrderManagementService();
  }

  group('Un changement de statut refusé', () {
    test('403 : la phrase du serveur remonte jusqu’à l’écran', () async {
      final sut = service(
        refus: const _Refus(
          code: 403,
          detail: 'Vous n’avez pas la permission « orders.update_status ».',
        ),
      );

      // Elle **lève** : c'est ce qui l'empêche d'être ignorée par distraction.
      // Un `false` rendu se laisse oublier ; une exception non rattrapée non.
      await expectLater(
        sut.updateOrderStatus('commande-1', StatutCommande.prete),
        throwsA(isA<eccore.ApiException>()),
      );
    });

    test('403 : le message affiché est celui du serveur, pas un nom de classe', () async {
      final sut = service(
        refus: const _Refus(
          code: 403,
          detail: 'Vous n’avez pas la permission « orders.update_status ».',
        ),
      );

      try {
        await sut.updateOrderStatus('commande-1', StatutCommande.prete);
        fail('le refus devait remonter');
      } on eccore.ApiException catch (e) {
        expect(messageErreur(e), contains('orders.update_status'));
        // Ce que l'opérateur lisait à la place, et qui n'indique aucun geste.
        expect(messageErreur(e), isNot(contains('Erreur lors du changement')));
        expect(messageErreur(e), isNot(contains('ApiException')));
      }
    });

    test('409 : une règle métier se distingue d’un manque de droit', () async {
      // Deux refus, deux gestes opposés : demander un droit, ou renoncer. Ils
      // donnaient la même phrase.
      final sut = service(
        refus: const _Refus(
          code: 409,
          detail: 'Cette commande est déjà partie : « prête » n’est plus jouable.',
        ),
      );

      try {
        await sut.updateOrderStatus('commande-1', StatutCommande.prete);
        fail('le refus devait remonter');
      } on eccore.ApiException catch (e) {
        expect(e.status, 409);
        expect(messageErreur(e), contains('déjà partie'));
      }
    });

    test('un refus ne laisse pas la commande modifiée localement', () async {
      // Le pire des deux mondes : l'écran affichait « Erreur » **et** la
      // commande passait au statut demandé dans la liste locale, jusqu'au
      // rechargement suivant.
      final sut = service(refus: const _Refus(code: 409, detail: 'Trop tard.'));
      await sut.ensureWindowLoaded();

      try {
        await sut.updateOrderStatus('commande-1', StatutCommande.prete);
      } on eccore.ApiException {
        // attendu
      }

      expect(sut.allOrders, isEmpty);
    });
  });

  group('Une annulation refusée', () {
    test('403 : le serveur dit lequel des deux motifs s’applique', () async {
      // L'écran **devinait** : « permission « orders.cancel », ou commande trop
      // avancée ». Le serveur, lui, avait écrit laquelle.
      final sut = service(
        refus: const _Refus(
          code: 403,
          detail: 'Vous n’avez pas la permission « orders.cancel ».',
        ),
      );

      try {
        await sut.cancelOrder('commande-1', 'Rupture en cuisine');
        fail('le refus devait remonter');
      } on eccore.ApiException catch (e) {
        expect(messageErreur(e), contains('orders.cancel'));
        expect(messageErreur(e), isNot(contains('ou commande trop avancée')));
      }
    });

    test('409 : « trop avancée » est une phrase du serveur, pas une hypothèse', () async {
      final sut = service(
        refus: const _Refus(
          code: 409,
          detail: 'Une commande livrée ne s’annule pas.',
        ),
      );

      try {
        await sut.cancelOrder('commande-1', 'Client injoignable');
        fail('le refus devait remonter');
      } on eccore.ApiException catch (e) {
        expect(e.status, 409);
        expect(messageErreur(e), contains('ne s’annule pas'));
      }
    });
  });

  group('Une affectation de livreur refusée', () {
    test('409 : « ce livreur porte déjà une course » remonte tel quel', () async {
      // Le back-office portait **deux** parcours d'affectation, écrits
      // séparément : l'un lisait le refus du serveur, l'autre jetait le
      // booléen et annonçait « Livreur assigné » quoi qu'il arrive. Le
      // superviseur croyait une course partie, et personne n'allait chercher
      // le repas. Il n'en reste qu'un (`afficherAssignationLivreur`), et il
      // repose sur cette méthode.
      final sut = service(
        refus: const _Refus(
          code: 409,
          detail: 'Ce livreur porte déjà une course.',
        ),
      );

      try {
        await sut.assignDriver('commande-1', 'livreur-7');
        fail('le refus devait remonter');
      } on eccore.ApiException catch (e) {
        expect(e.status, 409);
        expect(messageErreur(e), contains('porte déjà une course'));
      }
    });

    test('403 : un manque de droit se distingue d’un livreur indisponible', () async {
      final sut = service(
        refus: const _Refus(
          code: 403,
          detail: 'Vous n’avez pas la permission « orders.assign_courier ».',
        ),
      );

      await expectLater(
        sut.assignDriver('commande-1', 'livreur-7'),
        throwsA(isA<eccore.ApiException>()),
      );
    });
  });

  group('Ce qui aboutit', () {
    test('un changement accepté met la commande à jour localement', () async {
      final sut = service();
      serveur.commande = commandeJson(statut: 'ready');
      await sut.ensureWindowLoaded();

      await sut.updateOrderStatus('commande-1', StatutCommande.prete);

      expect(sut.allOrders.single.statut, StatutCommande.prete);
      expect(serveur.ecritures, hasLength(1));
    });

    test('une annulation acceptée met la commande à jour localement', () async {
      final sut = service();
      serveur.commande = commandeJson(statut: 'cancelled');
      await sut.ensureWindowLoaded();

      await sut.cancelOrder('commande-1', 'Rupture en cuisine');

      expect(sut.allOrders.single.statut, StatutCommande.annulee);
    });
  });
}

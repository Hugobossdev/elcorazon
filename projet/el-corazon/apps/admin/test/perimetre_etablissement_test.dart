import 'package:admin/presentation/echec.dart';
import 'package:admin/services/restaurant_scope_service.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter_test/flutter_test.dart';

/// Établissement supervisé par le back-office.
///
/// Le slug `el-corazon-lome` était écrit dans cinq fichiers de l'application,
/// et la carte de supervision s'ouvrait sur Dakar. Ces tests gardent ce qui
/// remplace les deux : un périmètre lu sur `/restaurants/manage/`, que le
/// serveur calcule à partir du compte connecté.
///
/// Ce qu'ils ne gardent pas — délibérément — c'est un quelconque contrôle
/// d'accès. Le serveur refuse de lui-même une écriture hors périmètre
/// (`assert_in_scope`) ; ce service dit seulement quoi écrire, et se tait
/// quand il ne sait pas.
void main() {
  eccore.ManagedRestaurant etablissement({
    required String slug,
    String name = 'El Corazón',
    double latitude = 6.1319,
    double longitude = 1.2255,
    eccore.RestaurantLifecycle status = eccore.RestaurantLifecycle.active,
    String currency = 'XOF',
    String timezone = 'Africa/Lome',
  }) {
    return eccore.ManagedRestaurant(
      id: 'rest-$slug',
      name: name,
      slug: slug,
      zoneId: 'zone-1',
      address: 'Boulevard du 13 Janvier',
      latitude: latitude,
      longitude: longitude,
      currency: currency,
      timezone: timezone,
      status: status,
      // Projection de `status` côté serveur : un établissement en service est
      // publié, et lui seul.
      isActive: status.isPublished,
      acceptsOrders: true,
      defaultPreparationMinutes: 20,
    );
  }

  /// Service isolé, alimenté par une lecture qu'on contrôle. Elle compte ses
  /// appels : « ne pas relire à chaque écriture » fait partie du contrat.
  ({RestaurantScopeService scope, List<int> appels}) monte(
    List<eccore.ManagedRestaurant> Function() reponse,
  ) {
    final appels = <int>[];
    final scope = RestaurantScopeService.avecLecture(() async {
      appels.add(appels.length + 1);
      return reponse();
    });
    return (scope: scope, appels: appels);
  }

  group('Résolution du périmètre', () {
    test('le slug reste nul tant que rien n’a été lu', () {
      final monte1 = monte(() => [etablissement(slug: 'el-corazon-lome')]);

      // Un écran qui écrit avant la résolution ne doit pas se voir offrir un
      // établissement par défaut : c'est exactement ce que faisait la
      // constante.
      expect(monte1.scope.slug, isNull);
      expect(monte1.appels, isEmpty);
    });

    test('un périmètre d’un seul établissement n’a rien à faire choisir', () async {
      final monte1 = monte(() => [etablissement(slug: 'el-corazon-lome')]);

      await monte1.scope.resolve();

      expect(monte1.scope.slug, 'el-corazon-lome');
      expect(monte1.scope.hasChoice, isFalse);
    });

    test('requireSlug lit une fois, puis se souvient', () async {
      final monte1 = monte(() => [etablissement(slug: 'el-corazon-lome')]);

      expect(await monte1.scope.requireSlug(), 'el-corazon-lome');
      expect(await monte1.scope.requireSlug(), 'el-corazon-lome');

      // Deux créations d'affilée ne valent pas deux allers-retours : la
      // composition d'un périmètre change côté serveur, pas entre deux clics.
      expect(monte1.appels, hasLength(1));
    });

    test('force relit le périmètre', () async {
      final monte1 = monte(() => [etablissement(slug: 'el-corazon-lome')]);

      await monte1.scope.resolve();
      await monte1.scope.resolve();
      await monte1.scope.resolve(force: true);

      expect(monte1.appels, hasLength(2));
    });
  });

  group('Plusieurs établissements', () {
    List<eccore.ManagedRestaurant> deux() => [
      etablissement(slug: 'el-corazon-lome'),
      etablissement(slug: 'el-corazon-kara', latitude: 9.5511, longitude: 1.1861),
    ];

    test('le premier du périmètre sert par défaut', () async {
      final monte1 = monte(deux);

      await monte1.scope.resolve();

      expect(monte1.scope.slug, 'el-corazon-lome');
      expect(monte1.scope.hasChoice, isTrue);
    });

    test('choisir le second le rend courant', () async {
      final monte1 = monte(deux);
      await monte1.scope.resolve();

      monte1.scope.select('el-corazon-kara');

      expect(monte1.scope.slug, 'el-corazon-kara');
      expect(monte1.scope.current!.latitude, closeTo(9.5511, 1e-9));
    });

    test('un slug hors périmètre est ignoré', () async {
      // Le sélecteur n'est pas une porte d'entrée vers l'établissement d'un
      // autre : le serveur refuserait, mais l'écran ne doit pas prétendre le
      // contraire entre-temps.
      final monte1 = monte(deux);
      await monte1.scope.resolve();

      monte1.scope.select('pizzeria-du-coin');

      expect(monte1.scope.slug, 'el-corazon-lome');
    });
  });

  group('Quand le périmètre est illisible', () {
    RestaurantScopeService refus(int status) {
      return RestaurantScopeService.avecLecture(
        () async => throw eccore.ApiException(
          status: status,
          code: 'permission_denied',
          detail: 'Vous n’avez pas la permission requise.',
        ),
      );
    }

    test('un 403 se dit comme un refus, pas comme une absence de rattachement', () async {
      // Le 403 était avalé : « Opérateur », privé de `restaurants.read`,
      // lisait « Aucun établissement rattaché » sur le poste de cuisine. Le
      // périmètre se lit désormais sur une route ouverte au personnel ; si un
      // refus survient quand même, il doit se lire comme tel.
      final scope = refus(403);

      await scope.resolve();

      expect(scope.echec?.nature, NatureEchec.autorisation);
      expect(scope.echec!.nature.reessayable, isFalse);
      expect(scope.slug, isNull);
    });

    test('une vraie panne se dit, et se réessaie', () async {
      final scope = refus(500);

      await scope.resolve();

      expect(scope.echec?.nature, NatureEchec.serveur);
      expect(scope.echec!.nature.reessayable, isTrue);
    });

    test('une session expirée n’est ni un refus ni une panne', () async {
      final scope = RestaurantScopeService.avecLecture(
        () async => throw const eccore.SessionExpiredException(),
      );

      await scope.resolve();

      expect(scope.echec?.nature, NatureEchec.session);
    });

    test('un périmètre vide n’est pas un échec', () async {
      // Le compte n'est rattaché à rien : c'est `sansPerimetre` qui le dit, et
      // proposer « Réessayer » n'y changerait rien.
      final scope = RestaurantScopeService.avecLecture(() async => const []);

      await scope.resolve();

      expect(scope.echec, isNull);
      expect(scope.current, isNull);
    });

    test('requireSlug rend null plutôt qu’un établissement inventé', () async {
      expect(await refus(403).requireSlug(), isNull);
    });
  });

  group('La devise d’une écriture', () {
    test('vient de l’établissement supervisé, pas d’une constante', () async {
      // Le serveur refuse un prix dont la devise n'est pas celle de
      // l'établissement (« Cet établissement facture en GHS ; prix reçu en
      // XOF »). Avec `'XOF'` écrit en dur, le back-office ne pouvait créer
      // aucun article pour un restaurant hors zone franc CFA.
      final monte1 = monte(
        () => [etablissement(slug: 'el-corazon-accra', currency: 'GHS')],
      );

      await monte1.scope.resolve();

      expect(monte1.scope.devise, 'GHS');
      expect(monte1.scope.versMoney(12.5).currency, 'GHS');
    });

    test('l’exposant de la devise est respecté', () async {
      // Le cédi a deux décimales : 12,50 vaut 1250 unités mineures. Les
      // services faisaient `montant.round()`, ce qui en aurait fait 13 — soit
      // treize centièmes de cédi.
      final monte1 = monte(
        () => [etablissement(slug: 'el-corazon-accra', currency: 'GHS')],
      );

      await monte1.scope.resolve();

      expect(monte1.scope.versMoney(12.5).amountMinor, 1250);
    });

    test('le franc CFA n’a pas de décimale, et c’est ce qui masquait le défaut', () async {
      final monte1 = monte(() => [etablissement(slug: 'el-corazon-lome')]);

      await monte1.scope.resolve();

      expect(monte1.scope.devise, 'XOF');
      expect(monte1.scope.versMoney(3500).amountMinor, 3500);
    });

    test('sans périmètre lu, le repli ne prétend rien — le serveur tranchera', () {
      final monte1 = monte(() => [etablissement(slug: 'el-corazon-lome')]);

      // Volontairement pas `null` : un montant doit bien porter une devise
      // pour partir. Le serveur refuse et le dit clairement si elle est
      // fausse, ce qui vaut mieux qu'un écran bloqué.
      expect(monte1.scope.devise, 'XOF');
    });
  });

  test('reset oublie le périmètre de la session précédente', () async {
    // Sans cela, un second compte hériterait du slug du premier, et ses
    // créations partiraient chez l'enseigne d'à côté.
    final monte1 = monte(() => [etablissement(slug: 'el-corazon-lome')]);
    await monte1.scope.resolve();

    monte1.scope.reset();

    expect(monte1.scope.slug, isNull);
    expect(monte1.scope.restaurants, isEmpty);

    await monte1.scope.resolve();
    expect(monte1.appels, hasLength(2));
  });
}

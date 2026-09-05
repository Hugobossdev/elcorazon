import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elcora_fast/services/restaurant_context_service.dart';

/// Sur quel restaurant porte l'application.
///
/// Six constantes décrivaient l'établissement — slug, latitude, longitude, slug
/// de la ville, nom de la ville, code du pays — lues à une trentaine
/// d'endroits. Chacune était juste pour un seul restaurant et fausse pour tous
/// les autres : ouvrir un second établissement demandait de modifier le code,
/// de recompiler et de republier l'application sur deux magasins.
///
/// Ces tests gardent ce qui les remplace, et surtout les deux propriétés qui ne
/// vont pas de soi :
///
/// * **on n'invente pas de repli.** Tant que l'annuaire n'a pas répondu, le
///   slug est nul et une écriture est refusée. Un repli produirait une requête
///   qui aboutit — sur le mauvais restaurant — au lieu d'échouer franchement ;
/// * **changer d'établissement se signale.** Le panier, les caches et les
///   écrans doivent se vider, sans quoi la carte de Lomé s'afficherait sous le
///   nom d'Abidjan.
void main() {
  eccore.Restaurant etablissement({
    required String slug,
    String name = 'El Corazón',
    String city = 'Lomé',
    String citySlug = 'lome',
    String country = 'TG',
    double latitude = 6.1319,
    double longitude = 1.2255,
  }) {
    return eccore.Restaurant(
      id: 'rest-$slug',
      name: name,
      slug: slug,
      address: 'Boulevard du 13 Janvier',
      latitude: latitude,
      longitude: longitude,
      cityName: city,
      citySlug: citySlug,
      countryIsoCode: country,
      currency: 'XOF',
      estimatedDeliveryMinutes: 35,
      defaultPreparationMinutes: 20,
      isOpen: true,
      acceptsOrders: true,
      canOrderNow: true,
      phonePrefix: '+228',
    );
  }

  /// Contexte isolé, alimenté par une lecture qu'on contrôle. La lecture compte
  /// ses appels : « ne pas relire à chaque demande » fait partie du contrat.
  ({RestaurantContextService contexte, List<int> appels}) monte(
    List<eccore.Restaurant> Function() reponse, {
    Map<String, Object> memoire = const {},
  }) {
    SharedPreferences.setMockInitialValues(memoire);
    final appels = <int>[];
    final contexte = RestaurantContextService.avecLecture(
      ({double? latitude, double? longitude}) async {
        appels.add(appels.length + 1);
        return reponse();
      },
    );
    return (contexte: contexte, appels: appels);
  }

  group('Résolution', () {
    test('le slug reste nul tant que rien n’a été lu', () {
      final monte1 = monte(() => [etablissement(slug: 'el-corazon-lome')]);

      // Un écran qui écrit avant la résolution ne doit pas se voir offrir un
      // établissement par défaut : c'est exactement ce que faisait la
      // constante, et c'est pourquoi elle était fausse au deuxième restaurant.
      expect(monte1.contexte.slug, isNull);
      expect(monte1.contexte.latitude, isNull);
      expect(monte1.contexte.citySlug, isNull);
      expect(monte1.appels, isEmpty);
    });

    test('resolve rend le premier établissement quand aucun n’est choisi', () async {
      final monte1 = monte(
        () => [
          etablissement(slug: 'el-corazon-lome'),
          etablissement(slug: 'el-corazon-abidjan', city: 'Abidjan'),
        ],
      );

      await monte1.contexte.resolve();

      // Rendre le premier plutôt que rien est un raccourci assumé : l'enseigne
      // n'en a qu'un dans l'immense majorité des cas, et obliger à choisir pour
      // n'avoir qu'une option serait une étape vide.
      expect(monte1.contexte.slug, 'el-corazon-lome');
      expect(monte1.contexte.hasChoice, isTrue);
    });

    test('un second appel ne relit pas', () async {
      final monte1 = monte(() => [etablissement(slug: 'el-corazon-lome')]);

      await monte1.contexte.resolve();
      await monte1.contexte.resolve();

      expect(monte1.appels, hasLength(1));
    });

    test('force relit', () async {
      final monte1 = monte(() => [etablissement(slug: 'el-corazon-lome')]);

      await monte1.contexte.resolve();
      await monte1.contexte.resolve(force: true);

      expect(monte1.appels, hasLength(2));
    });

    test('tout ce qui était en constante vient du serveur', () async {
      final monte1 = monte(
        () => [
          etablissement(
            slug: 'el-corazon-abidjan',
            name: 'El Corazón Abidjan',
            city: 'Abidjan',
            citySlug: 'abidjan',
            country: 'CI',
            latitude: 5.3610,
            longitude: -4.0070,
          ),
        ],
      );

      await monte1.contexte.resolve();

      expect(monte1.contexte.slug, 'el-corazon-abidjan');
      expect(monte1.contexte.name, 'El Corazón Abidjan');
      expect(monte1.contexte.cityName, 'Abidjan');
      expect(monte1.contexte.citySlug, 'abidjan');
      expect(monte1.contexte.latitude, 5.3610);
      expect(monte1.contexte.longitude, -4.0070);
      // En **minuscules** : c'est la forme qu'attend `components=country:xx`
      // de Google Places, et l'écran d'adresse la passait en dur (`ci`), si
      // bien qu'un client de Lomé ne recevait aucune suggestion.
      expect(monte1.contexte.countryCode, 'ci');
      expect(monte1.contexte.currency, 'XOF');
    });
  });

  group('Écriture sans établissement', () {
    test('exigerSlug refuse plutôt que d’inventer', () async {
      final monte1 = monte(() => const []);

      // Le point de tout ce travail : plus aucune valeur de repli. Une
      // constante aurait ici rendu `el-corazon-lome`, et la commande serait
      // partie au mauvais restaurant sans que rien ne le signale.
      await expectLater(
        monte1.contexte.exigerSlug(),
        throwsA(isA<AucunEtablissement>()),
      );
    });

    test('le message dit ce qui manque, pas « une erreur est survenue »', () {
      expect(
        const AucunEtablissement().message,
        contains("Aucun restaurant n'est en service"),
      );
      expect(
        const AucunEtablissement('service indisponible').message,
        contains('service indisponible'),
      );
    });

    test('requireSlug résout d’abord, puis rend le slug', () async {
      final monte1 = monte(() => [etablissement(slug: 'el-corazon-lome')]);

      expect(await monte1.contexte.requireSlug(), 'el-corazon-lome');
      expect(monte1.appels, hasLength(1));
    });
  });

  group('Choix et persistance', () {
    test('select retient l’établissement choisi', () async {
      final monte1 = monte(
        () => [
          etablissement(slug: 'el-corazon-lome'),
          etablissement(slug: 'el-corazon-abidjan', city: 'Abidjan'),
        ],
      );
      await monte1.contexte.resolve();

      await monte1.contexte.select('el-corazon-abidjan');

      expect(monte1.contexte.slug, 'el-corazon-abidjan');
      expect(monte1.contexte.cityName, 'Abidjan');
    });

    test('un slug hors annuaire est ignoré', () async {
      final monte1 = monte(() => [etablissement(slug: 'el-corazon-lome')]);
      await monte1.contexte.resolve();

      // Le sélecteur n'est pas une porte d'entrée vers un établissement que le
      // serveur ne sert pas.
      await monte1.contexte.select('el-corazon-inconnu');

      expect(monte1.contexte.slug, 'el-corazon-lome');
    });

    test('le choix survit à une nouvelle session', () async {
      final annuaire = [
        etablissement(slug: 'el-corazon-lome'),
        etablissement(slug: 'el-corazon-abidjan', city: 'Abidjan'),
      ];

      final premiere = monte(() => annuaire);
      await premiere.contexte.resolve();
      await premiere.contexte.select('el-corazon-abidjan');

      // Rouvrir l'application sur un autre restaurant que celui qu'on
      // parcourait la veille serait déroutant, et le panier serveur — qui est
      // par établissement — semblerait avoir disparu.
      final seconde = monte(
        () => annuaire,
        memoire: {'restaurant_context_slug': 'el-corazon-abidjan'},
      );
      await seconde.contexte.resolve();

      expect(seconde.contexte.slug, 'el-corazon-abidjan');
    });

    test('un choix devenu introuvable retombe sur le premier', () async {
      // L'établissement qu'on parcourait a été suspendu : il ne figure plus
      // dans l'annuaire, et le garder ferait échouer chaque requête.
      final monte1 = monte(
        () => [etablissement(slug: 'el-corazon-lome')],
        memoire: {'restaurant_context_slug': 'el-corazon-abidjan'},
      );

      await monte1.contexte.resolve();

      expect(monte1.contexte.slug, 'el-corazon-lome');
    });
  });

  group('Changement d’établissement', () {
    test('le changement est signalé aux caches', () async {
      final monte1 = monte(
        () => [
          etablissement(slug: 'el-corazon-lome'),
          etablissement(slug: 'el-corazon-abidjan', city: 'Abidjan'),
        ],
      );
      await monte1.contexte.resolve();

      final transitions = <String>[];
      monte1.contexte.ecouterLeChangement(
        (ancien, nouveau) => transitions.add('$ancien->$nouveau'),
      );

      await monte1.contexte.select('el-corazon-abidjan');

      expect(transitions, ['el-corazon-lome->el-corazon-abidjan']);
    });

    test('choisir le même établissement ne signale rien', () async {
      final monte1 = monte(
        () => [
          etablissement(slug: 'el-corazon-lome'),
          etablissement(slug: 'el-corazon-abidjan'),
        ],
      );
      await monte1.contexte.resolve();

      final transitions = <String>[];
      monte1.contexte.ecouterLeChangement((a, n) => transitions.add('$a->$n'));

      await monte1.contexte.select('el-corazon-lome');

      // Un vidage à chaque notification effacerait le panier au moindre
      // rafraîchissement de l'annuaire.
      expect(transitions, isEmpty);
    });

    test('un rafraîchissement sans changement ne signale rien', () async {
      final monte1 = monte(() => [etablissement(slug: 'el-corazon-lome')]);
      await monte1.contexte.resolve();

      final transitions = <String>[];
      monte1.contexte.ecouterLeChangement((a, n) => transitions.add('$a->$n'));

      await monte1.contexte.resolve(force: true);

      expect(transitions, isEmpty);
    });

    test('le désabonnement coupe le signal', () async {
      final monte1 = monte(
        () => [
          etablissement(slug: 'el-corazon-lome'),
          etablissement(slug: 'el-corazon-abidjan'),
        ],
      );
      await monte1.contexte.resolve();

      final transitions = <String>[];
      final couper = monte1.contexte.ecouterLeChangement(
        (a, n) => transitions.add('$a->$n'),
      );
      couper();

      await monte1.contexte.select('el-corazon-abidjan');

      expect(transitions, isEmpty);
    });
  });

  group('Panne de l’annuaire', () {
    test('une erreur laisse le slug nul et porte le message', () async {
      final contexte = RestaurantContextService.avecLecture(
        ({double? latitude, double? longitude}) async {
          throw const eccore.ApiException(
            status: 503,
            code: 'service_unavailable',
            detail: 'Service momentanément indisponible.',
          );
        },
      );

      await contexte.resolve();

      expect(contexte.slug, isNull);
      expect(contexte.error, 'Service momentanément indisponible.');
      await expectLater(
        contexte.exigerSlug(),
        throwsA(isA<AucunEtablissement>()),
      );
    });
  });
}

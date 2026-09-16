import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elcora_fast/presentation/messages_erreur.dart';
import 'package:elcora_fast/presentation/situation_cuisine.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/services/kitchen_context_service.dart';

/// Quelle cuisine livre ce client — et pourquoi aucune, quand c'est le cas.
///
/// Ces tests gardent ce que remplaçaient six constantes, et surtout les
/// propriétés qui ne vont pas de soi :
///
/// * **on n'invente pas de repli.** Tant que l'annuaire n'a pas répondu, le
///   slug est nul et une écriture est refusée ;
/// * **une panne n'est jamais une absence de cuisine.** Le 2026-09-13,
///   l'application a affiché « Aucun restaurant n'est en service » pour un 500 de
///   l'annuaire, et pour un annuaire encore en vol ;
/// * **tous les appelants attendent la même résolution** ;
/// * **la cuisine suit l'adresse**, sauf choix explicite ;
/// * **changer de cuisine se signale** aux caches.
void main() {
  eccore.Restaurant cuisine({
    required String slug,
    String name = 'El Corazón',
    String city = 'Lomé',
    String citySlug = 'lome',
    String country = 'TG',
    double latitude = 6.1319,
    double longitude = 1.2255,
    bool canOrderNow = true,
    String unavailableCode = '',
  }) {
    return eccore.Restaurant(
      id: 'cuisine-$slug',
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
      isOpen: unavailableCode != eccore.MotifIndisponibilite.cuisineFermee,
      acceptsOrders: unavailableCode != eccore.MotifIndisponibilite.cuisineEnPause,
      canOrderNow: canOrderNow,
      unavailableCode: unavailableCode,
      phonePrefix: '+228',
    );
  }

  final origines = <(double?, double?)>[];
  setUp(origines.clear);

  /// Contexte isolé, alimenté par une lecture qu'on contrôle. La lecture compte
  /// ses appels : « ne pas relire à chaque demande » fait partie du contrat.
  ({KitchenContextService contexte, List<int> appels}) monte(
    FutureOr<List<eccore.Restaurant>> Function() reponse, {
    Map<String, Object> memoire = const {},
    VerificationDeLivraison? verification,
  }) {
    SharedPreferences.setMockInitialValues(memoire);
    final appels = <int>[];
    final contexte = KitchenContextService.avecLecture(
      ({double? latitude, double? longitude}) async {
        appels.add(appels.length + 1);
        origines.add((latitude, longitude));
        return reponse();
      },
      verification: verification,
    );
    return (contexte: contexte, appels: appels);
  }

  KitchenContextService enPanne(Object erreur) {
    SharedPreferences.setMockInitialValues(const {});
    return KitchenContextService.avecLecture(
      ({double? latitude, double? longitude}) async => throw erreur,
    );
  }

  group('Résolution', () {
    test('le slug reste nul tant que rien n’a été lu', () {
      final monte1 = monte(() => [cuisine(slug: 'el-corazon-lome')]);

      expect(monte1.contexte.slug, isNull);
      expect(monte1.contexte.latitude, isNull);
      expect(monte1.contexte.citySlug, isNull);
      expect(monte1.contexte.situation, SituationCuisine.chargement);
      expect(monte1.appels, isEmpty);
    });

    test('resolve rend la première cuisine quand aucune n’est choisie', () async {
      final monte1 = monte(
        () => [
          cuisine(slug: 'el-corazon-lome'),
          cuisine(slug: 'el-corazon-abidjan', city: 'Abidjan'),
        ],
      );

      await monte1.contexte.resolve();

      expect(monte1.contexte.slug, 'el-corazon-lome');
      expect(monte1.contexte.hasChoice, isTrue);
      expect(monte1.contexte.etat, EtatDuContexte.pret);
    });

    test('un second appel ne relit pas', () async {
      final monte1 = monte(() => [cuisine(slug: 'el-corazon-lome')]);

      await monte1.contexte.resolve();
      await monte1.contexte.resolve();

      expect(monte1.appels, hasLength(1));
    });

    test('force relit', () async {
      final monte1 = monte(() => [cuisine(slug: 'el-corazon-lome')]);

      await monte1.contexte.resolve();
      await monte1.contexte.resolve(force: true);

      expect(monte1.appels, hasLength(2));
    });

    test('tout ce qui était en constante vient du serveur', () async {
      final monte1 = monte(
        () => [
          cuisine(
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
      expect(monte1.contexte.countryCode, 'ci');
      expect(monte1.contexte.currency, 'XOF');
    });
  });

  group('La course au démarrage', () {
    test('le catalogue qui demande le slug pendant la résolution attend sa fin', () async {
      // Le défaut exact : `resolve()` rendait la main sans attendre, le slug
      // était nul, et le catalogue lisait « Aucun restaurant n'est en service ».
      final annuaire = Completer<List<eccore.Restaurant>>();
      final monte1 = monte(() => annuaire.future);

      final demarrage = monte1.contexte.resolve();
      final catalogue = monte1.contexte.exigerSlug();

      annuaire.complete([cuisine(slug: 'el-corazon-lome')]);
      await demarrage;

      expect(await catalogue, 'el-corazon-lome');
      expect(monte1.appels, hasLength(1));
    });

    test('et apprend la vraie cause si la résolution échoue', () async {
      final annuaire = Completer<List<eccore.Restaurant>>();
      final monte1 = monte(() => annuaire.future);

      final demarrage = monte1.contexte.resolve();
      // L'attente est posée avant l'échec : l'erreur ne doit pas arriver sans
      // personne pour la recevoir.
      final catalogue = expectLater(
        monte1.contexte.exigerSlug(),
        throwsA(
          isA<CuisineIndisponible>().having(
            (e) => e.situation,
            'situation',
            SituationCuisine.erreurReseau,
          ),
        ),
      );

      annuaire.completeError(eccore.ApiException.network('Connection refused'));
      await demarrage;
      await catalogue;
    });

    test('un appel forcé pendant la résolution s’enchaîne au lieu d’être perdu', () async {
      final annuaire = Completer<List<eccore.Restaurant>>();
      var premiere = true;
      final monte1 = monte(() {
        if (premiere) {
          premiere = false;
          return annuaire.future;
        }
        return [cuisine(slug: 'el-corazon-lome')];
      });

      final demarrage = monte1.contexte.resolve();
      final tri = monte1.contexte.trierParProximite(latitude: 6.13, longitude: 1.22);
      annuaire.complete([cuisine(slug: 'el-corazon-lome')]);
      await Future.wait([demarrage, tri]);

      expect(monte1.appels, hasLength(2));
      expect(origines.last, (6.13, 1.22));
    });
  });

  group('Une panne n’est jamais une absence de cuisine', () {
    test('annuaire vide : aucune cuisine — la seule voie vers ce motif', () async {
      final monte1 = monte(() => const []);

      await monte1.contexte.resolve();

      expect(monte1.contexte.etat, EtatDuContexte.aucuneCuisine);
      expect(monte1.contexte.situation, SituationCuisine.aucuneCuisine);
      await expectLater(
        monte1.contexte.exigerSlug(),
        throwsA(
          isA<CuisineIndisponible>().having(
            (e) => e.situation.code,
            'code',
            'NO_KITCHEN_AVAILABLE',
          ),
        ),
      );
    });

    final pannes = <String, (Object, SituationCuisine, String)>{
      'serveur injoignable': (
        eccore.ApiException.network('Connection refused'),
        SituationCuisine.erreurReseau,
        'NETWORK_ERROR',
      ),
      '500 en page HTML (migration non appliquée)': (
        eccore.ApiException.unreadable(500),
        SituationCuisine.erreurServeur,
        'SERVER_ERROR',
      ),
      '401': (
        const eccore.ApiException(status: 401, code: 'not_authenticated', detail: 'Jeton expiré.'),
        SituationCuisine.erreurAuthentification,
        'AUTHENTICATION_ERROR',
      ),
      '403': (
        const eccore.ApiException(status: 403, code: 'permission_denied', detail: 'Refusé.'),
        SituationCuisine.erreurAutorisation,
        'AUTHORIZATION_ERROR',
      ),
      'JSON d’une autre forme': (
        const FormatException('Unexpected character'),
        SituationCuisine.reponseInvalide,
        'INVALID_RESPONSE',
      ),
      '503 argumenté': (
        const eccore.ApiException(
          status: 503,
          code: 'service_unavailable',
          detail: 'Service momentanément indisponible.',
        ),
        SituationCuisine.erreurServeur,
        'SERVER_ERROR',
      ),
    };

    for (final MapEntry(key: nom, value: (erreur, situation, code)) in pannes.entries) {
      test('$nom → $code, jamais NO_KITCHEN_AVAILABLE', () async {
        final contexte = enPanne(erreur);

        await contexte.resolve();

        expect(contexte.slug, isNull);
        expect(contexte.etat, EtatDuContexte.echec);
        expect(contexte.situation, situation);
        expect(contexte.situation, isNot(SituationCuisine.aucuneCuisine));
        await expectLater(
          contexte.exigerSlug(),
          throwsA(isA<CuisineIndisponible>().having((e) => e.situation.code, 'code', code)),
        );
      });
    }

    test('un champ manquant dans la réponse est une réponse invalide', () async {
      // `Restaurant.fromJson` sur un corps sans `slug` lève une `TypeError`.
      final contexte = KitchenContextService.avecLecture(
        ({double? latitude, double? longitude}) async =>
            [eccore.Restaurant.fromJson(const {'id': 'x', 'name': 'Sans slug'})],
      );

      await contexte.resolve();

      expect(contexte.situation, SituationCuisine.reponseInvalide);
    });

    test('une position refusée par le serveur est une localisation invalide', () async {
      final contexte = enPanne(
        const eccore.ApiException(
          status: 400,
          code: 'validation_error',
          detail: 'lat et lon se fournissent ensemble.',
        ),
      );

      await contexte.trierParProximite(latitude: 91, longitude: 0);

      expect(contexte.etat, EtatDuContexte.localisationInvalide);
      expect(contexte.situation, SituationCuisine.localisationInvalide);
    });

    test('une actualisation qui échoue garde la cuisine connue', () async {
      var coupure = false;
      final monte1 = monte(() {
        if (coupure) throw eccore.ApiException.network('coupure');
        return [cuisine(slug: 'el-corazon-lome')];
      });
      await monte1.contexte.resolve();

      coupure = true;
      await monte1.contexte.resolve(force: true);

      expect(monte1.contexte.etat, EtatDuContexte.echec);
      expect(monte1.contexte.slug, 'el-corazon-lome');
      expect(await monte1.contexte.exigerSlug(), 'el-corazon-lome');
    });

    test('réessayer après une panne relit l’annuaire', () async {
      var coupure = true;
      final monte1 = monte(() {
        if (coupure) throw eccore.ApiException.network('coupure');
        return [cuisine(slug: 'el-corazon-lome')];
      });
      await monte1.contexte.resolve();
      expect(monte1.contexte.slug, isNull);

      coupure = false;

      expect(await monte1.contexte.exigerSlug(), 'el-corazon-lome');
      expect(monte1.appels, hasLength(2));
    });

    test('le message affiché dit la cause, pas « aucun restaurant »', () {
      final reseau = messageErreur(const CuisineIndisponible(SituationCuisine.erreurReseau));
      final vide = messageErreur(const CuisineIndisponible(SituationCuisine.aucuneCuisine));
      final serveur = messageErreur(const CuisineIndisponible(SituationCuisine.erreurServeur));

      expect(reseau, contains('connexion'));
      expect(serveur, isNot(contains('connexion')));
      expect(vide, contains('Aucune cuisine'));
      for (final message in [reseau, vide, serveur]) {
        expect(message.toLowerCase(), isNot(contains('restaurant')));
      }
    });

    test('le catalogue classe ses échecs de la même façon', () {
      expect(
        AppService.situationDeLEchec(eccore.ApiException.network('coupure')).situation,
        SituationCuisine.erreurReseau,
      );
      expect(
        AppService.situationDeLEchec(eccore.ApiException.unreadable(502)).situation,
        SituationCuisine.erreurServeur,
      );
      expect(
        AppService.situationDeLEchec(
          const CuisineIndisponible(SituationCuisine.aucuneCuisine),
        ).situation,
        SituationCuisine.aucuneCuisine,
      );
    });
  });

  group('La situation d’une cuisine connue', () {
    final cas = <String, (String, SituationCuisine)>{
      'ouverte': ('', SituationCuisine.commandable),
      'fermée': (eccore.MotifIndisponibilite.cuisineFermee, SituationCuisine.fermee),
      'en pause': (eccore.MotifIndisponibilite.cuisineEnPause, SituationCuisine.enPause),
      'suspendue': (eccore.MotifIndisponibilite.cuisineSuspendue, SituationCuisine.suspendue),
      'non publiée': (eccore.MotifIndisponibilite.cuisineNonPubliee, SituationCuisine.indisponible),
    };

    for (final MapEntry(key: nom, value: (code, attendue)) in cas.entries) {
      test('$nom → ${attendue.code}', () async {
        final monte1 = monte(
          () => [cuisine(slug: 'lome', canOrderNow: code.isEmpty, unavailableCode: code)],
        );

        await monte1.contexte.resolve();

        expect(monte1.contexte.situation, attendue);
        // Fermée ou en pause, la cuisine reste la cuisine courante : sa carte
        // se parcourt, et c'est le serveur qui refusera la commande.
        expect(monte1.contexte.slug, 'lome');
      });
    }

    test('fermée ne propose pas de réessayer, une panne si', () {
      expect(PresentationSituation.de(SituationCuisine.fermee).reessayable, isFalse);
      expect(PresentationSituation.de(SituationCuisine.aucuneCuisine).reessayable, isFalse);
      expect(PresentationSituation.de(SituationCuisine.erreurReseau).reessayable, isTrue);
    });

    test('la phrase du serveur prime sur la phrase générique', () {
      final presentation = PresentationSituation.de(
        SituationCuisine.fermee,
        motifServeur: 'La cuisine El Corazón Lomé est fermée pour le moment.',
      );

      expect(presentation.message, 'La cuisine El Corazón Lomé est fermée pour le moment.');
    });
  });

  group('Choix et persistance', () {
    test('select retient la cuisine choisie', () async {
      final monte1 = monte(
        () => [
          cuisine(slug: 'el-corazon-lome'),
          cuisine(slug: 'el-corazon-abidjan', city: 'Abidjan'),
        ],
      );
      await monte1.contexte.resolve();

      await monte1.contexte.select('el-corazon-abidjan');

      expect(monte1.contexte.slug, 'el-corazon-abidjan');
      expect(monte1.contexte.cityName, 'Abidjan');
    });

    test('un slug hors annuaire est ignoré', () async {
      final monte1 = monte(() => [cuisine(slug: 'el-corazon-lome')]);
      await monte1.contexte.resolve();

      await monte1.contexte.select('el-corazon-inconnu');

      expect(monte1.contexte.slug, 'el-corazon-lome');
    });

    test('le choix survit à une nouvelle session, sous la clé d’origine', () async {
      final annuaire = [
        cuisine(slug: 'el-corazon-lome'),
        cuisine(slug: 'el-corazon-abidjan', city: 'Abidjan'),
      ];

      final premiere = monte(() => annuaire);
      await premiere.contexte.resolve();
      await premiere.contexte.select('el-corazon-abidjan');

      // La clé n'a pas été renommée avec le service : un appareil installé
      // retrouve la cuisine de son client.
      final seconde = monte(
        () => annuaire,
        memoire: {'restaurant_context_slug': 'el-corazon-abidjan'},
      );
      await seconde.contexte.resolve();

      expect(seconde.contexte.slug, 'el-corazon-abidjan');
    });

    test('un choix devenu introuvable retombe sur la première', () async {
      final monte1 = monte(
        () => [cuisine(slug: 'el-corazon-lome')],
        memoire: {'restaurant_context_slug': 'el-corazon-abidjan'},
      );

      await monte1.contexte.resolve();

      expect(monte1.contexte.slug, 'el-corazon-lome');
    });
  });

  group('Plusieurs cuisines, plusieurs villes', () {
    test('les villes desservies sortent sans doublon, dans l’ordre du serveur', () async {
      final monte1 = monte(
        () => [
          cuisine(slug: 'lome-centre'),
          cuisine(slug: 'lome-nord'),
          cuisine(slug: 'abidjan-plateau', city: 'Abidjan', citySlug: 'abidjan', country: 'CI'),
        ],
      );

      await monte1.contexte.resolve();

      expect(monte1.contexte.villesDesservies, ['Lomé', 'Abidjan']);
    });

    test('filtrer par ville ne rend que ses cuisines', () async {
      final monte1 = monte(
        () => [
          cuisine(slug: 'lome-centre'),
          cuisine(slug: 'abidjan-plateau', city: 'Abidjan', citySlug: 'abidjan', country: 'CI'),
        ],
      );

      await monte1.contexte.resolve();

      expect(monte1.contexte.cuisinesDe('Abidjan').map((e) => e.slug), ['abidjan-plateau']);
      expect(monte1.contexte.cuisinesDe('Cotonou'), isEmpty);
    });

    test('une enseigne à une seule cuisine n’offre aucun choix', () async {
      final monte1 = monte(() => [cuisine(slug: 'el-corazon-lome')]);

      await monte1.contexte.resolve();

      expect(monte1.contexte.hasChoice, isFalse);
      expect(monte1.contexte.villesDesservies, ['Lomé']);
    });

    test('la résolution ordinaire ne transmet aucune position', () async {
      final monte1 = monte(() => [cuisine(slug: 'el-corazon-lome')]);

      await monte1.contexte.resolve();

      expect(origines.single, (null, null));
    });

    test('trier ne défait pas un choix explicite', () async {
      final monte1 = monte(
        () => [
          cuisine(slug: 'lome-centre'),
          cuisine(slug: 'abidjan-plateau', city: 'Abidjan', citySlug: 'abidjan', country: 'CI'),
        ],
      );
      await monte1.contexte.resolve();
      await monte1.contexte.select('abidjan-plateau');

      await monte1.contexte.trierParProximite(latitude: 6.13, longitude: 1.22);

      expect(monte1.contexte.slug, 'abidjan-plateau');
    });
  });

  group('La cuisine suit l’adresse de livraison', () {
    final annuaire = [
      cuisine(slug: 'abidjan-plateau', city: 'Abidjan', citySlug: 'abidjan', country: 'CI'),
      cuisine(slug: 'lome-centre'),
      cuisine(slug: 'lome-nord'),
    ];

    eccore.DeliveryAvailability desservie(String slug) => eccore.DeliveryAvailability(
      isAvailable: true,
      restaurant: annuaire.firstWhere((c) => c.slug == slug),
    );

    test('sans choix, la cuisine est celle que la géographie désigne', () async {
      // Sans adresse, la première de l'annuaire — Abidjan, par ordre
      // alphabétique — aurait été servie à un client de Lomé.
      final demandes = <String?>[];
      final monte1 = monte(
        () => annuaire,
        verification: ({required latitude, required longitude, restaurantSlug}) async {
          demandes.add(restaurantSlug);
          return desservie('lome-nord');
        },
      );
      await monte1.contexte.resolve();
      final transitions = <String>[];
      monte1.contexte.ecouterLeChangement((a, n) => transitions.add('$a->$n'));

      await monte1.contexte.suivreLAdresse(latitude: 6.17, longitude: 1.23);

      expect(monte1.contexte.slug, 'lome-nord');
      expect(monte1.contexte.desserte, DesserteAdresse.desservie);
      expect(demandes, [null]);
      expect(transitions, ['abidjan-plateau->lome-nord']);
    });

    test('une cuisine pour une ville, aucune pour une autre', () async {
      final monte1 = monte(
        () => annuaire,
        verification: ({required latitude, required longitude, restaurantSlug}) async {
          // Lomé, vers 6,1° N, a sa cuisine ; Kara, vers 9,5° N, n'en a pas.
          if (latitude < 7) return desservie('lome-centre');
          return const eccore.DeliveryAvailability(
            isAvailable: false,
            unavailableCode: eccore.MotifIndisponibilite.aucuneCuisine,
            reason: 'Aucune cuisine El Corazón ne dessert cette adresse pour le moment.',
          );
        },
      );
      await monte1.contexte.resolve();

      await monte1.contexte.suivreLAdresse(latitude: 6.13, longitude: 1.22);
      expect(monte1.contexte.situation, SituationCuisine.commandable);
      expect(monte1.contexte.slug, 'lome-centre');

      await monte1.contexte.suivreLAdresse(latitude: 9.55, longitude: 1.19);
      expect(monte1.contexte.desserte, DesserteAdresse.aucuneCuisine);
      expect(monte1.contexte.situation, SituationCuisine.aucuneCuisine);
    });

    test('un choix explicite est gardé, et dit s’il livre l’adresse', () async {
      final demandes = <String?>[];
      final monte1 = monte(
        () => annuaire,
        verification: ({required latitude, required longitude, restaurantSlug}) async {
          demandes.add(restaurantSlug);
          return eccore.DeliveryAvailability(
            isAvailable: false,
            unavailableCode: eccore.MotifIndisponibilite.adresseNonDesservie,
            reason: 'Cette adresse n’est couverte par aucune zone de livraison.',
            restaurant: annuaire.first,
          );
        },
      );
      await monte1.contexte.resolve();
      await monte1.contexte.select('abidjan-plateau');

      await monte1.contexte.suivreLAdresse(latitude: 6.13, longitude: 1.22);

      expect(monte1.contexte.slug, 'abidjan-plateau');
      expect(demandes.last, 'abidjan-plateau');
      expect(monte1.contexte.situation, SituationCuisine.adresseNonDesservie);
      expect(monte1.contexte.motifDesserte, contains('zone de livraison'));
    });

    test('une vérification en panne ne dit pas « hors zone »', () async {
      final monte1 = monte(
        () => annuaire,
        verification: ({required latitude, required longitude, restaurantSlug}) async =>
            throw eccore.ApiException.network('coupure'),
      );
      await monte1.contexte.resolve();

      await monte1.contexte.suivreLAdresse(latitude: 6.13, longitude: 1.22);

      expect(monte1.contexte.desserte, DesserteAdresse.verificationImpossible);
      expect(monte1.contexte.situation, SituationCuisine.commandable);
      expect(monte1.contexte.slug, 'abidjan-plateau');
    });

    test('une adresse retenue avant l’annuaire est prise en compte à sa réponse', () async {
      final monte1 = monte(
        () => annuaire,
        verification: ({required latitude, required longitude, restaurantSlug}) async =>
            desservie('lome-centre'),
      );

      await monte1.contexte.suivreLAdresse(latitude: 6.13, longitude: 1.22);

      expect(monte1.contexte.slug, 'lome-centre');
      expect(monte1.appels, hasLength(1));
    });
  });

  group('Changement de cuisine', () {
    test('le changement est signalé aux caches', () async {
      final monte1 = monte(
        () => [
          cuisine(slug: 'el-corazon-lome'),
          cuisine(slug: 'el-corazon-abidjan', city: 'Abidjan'),
        ],
      );
      await monte1.contexte.resolve();

      final transitions = <String>[];
      monte1.contexte.ecouterLeChangement((a, n) => transitions.add('$a->$n'));

      await monte1.contexte.select('el-corazon-abidjan');

      expect(transitions, ['el-corazon-lome->el-corazon-abidjan']);
    });

    test('choisir la même cuisine ne signale rien', () async {
      final monte1 = monte(
        () => [
          cuisine(slug: 'el-corazon-lome'),
          cuisine(slug: 'el-corazon-abidjan'),
        ],
      );
      await monte1.contexte.resolve();

      final transitions = <String>[];
      monte1.contexte.ecouterLeChangement((a, n) => transitions.add('$a->$n'));

      await monte1.contexte.select('el-corazon-lome');

      expect(transitions, isEmpty);
    });

    test('un rafraîchissement sans changement ne signale rien', () async {
      final monte1 = monte(() => [cuisine(slug: 'el-corazon-lome')]);
      await monte1.contexte.resolve();

      final transitions = <String>[];
      monte1.contexte.ecouterLeChangement((a, n) => transitions.add('$a->$n'));

      await monte1.contexte.resolve(force: true);

      expect(transitions, isEmpty);
    });

    test('une cuisine suspendue qui disparaît de l’annuaire est signalée', () async {
      var suspendue = false;
      final monte1 = monte(
        () => [
          if (!suspendue) cuisine(slug: 'el-corazon-abidjan', city: 'Abidjan'),
          cuisine(slug: 'el-corazon-lome'),
        ],
      );
      await monte1.contexte.resolve();
      final transitions = <String>[];
      monte1.contexte.ecouterLeChangement((a, n) => transitions.add('$a->$n'));

      suspendue = true;
      await monte1.contexte.resolve(force: true);

      expect(transitions, ['el-corazon-abidjan->el-corazon-lome']);
    });

    test('le désabonnement coupe le signal', () async {
      final monte1 = monte(
        () => [
          cuisine(slug: 'el-corazon-lome'),
          cuisine(slug: 'el-corazon-abidjan'),
        ],
      );
      await monte1.contexte.resolve();

      final transitions = <String>[];
      final couper = monte1.contexte.ecouterLeChangement((a, n) => transitions.add('$a->$n'));
      couper();

      await monte1.contexte.select('el-corazon-abidjan');

      expect(transitions, isEmpty);
    });
  });
}

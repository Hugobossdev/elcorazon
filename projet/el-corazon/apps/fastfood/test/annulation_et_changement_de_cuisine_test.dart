import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/presentation/annulation_commande.dart';
import 'package:elcora_fast/services/kitchen_context_service.dart';

/// Deux gestes que le client pouvait croire possibles, et qui ne l'étaient pas.
///
/// * **Annuler.** Le serveur l'accepte depuis l'origine et le centre d'aide le
///   promet — « tant que la cuisine ne l'a pas prise en charge ». Aucun écran
///   ne l'appelait.
/// * **Changer d'adresse au paiement.** Le choix était retenu aussitôt, la
///   géographie désignait une autre cuisine, et le panier affiché se vidait
///   sous les yeux du client, à l'étape du règlement. Rien n'était perdu — un
///   panier par cuisine — mais personne ne l'avait demandé.
void main() {
  group('Qui peut annuler, et quand', () {
    test('avant la prise en charge, oui', () {
      // Miroir de `CUSTOMER_CANCELLABLE` côté serveur.
      expect(peutEtreAnnuleeParLeClient(OrderStatus.pending), isTrue);
      expect(peutEtreAnnuleeParLeClient(OrderStatus.confirmed), isTrue);
    });

    test('dès que la cuisine a commencé, non', () {
      // Passé ce point, des denrées sont engagées : c'est au restaurant de
      // décider ce qui est récupérable, et le serveur refuse en 409 avec la
      // phrase à afficher.
      for (final statut in [
        OrderStatus.preparing,
        OrderStatus.ready,
        OrderStatus.pickedUp,
        OrderStatus.onTheWay,
      ]) {
        expect(peutEtreAnnuleeParLeClient(statut), isFalse, reason: '$statut');
      }
    });

    test('ce qui est joué ne s’annule pas', () {
      for (final statut in [
        OrderStatus.delivered,
        OrderStatus.cancelled,
        OrderStatus.refunded,
        OrderStatus.failed,
      ]) {
        expect(peutEtreAnnuleeParLeClient(statut), isFalse, reason: '$statut');
      }
    });
  });

  group('Demander avant de changer de cuisine', () {
    eccore.Restaurant cuisine(String slug, String ville) => eccore.Restaurant(
      id: 'cuisine-$slug',
      name: 'El Corazón $ville',
      slug: slug,
      address: 'Boulevard du 13 Janvier',
      latitude: 6.1319,
      longitude: 1.2255,
      cityName: ville,
      citySlug: ville.toLowerCase(),
      countryIsoCode: 'TG',
      currency: 'XOF',
      estimatedDeliveryMinutes: 35,
      defaultPreparationMinutes: 20,
      isOpen: true,
      acceptsOrders: true,
      canOrderNow: true,
      phonePrefix: '+228',
    );

    KitchenContextService contexte({eccore.Restaurant? desservante}) {
      SharedPreferences.setMockInitialValues(const {});
      return KitchenContextService.avecLecture(
        ({double? latitude, double? longitude}) async => [
          cuisine('el-corazon-lome', 'Lomé'),
          cuisine('el-corazon-abidjan', 'Abidjan'),
        ],
        verification:
            ({
              required double latitude,
              required double longitude,
              String? restaurantSlug,
            }) async => eccore.DeliveryAvailability(
              isAvailable: desservante != null,
              reason: '',
              restaurant: desservante,
            ),
      );
    }

    test('elle nomme la cuisine qui desservirait l’adresse', () async {
      final sut = contexte(desservante: cuisine('el-corazon-abidjan', 'Abidjan'));
      await sut.resolve();

      final desservante = await sut.cuisineQuiDesservirait(latitude: 5.36, longitude: -4.00);

      expect(desservante, 'el-corazon-abidjan');
    });

    test('elle ne change **rien** — c’est une question, pas un geste', () async {
      // Toute la valeur de cette méthode est là : la caisse doit pouvoir
      // demander « votre panier ne suivra pas, on y va ? » sans que le panier
      // ait déjà changé de cuisine au moment où elle pose la question.
      final sut = contexte(desservante: cuisine('el-corazon-abidjan', 'Abidjan'));
      await sut.resolve();
      final avant = sut.slug;

      await sut.cuisineQuiDesservirait(latitude: 5.36, longitude: -4.00);

      expect(sut.slug, avant);
      expect(sut.desserte, DesserteAdresse.inconnue);
    });

    test('aucune cuisine désignée : il n’y a rien à confirmer', () async {
      final sut = contexte();
      await sut.resolve();

      expect(
        await sut.cuisineQuiDesservirait(latitude: 48.85, longitude: 2.35),
        isNull,
      );
    });

    test('une cuisine hors annuaire ne se propose pas', () async {
      // Le serveur peut désigner un établissement que l'annuaire du client ne
      // porte pas — suspendu entre-temps, par exemple. Le proposer ferait
      // basculer le panier vers une cuisine dont on ne sait rien.
      final sut = contexte(desservante: cuisine('el-corazon-douala', 'Douala'));
      await sut.resolve();

      expect(
        await sut.cuisineQuiDesservirait(latitude: 4.05, longitude: 9.70),
        isNull,
      );
    });

    test('une vérification en panne ne propose aucun changement', () async {
      SharedPreferences.setMockInitialValues(const {});
      final sut = KitchenContextService.avecLecture(
        ({double? latitude, double? longitude}) async => [
          cuisine('el-corazon-lome', 'Lomé'),
        ],
        verification:
            ({
              required double latitude,
              required double longitude,
              String? restaurantSlug,
            }) async => throw const eccore.ApiException(
              status: 503,
              code: 'service_unavailable',
              detail: 'Service indisponible',
            ),
      );
      await sut.resolve();

      expect(
        await sut.cuisineQuiDesservirait(latitude: 6.13, longitude: 1.22),
        isNull,
      );
    });
  });
}

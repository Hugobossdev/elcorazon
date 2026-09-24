import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les chiffres de tête, et **de quelle journée** ils parlent.
///
/// ## Pourquoi la fenêtre fait partie du contrat
///
/// Le back-office calculait sa journée sur `DateTime.now()` — l'horloge de son
/// propre poste — et l'envoyait au serveur. Deux erreurs en découlaient, dont
/// la seconde est la plus tenace :
///
/// * un siège qui consulte à minuit et demi est déjà au lendemain, quand la
///   cuisine n'a pas fini sa soirée : il demandait les chiffres d'une journée
///   qui n'avait pas commencé, et lisait un tableau de bord vide ;
/// * même juste, le chiffre s'affichait **sans date**. « Revenus du jour » ne
///   dit pas de quel jour, et un chiffre sans date ne peut qu'être cru.
///
/// Le serveur republie donc la fenêtre qu'il a retenue, et le fuseau qui l'a
/// découpée. Ce fichier épingle cette partie du contrat — elle n'avait aucun
/// test, et c'est le champ le plus facile à laisser tomber d'un sérialiseur.
void main() {
  Map<String, dynamic> apercuJson({
    Map<String, dynamic> extra = const {},
    Set<String> sans = const {},
  }) {
    final json = <String, dynamic>{
      'orders_count': 12,
      'orders_delivered': 9,
      'orders_cancelled': 1,
      'revenue_minor': 54000,
      'average_basket_minor': 6000,
      'currency': 'XAF',
      'revenues': [
        {
          'currency': 'XAF',
          'orders_delivered': 9,
          'revenue_minor': 54000,
          'average_basket_minor': 6000,
        },
      ],
      'customers_count': 40,
      'couriers_online': 3,
      'menu_items_available': 18,
      'menu_items_total': 22,
      'start': '2026-09-17',
      'end': '2026-09-17',
      'timezone_name': 'Africa/Douala',
      'timezone_certain': true,
      ...extra,
    };
    for (final clef in sans) {
      json.remove(clef);
    }
    return json;
  }

  group('La fenêtre agrégée', () {
    test('la journée et son fuseau arrivent jusqu’à l’écran', () {
      final apercu = AnalyticsOverview.fromJson(apercuJson());

      expect(apercu.start, DateTime(2026, 9, 17));
      expect(apercu.end, DateTime(2026, 9, 17));
      expect(apercu.timezoneName, 'Africa/Douala');
      expect(apercu.timezoneCertain, isTrue);
      expect(apercu.estUneJournee, isTrue);
    });

    test('une fenêtre de plusieurs jours n’est pas une journée', () {
      final apercu = AnalyticsOverview.fromJson(
        apercuJson(extra: {'start': '2026-09-01', 'end': '2026-09-30'}),
      );

      expect(apercu.estUneJournee, isFalse);
    });

    test('un périmètre à cheval sur plusieurs fuseaux le dit', () {
      // Toute l'enseigne : « la journée » n'y a pas de sens unique. L'écran
      // doit l'afficher plutôt que de donner une date qui ne vaut pour
      // personne.
      final apercu = AnalyticsOverview.fromJson(
        apercuJson(extra: {'timezone_name': 'UTC', 'timezone_certain': false}),
      );

      expect(apercu.timezoneCertain, isFalse);
    });

    test('un serveur muet sur le fuseau retombe sur UTC, incertain', () {
      // Le fuseau est une **précision** : l'absence se lit « on ne sait pas »,
      // ce qui est exactement ce que `timezoneCertain` à faux signifie.
      final apercu = AnalyticsOverview.fromJson(
        apercuJson(sans: {'timezone_name', 'timezone_certain'}),
      );

      expect(apercu.timezoneName, 'UTC');
      expect(apercu.timezoneCertain, isFalse);
    });

    test('une fenêtre absente fait échouer bruyamment', () {
      // Contrairement au fuseau, la journée n'a **pas** de repli honnête : la
      // deviner sur l'horloge locale serait précisément le défaut qu'on vient
      // de corriger. Mieux vaut une lecture qui échoue — l'écran dit
      // « indisponible » — qu'un chiffre daté d'un jour inventé (ADR-009).
      expect(
        () => AnalyticsOverview.fromJson(apercuJson(sans: {'start'})),
        throwsA(anything),
      );
    });
  });

  group('Les compteurs', () {
    test('sont lus tels que le serveur les agrège', () {
      final apercu = AnalyticsOverview.fromJson(apercuJson());

      expect(apercu.ordersCount, 12);
      expect(apercu.ordersDelivered, 9);
      expect(apercu.revenueMinor, 54000);
      expect(apercu.averageBasketMinor, 6000);
    });

    test('un périmètre à deux devises ne rend aucun total mêlé', () {
      // Forme réelle du serveur depuis le 22 septembre 2026 : XOF et XAF ne
      // s'additionnent pas ; le total est nul et chaque devise a sa ligne.
      final apercu = AnalyticsOverview.fromJson(
        apercuJson(
          extra: {
            'revenue_minor': null,
            'average_basket_minor': null,
            'currency': null,
            'revenues': [
              {
                'currency': 'XAF',
                'orders_delivered': 1,
                'revenue_minor': 10000,
                'average_basket_minor': 10000,
              },
              {
                'currency': 'XOF',
                'orders_delivered': 2,
                'revenue_minor': 6000,
                'average_basket_minor': 3000,
              },
            ],
          },
        ),
      );

      expect(apercu.revenueMinor, isNull);
      expect(apercu.currency, isNull);
      expect(apercu.revenues.map((ligne) => ligne.currency), ['XAF', 'XOF']);
      expect(apercu.revenues.last.averageBasketMinor, 3000);
    });

    test('le taux d’achèvement se calcule, et ne divise pas par zéro', () {
      expect(AnalyticsOverview.fromJson(apercuJson()).completionRate, 75);
      expect(
        AnalyticsOverview.fromJson(
          apercuJson(extra: {'orders_count': 0, 'orders_delivered': 0}),
        ).completionRate,
        0,
      );
    });
  });
}

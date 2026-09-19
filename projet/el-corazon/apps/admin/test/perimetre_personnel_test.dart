import 'dart:math';

import 'package:admin/presentation/perimetre_personnel.dart';
import 'package:admin/screens/admin/personnel/dialogues_personnel.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le périmètre d'un compte du personnel, tel que le back-office l'édite.
///
/// Le serveur savait rattacher un compte à un établissement, une ville ou un
/// marché ; aucun écran ne le proposait, si bien qu'un opérateur créé par
/// `django-admin` et oublié ouvrait un poste de cuisine vide. Ces cas gardent
/// ce que l'écran dit de ce rattachement — y compris ce qu'une case accorde
/// déjà sans qu'on la coche.

const _togo = eccore.ManagedCountry(
  id: 'tg',
  isoCode: 'TG',
  name: 'Togo',
  currency: 'XOF',
  phonePrefix: '+228',
  timezone: 'Africa/Lome',
  defaultLanguage: 'fr',
  isActive: true,
);

const _lome = eccore.ManagedCity(
  id: 'ville-lome',
  name: 'Lomé',
  slug: 'lome',
  countryIsoCode: 'TG',
  isActive: true,
);

const _kara = eccore.ManagedCity(
  id: 'ville-kara',
  name: 'Kara',
  slug: 'kara',
  countryIsoCode: 'TG',
  isActive: true,
);

eccore.ManagedRestaurant _cuisine(String slug, eccore.ManagedCity ville) => eccore.ManagedRestaurant(
  id: 'id-$slug',
  name: slug,
  slug: slug,
  zoneId: 'z',
  address: '',
  latitude: 0,
  longitude: 0,
  currency: 'XOF',
  timezone: 'Africa/Lome',
  status: eccore.RestaurantLifecycle.active,
  isActive: true,
  acceptsOrders: true,
  defaultPreparationMinutes: 20,
  countryIsoCode: ville.countryIsoCode,
  cityName: ville.name,
  citySlug: ville.slug,
);

eccore.StaffMember _membre({
  List<String> restaurants = const [],
  List<String> pays = const [],
  List<String> villes = const [],
  bool siege = false,
}) =>
    eccore.StaffMember(
      id: 'staff-1',
      email: 'awa@elcorazon.com',
      fullName: 'Awa K.',
      isActive: true,
      roleIds: const [],
      restaurantSlugs: restaurants,
      countryCodes: pays,
      citySlugs: villes,
      isSuperuser: siege,
      permissions: const [],
      createdAt: DateTime(2026, 9, 18),
      updatedAt: DateTime(2026, 9, 18),
    );

void main() {
  final tokoin = _cuisine('tokoin', _lome);
  final be = _cuisine('be', _lome);
  final karaCentre = _cuisine('kara-centre', _kara);

  group('Ce qu’une case couvre déjà', () {
    test('un marché couvre ses villes et leurs cuisines', () {
      const perimetre = PerimetreDuCompte(pays: {'TG'});

      expect(perimetre.couvertureDeVille(_lome), 'TG');
      expect(perimetre.couvertureDEtablissement(tokoin), 'TG');
    });

    test('une ville couvre ses cuisines, et se nomme avant le marché', () {
      // C'est la ville qu'on décoche pour restreindre : la nommer d'abord.
      const perimetre = PerimetreDuCompte(pays: {'TG'}, villes: {'lome'});

      expect(perimetre.couvertureDEtablissement(tokoin), 'Lomé');
      expect(perimetre.couvertureDEtablissement(karaCentre), 'TG');
    });

    test('une cuisine cochée seule ne couvre pas sa voisine', () {
      const perimetre = PerimetreDuCompte(etablissements: {'tokoin'});

      expect(perimetre.couvertureDEtablissement(be), isNull);
      expect(perimetre.couvertureDeVille(_lome), isNull);
    });

    test('le code ISO se compare sans égard à la casse', () {
      final perimetre = const PerimetreDuCompte().basculerPays('tg');

      expect(perimetre.pays, {'TG'});
      expect(perimetre.couvertureDeVille(_lome), 'TG');
    });

    test('basculer deux fois rend l’état de départ', () {
      final aller = const PerimetreDuCompte().basculerVille('lome');
      final retour = aller.basculerVille('lome');

      expect(aller.villes, {'lome'});
      expect(retour.estVide, isTrue);
    });
  });

  group('La ligne sous chaque compte', () {
    test('un compte rattaché à rien est dit aveugle', () {
      expect(resumeDuPerimetre(_membre()), contains('ne voit rien'));
    });

    test('le siège est dit voir tout, même sans rattachement', () {
      // Les deux n'ont aucun rattachement ; les confondre annonce une panne
      // qui n'existe pas, ou tait une qui existe.
      expect(resumeDuPerimetre(_membre(siege: true)), contains('tout le réseau'));
    });

    test('les noms remplacent les clés quand on les connaît', () {
      final ligne = resumeDuPerimetre(
        _membre(pays: ['TG'], villes: ['lome'], restaurants: ['tokoin']),
        nomDuPays: (_) => 'Togo',
        nomDeVille: (_) => 'Lomé',
        nomDEtablissement: (_) => 'El Corazón Tokoin',
      );

      expect(ligne, 'Marché Togo · Lomé · El Corazón Tokoin');
    });

    test('au-delà de deux cuisines, le nombre remplace la liste', () {
      final ligne = resumeDuPerimetre(_membre(restaurants: ['a', 'b', 'c']));

      expect(ligne, '3 établissements');
    });
  });

  group('Le sélecteur', () {
    Future<List<PerimetreDuCompte>> monter(
      WidgetTester tester,
      PerimetreDuCompte depart,
    ) async {
      final emis = <PerimetreDuCompte>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SelecteurDePerimetre(
                perimetre: depart,
                onChanged: emis.add,
                pays: const [_togo],
                villes: const [_lome, _kara],
                etablissements: [tokoin, be, karaCentre],
              ),
            ),
          ),
        ),
      );
      return emis;
    }

    testWidgets('une cuisine couverte par sa ville est cochée et grisée', (tester) async {
      final emis = await monter(tester, const PerimetreDuCompte(villes: {'lome'}));

      final caseTokoin = tester.widget<CheckboxListTile>(
        find.ancestor(of: find.text('tokoin'), matching: find.byType(CheckboxListTile)),
      );
      expect(caseTokoin.value, isTrue);
      expect(caseTokoin.onChanged, isNull, reason: 'la décocher ne retirerait rien');
      expect(find.text('Couvert par Lomé'), findsNWidgets(2));

      // La cuisine de Kara, elle, reste libre.
      await tester.tap(find.text('kara-centre'));
      expect(emis.single.etablissements, {'kara-centre'});
    });

    testWidgets('cocher le marché émet le pays, pas ses cuisines une à une', (tester) async {
      final emis = await monter(tester, const PerimetreDuCompte());

      await tester.tap(find.text('Marché Togo'));

      expect(emis.single.pays, {'TG'});
      expect(emis.single.etablissements, isEmpty);
    });

    testWidgets('un rattachement hors de vue est annoncé, et conservé', (tester) async {
      // Un directeur pays ne voit pas la cuisine d'Abidjan d'un collègue :
      // elle n'est pas à l'écran, mais l'enregistrement la renvoie.
      final emis = await monter(
        tester,
        const PerimetreDuCompte(etablissements: {'abidjan-plateau'}),
      );

      expect(find.textContaining('1 rattachement(s) hors de votre périmètre'), findsOneWidget);

      await tester.tap(find.text('tokoin'));
      expect(emis.single.etablissements, {'abidjan-plateau', 'tokoin'});
    });
  });

  group('Le mot de passe provisoire', () {
    test('ne contient aucun caractère qui se confond à la dictée', () {
      final motDePasse = motDePasseProvisoire(aleatoire: Random(42), longueur: 400);

      expect(motDePasse, hasLength(400));
      expect(motDePasse, isNot(matches(RegExp('[0O1lI]'))));
    });

    test('satisfait la longueur minimale du serveur', () {
      expect(motDePasseProvisoire().length, greaterThanOrEqualTo(8));
    });
  });
}

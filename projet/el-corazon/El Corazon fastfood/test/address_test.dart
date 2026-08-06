import 'dart:convert';

import 'package:elcora_fast/models/address.dart';
import 'package:elcora_fast/repositories/django_address_repository.dart';
import 'package:elcora_fast/services/address_service.dart';
import 'package:elcora_fast/utils/address_sorting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Carnet d'adresses.
///
/// Le défaut central que ces tests verrouillent n'était pas une erreur de
/// calcul mais un branchement absent : `initializeForUser`, seule méthode qui
/// relie le carnet au compte, n'était appelée par personne. Le service
/// travaillait donc en permanence en mode « invité », fabriquait ses propres
/// identifiants, et n'envoyait jamais rien à `/profiles/addresses/`. Les
/// adresses s'affichaient normalement ; elles n'existaient que sur l'appareil,
/// et `POST /orders/` ne pouvait que refuser l'identifiant qu'on lui
/// transmettait ensuite.
///
/// D'où la forme de ces tests : ils vérifient **ce qui part vers le serveur**,
/// pas seulement ce que l'écran affiche.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Address adresse(
    String id, {
    required String name,
    bool isDefault = false,
    bool isFavorite = false,
    double latitude = 6.13,
    double longitude = 1.20,
    String landmark = '',
    AddressType type = AddressType.home,
    DateTime? updatedAt,
  }) {
    final horodatage = updatedAt ?? DateTime(2026);
    return Address(
      id: id,
      userId: 'client-1',
      name: name,
      address: 'Rue $name',
      city: 'Lomé',
      landmark: landmark,
      latitude: latitude,
      longitude: longitude,
      type: type,
      isDefault: isDefault,
      isFavorite: isFavorite,
      createdAt: horodatage,
      updatedAt: horodatage,
    );
  }

  group('Ordre d\'affichage du carnet', () {
    test('le tri par nom reste trié quand une adresse est en favori', () {
      // Le cas qui échouait : la passe « favoris d'abord » relançait un tri
      // non stable, et l'ordre alphabétique des autres adresses partait avec.
      final carnet = [
        adresse('4', name: 'Douane'),
        adresse('1', name: 'Atelier'),
        adresse('3', name: 'Chantier', isFavorite: true),
        adresse('2', name: 'Bureau'),
      ];

      final ordonne = sortAddressesForDisplay(
        carnet,
        sortType: AddressSortType.name,
      );

      expect(
        ordonne.map((a) => a.name),
        ['Chantier', 'Atelier', 'Bureau', 'Douane'],
      );
    });

    test('l\'adresse par défaut passe avant les favoris', () {
      final carnet = [
        adresse('1', name: 'Bureau', isFavorite: true),
        adresse('2', name: 'Maison', isDefault: true),
        adresse('3', name: 'Atelier'),
      ];

      final ordonne = sortAddressesForDisplay(
        carnet,
        sortType: AddressSortType.name,
      );

      expect(ordonne.map((a) => a.name), ['Maison', 'Bureau', 'Atelier']);
    });

    test('le tri par distance range les adresses du plus proche au plus loin', () {
      final carnet = [
        adresse('1', name: 'Loin', latitude: 6.20, longitude: 1.25),
        adresse('2', name: 'Proche', latitude: 6.14, longitude: 1.21),
        adresse('3', name: 'Moyen', latitude: 6.16, longitude: 1.22),
      ];

      final distances = {'1': 9.0, '2': 0.5, '3': 3.0};
      final ordonne = sortAddressesForDisplay(
        carnet,
        sortType: AddressSortType.distance,
        distanceFrom: (a) => distances[a.id]!,
      );

      expect(ordonne.map((a) => a.name), ['Proche', 'Moyen', 'Loin']);
    });

    test('position inconnue : le tri par distance ne réordonne rien', () {
      final carnet = [
        adresse('2', name: 'Bureau'),
        adresse('1', name: 'Atelier'),
      ];

      final ordonne = sortAddressesForDisplay(
        carnet,
        sortType: AddressSortType.distance,
      );

      // Départage par identifiant : l'ordre reste le même à chaque rebuild,
      // au lieu de dépendre de l'implémentation du tri.
      expect(ordonne.map((a) => a.id), ['1', '2']);
    });

    test('l\'entrée n\'est pas modifiée en place', () {
      final carnet = [
        adresse('1', name: 'Bureau'),
        adresse('2', name: 'Atelier', isDefault: true),
      ];
      final avant = [...carnet];

      sortAddressesForDisplay(carnet, sortType: AddressSortType.name);

      expect(carnet, avant);
    });
  });

  group('Adresse', () {
    test('le repère et les consignes survivent à un aller-retour JSON', () {
      final origine = adresse(
        '1',
        name: 'Maison',
        landmark: 'en face de la pharmacie du Golfe',
        latitude: 6.1375,
        longitude: 1.2123,
      ).copyWith(deliveryInstructions: 'portail bleu, appeler en arrivant');

      final relue = Address.fromJson(origine.toJson());

      expect(relue.landmark, 'en face de la pharmacie du Golfe');
      expect(relue.deliveryInstructions, 'portail bleu, appeler en arrivant');
      expect(relue.latitude, 6.1375);
    });

    test('une entrée sans point est refusée à la relecture', () {
      // Ces entrées existent : elles ont été écrites par la version où le
      // carnet vivait en local. Elles ne peuvent pas devenir des `Address` —
      // le serveur les refuserait — et c'est la reprise qui les traite.
      expect(
        () => Address.fromJson(const {
          'id': '1',
          'user_id': 'client-1',
          'name': 'Maison',
          'address': 'Rue des Cocotiers',
          'city': 'Lomé',
          'type': 'home',
          'is_default': true,
          'created_at': '2026-01-01T00:00:00.000',
          'updated_at': '2026-01-01T00:00:00.000',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('copyWith conserve le repère quand on ne le touche pas', () {
      final origine = adresse('1', name: 'Maison', landmark: 'près du marché');

      expect(origine.copyWith(name: 'Chez moi').landmark, 'près du marché');
    });

    test('l\'adresse sur une ligne n\'affiche pas de séparateur vide', () {
      // Le code postal est vide dans la quasi-totalité des cas ici.
      expect(adresse('1', name: 'Maison').fullAddress, 'Rue Maison, Lomé');
    });

    test('un kind inconnu du client ne fait pas échouer la lecture', () {
      expect(AddressType.fromKind('warehouse'), AddressType.other);
      expect(AddressType.fromKind('work'), AddressType.work);
    });
  });

  group('Carnet — le serveur est la source de vérité', () {
    late _FauxCarnet serveur;
    late AddressService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      serveur = _FauxCarnet();
      service = AddressService.forTest(serveur);
    });

    AddressDraft brouillon({
      required String name,
      bool isDefault = false,
      bool isFavorite = false,
      double latitude = 6.14,
      double longitude = 1.21,
    }) {
      return AddressDraft(
        name: name,
        address: 'Rue $name',
        city: 'Lomé',
        landmark: 'en face du marché',
        latitude: latitude,
        longitude: longitude,
        type: AddressType.home,
        isDefault: isDefault,
        isFavorite: isFavorite,
      );
    }

    test('une adresse ajoutée part au serveur et prend son identifiant', () async {
      await service.initializeForUser('client-1');

      final creee = await service.addAddress(brouillon(name: 'Maison'));

      // Le cœur du défaut corrigé : l'identifiant vient du serveur, jamais
      // d'un `Uuid()` local. C'est lui que `POST /orders/` devra résoudre.
      expect(serveur.creees, hasLength(1));
      expect(creee.id, 'srv-1');
      expect(service.addresses.single.id, 'srv-1');
      expect(serveur.creees.single.landmark, 'en face du marché');
    });

    test('sans session, aucune écriture ne part et l\'appel échoue', () async {
      // Le carnet vit derrière `IsAuthenticated` : une adresse enregistrée
      // « en attendant » ne pourrait jamais servir à commander.
      await expectLater(
        service.addAddress(brouillon(name: 'Maison')),
        throwsA(isA<AddressSessionRequired>()),
      );
      expect(serveur.creees, isEmpty);
      expect(service.canEdit, isFalse);
    });

    test('la première adresse est annoncée par défaut', () async {
      await service.initializeForUser('client-1');

      await service.addAddress(brouillon(name: 'Maison'));

      // Le serveur promeut lui-même la première (`perform_create`) ; le
      // carnet local ne doit pas rester sans défaut jusqu'à la synchro
      // suivante, sinon l'écran de commande ne pré-remplit rien.
      expect(serveur.creees.single.isDefault, isTrue);
      expect(service.defaultAddress?.id, 'srv-1');
      expect(service.selectedAddress?.id, 'srv-1');
    });

    test('désigner un défaut retire le précédent', () async {
      await service.initializeForUser('client-1');
      await service.addAddress(brouillon(name: 'Maison'));
      await service.addAddress(brouillon(name: 'Bureau'));

      await service.setDefaultAddress('srv-2');

      expect(service.defaultAddress?.id, 'srv-2');
      expect(
        service.addresses.where((a) => a.isDefault),
        hasLength(1),
        reason: 'la base refuse deux défauts (one_default_address_per_user)',
      );
    });

    test('supprimer le défaut en promeut un autre, côté serveur aussi', () async {
      await service.initializeForUser('client-1');
      await service.addAddress(brouillon(name: 'Maison'));
      await service.addAddress(brouillon(name: 'Bureau'));

      await service.deleteAddress('srv-1');

      // Le serveur ne promeut personne après une suppression. La promotion
      // n'était auparavant écrite qu'en mémoire : la base restait sans
      // défaut, et le carnet repartait sans au rechargement suivant.
      expect(serveur.supprimees, ['srv-1']);
      expect(service.defaultAddress?.id, 'srv-2');
      expect(serveur.modifiees.last.$1, 'srv-2');
      expect(serveur.modifiees.last.$2.isDefault, isTrue);
    });

    test('une suppression refusée par le serveur ne retire rien de l\'écran', () async {
      await service.initializeForUser('client-1');
      await service.addAddress(brouillon(name: 'Maison'));
      serveur.echoueSurSuppression = true;

      await expectLater(service.deleteAddress('srv-1'), throwsException);

      // Dans l'ordre inverse, l'adresse disparaissait de l'écran mais restait
      // en base : elle revenait à la synchronisation suivante.
      expect(service.addresses, hasLength(1));
    });

    test('le favori ne déclenche aucun appel réseau', () async {
      await service.initializeForUser('client-1');
      await service.addAddress(brouillon(name: 'Maison'));
      final avant = serveur.modifiees.length;

      await service.toggleFavorite('srv-1');

      expect(service.addresses.single.isFavorite, isTrue);
      expect(serveur.modifiees.length, avant);
    });

    test('le favori survit à une synchronisation', () async {
      await service.initializeForUser('client-1');
      await service.addAddress(brouillon(name: 'Maison'));
      await service.toggleFavorite('srv-1');

      await service.refresh();

      // Le serveur ignore ce champ et rend `false` : sans report local,
      // l'étoile s'éteignait à chaque rechargement.
      expect(service.addresses.single.isFavorite, isTrue);
    });

    test('le choix du client survit à une synchronisation', () async {
      await service.initializeForUser('client-1');
      await service.addAddress(brouillon(name: 'Maison'));
      await service.addAddress(brouillon(name: 'Bureau'));
      await service.selectAddress('srv-2');

      await service.refresh();

      // Remplacer la sélection par le défaut ramenait « Maison » à chaque
      // réouverture, et le client ne s'en apercevait qu'à la commande.
      expect(service.selectedAddress?.id, 'srv-2');
    });

    test('un serveur injoignable laisse le carnet en cache affiché', () async {
      await service.initializeForUser('client-1');
      await service.addAddress(brouillon(name: 'Maison'));

      serveur.echoueSurLecture = true;
      await service.refresh();

      // Un carnet vide et un carnet inconnu ne se ressemblent que pour celui
      // qui regarde l'écran : vider ici ferait proposer « ajoutez votre
      // première adresse » à quelqu'un qui en a déjà.
      expect(service.addresses, hasLength(1));
    });

    test('la déconnexion ferme le carnet', () async {
      await service.initializeForUser('client-1');
      await service.addAddress(brouillon(name: 'Maison'));

      await service.clearSession();

      expect(service.addresses, isEmpty);
      expect(service.canEdit, isFalse);
    });
  });

  group('Reprise des carnets restés locaux', () {
    late _FauxCarnet serveur;
    late AddressService service;

    /// Une entrée telle que la version précédente l'écrivait : identifiant
    /// fabriqué localement, jamais connu du serveur.
    Map<String, dynamic> entreeLocale({
      required String name,
      bool isDefault = false,
      bool isFavorite = false,
      double? latitude = 6.14,
      double? longitude = 1.21,
    }) {
      return {
        'id': 'uuid-local-$name',
        'user_id': 'guest',
        'name': name,
        'address': 'Rue $name',
        'city': 'Lomé',
        'landmark': 'près du marché',
        'latitude': latitude,
        'longitude': longitude,
        'type': 'home',
        'is_default': isDefault,
        'is_favorite': isFavorite,
        'created_at': '2026-01-01T00:00:00.000',
        'updated_at': '2026-01-01T00:00:00.000',
      };
    }

    setUp(() => serveur = _FauxCarnet());

    test('les adresses locales sont envoyées au serveur, puis oubliées', () async {
      SharedPreferences.setMockInitialValues({
        'user_addresses_guest': [
          jsonEncode(entreeLocale(name: 'Maison', isDefault: true)),
          jsonEncode(entreeLocale(name: 'Bureau', isFavorite: true)),
        ],
        'selected_address_id_guest': 'uuid-local-Maison',
      });
      service = AddressService.forTest(serveur);

      await service.initializeForUser('client-1');

      // Sans cette reprise, la bascule ferait disparaître d'un coup le carnet
      // de chaque appareil déjà installé.
      expect(serveur.creees.map((d) => d.name), ['Maison', 'Bureau']);
      expect(service.addresses.map((a) => a.name), ['Maison', 'Bureau']);
      expect(serveur.creees.first.landmark, 'près du marché');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('user_addresses_guest'), isNull);
      expect(prefs.getString('selected_address_id_guest'), isNull);
    });

    test('le favori local suit l\'adresse reprise', () async {
      SharedPreferences.setMockInitialValues({
        'user_addresses_guest': [
          jsonEncode(entreeLocale(name: 'Bureau', isFavorite: true)),
        ],
      });
      service = AddressService.forTest(serveur);

      await service.initializeForUser('client-1');

      expect(service.addresses.single.isFavorite, isTrue);
    });

    test('une adresse locale sans point n\'est pas reprise', () async {
      // `location` est obligatoire côté serveur, et rien ici ne peut inventer
      // le point. Ces entrées ne pouvaient de toute façon servir à aucune
      // commande.
      SharedPreferences.setMockInitialValues({
        'user_addresses_guest': [
          jsonEncode(entreeLocale(name: 'Sans point', latitude: null)),
          jsonEncode(entreeLocale(name: 'Maison')),
        ],
      });
      service = AddressService.forTest(serveur);

      await service.initializeForUser('client-1');

      expect(serveur.creees.map((d) => d.name), ['Maison']);
    });

    test('la reprise ne duplique pas une adresse déjà présente au serveur', () async {
      serveur.existantes.add(
        _AdresseServeur(
          id: 'srv-0',
          draft: const AddressDraft(
            name: 'Maison',
            address: 'Rue Maison',
            city: 'Lomé',
            latitude: 6.14,
            longitude: 1.21,
            type: AddressType.home,
            isDefault: true,
          ),
        ),
      );
      SharedPreferences.setMockInitialValues({
        'user_addresses_guest': [jsonEncode(entreeLocale(name: 'Maison'))],
      });
      service = AddressService.forTest(serveur);

      await service.initializeForUser('client-1');

      expect(serveur.creees, isEmpty);
      expect(service.addresses, hasLength(1));
    });

    test('une reprise échouée garde les entrées pour le prochain démarrage', () async {
      SharedPreferences.setMockInitialValues({
        'user_addresses_guest': [jsonEncode(entreeLocale(name: 'Maison'))],
      });
      serveur.echoueSurCreation = true;
      service = AddressService.forTest(serveur);

      await service.initializeForUser('client-1');

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getStringList('user_addresses_guest'),
        isNotNull,
        reason: 'perdre l\'adresse serait pire que retenter demain',
      );
    });
  });
}

class _AdresseServeur {
  _AdresseServeur({required this.id, required this.draft});

  final String id;
  AddressDraft draft;
}

/// Serveur de carnet en mémoire, appliquant les règles de `AddressViewSet` :
/// il attribue les identifiants, promeut la première adresse, et rétrograde
/// l'ancien défaut. Il ignore `isFavorite`, comme le vrai.
class _FauxCarnet implements AddressBookRepository {
  final List<_AdresseServeur> existantes = [];
  final List<AddressDraft> creees = [];
  final List<(String, AddressDraft)> modifiees = [];
  final List<String> supprimees = [];

  bool echoueSurLecture = false;
  bool echoueSurCreation = false;
  bool echoueSurSuppression = false;

  int _prochainId = 0;

  Address _rendu(_AdresseServeur stockee, String userId) {
    return Address(
      id: stockee.id,
      userId: userId,
      name: stockee.draft.name,
      address: stockee.draft.address,
      city: stockee.draft.city,
      postalCode: stockee.draft.postalCode,
      landmark: stockee.draft.landmark,
      deliveryInstructions: stockee.draft.deliveryInstructions,
      latitude: stockee.draft.latitude,
      longitude: stockee.draft.longitude,
      type: stockee.draft.type,
      isDefault: stockee.draft.isDefault,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
  }

  void _retrograderLeDefaut() {
    for (final a in existantes) {
      if (a.draft.isDefault) a.draft = a.draft.copyWith(isDefault: false);
    }
  }

  @override
  Future<List<Address>> list({required String userId}) async {
    if (echoueSurLecture) throw Exception('réseau indisponible');
    return existantes.map((a) => _rendu(a, userId)).toList();
  }

  @override
  Future<Address> create(AddressDraft draft, {required String userId}) async {
    if (echoueSurCreation) throw Exception('création refusée');
    creees.add(draft);

    final premiere = existantes.isEmpty;
    final estDefaut = draft.isDefault || premiere;
    if (estDefaut) _retrograderLeDefaut();

    final stockee = _AdresseServeur(
      id: 'srv-${++_prochainId}',
      draft: draft.copyWith(isDefault: estDefaut),
    );
    existantes.add(stockee);
    return _rendu(stockee, userId);
  }

  @override
  Future<Address> update(
    String id,
    AddressDraft draft, {
    required String userId,
  }) async {
    modifiees.add((id, draft));
    if (draft.isDefault) _retrograderLeDefaut();

    final stockee = existantes.firstWhere((a) => a.id == id);
    stockee.draft = draft;
    return _rendu(stockee, userId);
  }

  @override
  Future<void> delete(String id) async {
    if (echoueSurSuppression) throw Exception('suppression refusée');
    supprimees.add(id);
    existantes.removeWhere((a) => a.id == id);
  }
}

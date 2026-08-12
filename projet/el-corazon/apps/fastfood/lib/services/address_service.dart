import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

import 'package:elcora_fast/presentation/adresse.dart';
import 'package:elcora_fast/repositories/django_address_repository.dart';

/// Levée par toute écriture tentée sans session.
///
/// Le carnet vit côté serveur, derrière `IsAuthenticated` : sans session il n'y
/// a pas de carnet, et une adresse enregistrée « en attendant » ne pourrait
/// jamais servir à commander. Dire non tout de suite vaut mieux que de laisser
/// saisir une adresse que le paiement refusera.
class AddressSessionRequired implements Exception {
  const AddressSessionRequired();

  @override
  String toString() => 'Connectez-vous pour gérer vos adresses de livraison.';
}

/// Carnet d'adresses du client.
///
/// **Le serveur est la source de vérité, sans exception.** Le stockage local
/// n'est qu'un cache de lecture : il permet d'afficher le carnet avant que le
/// réseau réponde, et de continuer à l'afficher s'il ne répond pas. Il ne
/// crée rien, ne numérote rien, et ne survit pas à une réponse du serveur qui
/// le contredit.
///
/// Ce point était l'inverse auparavant, et c'est ce qui empêchait de commander.
/// [initializeForUser] — seul endroit qui renseignait `_userId`, et donc seule
/// condition qui activait les appels Django — n'était appelé par personne. Le
/// service travaillait en permanence en mode « invité » : chaque adresse
/// recevait un UUID fabriqué ici, était écrite dans `SharedPreferences`, et
/// n'atteignait jamais `/profiles/addresses/`. Au paiement, cet identifiant
/// partait comme `address` dans `POST /orders/`, où le serveur ne pouvait que
/// le rejeter — il ne l'avait jamais émis. Le carnet s'affichait pourtant
/// normalement, et rien n'indiquait au client que ses adresses n'existaient
/// que sur son téléphone.
///
/// Les carnets ainsi constitués existent sur les appareils déjà installés :
/// [_adoptLegacyBook] les reprend au premier démarrage muni d'une session,
/// plutôt que de les laisser tomber.
class AddressService extends ChangeNotifier {
  factory AddressService() => _instance;
  AddressService._internal();

  /// Constructeur de test : une instance isolée, avec un dépôt substituable.
  /// Le singleton reste le seul chemin utilisé par l'application.
  @visibleForTesting
  AddressService.forTest(AddressBookRepository repository) : _repository = repository;

  static final AddressService _instance = AddressService._internal();

  /// Construit à la première écriture, et non dans le constructeur : le dépôt
  /// réel lit `apiClient` dans `main.dart`, ce qui déclencherait Firebase au
  /// simple fait de nommer le service.
  AddressBookRepository? _repository;
  AddressBookRepository get _addresses => _repository ??= DjangoAddressRepository();

  List<eccore.Address> _book = const [];
  Set<String> _favoriteIds = <String>{};
  String? _selectedId;
  String? _userId;
  bool _isInitialized = false;
  bool _isSyncing = false;

  /// Empêche deux synchronisations simultanées de se doubler — le geste
  /// « tirer pour rafraîchir » pendant que l'ouverture de l'écran charge déjà.
  Future<void>? _pendingSync;

  List<eccore.Address> get addresses => List.unmodifiable(_book);
  eccore.Address? get selectedAddress => _book.where((a) => a.id == _selectedId).firstOrNull;
  eccore.Address? get defaultAddress => _book.where((a) => a.isDefault).firstOrNull;
  List<eccore.Address> get favoriteAddresses =>
      _book.where((a) => estFavorite(a.id!)).toList();

  /// L'adresse est-elle marquée d'une étoile ?
  ///
  /// Le serveur ne connaît pas ce champ, et l'entité du socle non plus : c'est
  /// une préférence d'appareil, rangée ici et persistée en `SharedPreferences`.
  /// La porter sur l'adresse obligeait à réestampiller le carnet entier à
  /// chaque lecture, et à la réécrire après chaque réponse du serveur.
  bool estFavorite(String id) => _favoriteIds.contains(id);
  bool get isInitialized => _isInitialized;
  bool get hasAddresses => _book.isNotEmpty;
  bool get isSyncing => _isSyncing;

  /// Vrai quand une session est ouverte — donc quand le carnet est modifiable.
  /// Les écrans s'en servent pour proposer la connexion plutôt qu'un formulaire
  /// dont l'enregistrement échouerait.
  bool get canEdit => _userId != null;

  // ------------------------------------------------------------------ session

  /// Ouvre le carnet du client connecté.
  ///
  /// Affiche d'abord le cache — instantané, et seul contenu disponible hors
  /// ligne — puis se cale sur le serveur.
  Future<void> initializeForUser(String userId) async {
    if (_userId == userId && _isInitialized) {
      await refresh();
      return;
    }

    _userId = userId;
    await _loadFromCache();
    _isInitialized = true;
    notifyListeners();

    await refresh();
  }

  /// Ferme le carnet. Le cache de ce compte reste sur l'appareil : il sera
  /// relu à la reconnexion, et c'est ce qui permet d'afficher ses adresses
  /// avant la première réponse du serveur.
  Future<void> clearSession() async {
    _userId = null;
    _book = const [];
    _favoriteIds = <String>{};
    _selectedId = null;
    _isInitialized = false;
    notifyListeners();
  }

  /// Relit le carnet depuis le serveur.
  ///
  /// Un échec réseau **ne vide pas** l'affichage : le cache reste en place. Un
  /// carnet vide et un carnet inconnu ne se ressemblent que sur l'écran de
  /// celui qui les regarde, et confondre les deux ferait proposer « ajoutez
  /// votre première adresse » à un client qui en a cinq.
  Future<void> refresh() {
    if (_userId == null) return Future<void>.value();
    return _pendingSync ??= _pullFromServer().whenComplete(() {
      _pendingSync = null;
    });
  }

  Future<void> _pullFromServer() async {
    final userId = _userId;
    if (userId == null) return;

    _isSyncing = true;
    notifyListeners();

    try {
      var remote = await _addresses.list();
      remote = await _adoptLegacyBook(remote);
      _book = remote;
      _repairSelection();
      await _saveToCache();
    } catch (e) {
      eccore.Journal.trace('AddressService: synchronisation impossible — $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------------ lecture


  /// Garde une sélection cohérente avec le carnet.
  ///
  /// Le choix du client survit à une synchronisation tant que l'adresse
  /// choisie existe encore. Cette ligne la remplaçait auparavant sans
  /// condition par l'adresse par défaut : un client qui s'était fait livrer au
  /// bureau retrouvait « Maison » à la réouverture, et ne s'en apercevait qu'à
  /// la commande.
  void _repairSelection() {
    if (_book.any((a) => a.id == _selectedId)) return;
    _selectedId = (defaultAddress ?? _book.firstOrNull)?.id;
  }

  /// Recherche sur les champs qu'un client retient réellement.
  ///
  /// Le repère est inclus : « en face de la pharmacie » est souvent le seul
  /// terme dont il se souvienne, et le chercher sans lui ne renvoyait rien.
  List<eccore.Address> searchAddresses(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return addresses;

    return _book
        .where(
          (address) => [
            address.label,
            address.line1,
            address.line2,
            address.cityName ?? '',
            address.landmark,
          ].any((field) => field.toLowerCase().contains(needle)),
        )
        .toList();
  }

  // ----------------------------------------------------------------- écriture

  /// Crée l'adresse côté serveur, puis l'ajoute au carnet.
  ///
  /// Dans cet ordre, et jamais l'inverse : c'est le serveur qui attribue
  /// l'identifiant, et une adresse affichée avant d'exister chez lui est une
  /// adresse avec laquelle on ne peut pas commander.
  Future<eccore.Address> addAddress(BrouillonAdresse draft) async {
    _requireSession();

    // Le serveur promeut lui-même la première adresse du carnet
    // (`AddressViewSet.perform_create`) ; l'annoncer ici évite que le carnet
    // local reste sans défaut jusqu'à la synchronisation suivante.
    final created = await _addresses.create(
      _book.isEmpty ? draft.copyWith(estParDefaut: true) : draft,
    );

    if (draft.estFavorite) _favoriteIds.add(created.id!);

    // Les autres ne sont rétrogradées que si celle-ci prend le défaut — c'est
    // ce que fait le serveur (`_demote_current_default`). Rétrograder dans
    // tous les cas, comme on le faisait, retirait son défaut au carnet dès
    // qu'on y ajoutait une adresse ordinaire.
    _book = [
      ...(created.isDefault ? _applyDefault(_book, created.id!) : _book),
      created,
    ];
    if (created.isDefault || _book.length == 1) _selectedId = created.id;

    await _saveToCache();
    notifyListeners();
    return created;
  }

  Future<eccore.Address> updateAddress(String id, BrouillonAdresse draft) async {
    _requireSession();
    _requireKnown(id);

    final updated = await _addresses.update(id, draft);

    if (draft.estFavorite) {
      _favoriteIds.add(id);
    } else {
      _favoriteIds.remove(id);
    }

    // Même règle qu'à l'ajout : les autres ne bougent que si celle-ci vient de
    // prendre le défaut.
    _book = (updated.isDefault ? _applyDefault(_book, id) : _book)
        .map((a) => a.id == id ? updated : a)
        .toList();

    await _saveToCache();
    notifyListeners();
    return updated;
  }

  /// Supprime l'adresse — serveur d'abord, écran ensuite.
  ///
  /// Dans l'ordre inverse, un appel réseau qui échoue laissait l'adresse
  /// disparue de l'écran mais toujours présente en base : elle revenait à la
  /// synchronisation suivante, et le client la voyait ressusciter.
  Future<void> deleteAddress(String id) async {
    _requireSession();
    final removed = _requireKnown(id);

    await _addresses.delete(id);

    _favoriteIds.remove(id);
    _book = _book.where((a) => a.id != id).toList();
    _repairSelection();

    // Le serveur ne promeut personne après une suppression : sans cette
    // reprise, le carnet reste sans adresse par défaut et l'écran de commande
    // ne pré-remplit plus rien. La promotion n'était auparavant écrite qu'en
    // mémoire — la base, elle, restait sans défaut.
    if (removed.isDefault && _book.isNotEmpty) {
      await _promoteToDefault(_book.first.id!);
    }

    await _saveToCache();
    notifyListeners();
  }

  Future<void> setDefaultAddress(String id) async {
    _requireSession();
    _requireKnown(id);
    await _promoteToDefault(id);
    _selectedId = id;
    await _saveToCache();
    notifyListeners();
  }

  Future<void> _promoteToDefault(String id) async {
    final userId = _userId;
    if (userId == null) return;

    final address = _book.firstWhere((a) => a.id == id);
    final promoted = await _addresses.update(
      id,
      BrouillonAdresse.depuis(address).copyWith(estParDefaut: true),
    );

    // Le serveur rétrograde l'ancien défaut dans la même transaction
    // (`_demote_current_default`) ; le carnet local s'aligne sans relire.
    _book = _applyDefault(_book, id)
        .map((a) => a.id == id ? promoted : a)
        .toList();
  }

  /// Le choix de livraison. Purement local et volontairement : il désigne la
  /// commande en cours, pas une préférence de compte — c'est `is_default` qui
  /// porte celle-là, et elle, le serveur la connaît.
  Future<void> selectAddress(String id) async {
    _requireKnown(id);
    _selectedId = id;
    await _saveToCache();
    notifyListeners();
  }

  /// Bascule le favori — local, et sans aller-retour réseau.
  ///
  /// Le serveur n'a pas ce champ. Passer par [updateAddress] déclenchait un
  /// `PATCH` complet pour une étoile qui ne quitte jamais l'appareil, et
  /// l'adresse rendue par le serveur écrasait au retour l'étoile qu'on venait
  /// d'allumer.
  Future<void> toggleFavorite(String id) async {
    _requireKnown(id);

    if (!_favoriteIds.add(id)) _favoriteIds.remove(id);

    await _saveToCache();
    notifyListeners();
  }

  /// Un seul défaut dans le carnet, comme dans la base — l'index unique partiel
  /// `one_default_address_per_user` en fait une contrainte, pas une convention.
  List<eccore.Address> _applyDefault(List<eccore.Address> book, String? defaultId) {
    return book.map((a) => a.copyWith(isDefault: a.id == defaultId)).toList();
  }

  String _requireSession() {
    final userId = _userId;
    if (userId == null) throw const AddressSessionRequired();
    return userId;
  }

  eccore.Address _requireKnown(String id) {
    final address = _book.where((a) => a.id == id).firstOrNull;
    if (address == null) {
      throw StateError('Adresse $id absente du carnet.');
    }
    return address;
  }

  // -------------------------------------------------------------- persistance

  String get _bookKey => 'address_book_$_userId';
  String get _selectedKey => 'address_selected_$_userId';
  String get _favoritesKey => 'address_favorites_$_userId';

  Future<void> _loadFromCache() async {
    _book = const [];
    _favoriteIds = <String>{};
    _selectedId = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      _favoriteIds = (prefs.getStringList(_favoritesKey) ?? const []).toSet();
      _selectedId = prefs.getString(_selectedKey);
      _book = (prefs.getStringList(_bookKey) ?? const [])
          .map((e) => eccore.Address.fromJson(jsonDecode(e) as Map<String, dynamic>))
          .toList();
      _repairSelection();
    } catch (e) {
      // Cache illisible (format changé, écriture interrompue) : on repart d'un
      // carnet vide, que la synchronisation remplira. Aucune raison de faire
      // échouer l'ouverture de l'application pour un cache.
      eccore.Journal.trace('AddressService: cache illisible, ignoré — $e');
      _book = const [];
    }
  }

  Future<void> _saveToCache() async {
    if (_userId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final selectedId = _selectedId;

      if (_book.isEmpty) {
        await prefs.remove(_bookKey);
      } else {
        await prefs.setStringList(
          _bookKey,
          _book.map((a) => jsonEncode(a.versCache())).toList(),
        );
      }

      if (_favoriteIds.isEmpty) {
        await prefs.remove(_favoritesKey);
      } else {
        await prefs.setStringList(_favoritesKey, _favoriteIds.toList());
      }

      if (selectedId == null) {
        await prefs.remove(_selectedKey);
      } else {
        await prefs.setString(_selectedKey, selectedId);
      }
    } catch (e) {
      eccore.Journal.trace('AddressService: cache non écrit — $e');
    }
  }

  // ------------------------------------------------- reprise des carnets 2025

  /// Clés du carnet purement local d'avant cette version.
  ///
  /// `guest` est la seule qui compte en pratique : `_userId` n'étant jamais
  /// renseigné, tout y atterrissait, y compris pour un client connecté. La clé
  /// nominative est reprise aussi, au cas où une version antérieure l'ait
  /// alimentée.
  List<String> get _legacyBookKeys => [
        'user_addresses_guest',
        'user_addresses_$_userId',
      ];

  /// Envoie au serveur les adresses restées locales, puis efface les clés.
  ///
  /// Sans cela, la bascule ferait disparaître d'un coup le carnet de chaque
  /// appareil déjà installé — des adresses saisies à la main, avec leur repère,
  /// que personne n'a ailleurs.
  ///
  /// Rend le carnet serveur augmenté des adresses reprises. Une reprise qui
  /// échoue laisse les clés en place : elle sera retentée au prochain
  /// démarrage, plutôt que de perdre l'adresse.
  Future<List<eccore.Address>> _adoptLegacyBook(
    List<eccore.Address> remote,
  ) async {
    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e) {
      eccore.Journal.trace('AddressService: reprise impossible, stockage illisible — $e');
      return remote;
    }

    final legacy = <Map<String, dynamic>>[];
    for (final key in _legacyBookKeys) {
      for (final entry in prefs.getStringList(key) ?? const <String>[]) {
        try {
          legacy.add(jsonDecode(entry) as Map<String, dynamic>);
        } catch (_) {
          // Entrée illisible : elle ne redeviendra pas lisible, on la laisse.
        }
      }
    }
    if (legacy.isEmpty) {
      await _forgetLegacyKeys(prefs);
      return remote;
    }

    final adopted = <eccore.Address>[];
    var allAdopted = true;

    for (final entry in legacy) {
      final local = _depuisCarnet2025(entry);
      if (local == null) continue;
      if (_dejaSurLeServeur(local, [...remote, ...adopted])) continue;

      try {
        final created = await _addresses.create(
          local.copyWith(
            // Le défaut se rejoue seulement si le carnet serveur n'en a pas :
            // celui du serveur, plus récent, prime sur celui du cache.
            estParDefaut: local.estParDefaut && remote.every((a) => !a.isDefault),
          ),
        );
        if (local.estFavorite) _favoriteIds.add(created.id!);
        adopted.add(created);
      } catch (e) {
        eccore.Journal.trace('AddressService: reprise de "${local.nom}" échouée — $e');
        allAdopted = false;
      }
    }

    if (allAdopted) await _forgetLegacyKeys(prefs);
    if (adopted.isNotEmpty) {
      eccore.Journal.trace('AddressService: ${adopted.length} adresse(s) locale(s) reprise(s).');
    }
    return [...remote, ...adopted];
  }

  /// Une adresse est déjà là si son nom et son point coïncident. La comparaison
  /// des coordonnées est tolérante d'environ dix mètres : le serveur reprojette
  /// en `geography`, et exiger l'égalité stricte de deux `double` créerait un
  /// doublon à chaque démarrage.
  bool _dejaSurLeServeur(BrouillonAdresse local, List<eccore.Address> book) {
    return book.any(
      (a) =>
          a.label.trim().toLowerCase() == local.nom.trim().toLowerCase() &&
          (a.latitude - local.latitude).abs() < 0.0001 &&
          (a.longitude - local.longitude).abs() < 0.0001,
    );
  }

  /// Lit une entrée du carnet purement local d'avant cette version.
  ///
  /// Ce n'est **pas** la forme du serveur : le modèle d'alors rangeait le point
  /// à plat (`latitude`/`longitude`) plutôt que dans un objet `location`, et
  /// nommait ses champs autrement. `eccore.Address.fromJson` ne saurait pas la
  /// lire, et rien ne l'y obligeait — une entrée locale est un **brouillon** à
  /// créer côté serveur, pas une adresse qui existe déjà.
  ///
  /// Rend `null` pour une entrée inexploitable. Sans point, le serveur
  /// refuserait l'adresse (`location` obligatoire) et rien ici ne peut
  /// inventer un lieu : ces entrées ne pouvaient de toute façon servir à
  /// aucune commande.
  BrouillonAdresse? _depuisCarnet2025(Map<String, dynamic> json) {
    final latitude = (json['latitude'] as num?)?.toDouble();
    final longitude = (json['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) {
      eccore.Journal.trace('AddressService: adresse locale sans point, non reprise.');
      return null;
    }

    final nom = json['name'] as String?;
    final ligne1 = json['address'] as String?;
    if (nom == null || ligne1 == null) {
      eccore.Journal.trace('AddressService: adresse locale illisible, ignorée.');
      return null;
    }

    return BrouillonAdresse(
      nom: nom,
      ligne1: ligne1,
      // `postal_code` du carnet 2025 : le serveur n'a pas de code postal, et
      // c'est `line2` qui recueillait déjà cette saisie.
      ligne2: json['postal_code'] as String? ?? '',
      repere: json['landmark'] as String? ?? '',
      consignes: json['delivery_instructions'] as String? ?? '',
      latitude: latitude,
      longitude: longitude,
      type: TypeAdresse.depuisServeur(json['type'] as String? ?? ''),
      estParDefaut: json['is_default'] as bool? ?? false,
      estFavorite: json['is_favorite'] as bool? ?? false,
    );
  }

  Future<void> _forgetLegacyKeys(SharedPreferences prefs) async {
    for (final key in _legacyBookKeys) {
      await prefs.remove(key);
    }
    await prefs.remove('selected_address_id_guest');
    await prefs.remove('selected_address_id_$_userId');
  }
}

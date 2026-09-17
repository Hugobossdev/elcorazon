import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:elcora_fast/main.dart' show poserLeConteneurPourTests;
import 'package:elcora_fast/services/app_service.dart';

/// Ce qu'un compte laisse derrière lui — et ce qu'il trouve en arrivant.
///
/// ## Les deux défauts que cette suite ferme
///
/// * **L'historique survivait à la déconnexion.** `_orders` n'était vidé nulle
///   part : sur un téléphone partagé — le cas courant ici — le compte suivant
///   voyait les commandes du précédent jusqu'au premier rechargement. Le
///   récapitulatif du profil en comptait les commandes, et les recommandations
///   s'en nourrissaient.
/// * **Il manquait à la connexion.** Il n'était lu qu'au **démarrage**, et
///   seulement si une session existait déjà : quelqu'un qui ouvrait
///   l'application en visiteur puis se connectait lisait « Aucune commande
///   passée » sur un compte qui en avait, jusqu'à ce qu'il pense à tirer la
///   liste vers le bas.
const _canalStockage = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
const _entetesJson = {
  Headers.contentTypeHeader: [Headers.jsonContentType],
};

Map<String, dynamic> _montant(int mineur) => {'amount': '$mineur', 'currency': 'XOF'};

Map<String, dynamic> _compte(String id, String email) => {
  'id': id,
  'email': email,
  'phone': null,
  'full_name': 'Client $id',
  'user_type': 'customer',
  'avatar': null,
  'is_active': true,
  'permissions': const <String>[],
  'email_verified_at': '2026-09-01T10:00:00Z',
  'phone_verified_at': null,
  'last_seen_at': null,
  'created_at': '2026-09-01T10:00:00Z',
  'updated_at': '2026-09-01T10:00:00Z',
};

Map<String, dynamic> _commande(String id, String reference) => {
  'id': id,
  'reference': reference,
  'restaurant': 'el-corazon-lome',
  'restaurant_name': 'El Corazón Lomé',
  'status': 'delivered',
  'allowed_transitions': const <String>[],
  'subtotal': _montant(4000),
  'delivery_fee': _montant(500),
  'discount': _montant(0),
  'total': _montant(4500),
  'payment_method': 'cash',
  'delivery_address_line': 'Rue du Commerce',
  'delivery_landmark': '',
  'delivery_location': {'lat': 6.14, 'lon': 1.23},
  'recipient_name': 'Awa',
  'recipient_phone': '+22890000000',
  'placed_at': '2026-09-15T12:00:00Z',
  'created_at': '2026-09-15T12:00:00Z',
  'updated_at': '2026-09-15T12:30:00Z',
};

/// Sert l'authentification et l'historique — un jeu de commandes **par compte**.
class _FauxServeur implements HttpClientAdapter {
  Map<String, dynamic> compte = _compte('client-a', 'a@elcorazon.test');
  List<Map<String, dynamic>> commandes = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.contains('/auth/login/')) {
      return _json({
        'access': 'jeton-acces',
        'refresh': 'jeton-refresh',
        'user': compte,
      });
    }
    if (options.path.contains('/auth/me/')) return _json(compte);
    if (options.path.contains('/orders/')) {
      return _json({
        'count': commandes.length,
        'next': null,
        'previous': null,
        'results': commandes,
      });
    }
    // Déconnexion, enregistrement d'appareil, carnet, panier : tout le reste
    // est « best effort » pour ce qui est vérifié ici.
    return _json(const <String, dynamic>{});
  }

  ResponseBody _json(Object corps) =>
      ResponseBody.fromString(jsonEncode(corps), 200, headers: _entetesJson);
}

/// Attend qu'une condition devienne vraie, ou échoue en le disant.
///
/// Les lectures déclenchées par l'ouverture de session ne sont pas attendues
/// par elle : parier sur un délai fixe donnerait un test qui passe sur une
/// machine et pas sur une autre.
Future<void> _quand(bool Function() condition, {Duration limite = const Duration(seconds: 5)}) async {
  final butoir = DateTime.now().add(limite);
  while (!condition() && DateTime.now().isBefore(butoir)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue, reason: 'condition non atteinte en ${limite.inSeconds} s');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_canalStockage, (call) async => null);
  SharedPreferences.setMockInitialValues(const {});

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
      eccore.expectedUserTypeProvider.overrideWithValue(eccore.UserAccountType.customer),
    ],
  );
  // Le conteneur que `main()` pose d'ordinaire : sans lui, construire
  // `AppService` lève, faute d'`ApiClient`.
  poserLeConteneurPourTests(conteneur);
  final app = AppService(conteneur);

  tearDownAll(conteneur.dispose);

  Future<void> connecter(String id, String email, List<Map<String, dynamic>> commandes) async {
    serveur
      ..compte = _compte(id, email)
      ..commandes = commandes;
    await conteneur.read(eccore.sessionProvider.notifier).login(
      email: email,
      password: 'MotDePasseSolide!42',
    );
    // Le pont de session lance la lecture **sans l'attendre** : c'est le
    // comportement voulu — l'écran s'affiche, l'historique arrive ensuite. Le
    // test attend donc qu'elle ait abouti, au lieu de parier sur un délai.
    await _quand(() => app.orders.length == commandes.length);
  }

  test('se connecter charge l’historique, sans attendre un geste du client', () async {
    await connecter('client-a', 'a@elcorazon.test', [_commande('c-a1', 'EC000001')]);

    expect(app.currentUser?.email, 'a@elcorazon.test');
    expect(app.orders.map((o) => o.reference), ['EC000001']);
  });

  test('se déconnecter n’en laisse rien', () async {
    await app.logout();
    await _quand(() => app.currentUser == null && app.orders.isEmpty);

    expect(app.currentUser, isNull);
    // C'est le cœur du défaut : sans ce vidage, le compte suivant héritait de
    // l'historique du précédent.
    expect(app.orders, isEmpty);
    expect(app.erreurHistorique, isNull);
  });

  test('le compte suivant ne voit que ses commandes', () async {
    await connecter('client-b', 'b@elcorazon.test', [_commande('c-b1', 'EC000002')]);

    expect(app.currentUser?.email, 'b@elcorazon.test');
    expect(app.orders.map((o) => o.reference), ['EC000002']);
  });

  test('un compte sans commande lit un historique vide, pas celui d’un autre', () async {
    await app.logout();
    await _quand(() => app.currentUser == null);
    await connecter('client-c', 'c@elcorazon.test', []);

    expect(app.orders, isEmpty);
  });
}

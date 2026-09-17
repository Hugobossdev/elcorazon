import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elcora_fast/services/notification_service.dart';

/// Ce que l'application annonce quand une commande part.
///
/// ## Les deux défauts que cette suite ferme
///
/// * **Elle annonçait « ✅ Commande confirmée »** à la **création**, sur une
///   commande qui naît `pending` : ni la cuisine ni le paiement n'avaient rien
///   confirmé. Le client pouvait lire « confirmée » sur une commande que le
///   restaurant refusera dans la minute. La confirmation réelle est poussée par
///   le serveur au passage à `confirmed` ; celle-ci accuse réception.
/// * **Elle portait l'identifiant technique** — un UUID de trente-six
///   caractères — là où le serveur fabrique une référence faite pour être lue,
///   redite au téléphone et retrouvée dans le back-office.
const _canalNotifications = MethodChannel('dexterous.com/flutter/local_notifications');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final appels = <MethodCall>[];

  setUpAll(() {
    // Le greffon s'enregistre au démarrage de l'application, pas en test : sans
    // cette ligne, `show` lève avant même d'atteindre le canal qu'on écoute.
    // L'implémentation Android est celle que l'application utilise ; elle
    // n'appelle rien d'autre que ce canal, que le test intercepte.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    FlutterLocalNotificationsPlatform.instance = AndroidFlutterLocalNotificationsPlugin();
  });

  tearDownAll(() => debugDefaultTargetPlatformOverride = null);

  setUp(() {
    appels.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_canalNotifications, (call) async {
      appels.add(call);
      // `initialize` rend un booléen ; `show` ne rend rien.
      return call.method == 'initialize' ? true : null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_canalNotifications, null);
  });

  /// Les arguments du dernier `show` — titre et corps.
  ({String titre, String corps}) dernierMessage() {
    final show = appels.lastWhere((call) => call.method == 'show');
    final arguments = Map<String, dynamic>.from(show.arguments as Map);
    return (
      titre: arguments['title'] as String? ?? '',
      corps: arguments['body'] as String? ?? '',
    );
  }

  test('une commande créée est « reçue », pas « confirmée »', () async {
    await NotificationService().showOrderReceivedNotification(
      'EC000065',
      'Burger Corazón, Jus de bissap',
    );

    final message = dernierMessage();
    expect(message.titre, contains('reçue'));
    // Le mot qui mentait : il ne doit plus apparaître à la création.
    expect(message.titre.toLowerCase(), isNot(contains('confirmée')));
  });

  test('le message porte la référence métier, jamais un UUID', () async {
    await NotificationService().showOrderReceivedNotification(
      'EC000065',
      'Burger Corazón',
    );

    final message = dernierMessage();
    expect(message.corps, contains('EC000065'));
    expect(message.corps, contains('Burger Corazón'));
    // Ni le préfixe d'un identifiant technique, ni la forme « #… » qu'on
    // affichait à sa place.
    expect(message.corps, isNot(contains('-0000-')));
    expect(message.corps, isNot(contains('#')));
  });

  test('le contenu de la commande reste lisible', () async {
    await NotificationService().showOrderReceivedNotification('EC000066', 'Poulet braisé');

    expect(dernierMessage().corps, 'Commande EC000066 : Poulet braisé');
  });
}

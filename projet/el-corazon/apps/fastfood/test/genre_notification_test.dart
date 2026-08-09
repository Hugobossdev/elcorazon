import 'package:elcora_fast/presentation/genre_notification.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter_test/flutter_test.dart';

/// Le vocabulaire des notifications et ce qu'elles désignent.
///
/// Ces cas remplacent `models/notification_model.dart`, retiré avec
/// l'adaptateur. Deux d'entre eux décrivent des choses qui ne marchaient pas.
eccore.AppNotification _notification({
  String kind = 'order_status',
  Map<String, dynamic>? data,
}) =>
    eccore.AppNotification.fromJson({
      'id': 'notification-1',
      'kind': kind,
      'title': 'Votre commande est prête',
      'body': 'Passez la récupérer',
      'data': data ?? const <String, dynamic>{},
      'is_read': false,
      'created_at': '2026-08-08T12:00:00Z',
    });

void main() {
  group('Les genres du serveur', () {
    test('chacun a sa contrepartie, et l’aller-retour est fidèle', () {
      for (final kind in [
        'order_status',
        'delivery_offer',
        'payment',
        'account',
        'marketing',
      ]) {
        expect(
          GenreNotification.depuisServeur(kind).versServeur,
          kind,
          reason: 'le genre « $kind » doit revenir tel quel',
        );
      }
    });

    test('il y en a cinq, pas sept', () {
      // `NotificationModel` en déclarait sept — `reminder`, `reward` et
      // `general` n'ont jamais eu d'émetteur côté serveur.
      expect(GenreNotification.values, hasLength(5));
    });

    test('un genre inconnu ne fait pas disparaître la notification', () {
      // La liste se consulte justement pour ne rien manquer : mieux vaut une
      // notification mal rangée qu'une notification absente.
      expect(
        GenreNotification.depuisServeur('quelque_chose_de_neuf'),
        GenreNotification.compte,
      );
      expect(_notification(kind: 'quelque_chose_de_neuf').genre,
          GenreNotification.compte,);
    });

    test('chaque genre a son libellé', () {
      expect(GenreNotification.commande.libelle, 'Commandes');
      expect(GenreNotification.livraison.libelle, 'Livraisons');
      expect(GenreNotification.promotion.libelle, 'Promotions');
    });
  });

  group('La commande désignée', () {
    test('se lit sous la clé `order`, celle que le serveur écrit', () {
      final notification = _notification(data: {'order': 'commande-42'});

      expect(notification.commandeVisee, 'commande-42');
    });

    test('`orderId` n’est pas cette clé', () {
      // L'écran la cherchait sous ce nom : la navigation depuis une
      // notification de commande ne pouvait pas aboutir.
      expect(_notification(data: {'orderId': 'commande-42'}).commandeVisee,
          isNull,);
    });

    test('une notification sans charge utile ne désigne rien', () {
      expect(_notification().commandeVisee, isNull);
    });

    test('une valeur vide ne désigne rien non plus', () {
      expect(_notification(data: {'order': ''}).commandeVisee, isNull);
    });

    test('une valeur qui n’est pas une chaîne ne fait pas tomber l’écran', () {
      expect(_notification(data: {'order': 42}).commandeVisee, isNull);
    });
  });
}

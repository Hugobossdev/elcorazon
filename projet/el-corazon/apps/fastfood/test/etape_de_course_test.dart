import 'package:elcora_fast/presentation/etape_de_course.dart';
import 'package:flutter_test/flutter_test.dart';

/// L'événement `delivery.status`, que le client jetait.
///
/// ## Ce qui n'arrivait jamais à l'écran
///
/// Le serveur diffuse deux événements sur le canal d'une commande :
/// `order.status` — le repas — et `delivery.status` — la course, avec l'étape
/// et le nom du livreur. `RealtimeTrackingService` ne traitait que le premier,
/// et le second était reçu puis abandonné.
///
/// Ce n'est pas un doublon, et c'est tout le problème. `accepted` **ne projette
/// rien** sur la commande : choix assumé côté serveur, une commande reste
/// « prête » tant que le repas n'est pas parti — c'est en voulant projeter cette
/// étape que l'ancien code écrivait un statut hors énumération.
///
/// L'affectation d'un livreur ne produisait donc **aucun** événement écouté par
/// l'écran de suivi. Elle n'apparaissait qu'à la relecture périodique suivante,
/// jusqu'à une minute plus tard : le client lisait « Prête » sans savoir que
/// quelqu'un venait de prendre sa commande et roulait vers le restaurant.
Map<String, dynamic> _diffusion({
  String assignment = 'course-1',
  String order = 'commande-1',
  String status = 'accepted',
  String? courier = 'Kofi A.',
}) {
  return {
    'assignment': assignment,
    'order': order,
    'status': status,
    if (courier != null) 'courier': courier,
  };
}

void main() {
  group('Une étape de course diffusée', () {
    test('se lit depuis la charge utile du serveur', () {
      final etape = EtapeDeCourse.depuisDiffusion(_diffusion())!;

      expect(etape.assignmentId, 'course-1');
      expect(etape.orderId, 'commande-1');
      expect(etape.statut, 'accepted');
      expect(etape.livreur, 'Kofi A.');
    });

    test('l’acceptation est l’étape que la commande ne dit pas', () {
      // C'est la seule information que ce canal apporte en exclusivité : les
      // trois suivantes se projettent sur le statut de la commande, celle-ci
      // non.
      expect(
        EtapeDeCourse.depuisDiffusion(_diffusion(status: 'accepted'))!
            .vientDEtreAcceptee,
        isTrue,
      );
      for (final statut in ['picked_up', 'on_the_way', 'delivered']) {
        expect(
          EtapeDeCourse.depuisDiffusion(_diffusion(status: statut))!
              .vientDEtreAcceptee,
          isFalse,
          reason: statut,
        );
      }
    });

    test('un livreur sans nom donne une chaîne vide, pas une exception', () {
      // Les écrans testent `isNotEmpty`. Un livreur sans nom affiché vaut mieux
      // qu'un écran de suivi qui refuse de se dessiner.
      final etape = EtapeDeCourse.depuisDiffusion(_diffusion(courier: null))!;

      expect(etape.livreur, isEmpty);
    });
  });

  group('Un message incomplet', () {
    test('sans commande, rien n’est produit', () {
      final charge = _diffusion()..remove('order');

      expect(EtapeDeCourse.depuisDiffusion(charge), isNull);
    });

    test('sans statut non plus', () {
      final charge = _diffusion()..remove('status');

      expect(EtapeDeCourse.depuisDiffusion(charge), isNull);
    });

    test('un type inattendu ne lève pas', () {
      // Un événement mal formé ne doit pas faire tomber l'écran d'un client qui
      // attend son repas : il est ignoré, et la relecture périodique rattrape.
      expect(
        EtapeDeCourse.depuisDiffusion({'order': 42, 'status': 'accepted'}),
        isNull,
      );
    });
  });
}

import 'package:elcora_dely/repositories/django_delivery_repository.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter_test/flutter_test.dart';

/// Ce que le livreur lit d'une course : où il va, ce qu'il encaisse, la
/// consigne — portés par la course elle-même, même sans la commande relue.
eccore.Assignment _affectation({Map<String, dynamic> extra = const {}}) =>
    eccore.Assignment.fromJson({
      'id': 'a1',
      'order': 'o1',
      'order_reference': 'EC000001',
      'restaurant_name': 'El Corazón Cocody',
      'pickup_location': {'lat': 5.36, 'lon': -3.99},
      'delivery_address_line': 'Riviera 2',
      'delivery_location': {'lat': 5.37, 'lon': -3.98},
      'recipient_name': 'Awa',
      'recipient_phone': '',
      'courier': {
        'id': 'c1',
        'full_name': 'Kouassi',
        'vehicle_type': 'motorcycle',
        'rating_average': '0.00',
        'rating_count': 0,
      },
      'status': 'offered',
      'allowed_transitions': ['accepted', 'declined'],
      'offered_at': '2026-09-14T12:00:00Z',
      'created_at': '2026-09-14T12:00:00Z',
      'updated_at': '2026-09-14T12:00:00Z',
      ...extra,
    });

void main() {
  test('une course en espèces dit ce qu’il faut encaisser, et où', () {
    final course = Course(
      assignment: _affectation(
        extra: {
          'delivery_instructions': 'Portail vert',
          'delivery_zone_name': 'Cocody',
          'city_name': 'Abidjan',
          'payment_method': 'cash',
          'order_total': {'amount': '8400', 'currency': 'XOF'},
          'amount_to_collect': {'amount': '8400', 'currency': 'XOF'},
        },
      ),
    );

    expect(course.aEncaisser?.amountMinor, 8400);
    expect(course.total?.amountMinor, 8400);
    expect(course.zoneLivraison, 'Cocody, Abidjan');
    expect(course.consignes, 'Portail vert');
  });

  test('une course déjà payée n’a rien à encaisser ; un serveur antérieur reste lisible', () {
    final course = Course(assignment: _affectation());

    expect(course.aEncaisser, isNull);
    expect(course.zoneLivraison, isEmpty);
    expect(course.consignes, isNull);
  });
}

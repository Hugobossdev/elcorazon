import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// La copie d'une adresse du carnet.
///
/// Le carnet client en a besoin pour deux gestes posés sans aller-retour
/// serveur : marquer l'adresse par défaut, et rejouer une saisie corrigée.
/// L'entité savait déjà se lire et s'écrire ; elle ne savait pas se recopier.
Address _adresse({bool isDefault = false}) => Address(
      id: 'adresse-1',
      label: 'Maison',
      kind: 'home',
      recipientName: 'Awa',
      recipientPhone: '+22890000000',
      line1: 'Rue du Commerce',
      line2: 'Immeuble Kponton, 2e étage',
      landmark: 'face à la pharmacie',
      city: 'ville-lome',
      cityName: 'Lomé',
      latitude: 6.14,
      longitude: 1.23,
      deliveryInstructions: 'Sonner deux fois',
      isDefault: isDefault,
      createdAt: DateTime(2026, 8, 8, 9),
      updatedAt: DateTime(2026, 8, 8, 10),
    );

void main() {
  group('Ce qui ne change pas', () {
    test('une copie sans argument est identique champ pour champ', () {
      final origine = _adresse();
      final copie = origine.copyWith();

      expect(copie.id, origine.id);
      expect(copie.label, origine.label);
      expect(copie.kind, origine.kind);
      expect(copie.recipientName, origine.recipientName);
      expect(copie.recipientPhone, origine.recipientPhone);
      expect(copie.line1, origine.line1);
      expect(copie.line2, origine.line2);
      expect(copie.landmark, origine.landmark);
      expect(copie.city, origine.city);
      expect(copie.cityName, origine.cityName);
      expect(copie.latitude, origine.latitude);
      expect(copie.longitude, origine.longitude);
      expect(copie.deliveryInstructions, origine.deliveryInstructions);
      expect(copie.isDefault, origine.isDefault);
      expect(copie.createdAt, origine.createdAt);
      expect(copie.updatedAt, origine.updatedAt);
    });

    test('l’original n’est pas touché', () {
      final origine = _adresse();
      origine.copyWith(label: 'Bureau', isDefault: true);

      expect(origine.label, 'Maison');
      expect(origine.isDefault, isFalse);
    });
  });

  group('Ce qui change', () {
    test('marquer par défaut ne touche que ce drapeau', () {
      final promue = _adresse().copyWith(isDefault: true);

      expect(promue.isDefault, isTrue);
      expect(promue.label, 'Maison');
      expect(promue.line1, 'Rue du Commerce');
    });

    test('retirer le défaut se fait avec `false`, pas avec `null`', () {
      // `null` conserve la valeur — c'est la convention de la méthode, et la
      // seule qui permette de ne pas énumérer quinze champs à chaque appel.
      final deja = _adresse(isDefault: true);

      expect(deja.copyWith().isDefault, isTrue);
      expect(deja.copyWith(isDefault: false).isDefault, isFalse);
    });

    test('plusieurs champs à la fois', () {
      final corrigee = _adresse().copyWith(
        label: 'Bureau',
        kind: 'work',
        line1: 'Boulevard du 13 Janvier',
      );

      expect(corrigee.label, 'Bureau');
      expect(corrigee.kind, 'work');
      expect(corrigee.line1, 'Boulevard du 13 Janvier');
      expect(corrigee.landmark, 'face à la pharmacie');
    });

    test('une chaîne se vide avec la chaîne vide', () {
      expect(_adresse().copyWith(landmark: '').landmark, isEmpty);
    });
  });

  group('La copie reste écrivable', () {
    test('sa forme d’écriture porte les valeurs modifiées', () {
      final json = _adresse().copyWith(label: 'Bureau', isDefault: true).toJson();

      expect(json['label'], 'Bureau');
      expect(json['is_default'], isTrue);
      expect(json['location'], {'lat': 6.14, 'lon': 1.23});
    });

    test('elle n’expose toujours pas les champs en lecture seule', () {
      // `id`, `city_name`, `created_at` et `updated_at` appartiennent au
      // serveur ; les renvoyer dans un `PATCH` serait au mieux ignoré.
      final json = _adresse().copyWith(label: 'Bureau').toJson();

      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('city_name'), isFalse);
      expect(json.containsKey('created_at'), isFalse);
      expect(json.containsKey('updated_at'), isFalse);
    });
  });
}

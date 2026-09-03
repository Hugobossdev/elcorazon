import 'package:admin/presentation/statut_livreur.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ce que le siège lit de la position d'un livreur.
///
/// ## Ce que ces tests protègent
///
/// La carte de supervision posait un repère de la même façon qu'un relevé date
/// de huit secondes ou de onze minutes : `last_location_at` était rendu par le
/// serveur, lu par le modèle, et **utilisé nulle part**. Le siège lisait donc
/// comme un suivi en direct la dernière position d'un livreur dont le téléphone
/// s'était éteint — et n'appelait pas, puisqu'il croyait savoir où il était.
///
/// Le dossier est construit par son JSON plutôt que par son constructeur :
/// c'est cette lecture-là que le produit exécute.
eccore.CourierProfile _dossier({
  Map<String, dynamic>? position,
  String? positionDatee,
}) {
  return eccore.CourierProfile.fromJson({
    'id': 'livreur-1',
    'full_name': 'Koffi Mensah',
    'email': 'koffi@example.tg',
    'restaurant': 'el-corazon-lome',
    'verification_status': 'approved',
    'vehicle_type': 'moto',
    'is_online': true,
    'can_accept_orders': true,
    'last_location': position,
    'last_location_at': positionDatee,
    'deliveries_completed': 42,
    'deliveries_cancelled': 1,
    'rating_average': '4.8',
    'rating_count': 30,
    'created_at': '2026-01-01T08:00:00Z',
    'updated_at': '2026-09-03T12:00:00Z',
  });
}

/// Un horodatage vieux de [age], exprimé en UTC comme le rend le serveur.
String _ilYA(Duration age) =>
    DateTime.now().toUtc().subtract(age).toIso8601String();

void main() {
  const positionLome = {'lat': 6.1319, 'lon': 1.2255};

  group('Sans aucun relevé', () {
    test('la fraîcheur n’existe pas, et le dit', () {
      final dossier = _dossier();

      expect(dossier.aUnePosition, isFalse);
      expect(dossier.fraicheurPosition, isNull);
      expect(dossier.ageDeLaPosition, isEmpty);
      // « Aucune position » et « position vieille » ne sont pas la même chose :
      // les confondre ferait chercher un point qui n'a jamais existé.
      expect(dossier.libelleDePosition, 'Aucune position transmise');
      expect(dossier.couleurDeFraicheur, Colors.grey);
    });
  });

  group('Avec un relevé', () {
    test('récent : le suivi est en direct', () {
      final dossier = _dossier(
        position: positionLome,
        positionDatee: _ilYA(const Duration(seconds: 8)),
      );

      expect(dossier.fraicheurPosition, eccore.FraicheurPosition.fraiche);
      expect(dossier.libelleDePosition, startsWith('Position il y a 8'));
      expect(dossier.couleurDeFraicheur, Colors.green);
    });

    test('en retard : le libellé cesse de promettre du direct', () {
      final dossier = _dossier(
        position: positionLome,
        positionDatee: _ilYA(const Duration(minutes: 2)),
      );

      expect(dossier.fraicheurPosition, eccore.FraicheurPosition.retardee);
      expect(dossier.libelleDePosition, startsWith('Dernière position'));
      expect(dossier.couleurDeFraicheur, Colors.orange);
    });

    test('perdu : le libellé annonce une position figée', () {
      final dossier = _dossier(
        position: positionLome,
        positionDatee: _ilYA(const Duration(minutes: 20)),
      );

      expect(dossier.fraicheurPosition, eccore.FraicheurPosition.perdue);
      expect(dossier.libelleDePosition, contains('figée'));
      expect(dossier.couleurDeFraicheur, Colors.red);
    });

    test('sans horodatage, on ne prétend pas savoir', () {
      // Le serveur peut rendre une position sans `last_location_at` pour les
      // dossiers antérieurs au champ. L'afficher comme fraîche serait le pire
      // des choix : c'est justement le cas le plus douteux.
      final dossier = _dossier(position: positionLome);

      expect(dossier.aUnePosition, isTrue);
      expect(dossier.fraicheurPosition, isNull);
      expect(dossier.libelleDePosition, contains('sans horodatage'));
      expect(dossier.couleurDeFraicheur, Colors.grey);
    });
  });
}

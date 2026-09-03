import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Quatre situations empêchent de relever une position, et elles appellent
/// quatre gestes différents. Ramenées à un `bool`, comme elles l'étaient dans
/// les deux applications, elles produisaient le même écran muet — devant lequel
/// l'utilisateur n'a rien à faire.
void main() {
  group('LocationAvailability', () {
    test('seule « disponible » l’est', () {
      expect(LocationAvailability.disponible.estDisponible, isTrue);
      for (final autre in LocationAvailability.values
          .where((e) => e != LocationAvailability.disponible)) {
        expect(autre.estDisponible, isFalse, reason: '$autre');
      }
    });

    test('chaque empêchement dit quoi faire', () {
      for (final etat in LocationAvailability.values
          .where((e) => e != LocationAvailability.disponible)) {
        expect(etat.titre, isNotEmpty, reason: '$etat');
        expect(etat.consigne, isNotEmpty, reason: '$etat');
      }
    });

    test('un GPS coupé renvoie aux réglages du système, pas à une demande', () {
      // Redemander la permission ne rallume pas la localisation de l'appareil :
      // le message qui invitait à « autoriser » était un cul-de-sac.
      expect(
        LocationAvailability.serviceDesactive.remede,
        LocationRemede.ouvrirReglagesDeLocalisation,
      );
    });

    test('un refus simple se redemande', () {
      expect(
        LocationAvailability.permissionRefusee.remede,
        LocationRemede.redemanderLaPermission,
      );
    });

    test('un refus définitif ne se redemande pas', () {
      // Le système ne réafficherait rien : insister laisse l'utilisateur
      // appuyer sur un bouton qui ne produit jamais de dialogue.
      expect(
        LocationAvailability.permissionRefuseeDefinitivement.remede,
        LocationRemede.ouvrirLaFicheDeLApplication,
      );
    });

    test('un capteur muet demande d’attendre, et rien d’autre', () {
      final remede = LocationAvailability.positionIndisponible.remede;
      expect(remede, LocationRemede.patienter);
      // Pas de bouton : il n'y a pas de geste qui accélère une fixation GPS.
      expect(remede.libelle, isEmpty);
    });

    test('« disponible » ne propose aucun geste', () {
      expect(LocationAvailability.disponible.remede, LocationRemede.aucun);
      expect(LocationAvailability.disponible.consigne, isEmpty);
      expect(LocationRemede.aucun.libelle, isEmpty);
    });

    test('tout remède actionnable porte un libellé de bouton', () {
      const actionnables = {
        LocationRemede.ouvrirReglagesDeLocalisation,
        LocationRemede.redemanderLaPermission,
        LocationRemede.ouvrirLaFicheDeLApplication,
      };
      for (final remede in actionnables) {
        expect(remede.libelle, isNotEmpty, reason: '$remede');
      }
    });
  });
}

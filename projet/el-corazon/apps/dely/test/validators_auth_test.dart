import 'package:elcora_dely/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les validateurs du formulaire de candidature.
///
/// Ils **doublent** des règles que le serveur applique de toute façon, et ne le
/// remplacent jamais : ce qui décide, c'est `phone_validator` et les
/// validateurs de mot de passe de Django. Ce qu'ils apportent est le moment du
/// refus — avant l'aller-retour plutôt qu'après huit secondes de réseau lent.
///
/// D'où ce que ces tests vérifient en creux : que le client ne refuse **rien
/// que le serveur accepterait**. Un validateur plus strict que le serveur est
/// un blocage que personne ne peut lever depuis l'application.
void main() {
  group('Téléphone au format E.164', () {
    test('accepte un numéro togolais international', () {
      expect(Validators.validatePhoneE164('+22890123456'), isNull);
    });

    test('accepte les espaces et tirets de présentation', () {
      // Ils sont retirés avant l'envoi : les refuser obligerait le candidat à
      // retaper un numéro qu'il vient de coller depuis ses contacts.
      expect(Validators.validatePhoneE164('+228 90 12-34 56'), isNull);
    });

    test('refuse un numéro local sans indicatif', () {
      // Sans indicatif, deux pays ont le même numéro — et le serveur le
      // refuse.
      expect(Validators.validatePhoneE164('90123456'), contains('indicatif'));
    });

    test('refuse un numéro trop court ou trop long', () {
      expect(Validators.validatePhoneE164('+2289'), isNotNull);
      expect(Validators.validatePhoneE164('+2289012345678901'), isNotNull);
    });

    test('refuse un indicatif commençant par zéro', () {
      expect(Validators.validatePhoneE164('+02890123456'), isNotNull);
    });

    test('refuse un champ vide', () {
      expect(Validators.validatePhoneE164(''), isNotNull);
      expect(Validators.validatePhoneE164(null), isNotNull);
    });
  });

  group('Mot de passe', () {
    test('accepte un mot de passe de huit caractères mêlés', () {
      expect(Validators.validateStrongPassword('MotDePasseSolide!42'), isNull);
    });

    test('refuse en dessous de huit caractères — la limite du serveur', () {
      expect(Validators.validateStrongPassword('Abc12!'), contains('8 caractères'));
    });

    test('refuse un mot de passe tout en chiffres', () {
      // Django le refuse aussi (`NumericPasswordValidator`) : le dire ici évite
      // un aller-retour sur le cas le plus courant.
      expect(Validators.validateStrongPassword('12345678'), isNotNull);
    });

    test('n\'invente aucune règle de complexité absente du serveur', () {
      // Pas d'exigence de majuscule, de chiffre ou de caractère spécial : le
      // serveur n'en pose aucune, et l'imposer ici refuserait un mot de passe
      // qu'il aurait accepté.
      expect(Validators.validateStrongPassword('correcthorsebattery'), isNull);
    });

    test('la confirmation compare les deux saisies', () {
      expect(Validators.validatePasswordConfirmation('abc12345', 'abc12345'), isNull);
      expect(
        Validators.validatePasswordConfirmation('abc12345', 'abc12346'),
        contains('ne correspondent pas'),
      );
      expect(Validators.validatePasswordConfirmation('', 'abc12345'), isNotNull);
    });
  });
}

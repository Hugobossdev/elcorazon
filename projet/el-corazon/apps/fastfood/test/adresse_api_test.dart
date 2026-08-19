import 'package:elcora_fast/main.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adresse du backend, lue dans `.env`.
///
/// `API_BASE_URL` a été écrit un jour sans `http://`. Le navigateur lit alors
/// `localhost:` comme un nom de protocole et refuse la requête avec « Cross
/// origin requests are only supported for protocol schemes… » — un message qui
/// accuse le CORS alors que la requête n'a jamais quitté l'onglet, et que le
/// serveur répondait parfaitement. Une heure perdue à chercher du côté du
/// backend.
void main() {
  group('Schéma manquant', () {
    test('un hôte nu reçoit http://', () {
      expect(
        adresseDeLApi('localhost:8000/api/v1'),
        'http://localhost:8000/api/v1',
      );
    });

    test('une adresse IP nue aussi', () {
      expect(
        adresseDeLApi('10.160.173.68:8000/api/v1'),
        'http://10.160.173.68:8000/api/v1',
      );
    });
  });

  group('Adresse déjà valide', () {
    test('http est laissé intact', () {
      expect(
        adresseDeLApi('http://localhost:8000/api/v1'),
        'http://localhost:8000/api/v1',
      );
    });

    test('https aussi — et surtout : ne pas le rétrograder', () {
      expect(
        adresseDeLApi('https://api.elcorazon.tg/api/v1'),
        'https://api.elcorazon.tg/api/v1',
      );
    });
  });

  group('Absence de réglage', () {
    test('sans valeur, on retombe sur l\'hôte de l\'émulateur Android', () {
      expect(adresseDeLApi(null), 'http://10.0.2.2:8000/api/v1');
    });

    test('une valeur vide vaut une absence', () {
      expect(adresseDeLApi('   '), 'http://10.0.2.2:8000/api/v1');
    });
  });
}

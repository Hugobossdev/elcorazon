import 'package:elcora_dely/config/adresses.dart';
import 'package:flutter_test/flutter_test.dart';

/// La dérivation des deux adresses du backend.
///
/// Cette fonction porte plus qu'il n'y paraît : **quatre canaux temps réel**
/// en dépendent — la file des courses, la file personnelle (donc les appels
/// entrants), la conversation et le suivi. Elle était recopiée à trois
/// endroits dans `dely`, et aucune des trois copies ne réparait le défaut
/// vérifié ici.
void main() {
  group('Adresse de l\'API', () {
    test('une valeur complète passe telle quelle', () {
      expect(adresseDeLApi('https://api.elcorazon.app/api/v1'), 'https://api.elcorazon.app/api/v1');
    });

    test('une valeur vide retombe sur l\'hôte de l\'émulateur', () {
      expect(adresseDeLApi(''), 'http://10.0.2.2:8000/api/v1');
      expect(adresseDeLApi('   '), 'http://10.0.2.2:8000/api/v1');
    });

    test('un schéma manquant est réparé', () {
      // La faute la plus naturelle quand on renseigne un `.env` à la main.
      expect(adresseDeLApi('localhost:8000/api/v1'), 'http://localhost:8000/api/v1');
    });
  });

  group('Adresse WebSocket', () {
    test('http donne ws, https donne wss', () {
      expect(
        adresseWebSocket('/ws/me/', 'http://10.0.2.2:8000/api/v1'),
        'ws://10.0.2.2:8000/ws/me/',
      );
      expect(
        adresseWebSocket('/ws/me/', 'https://api.elcorazon.app/api/v1'),
        'wss://api.elcorazon.app/ws/me/',
      );
    });

    test('le chemin n\'emporte pas /api/v1', () {
      // Channels monte `ws/` à la racine (`backend/config/routing.py`), pas
      // sous le préfixe de l'API. Une adresse en `/api/v1/ws/…` rend 404 sans
      // que rien d'autre ne bouge.
      final url = adresseWebSocket('/ws/orders/abc/chat/', 'https://api.elcorazon.app/api/v1');

      expect(url, 'wss://api.elcorazon.app/ws/orders/abc/chat/');
      expect(url, isNot(contains('/api/v1')));
    });

    test('un schéma manquant ne produit pas une adresse sans hôte', () {
      // Le défaut que ce fichier existe pour absorber :
      //
      //   Uri.parse('localhost:8000/api/v1')
      //     → scheme 'localhost', host '' → 'ws:///ws/me/'
      //
      // Le REST continuait de fonctionner ; seul le temps réel tombait — donc
      // les appels entrants, en silence.
      final url = adresseWebSocket('/ws/me/', 'localhost:8000/api/v1');

      expect(url, 'ws://localhost:8000/ws/me/');
      expect(url, isNot(startsWith('ws:///')));
      expect(Uri.parse(url).host, isNotEmpty);
    });

    test('le port déclaré est conservé', () {
      expect(
        adresseWebSocket('/ws/couriers/me/', 'http://192.168.1.10:8080/api/v1'),
        'ws://192.168.1.10:8080/ws/couriers/me/',
      );
    });
  });
}

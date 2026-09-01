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

  /// Deuxième omission du même fichier, un cran plus coûteuse que la
  /// première : `API_BASE_URL=localhost:8000`, sans `/api/v1`. Le schéma était
  /// rattrapé, le préfixe non — et l'API n'est montée que sous lui
  /// (`config/urls.py`). Toutes les routes répondaient 404 sur un backend
  /// parfaitement sain, ce qui se lit comme une base vide plutôt que comme un
  /// réglage incomplet.
  group('Préfixe /api/v1 manquant', () {
    test('un hôte nu et sans préfixe reçoit les deux', () {
      expect(adresseDeLApi('localhost:8000'), 'http://localhost:8000/api/v1');
    });

    test('une adresse complète mais sans préfixe le reçoit', () {
      expect(
        adresseDeLApi('http://localhost:8000'),
        'http://localhost:8000/api/v1',
      );
    });

    test('une barre finale ne produit pas //api/v1', () {
      // `Uri.parse('http://h:8000/').path` vaut '/', c'est-à-dire aucun
      // chemin : la barre est retirée avant l'examen, sans quoi l'adresse de
      // base finirait par une — or tous les chemins des dépôts commencent
      // par une.
      expect(
        adresseDeLApi('http://localhost:8000/'),
        'http://localhost:8000/api/v1',
      );
    });

    test('un domaine en https aussi', () {
      expect(
        adresseDeLApi('https://elcorazon-backend.onrender.com'),
        'https://elcorazon-backend.onrender.com/api/v1',
      );
    });
  });

  group('Chemin déjà déclaré', () {
    test("le préfixe présent n'est pas redoublé", () {
      expect(
        adresseDeLApi('http://localhost:8000/api/v1'),
        'http://localhost:8000/api/v1',
      );
    });

    test('un autre chemin est un choix, pas un oubli : il est respecté', () {
      // Une v2 le jour venu, ou le préfixe d'un proxy. Le rattrapage ne
      // s'applique qu'à l'absence de chemin — deviner au-delà reviendrait à
      // défaire un réglage volontaire.
      expect(
        adresseDeLApi('https://api.elcorazon.tg/api/v2'),
        'https://api.elcorazon.tg/api/v2',
      );
    });

    test('une barre finale est retirée même quand le chemin existe', () {
      // `baseUrl` + `/catalog/items/` ne doit pas produire de double barre.
      expect(
        adresseDeLApi('http://localhost:8000/api/v1/'),
        'http://localhost:8000/api/v1',
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

  /// Le temps réel dérivait son adresse de son côté, en relisant `API_BASE_URL`
  /// **brut** dans chacun des quatre services. Le rattrapage du schéma ne les
  /// atteignait donc pas, et l'omission qu'il existe pour absorber les cassait
  /// en silence : le menu s'affichait, seuls le chat, le suivi, les appels et
  /// le panier de groupe restaient muets. On cherche alors du côté des
  /// consumers Django, qui n'y sont pour rien.
  group('Adresse WebSocket', () {
    test('un hôte nu ne produit plus une adresse sans hôte', () {
      // Le défaut corrigé : `Uri.parse('localhost:8000/api/v1')` lit
      // `localhost` comme protocole, laisse l'hôte vide, et rendait
      // 'ws:///ws/me/'.
      expect(
        adresseWebSocket('localhost:8000/api/v1', '/ws/me/'),
        'ws://localhost:8000/ws/me/',
      );
    });

    test('http donne ws', () {
      expect(
        adresseWebSocket('http://localhost:8000/api/v1', '/ws/me/'),
        'ws://localhost:8000/ws/me/',
      );
    });

    test('https donne wss — jamais ws en clair', () {
      expect(
        adresseWebSocket('https://api.elcorazon.tg/api/v1', '/ws/me/'),
        'wss://api.elcorazon.tg:443/ws/me/',
      );
    });

    test("le préfixe /api/v1 n'est pas repris : Channels monte ws/ à la racine", () {
      // `config/routing.py` déclare `ws/orders/<uuid>/tracking/`, pas
      // `api/v1/ws/...`. Reprendre le préfixe donnerait un 404 à la poignée
      // de main, que le client ne distingue pas d'un serveur éteint.
      expect(
        adresseWebSocket('http://localhost:8000/api/v1', '/ws/orders/abc/tracking/'),
        'ws://localhost:8000/ws/orders/abc/tracking/',
      );
    });

    test('sans réglage, le repli reste celui de l\'API', () {
      expect(adresseWebSocket(null, '/ws/me/'), 'ws://10.0.2.2:8000/ws/me/');
    });
  });
}

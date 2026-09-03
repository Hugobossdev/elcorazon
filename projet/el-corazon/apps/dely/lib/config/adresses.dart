/// Les deux adresses du backend, dérivées d'une seule variable.
///
/// ## Pourquoi ce fichier existe
///
/// `API_BASE_URL` était relue **à trois endroits** dans `dely` — le client HTTP
/// dans `main.dart`, la conversation, le suivi — et chacun la reparsait à sa
/// façon. Trois copies d'une dérivation, c'est trois occasions de diverger, et
/// c'est surtout trois endroits à corriger quand l'une d'elles se révèle
/// fausse. Le service d'appel en aurait fait une quatrième.
///
/// ## Le défaut que [adresseDeLApi] absorbe
///
/// Une valeur sans schéma — `localhost:8000/api/v1`, la faute la plus
/// naturelle quand on renseigne un `.env` à la main — ne casse pas de façon
/// franche :
///
/// ```
/// Uri.parse('localhost:8000/api/v1')
///   → scheme: 'localhost', host: '', port: 0
///   → 'ws:///ws/me/'   ← aucun hôte
/// ```
///
/// Le REST peut continuer de fonctionner pendant que **seul le temps réel**
/// tombe : l'application s'ouvre, les courses s'affichent, et seuls la
/// conversation, le suivi et les appels restent muets. Une panne partielle
/// coûte plus cher à diagnostiquer qu'une panne franche — on cherche du côté
/// des consumers Django, qui n'y sont pour rien.
///
/// L'app cliente porte la même réparation depuis le lot 3
/// (`apps/fastfood/lib/main.dart`) ; `dely` ne l'avait pas.
library;

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Valeur de repli : l'hôte de l'émulateur Android vers le `localhost` du poste.
const _repli = 'http://10.0.2.2:8000/api/v1';

/// Adresse de l'API REST, schéma garanti.
String adresseDeLApi([String? valeurDeclaree]) {
  final brute = (valeurDeclaree ?? dotenv.env['API_BASE_URL'] ?? '').trim();
  if (brute.isEmpty) return _repli;

  // `Uri.parse` ne lève pas sur une valeur sans schéma : il prend le premier
  // segment pour un schéma. Le test porte donc sur la présence de `//`, seul
  // marqueur fiable d'une autorité.
  if (!brute.contains('://')) return 'http://$brute';
  return brute;
}

/// Ports que `Uri` sous-entend quand l'adresse n'en déclare pas.
const _portsImplicites = {'http': 80, 'https': 443};

/// Adresse d'un canal WebSocket, dérivée de la même valeur.
///
/// Le [chemin] n'emporte **pas** `/api/v1` : Channels monte `ws/` à la racine
/// (`backend/config/routing.py`), pas sous le préfixe de l'API.
String adresseWebSocket(String chemin, [String? valeurDeclaree]) {
  final api = Uri.parse(adresseDeLApi(valeurDeclaree));

  // `Uri.port` rend le port **implicite** du schéma quand l'adresse n'en porte
  // pas : 443 pour `https`. Le repasser tel quel produirait
  // `wss://api.elcorazon.app:443/ws/me/` — fonctionnel, mais c'est une adresse
  // que personne ne reconnaît dans un journal, et qui ne correspond à aucun
  // `CSRF_TRUSTED_ORIGINS` ni à aucune règle de proxy écrite à la main. On ne
  // le reporte donc que s'il a été déclaré.
  final implicite = _portsImplicites[api.scheme];
  return Uri(
    scheme: api.scheme == 'https' ? 'wss' : 'ws',
    host: api.host,
    port: api.port == implicite ? null : api.port,
    path: chemin,
  ).toString();
}

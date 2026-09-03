import 'package:elcorazon_core/src/tracking/position_freshness.dart';

/// Cadence du suivi de position — les trois nombres qui décident de ce que
/// coûte une course en batterie et en réseau.
///
/// ## Pourquoi ils ne sont plus écrits dans le service
///
/// Ils l'étaient, en constantes privées de `RealtimeTrackingService` : une
/// valeur juste, mais impossible à corriger sans republier l'application du
/// livreur. Or ce sont exactement des valeurs qu'on ajuste après coup, à la
/// lecture de ce que le terrain rend — un livreur en moto dans un centre-ville
/// dense n'appelle pas la même cadence qu'une tournée de périphérie.
///
/// Elles ne sont pas non plus libres : le serveur n'écrit un relevé qu'au-delà
/// de `TRACKING_MIN_WRITE_SECONDS` (30 s) ou `TRACKING_MIN_WRITE_METERS`
/// (100 m) — voir `backend/apps/tracking/services.py` — et limite la cadence
/// par `TrackingPingThrottle`. Émettre plus vite que le pas d'échantillonnage
/// dépense de la batterie pour des relevés que le serveur écarte, et rapproche
/// du `429`. [verifier] refuse donc les réglages qui feraient cela.
class TrackingSettings {
  const TrackingSettings({
    this.emissionInterval = const Duration(seconds: 10),
    this.distanceFilterMeters = 25,
    this.heartbeatInterval = const Duration(seconds: 30),
    this.retryInterval = const Duration(seconds: 30),
    this.accuracy = TrackingAccuracy.haute,
  });

  /// Lit les réglages depuis l'environnement de l'application (`dotenv.env`).
  ///
  /// Prend une `Map` plutôt que d'importer `flutter_dotenv` : le socle ne
  /// charge pas de fichier, et un test n'a alors rien à monter pour vérifier
  /// une valeur. Toute entrée absente, vide ou illisible retombe sur la valeur
  /// par défaut — un `.env` mal saisi ne doit pas couper le suivi, il doit le
  /// laisser tourner à sa cadence nominale.
  factory TrackingSettings.depuisEnvironnement(Map<String, String> env) {
    int? entier(String cle) {
      final brut = env[cle]?.trim();
      if (brut == null || brut.isEmpty) return null;
      return int.tryParse(brut);
    }

    const defauts = TrackingSettings();
    final secondes = entier('TRACKING_INTERVAL_SECONDS');
    final battement = entier('TRACKING_HEARTBEAT_SECONDS');
    final reprise = entier('TRACKING_RETRY_SECONDS');

    return TrackingSettings(
      emissionInterval: secondes == null || secondes <= 0
          ? defauts.emissionInterval
          : Duration(seconds: secondes),
      distanceFilterMeters:
          entier('TRACKING_MINIMUM_DISTANCE_METERS') ?? defauts.distanceFilterMeters,
      heartbeatInterval: battement == null || battement <= 0
          ? defauts.heartbeatInterval
          : Duration(seconds: battement),
      retryInterval: reprise == null || reprise <= 0
          ? defauts.retryInterval
          : Duration(seconds: reprise),
      accuracy: TrackingAccuracy.depuisNom(env['TRACKING_ACCURACY']) ??
          defauts.accuracy,
    );
  }

  /// Intervalle minimal entre deux relevés **envoyés au serveur**.
  ///
  /// Distinct du pas du capteur : le flux peut rendre plus souvent, l'émission
  /// est ce qui est bridé.
  final Duration emissionInterval;

  /// Déplacement à partir duquel le système réveille l'application.
  ///
  /// Sous le seuil serveur (100 m) à dessein : un relevé à 25 m arrivé juste
  /// après les 30 s d'attente est écrit, alors qu'un filtre calé sur 100 m
  /// ferait perdre les déplacements lents — un livreur dans les embouteillages.
  final int distanceFilterMeters;

  /// Battement pour un livreur immobile.
  ///
  /// Le flux de position ne dit rien tant que rien ne bouge : sans ce
  /// battement, un livreur arrêté à un feu ou attendant au restaurant
  /// disparaîtrait de la carte du client, qui verrait sa dernière position
  /// vieillir sans savoir si le suivi fonctionne encore.
  final Duration heartbeatInterval;

  /// Délai entre deux tentatives de reprise quand le suivi est empêché — GPS
  /// éteint, permission pas encore accordée.
  ///
  /// Sans cette reprise, un livreur qui rallume son GPS après le début de sa
  /// course reste hors suivi pour le reste de la session : rien ne relit
  /// l'obstacle une fois qu'il a été constaté.
  final Duration retryInterval;

  final TrackingAccuracy accuracy;

  /// Tout ce que ces réglages ont d'incohérent — avec le serveur, avec les
  /// seuils de fraîcheur, ou entre eux. Vide quand tout va bien.
  ///
  /// Avertit plutôt que de corriger : un réglage douteux se journalise au
  /// démarrage et laisse le suivi tourner. Couper le suivi parce qu'un `.env`
  /// annonce 2 secondes serait pire que la cadence qu'il demande.
  ///
  /// ## Pourquoi les bornes **hautes** comptent autant que les basses
  ///
  /// Seules les valeurs trop petites étaient signalées, parce qu'elles coûtent
  /// visiblement — batterie, quota, `429`. Les trop grandes ne coûtent rien et
  /// cassent tout, en silence : à `TRACKING_INTERVAL_SECONDS=600` — la faute de
  /// frappe naturelle pour 60 — le livreur émet une fois toutes les dix
  /// minutes, le back-office le déclare « position figée » en permanence
  /// ([FraicheurPosition.seuilPerte] est à 5 min), et **rien n'apparaît dans
  /// les journaux**. On cherche alors la panne du côté du réseau, du GPS ou du
  /// serveur, pas du côté d'un chiffre en trop.
  List<String> get avertissements {
    final anomalies = <String>[];

    if (emissionInterval < const Duration(seconds: 5)) {
      anomalies.add(
        'TRACKING_INTERVAL_SECONDS=${emissionInterval.inSeconds} : sous 5 s, le '
        'serveur écarte la plupart des relevés (TrackingPingThrottle) et la '
        'batterie paie pour rien.',
      );
    } else if (emissionInterval > FraicheurPosition.seuilRetard) {
      // Le seuil de comparaison est celui que le back-office applique : les
      // deux doivent s'accorder, sans quoi une flotte parfaitement suivie
      // s'affiche en rouge sur la carte de supervision.
      anomalies.add(
        'TRACKING_INTERVAL_SECONDS=${emissionInterval.inSeconds} : au-delà de '
        '${FraicheurPosition.seuilRetard.inSeconds} s, le back-office affiche '
        'en permanence une position en retard, et au-delà de '
        '${FraicheurPosition.seuilPerte.inMinutes} min une position figée.',
      );
    }

    if (distanceFilterMeters < 0) {
      anomalies.add(
        'TRACKING_MINIMUM_DISTANCE_METERS=$distanceFilterMeters : une distance '
        'négative n’a pas de sens, le filtre est ignoré.',
      );
    } else if (distanceFilterMeters > 100) {
      anomalies.add(
        'TRACKING_MINIMUM_DISTANCE_METERS=$distanceFilterMeters : au-delà du '
        'seuil d’écriture du serveur (100 m), les déplacements lents ne sont '
        'plus relevés.',
      );
    }

    // Le battement passe par la même bride que les relevés du capteur
    // (`_emitPosition`) : plus court que l'émission, il est intégralement
    // écarté, et un livreur immobile disparaît quand même de la carte. Le
    // réglage a l'air actif et ne fait rien — le pire des deux mondes.
    if (heartbeatInterval < emissionInterval) {
      anomalies.add(
        'TRACKING_HEARTBEAT_SECONDS=${heartbeatInterval.inSeconds} est sous '
        'TRACKING_INTERVAL_SECONDS=${emissionInterval.inSeconds} : le battement '
        'est écarté par la bride d’émission, il ne sert à rien.',
      );
    } else if (heartbeatInterval >= FraicheurPosition.seuilPerte) {
      anomalies.add(
        'TRACKING_HEARTBEAT_SECONDS=${heartbeatInterval.inSeconds} : un livreur '
        'immobile sera déclaré « position figée » avant son prochain battement.',
      );
    }

    if (retryInterval > const Duration(minutes: 5)) {
      anomalies.add(
        'TRACKING_RETRY_SECONDS=${retryInterval.inSeconds} : un livreur qui '
        'rallume son GPS en cours de course attendra jusqu’à '
        '${retryInterval.inMinutes} min avant d’être suivi de nouveau.',
      );
    }

    return anomalies;
  }

  /// La première anomalie, ou `null`. Raccourci de journalisation.
  String? get avertissement =>
      avertissements.isEmpty ? null : avertissements.first;

  TrackingSettings copyWith({
    Duration? emissionInterval,
    int? distanceFilterMeters,
    Duration? heartbeatInterval,
    Duration? retryInterval,
    TrackingAccuracy? accuracy,
  }) {
    return TrackingSettings(
      emissionInterval: emissionInterval ?? this.emissionInterval,
      distanceFilterMeters: distanceFilterMeters ?? this.distanceFilterMeters,
      heartbeatInterval: heartbeatInterval ?? this.heartbeatInterval,
      retryInterval: retryInterval ?? this.retryInterval,
      accuracy: accuracy ?? this.accuracy,
    );
  }
}

/// Précision demandée au capteur, sans dépendance au greffon.
///
/// Miroir volontairement pauvre de `LocationAccuracy` : le suivi n'a besoin
/// que de trois crans, et les six de `geolocator` inviteraient à un réglage
/// dont personne ne saurait dire l'effet.
enum TrackingAccuracy {
  /// Réseau et cellules — quelques centaines de mètres, presque rien en
  /// batterie. Ne dit pas grand-chose à un client qui attend son repas.
  basse,

  /// Compromis usuel : une dizaine de mètres en ville.
  moyenne,

  /// GPS pleine puissance. Le réglage du suivi de course.
  haute;

  static TrackingAccuracy? depuisNom(String? nom) {
    return switch (nom?.trim().toLowerCase()) {
      'basse' || 'low' => TrackingAccuracy.basse,
      'moyenne' || 'medium' => TrackingAccuracy.moyenne,
      'haute' || 'high' || 'best' => TrackingAccuracy.haute,
      _ => null,
    };
  }
}

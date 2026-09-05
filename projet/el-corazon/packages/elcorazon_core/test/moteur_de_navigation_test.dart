import 'dart:math' as math;

import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le guidage, vérifié sans carte, sans GPS et sans moteur de synthèse.
///
/// ## Pourquoi ces tests existent
///
/// Le développement se fait depuis Abidjan et l'établissement est à Lomé. Rien
/// de ce que fait une navigation — annoncer un virage au bon moment, ne pas
/// l'annoncer trois fois, détecter une sortie d'itinéraire sans partir en
/// boucle, savoir qu'on est arrivé — ne se vérifie en regardant une carte à
/// six cents kilomètres du trajet. Le moteur a donc été écrit pour être
/// exerçable ici : il reçoit des positions, il rend des phrases.
///
/// C'est aussi ce qui fait que le mode simulé de l'application n'est pas une
/// démonstration séparée. Il pousse des positions dans **ce** moteur, par le
/// même chemin qu'un capteur réel.
void main() {
  // Lomé. Tous les points du trajet en sont dérivés : un mètre vers le nord
  // vaut toujours le même incrément de latitude, ce qui rend les distances des
  // tests lisibles en mètres.
  const depart = GeoPoint(6.1319, 1.2228);
  const metreEnLatitude = 1 / 111320.0;
  final metreEnLongitude =
      1 / (111320.0 * math.cos(depart.latitude * math.pi / 180));

  GeoPoint auNord(GeoPoint origine, double metres) =>
      GeoPoint(origine.latitude + metres * metreEnLatitude, origine.longitude);

  GeoPoint aLEst(GeoPoint origine, double metres) =>
      GeoPoint(origine.latitude, origine.longitude + metres * metreEnLongitude);

  RouteStep etape({
    required GeoPoint de,
    required GeoPoint a,
    required Manoeuvre manoeuvre,
    int? secondes,
  }) {
    final metres = GeoCalcul.distanceMetres(de, a).round();
    return RouteStep(
      distanceMeters: metres,
      durationSeconds: secondes ?? (metres / 8.33).round(),
      start: de,
      end: a,
      instruction: 'Continuer',
      manoeuvre: manoeuvre,
      polylinePoints: [de, a],
    );
  }

  /// Un trajet en trois manœuvres : 1 km au nord, virage à droite, 600 m à
  /// l'est, virage à gauche, 300 m au nord.
  ///
  /// Trois étapes de longueurs différentes, parce que c'est là que les règles
  /// de palier se jouent : une étape courte ne doit pas déclencher l'annonce
  /// lointaine.
  final borne1 = auNord(depart, 1000);
  final borne2 = aLEst(borne1, 600);
  final arrivee = auNord(borne2, 300);

  RouteInfo itineraire({List<RouteStep>? etapes}) {
    final liste = etapes ??
        [
          etape(de: depart, a: borne1, manoeuvre: Manoeuvre.aDroite),
          etape(de: borne1, a: borne2, manoeuvre: Manoeuvre.aGauche),
          etape(de: borne2, a: arrivee, manoeuvre: Manoeuvre.aucune),
        ];
    final metres =
        liste.fold<int>(0, (total, e) => total + e.distanceMeters);
    return RouteInfo(
      distanceKm: metres / 1000,
      distanceMeters: metres,
      durationMinutes: (metres / 500).round(),
      polylinePoints: [depart, borne1, borne2, arrivee],
      encodedPolyline: '',
      timestamp: DateTime(2026, 9, 5, 12),
      steps: liste,
    );
  }

  var horloge = DateTime(2026, 9, 5, 12);

  /// Un relevé de position propre — précis, en mouvement, daté.
  PositionNavigation releve(
    GeoPoint point, {
    double precision = 5,
    double vitesse = 8.3,
    double? cap,
  }) {
    horloge = horloge.add(const Duration(seconds: 2));
    return PositionNavigation(
      point: point,
      horodatage: horloge,
      capDegres: cap,
      vitesseMetresParSeconde: vitesse,
      precisionMetres: precision,
    );
  }

  setUp(() => horloge = DateTime(2026, 9, 5, 12));

  MoteurDeNavigation moteurEnRoute({
    ReglagesNavigation? reglages,
    EtapeNavigation etape = EtapeNavigation.restaurant,
    ModeNavigation mode = ModeNavigation.navigation,
    RouteInfo? route,
  }) {
    final moteur = MoteurDeNavigation(
      reglages: reglages ?? const ReglagesNavigation(),
    );
    moteur.demarrer(
      etape: etape,
      itineraire: route ?? itineraire(),
      mode: mode,
    );
    return moteur;
  }

  group('Départ', () {
    test('le guidage annonce sa destination', () {
      final moteur = MoteurDeNavigation();
      final decision = moteur.demarrer(
        etape: EtapeNavigation.restaurant,
        itineraire: itineraire(),
      );

      expect(decision.aPrononcer, ['Navigation vers le restaurant.']);
      expect(moteur.etat, EtatNavigation.versLeRestaurant);
      expect(moteur.etape, EtapeNavigation.restaurant);
    });

    test('en aperçu, rien n’est prononcé', () {
      // Le livreur regarde son itinéraire à l'arrêt ; le téléphone n'a aucune
      // raison de parler.
      final moteur = MoteurDeNavigation();
      final decision = moteur.demarrer(
        etape: EtapeNavigation.restaurant,
        itineraire: itineraire(),
        mode: ModeNavigation.apercu,
      );

      expect(decision.aPrononcer, isEmpty);
      expect(moteur.etat, EtatNavigation.versLeRestaurant);
    });

    test('le tracé suivi est celui des étapes, pas l’aperçu simplifié', () {
      final moteur = moteurEnRoute();
      // Les trois étapes portent chacune deux points, jonctions dédupliquées.
      expect(moteur.trace.length, 4);
      expect(moteur.trace.first, depart);
      expect(moteur.trace.last, arrivee);
    });
  });

  group('Annonces et paliers', () {
    test('rien n’est dit tant que la manœuvre est lointaine', () {
      final moteur = moteurEnRoute();
      // À 300 m du départ, il reste 700 m avant le virage : au-delà du palier
      // de 500.
      final decision = moteur.mettreAJour(releve(auNord(depart, 300)));
      expect(decision.aPrononcer, isEmpty);
    });

    test('le palier de 500 mètres annonce la manœuvre avec sa distance', () {
      final moteur = moteurEnRoute();
      final decision = moteur.mettreAJour(releve(auNord(depart, 550)));

      expect(decision.aPrononcer.single, contains('tournez à droite'));
      expect(decision.aPrononcer.single, startsWith('Dans 450 mètres'));
    });

    test('la même instruction n’est pas répétée entre deux paliers', () {
      // C'est la règle qui rend le guidage supportable : sans elle, chaque
      // relevé — un toutes les deux secondes — redirait le même virage.
      final moteur = moteurEnRoute();
      moteur.mettreAJour(releve(auNord(depart, 550)));

      for (final metres in [560.0, 600.0, 700.0, 780.0]) {
        expect(
          moteur.mettreAJour(releve(auNord(depart, metres))).aPrononcer,
          isEmpty,
          reason: 'à $metres m, le palier de 500 est déjà passé',
        );
      }
    });

    test('le palier de 200 mètres annonce à nouveau', () {
      final moteur = moteurEnRoute();
      moteur.mettreAJour(releve(auNord(depart, 550)));
      final decision = moteur.mettreAJour(releve(auNord(depart, 850)));

      expect(decision.aPrononcer.single, startsWith('Dans 150 mètres'));
      expect(decision.aPrononcer.single, contains('tournez à droite'));
    });

    test('au dernier palier, l’instruction est nue — c’est maintenant', () {
      final moteur = moteurEnRoute();
      moteur.mettreAJour(releve(auNord(depart, 550)));
      moteur.mettreAJour(releve(auNord(depart, 850)));
      final decision = moteur.mettreAJour(releve(auNord(depart, 970)));

      expect(decision.aPrononcer.single, 'Tournez à droite.');
    });

    test('l’instruction immédiate ne se répète pas non plus', () {
      final moteur = moteurEnRoute();
      moteur.mettreAJour(releve(auNord(depart, 970)));
      expect(moteur.mettreAJour(releve(auNord(depart, 985))).aPrononcer, isEmpty);
      expect(moteur.mettreAJour(releve(auNord(depart, 995))).aPrononcer, isEmpty);
    });

    test('un relevé espacé qui saute deux paliers n’en dit qu’un', () {
      // Un livreur à cinquante à l'heure parcourt 140 m entre deux relevés, et
      // peut passer de 600 m à 250 m sans qu'on l'ait vu à 500. Prononcer les
      // deux annonces coup sur coup serait pire que d'en sauter une.
      final moteur = moteurEnRoute();
      final decision = moteur.mettreAJour(releve(auNord(depart, 850)));
      expect(decision.aPrononcer, hasLength(1));
      expect(decision.aPrononcer.single, startsWith('Dans 150 mètres'));
    });

    test('le palier sauté ne repart pas au relevé suivant', () {
      // Le piège que la version précédente laissait passer : le palier de 500
      // déclenche à 150 m, on ne retient que lui, et le palier de 200 —
      // satisfait par la même distance — repart deux secondes plus tard.
      // Le livreur entendait « dans 150 mètres, tournez à droite » puis
      // « dans 140 mètres, tournez à droite ».
      final moteur = moteurEnRoute();
      moteur.mettreAJour(releve(auNord(depart, 850)));

      expect(moteur.mettreAJour(releve(auNord(depart, 860))).aPrononcer, isEmpty);
      expect(moteur.mettreAJour(releve(auNord(depart, 870))).aPrononcer, isEmpty);
      expect(moteur.mettreAJour(releve(auNord(depart, 900))).aPrononcer, isEmpty);
    });

    test('sur tout le trajet, chaque manœuvre est annoncée sans doublon', () {
      // Le trajet entier, relevé tous les vingt mètres — la cadence d'un
      // livreur en ville. Aucune phrase ne doit sortir deux fois.
      final moteur = moteurEnRoute();
      final dites = <String>[];
      for (var metres = 20.0; metres <= 1880; metres += 20) {
        final point = metres <= 1000
            ? auNord(depart, metres)
            : (metres <= 1600
                ? aLEst(borne1, metres - 1000)
                : auNord(borne2, metres - 1600));
        dites.addAll(moteur.mettreAJour(releve(point)).aPrononcer);
      }

      expect(dites.toSet(), hasLength(dites.length), reason: 'aucun doublon');
      expect(
        dites.where((p) => p.contains('tournez à droite')),
        isNotEmpty,
        reason: 'la première manœuvre est annoncée',
      );
      expect(
        dites.where((p) => p.contains('tournez à gauche')),
        isNotEmpty,
        reason: 'la seconde aussi',
      );
      expect(dites.last, 'Vous êtes arrivé au restaurant.');
    });

    test('la manœuvre franchie, l’étape suivante prend la parole', () {
      final moteur = moteurEnRoute();
      moteur.mettreAJour(releve(auNord(depart, 970)));

      // Le virage est passé : on roule maintenant vers l'est, 600 m avant le
      // virage à gauche.
      moteur.mettreAJour(releve(aLEst(borne1, 50)));
      expect(moteur.etapeCourante?.manoeuvre, Manoeuvre.aGauche);

      final decision = moteur.mettreAJour(releve(aLEst(borne1, 150)));
      expect(decision.aPrononcer.single, contains('tournez à gauche'));
    });

    test('une étape trop courte ne déclenche pas l’annonce lointaine', () {
      // Annoncer « dans 500 mètres » au début d'une étape de 80 mètres
      // prononcerait les trois annonces dans la même seconde.
      final courte = auNord(depart, 80);
      final moteur = moteurEnRoute(
        route: itineraire(
          etapes: [
            etape(de: depart, a: courte, manoeuvre: Manoeuvre.aDroite),
            etape(
              de: courte,
              a: auNord(courte, 900),
              manoeuvre: Manoeuvre.aucune,
            ),
          ],
        ),
      );

      final decision = moteur.mettreAJour(releve(auNord(depart, 10)));
      expect(decision.aPrononcer, isEmpty);

      // Seule l'annonce immédiate est due, à cinquante mètres du virage.
      final proche = moteur.mettreAJour(releve(auNord(depart, 40)));
      expect(proche.aPrononcer.single, 'Tournez à droite.');
    });

    test('sans manœuvre, c’est le texte de Google qui est prononcé', () {
      // Jamais un geste inventé : dire « tournez à droite » là où Google n'a
      // rien affirmé enverrait le livreur dans la mauvaise rue.
      final moteur = moteurEnRoute(
        route: itineraire(
          etapes: [
            RouteStep(
              distanceMeters: 1000,
              durationSeconds: 120,
              start: depart,
              end: borne1,
              instruction: 'Prendre la direction du nord sur le Boulevard',
              manoeuvre: Manoeuvre.aucune,
              polylinePoints: [depart, borne1],
            ),
          ],
        ),
      );

      final decision = moteur.mettreAJour(releve(auNord(depart, 550)));
      expect(
        decision.aPrononcer.single,
        'Dans 450 mètres, Prendre la direction du nord sur le Boulevard.',
      );
    });
  });

  group('Répétition à la demande', () {
    test('elle rend l’instruction courante, pas celle d’avant', () {
      // Entre les deux, le livreur a pu franchir la manœuvre : lui rejouer une
      // consigne périmée l'enverrait dans la mauvaise rue.
      final moteur = moteurEnRoute();
      moteur.mettreAJour(releve(auNord(depart, 550)));
      moteur.mettreAJour(releve(aLEst(borne1, 100)));

      expect(moteur.phraseARepeter(), contains('tournez à gauche'));
    });
  });

  group('Sortie d’itinéraire', () {
    /// Un point à [metres] de côté du tracé, à mi-chemin de la première étape.
    GeoPoint deCote(double metres) => aLEst(auNord(depart, 500), metres);

    test('un seul relevé écarté ne déclenche rien', () {
      // Un point aberrant arrive régulièrement en ville. Recalculer dessus
      // coûte une requête, une polyline, une annonce, et la confiance du
      // livreur.
      final moteur = moteurEnRoute();
      final decision = moteur.mettreAJour(releve(deCote(200)));

      expect(decision.recalculDemande, isFalse);
      expect(moteur.etat, EtatNavigation.versLeRestaurant);
    });

    test('trois relevés écartés concluent et demandent un recalcul', () {
      final moteur = moteurEnRoute();
      moteur.mettreAJour(releve(deCote(200)));
      moteur.mettreAJour(releve(deCote(210)));
      final decision = moteur.mettreAJour(releve(deCote(220)));

      expect(decision.recalculDemande, isTrue);
      expect(decision.aPrononcer.single, contains('quitté l’itinéraire'));
      expect(moteur.etat, EtatNavigation.horsItineraire);
    });

    test('le temps mort empêche la boucle de recalculs', () {
      // Un livreur arrêté à cent mètres du tracé — l'embouteillage sur la voie
      // d'à côté — redemanderait sinon un itinéraire toutes les deux secondes.
      final moteur = moteurEnRoute();
      for (var i = 0; i < 3; i++) {
        moteur.mettreAJour(releve(deCote(200)));
      }

      var recalculs = 0;
      for (var i = 0; i < 9; i++) {
        if (moteur.mettreAJour(releve(deCote(200))).recalculDemande) recalculs++;
      }
      expect(recalculs, 0, reason: 'dix-huit secondes, temps mort de vingt');
    });

    test('l’annonce de sortie n’est faite qu’une fois', () {
      final moteur = moteurEnRoute();
      final dites = <String>[];
      for (var i = 0; i < 12; i++) {
        dites.addAll(moteur.mettreAJour(releve(deCote(200))).aPrononcer);
      }
      expect(
        dites.where((p) => p.contains('quitté')).length,
        1,
      );
    });

    test('revenu sur le tracé sans recalcul, le guidage reprend', () {
      final moteur = moteurEnRoute();
      for (var i = 0; i < 3; i++) {
        moteur.mettreAJour(releve(deCote(200)));
      }
      expect(moteur.etat, EtatNavigation.horsItineraire);

      moteur.mettreAJour(releve(auNord(depart, 520)));
      expect(moteur.etat, EtatNavigation.versLeRestaurant);
    });

    test('un relevé imprécis ne fait pas conclure à une sortie', () {
      // Un point donné à 150 mètres près place le livreur n'importe où dans le
      // pâté de maisons : conclure dessus, c'est conclure sur du bruit.
      final moteur = moteurEnRoute();
      for (var i = 0; i < 5; i++) {
        final decision =
            moteur.mettreAJour(releve(deCote(200), precision: 150));
        expect(decision.recalculDemande, isFalse);
      }
      expect(moteur.etat, EtatNavigation.versLeRestaurant);
    });

    test('le nouvel itinéraire remet le guidage en route', () {
      final moteur = moteurEnRoute();
      for (var i = 0; i < 3; i++) {
        moteur.mettreAJour(releve(deCote(200)));
      }

      final decision = moteur.remplacerLItineraire(itineraire());
      expect(decision.aPrononcer.single, 'Nouvel itinéraire.');
      expect(moteur.etat, EtatNavigation.versLeRestaurant);
    });

    test('le nouvel itinéraire rouvre les annonces déjà faites', () {
      // Les paliers dits appartenaient au tracé remplacé. Les garder ferait
      // rouler le livreur en silence jusqu'au carrefour suivant.
      final moteur = moteurEnRoute();
      moteur.mettreAJour(releve(auNord(depart, 550)));
      moteur.remplacerLItineraire(itineraire());

      final decision = moteur.mettreAJour(releve(auNord(depart, 560)));
      expect(decision.aPrononcer.single, startsWith('Dans 450 mètres'));
    });
  });

  group('Arrivée', () {
    test('elle est détectée dans le rayon et annoncée une seule fois', () {
      final moteur = moteurEnRoute(etape: EtapeNavigation.client);
      // Le tracé fait 1900 m ; on se pose à 30 m de la fin.
      final decision = moteur.mettreAJour(releve(auNord(borne2, 275)));

      expect(moteur.etat, EtatNavigation.arriveChezLeClient);
      expect(decision.aPrononcer.single, 'Vous êtes arrivé à destination.');

      final ensuite = moteur.mettreAJour(releve(auNord(borne2, 285)));
      expect(ensuite.aPrononcer, isEmpty);
    });

    test('le restaurant a sa propre phrase', () {
      final moteur = moteurEnRoute();
      final decision = moteur.mettreAJour(releve(auNord(borne2, 280)));

      expect(moteur.etat, EtatNavigation.arriveAuRestaurant);
      expect(decision.aPrononcer.single, 'Vous êtes arrivé au restaurant.');
    });

    test('elle n’est pas conclue sur un relevé imprécis', () {
      // Le GPS ne décide pas d'une livraison. Il ne décide même pas d'une
      // arrivée, quand il annonce lui-même qu'il ne sait pas où il est.
      final moteur = moteurEnRoute();
      moteur.mettreAJour(releve(auNord(borne2, 280), precision: 200));
      expect(moteur.etat, EtatNavigation.versLeRestaurant);
    });

    test('couper par le parking suffit — la mesure à vol d’oiseau compte', () {
      // Le livreur qui coupe n'a pas fini le tracé, mais il est arrivé.
      final moteur = moteurEnRoute();
      final aCote = aLEst(arrivee, 25);
      moteur.mettreAJour(releve(aCote));
      expect(moteur.etat, EtatNavigation.arriveAuRestaurant);
    });
  });

  group('Changement d’étape', () {
    test('le passage au client remet tout à zéro et l’annonce', () {
      final moteur = moteurEnRoute();
      moteur.mettreAJour(releve(auNord(depart, 550)));

      final decision = moteur.changerDEtape(EtapeNavigation.client);
      expect(decision.aPrononcer.single, 'Navigation vers le client.');
      expect(moteur.etat, EtatNavigation.preparation);
      expect(moteur.itineraire, isNull);
      expect(moteur.derniereInstructionPrononcee, 'Navigation vers le client.');
    });

    test('le nouvel itinéraire reprend le guidage vers le client', () {
      final moteur = moteurEnRoute();
      moteur.changerDEtape(EtapeNavigation.client);
      moteur.remplacerLItineraire(itineraire(), annoncer: false);

      expect(moteur.etat, EtatNavigation.versLeClient);
      final decision = moteur.mettreAJour(releve(auNord(depart, 550)));
      expect(decision.aPrononcer.single, startsWith('Dans 450 mètres'));
    });

    test('redemander l’étape courante ne fait rien', () {
      final moteur = moteurEnRoute();
      expect(
        moteur.changerDEtape(EtapeNavigation.restaurant).sansEffet,
        isTrue,
      );
      expect(moteur.itineraire, isNotNull);
    });
  });

  group('Distance et heure d’arrivée', () {
    test('la distance restante se mesure le long du tracé', () {
      // Et non à vol d'oiseau : un livreur séparé de son client par un fleuve
      // en est à 300 mètres et à quatre kilomètres par le pont.
      final moteur = moteurEnRoute();
      moteur.mettreAJour(releve(auNord(depart, 400)));

      // 1900 m de tracé, 400 m parcourus.
      expect(moteur.distanceRestanteMetres, closeTo(1500, 15));
    });

    test('l’heure d’arrivée ne bouge pas pour quelques secondes d’écart', () {
      // « 12 min », « 11 min », « 12 min » : une estimation qui change sans
      // arrêt se relit sans arrêt, et n'apprend rien.
      final moteur = moteurEnRoute();
      moteur.mettreAJour(releve(auNord(depart, 100)));
      final ancree = moteur.heureArriveeEstimee;

      moteur.mettreAJour(releve(auNord(depart, 120)));
      moteur.mettreAJour(releve(auNord(depart, 140)));

      expect(moteur.heureArriveeEstimee, ancree);
    });

    test('elle est réancrée quand l’estimation s’écarte d’une minute', () {
      final moteur = moteurEnRoute();
      moteur.mettreAJour(releve(auNord(depart, 100)));
      final ancree = moteur.heureArriveeEstimee!;

      // Un bond de 700 mètres retire près de deux minutes de trajet.
      moteur.mettreAJour(releve(auNord(depart, 800)));
      expect(moteur.heureArriveeEstimee!.isBefore(ancree), isTrue);
    });

    test('la durée restante se déduit de l’heure ancrée', () {
      final moteur = moteurEnRoute();
      moteur.mettreAJour(releve(auNord(depart, 100)));

      final reste = moteur.dureeRestante(maintenant: horloge);
      expect(reste, isNotNull);
      expect(reste!.inSeconds, greaterThan(0));
    });

    test('sans position, il n’y a ni distance ni heure', () {
      final moteur = MoteurDeNavigation();
      expect(moteur.distanceRestanteMetres, isNull);
      expect(moteur.heureArriveeEstimee, isNull);
      expect(moteur.dureeRestante(), isNull);
    });
  });

  group('Cap du livreur', () {
    test('un appareil immobile ne fait pas tourner le repère', () {
      // Le cap d'un GPS à l'arrêt tourne au hasard : le repère pivoterait sur
      // lui-même devant le restaurant.
      final moteur = moteurEnRoute();
      moteur.mettreAJour(releve(auNord(depart, 100), cap: 12, vitesse: 8));
      expect(moteur.capDegres, 12);

      moteur.mettreAJour(releve(auNord(depart, 101), cap: 250, vitesse: 0.2));
      expect(moteur.capDegres, 12, reason: 'immobile : on garde le dernier cap');
    });

    test('sans cap du capteur, aucun cap n’est inventé', () {
      final moteur = moteurEnRoute();
      moteur.mettreAJour(releve(auNord(depart, 100)));
      expect(moteur.capDegres, isNull);
    });
  });

  group('Position et itinéraire indisponibles', () {
    test('la perte de position se dit, une fois, et seulement en route', () {
      final moteur = moteurEnRoute();
      moteur.mettreAJour(releve(auNord(depart, 100)));

      final premiere = moteur.signalerPositionIndisponible('GPS coupé');
      expect(premiere.aPrononcer.single, contains('Position perdue'));
      expect(moteur.etat, EtatNavigation.positionIndisponible);
      expect(moteur.erreur, 'GPS coupé');

      expect(moteur.signalerPositionIndisponible('GPS coupé').sansEffet, isTrue);
    });

    test('avant la première fixation, elle ne se dit pas', () {
      // Les dix premières secondes d'un démarrage sont normales ; faire parler
      // le téléphone pour cela n'apprend rien au livreur.
      final moteur = MoteurDeNavigation();
      final decision = moteur.signalerPositionIndisponible('en attente');
      expect(decision.aPrononcer, isEmpty);
    });

    test('la position revenue rend le guidage', () {
      final moteur = moteurEnRoute();
      moteur.mettreAJour(releve(auNord(depart, 100)));
      moteur.signalerPositionIndisponible('GPS coupé');

      moteur.mettreAJour(releve(auNord(depart, 150)));
      expect(moteur.etat, EtatNavigation.versLeRestaurant);
      expect(moteur.erreur, isNull);
    });

    test('un itinéraire impossible se dit et se retient', () {
      final moteur = moteurEnRoute();
      final decision = moteur.signalerErreur('Réseau indisponible');

      expect(moteur.etat, EtatNavigation.erreur);
      expect(moteur.erreur, 'Réseau indisponible');
      expect(decision.aPrononcer.single, contains('Impossible de calculer'));
    });
  });

  group('Modes', () {
    test('l’aperçu ne prononce rien, même en roulant', () {
      final moteur = moteurEnRoute(mode: ModeNavigation.apercu);
      for (final metres in [550.0, 850.0, 970.0]) {
        expect(
          moteur.mettreAJour(releve(auNord(depart, metres))).aPrononcer,
          isEmpty,
        );
      }
    });

    test('l’aperçu mesure quand même la distance', () {
      // Le livreur consulte son itinéraire : il doit voir ce qu'il représente.
      final moteur = moteurEnRoute(mode: ModeNavigation.apercu);
      moteur.mettreAJour(releve(auNord(depart, 400)));
      expect(moteur.distanceRestanteMetres, closeTo(1500, 15));
    });

    test('l’aperçu ne demande pas de recalcul', () {
      final moteur = moteurEnRoute(mode: ModeNavigation.apercu);
      for (var i = 0; i < 6; i++) {
        final decision = moteur.mettreAJour(
          releve(aLEst(auNord(depart, 500), 300)),
        );
        expect(decision.recalculDemande, isFalse);
      }
    });

    test('passer en navigation annonce la destination', () {
      final moteur = moteurEnRoute(mode: ModeNavigation.apercu);
      final decision = moteur.changerDeMode(ModeNavigation.navigation);
      expect(decision.aPrononcer.single, 'Navigation vers le restaurant.');
    });
  });

  group('Langue', () {
    test('le guidage bascule en anglais sans redémarrer', () {
      final moteur = moteurEnRoute();
      moteur.changerDeLangue(LangueNavigation.anglais);

      final decision = moteur.mettreAJour(releve(auNord(depart, 550)));
      expect(decision.aPrononcer.single, 'In 450 meters, turn right.');
    });

    test('changer de langue rouvre les annonces déjà faites', () {
      // Sans cela, le changement resterait inaudible jusqu'au carrefour
      // suivant.
      final moteur = moteurEnRoute();
      moteur.mettreAJour(releve(auNord(depart, 550)));
      moteur.changerDeLangue(LangueNavigation.anglais);

      final decision = moteur.mettreAJour(releve(auNord(depart, 560)));
      expect(decision.aPrononcer.single, startsWith('In 450 meters'));
    });
  });

  group('Arrêt', () {
    test('tout est oublié', () {
      final moteur = moteurEnRoute();
      moteur.mettreAJour(releve(auNord(depart, 550)));
      moteur.arreter();

      expect(moteur.etat, EtatNavigation.inactif);
      expect(moteur.itineraire, isNull);
      expect(moteur.trace, isEmpty);
      expect(moteur.position, isNull);
      expect(moteur.distanceRestanteMetres, isNull);
      expect(moteur.derniereInstructionPrononcee, isNull);
    });

    test('une position reçue après l’arrêt ne relance rien', () {
      final moteur = moteurEnRoute();
      moteur.arreter();
      expect(moteur.mettreAJour(releve(auNord(depart, 550))).sansEffet, isTrue);
    });

    test('une course terminée ne guide plus', () {
      final moteur = moteurEnRoute();
      moteur.terminer();
      expect(moteur.etat, EtatNavigation.terminee);
      expect(moteur.mettreAJour(releve(auNord(depart, 550))).sansEffet, isTrue);
    });
  });

  group('Itinéraire sans manœuvres', () {
    test('la navigation mesure et se tait plutôt que d’échouer', () {
      // Un repli peut ne rendre qu'un tracé. Mieux vaut une carte juste et une
      // distance juste, sans virages, qu'aucune navigation.
      final sansEtapes = RouteInfo(
        distanceKm: 1.9,
        distanceMeters: 1900,
        durationMinutes: 6,
        polylinePoints: [depart, borne1, borne2, arrivee],
        encodedPolyline: '',
        timestamp: DateTime(2026, 9, 5, 12),
      );

      final moteur = moteurEnRoute(route: sansEtapes);
      expect(moteur.itineraire!.guidagePossible, isFalse);

      final decision = moteur.mettreAJour(releve(auNord(depart, 550)));
      expect(decision.aPrononcer, isEmpty);
      expect(moteur.etapeCourante, isNull);
      expect(moteur.distanceRestanteMetres, closeTo(1350, 20));
    });
  });
}

import 'dart:async';

import 'package:elcora_dely/services/navigation_voice_service.dart';
import 'package:elcorazon_core/elcorazon_core.dart' show LangueNavigation;
import 'package:flutter_test/flutter_test.dart';

/// La voix de la navigation, contre un moteur de synthèse simulé.
///
/// ## Pourquoi un moteur simulé
///
/// `flutter_tts` passe par un canal de plateforme : dans un test, chacun de
/// ses appels lève `MissingPluginException`. Les règles qui comptent ici ne
/// sont pourtant pas celles du greffon, ce sont les nôtres — une instruction
/// n'est pas prononcée deux fois, la plus récente chasse celle qui attendait,
/// couper la voix coupe ce qui sort du haut-parleur. Aucune ne se vérifie en
/// écoutant un téléphone, et toutes se vérifient ici.
class _MoteurSimule implements MoteurVocal {
  _MoteurSimule({this.disponible = true});

  final bool disponible;

  /// Tout ce qui a été prononcé, dans l'ordre.
  final List<String> dites = [];

  /// Les réglages successivement appliqués.
  final List<String> langues = [];
  final List<double> volumes = [];

  int arrets = 0;
  int pauses = 0;
  int liberations = 0;

  /// Rend la parole bloquante jusqu'à ce que le test la relâche, pour observer
  /// ce qui se passe **pendant** qu'une phrase est en cours.
  Completer<void>? enCours;

  @override
  Future<bool> preparer({
    required String langue,
    required double volume,
    required double vitesse,
  }) async {
    langues.add(langue);
    volumes.add(volume);
    return disponible;
  }

  @override
  Future<void> dire(String texte) async {
    dites.add(texte);
    final attente = enCours;
    if (attente != null) await attente.future;
  }

  @override
  Future<void> taire() async {
    arrets++;
    enCours?.complete();
    enCours = null;
  }

  @override
  Future<void> suspendre() async => pauses++;

  @override
  Future<void> liberer() async => liberations++;
}

void main() {
  late _MoteurSimule moteur;
  late NavigationVoiceService voix;

  setUp(() {
    moteur = _MoteurSimule();
    voix = NavigationVoiceService(moteur: moteur);
  });

  group('Ouverture', () {
    test('elle applique la langue et le volume', () async {
      await voix.initialize();
      expect(voix.disponible, isTrue);
      expect(moteur.langues, ['fr-FR']);
      expect(moteur.volumes, [1.0]);
    });

    test('elle est idempotente', () async {
      await voix.initialize();
      await voix.initialize();
      expect(moteur.langues, hasLength(1));
    });

    test('sans moteur, tout devient inerte plutôt que de casser', () async {
      // Un poste sans synthèse — un test, un bureau — ne doit pas empêcher la
      // navigation. Elle continue, muette.
      final absent = _MoteurSimule(disponible: false);
      final muette = NavigationVoiceService(moteur: absent);

      await muette.initialize();
      expect(muette.disponible, isFalse);

      await muette.speak('Tournez à droite.');
      expect(absent.dites, isEmpty);
    });
  });

  group('Prononciation', () {
    test('une instruction est prononcée', () async {
      await voix.speak('Tournez à droite.');
      await pumpEventQueue();
      expect(moteur.dites, ['Tournez à droite.']);
    });

    test('une phrase vide n’est pas prononcée', () async {
      await voix.speak('   ');
      await pumpEventQueue();
      expect(moteur.dites, isEmpty);
    });

    test('la voix coupée ne prononce rien', () async {
      await voix.initialize();
      await voix.definirActif(actif: false);

      await voix.speak('Tournez à droite.');
      await pumpEventQueue();
      expect(moteur.dites, isEmpty);
      expect(voix.actif, isFalse);
    });

    test('la voix rétablie prononce à nouveau', () async {
      await voix.initialize();
      await voix.definirActif(actif: false);
      await voix.definirActif(actif: true);

      await voix.speak('Tournez à droite.');
      await pumpEventQueue();
      expect(moteur.dites, ['Tournez à droite.']);
    });
  });

  group('Répétitions et file d’attente', () {
    test('redemander la phrase en cours ne la rejoue pas', () async {
      await voix.initialize();
      moteur.enCours = Completer<void>();

      unawaited(voix.speak('Tournez à droite.'));
      await pumpEventQueue();
      expect(moteur.dites, ['Tournez à droite.']);

      // La même, pendant qu'elle sort du haut-parleur.
      await voix.speak('Tournez à droite.');
      await pumpEventQueue();
      expect(moteur.dites, hasLength(1));

      await moteur.taire();
      await pumpEventQueue();
    });

    test('une instruction plus récente chasse celle qui attendait', () async {
      // Une instruction de navigation périme vite : entendre « tournez à
      // droite » six secondes après le carrefour est pire que ne rien
      // entendre.
      await voix.initialize();
      moteur.enCours = Completer<void>();

      unawaited(voix.speak('Dans 500 mètres, tournez à droite.'));
      await pumpEventQueue();

      unawaited(voix.speak('Dans 200 mètres, tournez à droite.'));
      unawaited(voix.speak('Tournez à droite.'));
      await pumpEventQueue();

      moteur.enCours!.complete();
      moteur.enCours = null;
      await pumpEventQueue();

      expect(moteur.dites, [
        'Dans 500 mètres, tournez à droite.',
        'Tournez à droite.',
      ]);
    });

    test('une annonce prioritaire coupe ce qui est en cours', () async {
      await voix.initialize();
      moteur.enCours = Completer<void>();

      unawaited(voix.speak('Dans 500 mètres, tournez à droite.'));
      await pumpEventQueue();
      expect(moteur.arrets, 0);

      await voix.speak('Vous êtes arrivé à destination.', prioritaire: true);
      await pumpEventQueue();

      expect(moteur.arrets, 1);
      expect(moteur.dites.last, 'Vous êtes arrivé à destination.');
    });

    test('la dernière phrase confiée est retenue', () async {
      await voix.speak('Tournez à droite.');
      await pumpEventQueue();
      expect(voix.dernierePhrase, 'Tournez à droite.');
    });
  });

  group('Arrêt et pause', () {
    test('arrêter coupe le moteur et vide la file', () async {
      await voix.initialize();
      await voix.stop();
      expect(moteur.arrets, 1);
    });

    test('la pause fait taire et ignore les annonces suivantes', () async {
      await voix.initialize();
      await voix.pause();
      expect(voix.enPause, isTrue);
      expect(moteur.pauses, 1);

      await voix.speak('Tournez à droite.');
      await pumpEventQueue();
      expect(moteur.dites, isEmpty);
    });

    test('la reprise ne rejoue pas la phrase interrompue', () async {
      // Elle était liée à un carrefour que le livreur a peut-être franchi
      // pendant l'appel. C'est la prochaine instruction qui compte.
      await voix.initialize();
      await voix.speak('Tournez à droite.');
      await pumpEventQueue();
      moteur.dites.clear();

      await voix.pause();
      await voix.resume();
      await pumpEventQueue();

      expect(voix.enPause, isFalse);
      expect(moteur.dites, isEmpty);
    });

    test('libérer ferme le moteur', () async {
      await voix.initialize();
      await voix.dispose();
      expect(moteur.liberations, 1);
      expect(voix.disponible, isFalse);
    });
  });

  group('Réglages', () {
    test('le volume est borné et réappliqué', () async {
      await voix.initialize();
      await voix.definirVolume(2.5);
      expect(voix.volume, 1.0);

      await voix.definirVolume(0.4);
      expect(voix.volume, 0.4);
      expect(moteur.volumes.last, 0.4);
    });

    test('changer de langue coupe la phrase en cours et réapplique', () async {
      // Ce qui est en train d'être dit appartient à l'ancienne langue.
      await voix.initialize();
      await voix.definirLangue(LangueNavigation.anglais);

      expect(voix.langue, LangueNavigation.anglais);
      expect(moteur.arrets, 1);
      expect(moteur.langues.last, 'en-US');
    });

    test('redemander la langue courante ne fait rien', () async {
      await voix.initialize();
      await voix.definirLangue(LangueNavigation.francais);
      expect(moteur.langues, hasLength(1));
      expect(moteur.arrets, 0);
    });
  });
}

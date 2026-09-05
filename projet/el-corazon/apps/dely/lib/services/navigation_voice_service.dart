import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' show Journal, LangueNavigation;
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Un moteur de synthèse vocale, réduit à ce que la navigation lui demande.
///
/// ## Pourquoi cette interface existe
///
/// `flutter_tts` passe par un canal de plateforme : dans un test, il lève
/// `MissingPluginException` à chaque appel. Sans cette frontière, aucune des
/// règles qui comptent — une instruction n'est pas prononcée deux fois, la
/// voix se tait quand on la coupe, un changement de langue est appliqué avant
/// la phrase suivante — ne serait vérifiable autrement qu'en écoutant un
/// téléphone.
///
/// Elle sert aussi de garde-fou : le service au-dessus ne connaît que ces cinq
/// gestes, et ne peut donc pas dépendre d'une particularité du greffon qui
/// changerait à la prochaine version.
abstract class MoteurVocal {
  /// Ouvre le moteur et applique les réglages. Rend `false` si le moteur n'est
  /// pas disponible — greffon absent, plateforme sans synthèse.
  Future<bool> preparer({
    required String langue,
    required double volume,
    required double vitesse,
  });

  /// Prononce, et ne rend la main qu'une fois la phrase finie.
  Future<void> dire(String texte);

  /// Coupe la phrase en cours.
  Future<void> taire();

  /// Suspend la phrase en cours, sans l'oublier.
  Future<void> suspendre();

  /// Ferme le moteur.
  Future<void> liberer();
}

/// Le moteur réel, adossé à `flutter_tts`.
class MoteurVocalFlutterTts implements MoteurVocal {
  MoteurVocalFlutterTts([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  @override
  Future<bool> preparer({
    required String langue,
    required double volume,
    required double vitesse,
  }) async {
    try {
      // Sur Android, déclare la synthèse comme **guidage de navigation**
      // (`USAGE_ASSISTANCE_NAVIGATION_GUIDANCE`). C'est ce qui fait que la
      // musique du livreur baisse pendant l'instruction au lieu de s'arrêter,
      // et que l'instruction passe par-dessus un appel Bluetooth mains libres.
      // Sans cela, le système traite l'annonce comme un média quelconque et
      // peut la faire attendre — c'est-à-dire arriver après le carrefour.
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _tts.setAudioAttributesForNavigation();
      }

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // `playback` pour que l'instruction passe même sur silencieux — un
        // livreur laisse son téléphone en silencieux toute la journée.
        // `duckOthers` plutôt qu'une interruption : on baisse la musique, on
        // ne la coupe pas. `voicePrompt` indique au système qu'il s'agit d'une
        // consigne courte, ce qui raccourcit la reprise de l'audio d'origine.
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.duckOthers,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          ],
          IosTextToSpeechAudioMode.voicePrompt,
        );
      }

      await _tts.setLanguage(langue);
      await _tts.setVolume(volume);
      await _tts.setSpeechRate(vitesse);
      await _tts.setPitch(1.0);
      // Sans cela, `speak` rend la main immédiatement et deux instructions
      // rapprochées se recouvrent.
      await _tts.awaitSpeakCompletion(true);
      return true;
    } catch (e) {
      Journal.trace('⚠️ Synthèse vocale indisponible : $e');
      return false;
    }
  }

  @override
  Future<void> dire(String texte) => _tts.speak(texte);

  @override
  Future<void> taire() => _tts.stop();

  @override
  Future<void> suspendre() => _tts.pause();

  @override
  Future<void> liberer() => _tts.stop();
}

/// La voix de la navigation.
///
/// ## Ce qu'il garantit
///
/// * **Une phrase à la fois.** Les annonces sont sérialisées : deux
///   instructions rapprochées se suivent au lieu de se recouvrir, ce qui les
///   rendrait toutes deux inaudibles.
/// * **Pas de retard.** La file ne contient qu'une phrase en attente. Une
///   instruction de navigation périme vite : entendre « tournez à droite » six
///   secondes après le carrefour est pire que ne rien entendre. Une nouvelle
///   annonce remplace donc celle qui attendait.
/// * **Pas de doublon.** Redemander la phrase en cours ne la rejoue pas.
/// * **Rien ne casse sans moteur.** Sur un poste sans synthèse — un test, un
///   bureau — [disponible] passe à faux et tous les gestes deviennent inertes.
///   La navigation continue, muette ; elle ne s'arrête pas.
///
/// ## Ce qu'il ne fait pas
///
/// Il ne décide pas de ce qu'il faut dire ni quand : cela vient de
/// `MoteurDeNavigation`, qui rend des phrases. Ce service ne fait que les
/// porter jusqu'au haut-parleur.
class NavigationVoiceService extends ChangeNotifier {
  NavigationVoiceService({MoteurVocal? moteur})
      : _moteur = moteur ?? MoteurVocalFlutterTts();

  final MoteurVocal _moteur;

  /// Vitesse d'élocution.
  ///
  /// L'échelle de `flutter_tts` n'est pas la même partout : sur Android, 1.0
  /// est déjà rapide et 0.5 correspond au débit normal ; sur iOS, la vitesse
  /// nominale est plus basse encore. Les deux valeurs sont donc nommées, plutôt
  /// qu'un nombre unique qui rendrait la voix précipitée sur une plateforme.
  static const double vitesseAndroid = 0.52;
  static const double vitesseApple = 0.5;

  bool _initialise = false;
  bool _disponible = false;
  bool _actif = true;
  bool _enPause = false;
  double _volume = 1.0;
  LangueNavigation _langue = LangueNavigation.francais;

  /// Le moteur a-t-il répondu ? Faux tant que [initialize] n'a pas tourné, et
  /// faux définitivement sur une plateforme sans synthèse.
  bool get disponible => _disponible;

  /// La voix est-elle allumée ? C'est le réglage du livreur, distinct de la
  /// disponibilité du moteur.
  bool get actif => _actif;

  bool get enPause => _enPause;
  double get volume => _volume;
  LangueNavigation get langue => _langue;

  /// La dernière phrase confiée au moteur — celle que « répéter » rejouerait
  /// à défaut d'instruction courante.
  String? get dernierePhrase => _dernierePhrase;
  String? _dernierePhrase;

  /// Ce qui est en train d'être prononcé, ou `null`.
  String? _enCours;

  /// La seule phrase en attente. Volontairement unique : voir la classe.
  String? _enAttente;

  Future<void>? _boucle;

  /// Ouvre le moteur. Idempotente : la rappeler ne rouvre rien.
  Future<void> initialize() async {
    if (_initialise) return;
    _initialise = true;

    _disponible = await _moteur.preparer(
      langue: _langue.etiquetteVocale,
      volume: _volume,
      vitesse: _vitesseDeLaPlateforme,
    );
    if (!_disponible) {
      Journal.trace('🔇 Guidage vocal indisponible : la navigation restera muette.');
    }
    notifyListeners();
  }

  double get _vitesseDeLaPlateforme =>
      defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS
          ? vitesseApple
          : vitesseAndroid;

  /// Prononce [texte].
  ///
  /// [prioritaire] coupe ce qui est en train d'être dit. Réservé à ce qui ne
  /// peut pas attendre la fin de la phrase précédente : une sortie
  /// d'itinéraire, une arrivée. Une instruction ordinaire attend son tour —
  /// couper systématiquement rendrait chaque annonce partielle.
  Future<void> speak(String texte, {bool prioritaire = false}) async {
    if (texte.trim().isEmpty) return;
    if (!_actif || _enPause) return;
    if (!_initialise) await initialize();
    if (!_disponible) return;

    // Redemander exactement ce qui sort du haut-parleur ne le rejoue pas.
    if (_enCours == texte) return;

    _dernierePhrase = texte;

    if (prioritaire) {
      _enAttente = texte;
      await _moteur.taire();
      // `taire` fait rendre la main à `dire`, donc à la boucle, qui
      // enchaînera sur ce qui attend.
      notifyListeners();
      _demarrerLaBoucle();
      return;
    }

    // Remplace ce qui attendait : une instruction plus récente est toujours
    // plus utile que celle qu'elle chasse.
    _enAttente = texte;
    notifyListeners();
    _demarrerLaBoucle();
  }

  void _demarrerLaBoucle() {
    _boucle ??= _vider().whenComplete(() => _boucle = null);
  }

  Future<void> _vider() async {
    while (_enAttente != null) {
      final phrase = _enAttente!;
      _enAttente = null;
      _enCours = phrase;
      notifyListeners();

      try {
        await _moteur.dire(phrase);
      } catch (e) {
        Journal.trace('⚠️ Instruction vocale non prononcée : $e');
        // Un moteur qui refuse une phrase refusera probablement les
        // suivantes ; le signaler une fois vaut mieux que d'inonder le
        // journal à chaque carrefour.
        _disponible = false;
      } finally {
        _enCours = null;
      }
    }
    notifyListeners();
  }

  /// Coupe la phrase en cours et jette ce qui attendait.
  Future<void> stop() async {
    _enAttente = null;
    if (!_disponible) return;
    try {
      await _moteur.taire();
    } catch (e) {
      Journal.trace('⚠️ Arrêt de la synthèse : $e');
    }
    _enCours = null;
    notifyListeners();
  }

  /// Suspend le guidage vocal — un appel entrant, une pause.
  Future<void> pause() async {
    if (_enPause) return;
    _enPause = true;
    _enAttente = null;
    if (_disponible) {
      try {
        await _moteur.suspendre();
      } catch (e) {
        Journal.trace('⚠️ Mise en pause de la synthèse : $e');
      }
    }
    notifyListeners();
  }

  /// Reprend le guidage vocal.
  ///
  /// Sans rejouer la phrase interrompue : elle était liée à un carrefour que
  /// le livreur a peut-être franchi pendant l'appel. C'est la prochaine
  /// instruction qui compte, et le bouton « répéter » est là pour la demander.
  Future<void> resume() async {
    if (!_enPause) return;
    _enPause = false;
    notifyListeners();
  }

  /// Allume ou éteint la voix. L'éteindre coupe immédiatement ce qui se dit.
  Future<void> definirActif({required bool actif}) async {
    if (_actif == actif) return;
    _actif = actif;
    if (!actif) await stop();
    notifyListeners();
  }

  /// Règle le volume, entre 0 et 1.
  Future<void> definirVolume(double volume) async {
    final borne = volume.clamp(0.0, 1.0);
    if (_volume == borne) return;
    _volume = borne;
    notifyListeners();
    if (!_disponible) return;
    // Le greffon n'expose pas de réglage isolé du volume à chaud : c'est la
    // préparation entière qui le porte. La rejouer est sans effet de bord.
    await _moteur.preparer(
      langue: _langue.etiquetteVocale,
      volume: _volume,
      vitesse: _vitesseDeLaPlateforme,
    );
  }

  /// Change la langue de la voix.
  ///
  /// Ne traduit rien : les phrases arrivent déjà rédigées de
  /// `MoteurDeNavigation`, qu'il faut donc basculer en même temps. C'est
  /// `NavigationService` qui tient les deux.
  Future<void> definirLangue(LangueNavigation langue) async {
    if (_langue == langue) return;
    _langue = langue;
    // Ce qui est en cours appartient à l'ancienne langue.
    await stop();
    notifyListeners();
    if (!_disponible) return;
    await _moteur.preparer(
      langue: _langue.etiquetteVocale,
      volume: _volume,
      vitesse: _vitesseDeLaPlateforme,
    );
  }

  @override
  Future<void> dispose() async {
    _enAttente = null;
    _enCours = null;
    if (_disponible) {
      try {
        await _moteur.liberer();
      } catch (e) {
        Journal.trace('⚠️ Libération de la synthèse : $e');
      }
    }
    _disponible = false;
    super.dispose();
  }
}

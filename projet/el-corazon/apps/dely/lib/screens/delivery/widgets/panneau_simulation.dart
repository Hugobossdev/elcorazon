import 'package:elcorazon_core/elcorazon_core.dart'
    show GeoPoint, PositionSimulee;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:elcora_dely/services/navigation_service.dart';
import 'package:elcora_dely/services/realtime_tracking_service.dart';

/// Le pilotage du trajet simulé — **mode debug uniquement**.
///
/// ## Pourquoi il existe
///
/// Le développement se fait depuis Abidjan ; l'établissement est à Lomé, à six
/// cents kilomètres. Rien de ce que fait une navigation ne se vérifie sans
/// bouger : l'annonce d'un virage, son absence de répétition, le passage à
/// l'instruction suivante, la sortie d'itinéraire, le recalcul, l'entrée dans
/// le rayon d'arrivée. Le simulateur de position du système n'existe ni sur un
/// appareil sans mode développeur, ni de façon scriptable, et il ne rejoue pas
/// un trajet.
///
/// ## Ce que ce panneau n'est pas
///
/// **Une démonstration.** Il ne dessine aucune fausse carte, ne fabrique aucune
/// fausse instruction et n'appelle aucun code réservé au test. Il pose un
/// trajet dans `PositionSimulee`, et ce trajet ressort par le **même** flux que
/// le capteur (`fluxDePositions`), consommé par le **même**
/// `RealtimeTrackingService`, poussé dans le **même** `MoteurDeNavigation`, dit
/// par le **même** moteur de synthèse. La voix qu'on entend en simulation est
/// celle qu'entendra le livreur ; c'est tout l'intérêt.
///
/// ## Ce qu'il ne peut pas atteindre
///
/// La production. `PositionSimulee.estActive` est constant à faux hors
/// `kDebugMode` ; le compilateur retire ces branches du binaire. Ce widget rend
/// lui-même un espace vide en release.
class PanneauSimulation extends StatefulWidget {
  const PanneauSimulation({required this.navigation, super.key});

  final NavigationService navigation;

  @override
  State<PanneauSimulation> createState() => _PanneauSimulationState();
}

class _PanneauSimulationState extends State<PanneauSimulation> {
  final PositionSimulee _simulation = PositionSimulee();
  final RealtimeTrackingService _tracking = RealtimeTrackingService();

  double _vitesseKmH = 40;
  bool _deplie = false;

  /// Pose le trajet et rouvre le flux de position.
  ///
  /// Les deux gestes vont ensemble : `fluxDePositions` choisit sa source **à
  /// l'abonnement**, si bien qu'allumer la simulation alors que le flux du
  /// capteur est déjà ouvert ne changerait rien — et ferait chercher longtemps
  /// pourquoi le trajet ne bouge pas.
  Future<void> _lancer({bool detour = false}) async {
    final trace = widget.navigation.trace;
    if (trace.length < 2) {
      _prevenir('Aucun itinéraire à rejouer : attendez le calcul.');
      return;
    }

    var points = [
      for (final point in trace) GeoPoint(point.latitude, point.longitude),
    ];
    if (detour) points = _devier(points);

    _simulation.suivre(points, vitesseKmH: _vitesseKmH);
    await _tracking.relancerLeFluxDePosition();
    if (mounted) setState(() {});
  }

  /// Écarte la seconde moitié du trajet de deux cents mètres vers l'est.
  ///
  /// C'est le seul moyen d'exercer la sortie d'itinéraire : le tracé rejoué tel
  /// quel ne quitte jamais le tracé calculé, et le recalcul ne se déclencherait
  /// donc jamais. Deux cents mètres, parce que le seuil est à soixante et qu'il
  /// faut le dépasser franchement pour que trois relevés consécutifs comptent.
  List<GeoPoint> _devier(List<GeoPoint> trace) {
    const decalageEnDegres = 200 / 111320.0;
    final milieu = trace.length ~/ 2;
    return [
      for (var i = 0; i < trace.length; i++)
        i < milieu
            ? trace[i]
            : GeoPoint(
                trace[i].latitude,
                trace[i].longitude + decalageEnDegres,
              ),
    ];
  }

  Future<void> _arreter() async {
    _simulation.desactiver();
    await _tracking.relancerLeFluxDePosition();
    if (mounted) setState(() {});
  }

  void _prevenir(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.orange),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Double garde : la constante retire le code du binaire, le rendu vide
    // protège d'un appel qui aurait échappé à la constante.
    if (!kDebugMode) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final actif = _simulation.estActive;

    return Material(
      color: Colors.deepPurple.shade900.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _deplie = !_deplie),
              child: Row(
                children: [
                  Icon(
                    actif ? Icons.videogame_asset : Icons.bug_report,
                    size: 18,
                    color: actif ? Colors.amber : Colors.white70,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      actif
                          ? 'Trajet simulé — ${(_simulation.avancement * 100).round()} %'
                          : 'Trajet simulé (debug)',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    _deplie ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
            if (_deplie) ...[
              const SizedBox(height: 6),
              Text(
                actif
                    ? 'Les positions viennent du trajet, par le flux du suivi. '
                        'La voix et le recalcul sont réels.'
                    : 'Rejoue l’itinéraire calculé, à travers les services réels.',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.speed, size: 16, color: Colors.white70),
                  Expanded(
                    child: Slider(
                      value: _vitesseKmH,
                      min: 10,
                      max: 120,
                      divisions: 11,
                      label: '${_vitesseKmH.round()} km/h',
                      onChanged: (valeur) =>
                          setState(() => _vitesseKmH = valeur),
                    ),
                  ),
                  Text(
                    '${_vitesseKmH.round()} km/h',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _bouton(
                    Icons.play_arrow,
                    'Départ',
                    () => _lancer(),
                  ),
                  _bouton(
                    Icons.pause,
                    'Pause',
                    !_simulation.enDeplacement
                        ? null
                        : () {
                            _simulation.interrompre();
                            setState(() {});
                          },
                  ),
                  _bouton(
                    Icons.play_circle_outline,
                    'Reprise',
                    !_simulation.aUnTrajet || _simulation.enDeplacement
                        ? null
                        : () {
                            _simulation.reprendre();
                            setState(() {});
                          },
                  ),
                  _bouton(
                    Icons.restart_alt,
                    'Reprise à zéro',
                    !_simulation.aUnTrajet
                        ? null
                        : () {
                            _simulation.reinitialiser();
                            setState(() {});
                          },
                  ),
                  _bouton(
                    Icons.alt_route,
                    'Détour',
                    () => _lancer(detour: true),
                  ),
                  _bouton(Icons.gps_fixed, 'Capteur réel', _arreter),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bouton(IconData icone, String libelle, VoidCallback? action) {
    return TextButton.icon(
      onPressed: action,
      icon: Icon(icone, size: 16),
      label: Text(libelle, style: const TextStyle(fontSize: 12)),
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white30,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

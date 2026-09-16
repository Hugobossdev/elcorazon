import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:elcora_dely/services/app_service.dart';

/// « Pas de réseau », et non « connectez-vous ».
///
/// ## Ce que cet écran remplace
///
/// Au démarrage, l'application vérifie la session auprès de `/auth/me/`. Quand
/// cet appel échouait faute de réseau, l'état de session devenait une erreur
/// sans valeur : le portail lisait « aucun compte » et affichait l'écran de
/// connexion. Un livreur qui ouvrait son application dans un parking, un
/// sous-sol ou une zone sans couverture se voyait donc redemander ses
/// identifiants — au moment précis où ils ne pouvaient pas être vérifiés.
///
/// Ses jetons étaient pourtant intacts. Ce qu'il fallait n'était pas une
/// nouvelle connexion, mais du réseau.
///
/// ## La reprise
///
/// Le bouton est là pour celui qui sait qu'il vient de retrouver du signal.
/// La tentative automatique, toutes les dix secondes, est pour celui qui ne
/// regarde pas : il pose son téléphone sur le guidon, sort du sous-sol, et
/// l'application s'ouvre d'elle-même. Elle s'arrête avec l'écran — c'est le
/// portail qui le retire dès que la session est rétablie.
class SessionHorsLigneScreen extends StatefulWidget {
  const SessionHorsLigneScreen({super.key});

  @override
  State<SessionHorsLigneScreen> createState() => _SessionHorsLigneScreenState();
}

class _SessionHorsLigneScreenState extends State<SessionHorsLigneScreen> {
  static const _cadenceDeReprise = Duration(seconds: 10);

  Timer? _reprise;
  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    _reprise = Timer.periodic(_cadenceDeReprise, (_) => unawaited(_reessayer()));
  }

  @override
  void dispose() {
    _reprise?.cancel();
    super.dispose();
  }

  Future<void> _reessayer() async {
    if (_enCours || !mounted) return;
    setState(() => _enCours = true);
    try {
      await context.read<AppService>().reprendreLaSession();
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 64, color: theme.colorScheme.outline),
              const SizedBox(height: 24),
              Text(
                'Pas de connexion',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Votre session est enregistrée sur cet appareil : il n’y a rien '
                'à ressaisir. Dès que le réseau revient, vos courses '
                's’affichent — nous réessayons toutes les dix secondes.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _enCours ? null : () => unawaited(_reessayer()),
                icon: _enCours
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
                label: Text(_enCours ? 'Connexion…' : 'Réessayer maintenant'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

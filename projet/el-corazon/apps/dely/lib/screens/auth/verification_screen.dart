import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:elcora_dely/presentation/messages_erreur.dart';
import 'package:elcora_dely/services/app_service.dart';
import 'package:elcora_dely/widgets/code_input_field.dart';
import 'package:elcora_dely/widgets/custom_button.dart';

/// Saisie du code reçu par courriel — l'étape qui ouvre la session.
///
/// ## Pourquoi « votre adresse » et non « votre numéro »
///
/// Le code part par **courriel**, parce que c'est le seul canal dont ce backend
/// dispose réellement (`EMAIL_BACKEND` ; aucun opérateur SMS n'est configuré).
/// Écrire « vérifiez votre numéro » devant un code que personne ne recevrait
/// jamais serait la pire des deux options : le livreur attendrait un SMS qui
/// n'existe pas, et conclurait que l'application est cassée.
///
/// ## Ce que cet écran ne décide pas
///
/// Rien. Le compte n'est vérifié que lorsque le serveur le dit — c'est lui qui
/// pose `email_verified_at`, et c'est le couple de jetons rendu par
/// `POST /auth/verify/` qui ouvre la session. Cet écran n'a aucun moyen de
/// « passer outre », et c'est délibéré : `POST /delivery/apply/` ne rend aucun
/// jeton, il n'y a donc rien à sauter.
class VerificationScreen extends StatefulWidget {
  const VerificationScreen({required this.email, super.key, this.challenge, this.onChangeEmail});

  /// Adresse à laquelle le code a été envoyé.
  final String email;

  /// Ce que le serveur a répondu à l'émission — longueur du code, péremption,
  /// délai avant renvoi. Nul quand l'écran est atteint autrement que par une
  /// candidature (une session restaurée dont l'adresse n'est pas vérifiée, par
  /// exemple) : le compte à rebours démarre alors à zéro, un renvoi immédiat
  /// est possible, et c'est la réponse du serveur qui le recalera.
  final eccore.VerificationChallenge? challenge;

  /// Comment revenir en arrière pour corriger l'adresse. Nul quand il n'y a
  /// nulle part où revenir — l'écran est alors la racine, et n'affiche pas de
  /// bouton qui ne mènerait à rien.
  final VoidCallback? onChangeEmail;

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _codeKey = GlobalKey<CodeInputFieldState>();

  late int _longueurCode;
  late int _secondesAvantRenvoi;
  DateTime? _expiration;

  Timer? _compteARebours;
  bool _enVerification = false;
  bool _enRenvoi = false;
  String? _erreur;
  String? _succes;

  @override
  void initState() {
    super.initState();
    _longueurCode = widget.challenge?.codeLength ?? 6;
    _expiration = widget.challenge?.expiresAt;
    _demarrerCompteARebours(widget.challenge?.retryAfter ?? 0);
  }

  @override
  void dispose() {
    _compteARebours?.cancel();
    super.dispose();
  }

  /// Le compte à rebours suit la valeur **du serveur**.
  ///
  /// Une constante locale finirait par proposer « Renvoyer » à un moment où le
  /// serveur refuse encore : le délai de garde vit dans ses réglages
  /// (`ACCOUNT_VERIFICATION_RESEND_COOLDOWN_SECONDS`), et il change sans que
  /// l'application soit redéployée.
  void _demarrerCompteARebours(int secondes) {
    _compteARebours?.cancel();
    setState(() => _secondesAvantRenvoi = secondes);
    if (secondes <= 0) return;

    _compteARebours = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _secondesAvantRenvoi -= 1);
      if (_secondesAvantRenvoi <= 0) timer.cancel();
    });
  }

  Future<void> _valider(String code) async {
    if (_enVerification) return;
    setState(() {
      _enVerification = true;
      _erreur = null;
      _succes = null;
    });

    try {
      await context.read<AppService>().verifierCompte(email: widget.email, code: code);
      // Aucune navigation ici : `DriverGate` écoute la session et remplace
      // l'écran de lui-même. Pousser une route en plus laisserait cet écran
      // dans la pile, atteignable par le bouton retour d'un compte désormais
      // connecté.
    } catch (erreur) {
      if (!mounted) return;
      setState(() => _erreur = messageErreur(erreur));
      _codeKey.currentState?.clear();
    } finally {
      if (mounted) setState(() => _enVerification = false);
    }
  }

  Future<void> _renvoyer() async {
    if (_enRenvoi || _secondesAvantRenvoi > 0) return;
    setState(() {
      _enRenvoi = true;
      _erreur = null;
      _succes = null;
    });

    try {
      final challenge = await context.read<AppService>().renvoyerCodeDeVerification(widget.email);
      if (!mounted) return;
      setState(() {
        _longueurCode = challenge.codeLength;
        _expiration = challenge.expiresAt;
        // La phrase vient du serveur : elle dit « si un compte correspond à
        // cette adresse », ce qui est vrai dans les deux cas. L'application ne
        // doit rien affirmer de plus — le serveur s'interdit de dire si le
        // compte existe, et le déduire à sa place annulerait la précaution.
        _succes = challenge.detail;
      });
      _codeKey.currentState?.clear();
      _demarrerCompteARebours(challenge.retryAfter);
    } catch (erreur) {
      if (!mounted) return;
      setState(() => _erreur = messageErreur(erreur));
    } finally {
      if (mounted) setState(() => _enRenvoi = false);
    }
  }

  String get _libelleRenvoi => _secondesAvantRenvoi > 0
      ? 'Renvoyer le code dans ${_secondesAvantRenvoi}s'
      : 'Renvoyer le code';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vérifiez votre adresse'),
        leading: widget.onChangeEmail == null
            ? null
            : IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onChangeEmail),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Icon(Icons.mark_email_unread_outlined, size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 24),
              Text(
                'Un code de vérification vous a été envoyé.',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.email,
                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Regardez aussi dans vos courriers indésirables.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              CodeInputField(
                key: _codeKey,
                length: _longueurCode,
                enabled: !_enVerification,
                hasError: _erreur != null,
                onChanged: (_) {
                  if (_erreur != null) setState(() => _erreur = null);
                },
                onCompleted: _valider,
              ),

              if (_expiration != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Ce code expire à ${_heure(_expiration!)}.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              if (_erreur != null) ...[
                const SizedBox(height: 16),
                _Bandeau(
                  texte: _erreur!,
                  couleur: theme.colorScheme.error,
                  icone: Icons.error_outline,
                ),
              ],
              if (_succes != null) ...[
                const SizedBox(height: 16),
                _Bandeau(
                  texte: _succes!,
                  couleur: theme.colorScheme.primary,
                  icone: Icons.mark_email_read_outlined,
                ),
              ],

              const SizedBox(height: 24),
              // Le bouton reste offert alors que la validation part toute
              // seule : l'envoi automatique échoue parfois (réseau), et il faut
              // pouvoir réessayer sans retaper les six chiffres.
              CustomButton(
                text: 'Valider',
                isLoading: _enVerification,
                icon: Icons.check_circle_outline,
                onPressed: () {
                  final code = _codeKey.currentState?.value ?? '';
                  if (code.length != _longueurCode) {
                    setState(() => _erreur = 'Saisissez les $_longueurCode chiffres du code.');
                    return;
                  }
                  unawaited(_valider(code));
                },
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _secondesAvantRenvoi > 0 || _enRenvoi ? null : _renvoyer,
                icon: _enRenvoi
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(_libelleRenvoi),
              ),
              if (widget.onChangeEmail != null)
                TextButton(
                  onPressed: widget.onChangeEmail,
                  child: const Text('Modifier l\'adresse'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _heure(DateTime instant) {
    final local = instant.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

/// Message d'état sous la grille de saisie — succès comme échec.
///
/// Un `SnackBar` disparaîtrait au bout de quelques secondes, c'est-à-dire
/// pendant que le livreur bascule vers son application de courriel pour lire le
/// code. Le message doit être encore là quand il revient.
class _Bandeau extends StatelessWidget {
  const _Bandeau({required this.texte, required this.couleur, required this.icone});

  final String texte;
  final Color couleur;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: couleur.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: couleur, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texte,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: couleur),
            ),
          ),
        ],
      ),
    );
  }
}

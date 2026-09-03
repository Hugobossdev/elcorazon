import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:elcora_dely/presentation/messages_erreur.dart';
import 'package:elcora_dely/services/app_service.dart';
import 'package:elcora_dely/utils/validators.dart';
import 'package:elcora_dely/widgets/code_input_field.dart';
import 'package:elcora_dely/widgets/custom_button.dart';
import 'package:elcora_dely/widgets/custom_text_field.dart';

/// Mot de passe oublié — adresse, code reçu, nouveau mot de passe.
///
/// ## Trois étapes, un seul écran
///
/// Trois routes empilées obligeraient à porter l'adresse et le code de l'une à
/// l'autre, et un retour en arrière au milieu laisserait un code émis sans
/// destination. Ici l'état vit à un seul endroit, et le bouton retour du
/// système ferme le parcours entier — ce qui est la bonne chose : un parcours
/// de reprise à moitié fait ne vaut rien.
///
/// ## Ce que le serveur refuse de dire
///
/// La demande de code répond **202 même pour une adresse inconnue**. L'écran
/// affiche donc la phrase du serveur — « si un compte correspond à cette
/// adresse… » — et n'annonce jamais « adresse inconnue » : le serveur s'interdit
/// de le dire pour ne pas devenir un annuaire d'abonnés, et le déduire à sa
/// place annulerait la précaution.
///
/// ## Un mot de passe refusé ne brûle pas le code
///
/// Le serveur ne consomme le code qu'une fois le mot de passe accepté par ses
/// validateurs. Un mot de passe trop faible renvoie donc à l'étape 3 avec le
/// même code encore valable — sans redemander d'envoi.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.email});

  /// Adresse pré-remplie, reprise de l'écran de connexion quand le livreur y
  /// avait déjà tapé la sienne.
  final String? email;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

enum _Etape { adresse, code, motDePasse }

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _adresseKey = GlobalKey<FormState>();
  final _motDePasseKey = GlobalKey<FormState>();
  final _codeKey = GlobalKey<CodeInputFieldState>();

  late final TextEditingController _email = TextEditingController(text: widget.email ?? '');
  final _nouveau = TextEditingController();
  final _confirmation = TextEditingController();

  _Etape _etape = _Etape.adresse;
  eccore.VerificationChallenge? _challenge;
  String _code = '';

  Timer? _compteARebours;
  int _secondesAvantRenvoi = 0;
  bool _enCours = false;
  String? _erreur;
  String? _info;

  @override
  void dispose() {
    _compteARebours?.cancel();
    _email.dispose();
    _nouveau.dispose();
    _confirmation.dispose();
    super.dispose();
  }

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

  Future<void> _demanderCode() async {
    if (_enCours) return;
    if (!_adresseKey.currentState!.validate()) return;

    setState(() {
      _enCours = true;
      _erreur = null;
      _info = null;
    });
    try {
      final challenge = await context.read<AppService>().demanderReinitialisation(
        _email.text.trim().toLowerCase(),
      );
      if (!mounted) return;
      setState(() {
        _challenge = challenge;
        _info = challenge.detail;
        _etape = _Etape.code;
      });
      _demarrerCompteARebours(challenge.retryAfter);
    } catch (erreur) {
      if (!mounted) return;
      setState(() => _erreur = messageErreur(erreur));
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  /// Passe à l'étape du mot de passe **sans appeler le serveur**.
  ///
  /// Il n'existe pas de route qui dirait « ce code est bon » sans rien en
  /// faire, et c'est cohérent : un code se présente une fois, avec l'effet
  /// qu'on en attend. La validité est donc éprouvée à l'étape suivante, en même
  /// temps que le mot de passe — et un code faux y renvoie à cette étape-ci.
  void _codeSaisi(String code) {
    setState(() {
      _code = code;
      _erreur = null;
      _info = null;
      _etape = _Etape.motDePasse;
    });
  }

  Future<void> _reposerLeMotDePasse() async {
    if (_enCours) return;
    if (!_motDePasseKey.currentState!.validate()) return;

    setState(() {
      _enCours = true;
      _erreur = null;
    });
    try {
      await context.read<AppService>().reinitialiserMotDePasse(
        email: _email.text.trim().toLowerCase(),
        code: _code,
        nouveauMotDePasse: _nouveau.text,
      );
      // La session est ouverte et `DriverGate` prend la main : rien à pousser
      // ici. Le parcours se referme de lui-même quand cet écran quitte la pile.
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on eccore.ApiException catch (erreur) {
      if (!mounted) return;
      setState(() {
        _erreur = messageErreur(erreur);
        // Un code refusé renvoie à sa saisie ; un mot de passe refusé laisse
        // sur place, le code étant intact côté serveur.
        if (erreur.code == 'invalid_verification_code') {
          _etape = _Etape.code;
          _code = '';
          _codeKey.currentState?.clear();
        }
      });
    } catch (erreur) {
      if (!mounted) return;
      setState(() => _erreur = messageErreur(erreur));
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mot de passe oublié'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _enCours ? null : _reculer,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Progression(etape: _etape),
              const SizedBox(height: 28),
              switch (_etape) {
                _Etape.adresse => _formulaireAdresse(),
                _Etape.code => _formulaireCode(),
                _Etape.motDePasse => _formulaireMotDePasse(),
              },
              if (_erreur != null) ...[
                const SizedBox(height: 20),
                _Message(texte: _erreur!, erreur: true),
              ],
              if (_info != null) ...[
                const SizedBox(height: 20),
                _Message(texte: _info!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _reculer() {
    switch (_etape) {
      case _Etape.adresse:
        Navigator.of(context).pop();
      case _Etape.code:
        setState(() {
          _etape = _Etape.adresse;
          _erreur = null;
          _info = null;
        });
      case _Etape.motDePasse:
        setState(() {
          _etape = _Etape.code;
          _erreur = null;
        });
    }
  }

  Widget _formulaireAdresse() {
    return Form(
      key: _adresseKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Saisissez l\'adresse de votre compte. Nous vous enverrons un code '
            'pour choisir un nouveau mot de passe.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          CustomTextField(
            label: 'Adresse e-mail',
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.email_outlined,
            enabled: !_enCours,
            validator: Validators.validateEmail,
          ),
          const SizedBox(height: 28),
          CustomButton(
            text: 'Envoyer le code',
            isLoading: _enCours,
            icon: Icons.send_outlined,
            onPressed: _demanderCode,
          ),
        ],
      ),
    );
  }

  Widget _formulaireCode() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Saisissez le code envoyé à', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text(
          _email.text.trim().toLowerCase(),
          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        CodeInputField(
          key: _codeKey,
          length: _challenge?.codeLength ?? 6,
          enabled: !_enCours,
          hasError: _erreur != null,
          onChanged: (_) {
            if (_erreur != null) setState(() => _erreur = null);
          },
          onCompleted: _codeSaisi,
        ),
        const SizedBox(height: 20),
        TextButton.icon(
          onPressed: _secondesAvantRenvoi > 0 || _enCours ? null : _demanderCode,
          icon: const Icon(Icons.refresh),
          label: Text(
            _secondesAvantRenvoi > 0
                ? 'Renvoyer le code dans ${_secondesAvantRenvoi}s'
                : 'Renvoyer le code',
          ),
        ),
      ],
    );
  }

  Widget _formulaireMotDePasse() {
    return Form(
      key: _motDePasseKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Choisissez un nouveau mot de passe. Vos autres appareils seront '
            'déconnectés.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          CustomTextField(
            label: 'Nouveau mot de passe',
            controller: _nouveau,
            isPassword: true,
            prefixIcon: Icons.lock_outline,
            enabled: !_enCours,
            validator: Validators.validateStrongPassword,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            label: 'Confirmez le mot de passe',
            controller: _confirmation,
            isPassword: true,
            prefixIcon: Icons.lock_reset_outlined,
            enabled: !_enCours,
            validator: (value) =>
                Validators.validatePasswordConfirmation(value, _nouveau.text),
          ),
          const SizedBox(height: 28),
          CustomButton(
            text: 'Enregistrer et me connecter',
            isLoading: _enCours,
            icon: Icons.check_circle_outline,
            onPressed: _reposerLeMotDePasse,
          ),
        ],
      ),
    );
  }
}

class _Progression extends StatelessWidget {
  const _Progression({required this.etape});

  final _Etape etape;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const libelles = ['Adresse', 'Code', 'Mot de passe'];

    return Row(
      children: [
        for (var i = 0; i < libelles.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= etape.index
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  libelles[i],
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: i <= etape.index
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontWeight: i == etape.index ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          if (i < libelles.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.texte, this.erreur = false});

  final String texte;
  final bool erreur;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final couleur = erreur ? theme.colorScheme.error : theme.colorScheme.primary;

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
          Icon(erreur ? Icons.error_outline : Icons.info_outline, color: couleur, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(texte, style: theme.textTheme.bodyMedium?.copyWith(color: couleur)),
          ),
        ],
      ),
    );
  }
}

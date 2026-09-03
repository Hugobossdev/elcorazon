import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_dely/l10n/app_localizations.dart';
import 'package:elcora_dely/screens/auth/driver_register_screen.dart';
import 'package:elcora_dely/screens/auth/forgot_password_screen.dart';
import 'package:elcora_dely/services/app_service.dart';
import 'package:elcora_dely/utils/validators.dart';
import 'package:elcora_dely/widgets/custom_button.dart';
import 'package:elcora_dely/widgets/custom_text_field.dart';
import 'package:elcora_dely/widgets/el_corazon_logo.dart';
import 'package:elcora_dely/presentation/messages_erreur.dart';

/// Connexion du livreur, et les deux portes qui en partent : créer un compte,
/// et reprendre la main sur un mot de passe oublié.
///
/// ## Ce qui a changé, et pourquoi
///
/// Cet écran affichait « Pour devenir livreur, contactez El Corazón » : le
/// backend n'avait alors aucune route de création de compte livreur, et
/// inventer un formulaire devant une API inexistante aurait été pire que le
/// message. La route existe désormais (`POST /delivery/apply/`) et crée un
/// dossier **en attente d'instruction** — l'équipe lit toujours les pièces,
/// c'est le formulaire de dépôt qui a changé de main.
///
/// ## Un compte non vérifié se connecte quand même
///
/// Le serveur accepte le mot de passe d'un compte dont l'adresse n'est pas
/// prouvée, et il a raison : ce sont des identifiants corrects, et répondre
/// « identifiants invalides » enverrait le livreur les retaper indéfiniment.
/// C'est [DriverGate] qui l'oriente ensuite vers la saisie du code — cet écran
/// n'a donc rien de particulier à faire de ce cas, et c'est précisément le but
/// d'avoir une seule porte.
class DriverAuthScreen extends StatefulWidget {
  const DriverAuthScreen({super.key});

  @override
  State<DriverAuthScreen> createState() => _DriverAuthScreenState();
}

class _DriverAuthScreenState extends State<DriverAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _erreur;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isLoading) return;
    setState(() => _erreur = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await context.read<AppService>().loginDriver(
        _emailController.text.trim().toLowerCase(),
        _passwordController.text,
      );
      // Aucune navigation : `DriverGate` écoute la session et remplace l'écran
      // de lui-même — vers l'accueil, la saisie du code ou le mur du compte
      // suspendu, selon ce que le serveur vient de rendre. Pousser
      // `/delivery-home` ici court-circuiterait cette décision.
    } catch (erreur) {
      if (!mounted) return;
      setState(() => _erreur = messageErreur(erreur));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // Repli si l10n est nul (ne devrait pas arriver si la configuration est
    // correcte).
    if (l10n == null) return const SizedBox.shrink();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),

              Column(
                children: [
                  const ElCorazonLogo(size: 120, showText: false),
                  const SizedBox(height: 24),
                  Text(
                    l10n.appTitle,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.loginTitle,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),

              const SizedBox(height: 48),

              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CustomTextField(
                      label: l10n.email,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.email_outlined,
                      enabled: !_isLoading,
                      validator: Validators.validateEmail,
                    ),
                    const SizedBox(height: 16),
                    // `CustomTextField` et non un `TextField` nu : le champ de
                    // mot de passe de cet écran n'avait ni validateur, ni
                    // libellé aligné sur les autres. Un formulaire dont un seul
                    // champ ne se valide pas laisse partir une requête vide,
                    // qui revient en 400.
                    CustomTextField(
                      label: l10n.password,
                      controller: _passwordController,
                      isPassword: true,
                      prefixIcon: Icons.lock_outline,
                      enabled: !_isLoading,
                      validator: (value) =>
                          Validators.validateRequired(value, 'votre mot de passe'),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading ? null : _ouvrirMotDePasseOublie,
                        child: const Text('Mot de passe oublié ?'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    CustomButton(
                      text: l10n.loginButton,
                      isLoading: _isLoading,
                      onPressed: _login,
                      icon: Icons.login,
                    ),
                  ],
                ),
              ),

              if (_erreur != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _erreur!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),

              Text(
                'Pas encore livreur chez El Corazón ?',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              CustomButton(
                text: 'Créer mon compte',
                outlined: true,
                icon: Icons.person_add_alt_1,
                onPressed: _isLoading ? null : _ouvrirInscription,
              ),
              const SizedBox(height: 12),
              Text(
                'Votre dossier — permis, pièce d\'identité, véhicule — est '
                'vérifié par notre équipe avant votre première course.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _ouvrirInscription() {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const DriverRegisterScreen()),
      ),
    );
  }

  void _ouvrirMotDePasseOublie() {
    final saisie = _emailController.text.trim();
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          // L'adresse déjà tapée est reprise : la retaper est le genre de
          // frottement qui fait abandonner un parcours de reprise.
          builder: (_) => ForgotPasswordScreen(email: saisie.isEmpty ? null : saisie),
        ),
      ),
    );
  }
}

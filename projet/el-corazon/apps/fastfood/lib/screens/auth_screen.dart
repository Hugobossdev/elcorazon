import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/navigation/navigation_service.dart';
import 'package:elcora_fast/widgets/navigation_error_handler.dart';
import 'package:elcora_fast/widgets/design/design.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/utils/input_sanitizer.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

/// Connexion et inscription.
///
/// ## Ce que la maquette change
///
/// `onboarding_create_account` pose l'écran sur le **fond clair** du design
/// system, avec le logo en tête et des champs posés à plat. La version
/// précédente peignait tout l'écran d'un dégradé rouge et posait dessus une
/// carte blanche : le rouge de marque, que `DESIGN.md` réserve aux actions et
/// aux bannières, occupait ici la totalité de la première impression.
///
/// ## Un lien plutôt que deux onglets
///
/// La bascule connexion / inscription était une paire d'onglets en tête de
/// carte. La maquette la met en **bas**, en une phrase — « Already have an
/// account? Log In ». C'est mieux placé : on choisit ce qu'on vient faire une
/// fois, au début, et le reste du temps l'onglet inutile occupe le haut de
/// l'écran, juste au-dessus du champ qu'on veut atteindre.
///
/// ## Ce qui n'est pas dessiné
///
/// Ni Google, ni Apple, ni « mot de passe oublié » : aucun des trois n'a
/// d'équivalent côté Django (Phase 6). Voir BR-001 de
/// `docs/STITCH_BACKEND_REQUIREMENTS.md`.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _isLoading = false;
  bool _motDePasseVisible = false;
  bool _confirmationVisible = false;

  /// Numéro complet, indicatif compris, tel qu'`IntlPhoneField` le compose.
  String _fullPhoneNumber = '';

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  /// Côte d'Ivoire, et non le Togo comme auparavant : l'établissement est à
  /// Abidjan, et `EditProfileDialog` proposait déjà `CI`. Deux indicatifs par
  /// défaut différents dans la même application faisaient saisir un numéro
  /// togolais à l'inscription, ivoirien à la modification.
  static const String _indicatifParDefaut = 'CI';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _basculer() {
    setState(() {
      _isLogin = !_isLogin;
      // Les messages de validation du mode précédent n'ont plus de sens :
      // « Confirmez votre mot de passe » n'a rien à reprocher à une connexion.
      _formKey.currentState?.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              DesignConstants.edgeMargin,
              DesignConstants.spacingL,
              DesignConstants.edgeMargin,
              DesignConstants.spacingXL,
            ),
            child: ConstrainedBox(
              // Sur tablette et navigateur, un formulaire étiré sur 1 200 px
              // devient illisible : l'œil perd la ligne entre le libellé et le
              // champ.
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _enTete(theme),
                  const SizedBox(height: DesignConstants.spacingXL),
                  _formulaire(theme),
                  const SizedBox(height: DesignConstants.spacingL),
                  _bascule(theme),
                  const SizedBox(height: DesignConstants.spacingM),
                  _mentionsLegales(theme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _enTete(ThemeData theme) {
    return Column(
      children: [
        Image.asset(
          'assets/logo/logo.png',
          height: 88,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.restaurant_rounded,
            size: 72,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: DesignConstants.spacingM),
        Text(
          'El Corazón',
          textAlign: TextAlign.center,
          style: AppTypography.headlineMd(color: theme.colorScheme.primary)
              .copyWith(fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: DesignConstants.spacingL),
        Text(
          _isLogin ? 'Content de vous revoir.' : 'Rejoignez la table.',
          textAlign: TextAlign.center,
          style: AppTypography.headlineSm(color: theme.colorScheme.onSurface),
        ),
        const SizedBox(height: DesignConstants.spacingS),
        Text(
          _isLogin
              ? 'Connectez-vous pour retrouver vos commandes et vos adresses.'
              : 'Créez votre compte pour commander les saveurs grillées '
                  'd’Abidjan.',
          textAlign: TextAlign.center,
          style: AppTypography.bodyMd(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _formulaire(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_isLogin) ...[
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nom complet',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: _validerNom,
            ),
            const SizedBox(height: DesignConstants.spacingM),
            _champTelephone(theme),
            const SizedBox(height: DesignConstants.spacingM),
          ],
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Adresse e-mail',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
            validator: _validerEmail,
          ),
          const SizedBox(height: DesignConstants.spacingM),
          TextFormField(
            controller: _passwordController,
            obscureText: !_motDePasseVisible,
            textInputAction:
                _isLogin ? TextInputAction.done : TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Mot de passe',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              // La maquette montre l'œil barré : sans lui, un mot de passe
              // fort — majuscule, chiffre, caractère spécial — se saisit à
              // l'aveugle sur un clavier de téléphone.
              suffixIcon: _oeil(
                visible: _motDePasseVisible,
                onTap: () => setState(
                  () => _motDePasseVisible = !_motDePasseVisible,
                ),
              ),
            ),
            validator: _validerMotDePasse,
            onFieldSubmitted: _isLogin ? (_) => _handleAuth() : null,
          ),
          if (!_isLogin) ...[
            const SizedBox(height: DesignConstants.spacingM),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: !_confirmationVisible,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Confirmer le mot de passe',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: _oeil(
                  visible: _confirmationVisible,
                  onTap: () => setState(
                    () => _confirmationVisible = !_confirmationVisible,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez confirmer votre mot de passe';
                }
                if (value != _passwordController.text) {
                  return 'Les mots de passe ne correspondent pas';
                }
                return null;
              },
              onFieldSubmitted: (_) => _handleAuth(),
            ),
          ],
          const SizedBox(height: DesignConstants.spacingL),
          ActionButton(
            label: _isLogin ? 'Se connecter' : 'Créer mon compte',
            emphasis: ActionEmphasis.gradient,
            trailingIcon: Icons.arrow_forward_rounded,
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _handleAuth,
          ),
        ],
      ),
    );
  }

  Widget _oeil({required bool visible, required VoidCallback onTap}) {
    return IconButton(
      icon: Icon(
        visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      ),
      tooltip: visible ? 'Masquer le mot de passe' : 'Afficher le mot de passe',
      onPressed: onTap,
    );
  }

  Widget _champTelephone(ThemeData theme) {
    return IntlPhoneField(
      controller: _phoneController,
      decoration: const InputDecoration(labelText: 'Téléphone'),
      initialCountryCode: _indicatifParDefaut,
      languageCode: 'fr',
      onChanged: (phone) => _fullPhoneNumber = phone.completeNumber,
      onCountryChanged: (country) {
        _fullPhoneNumber = '+${country.dialCode}${_phoneController.text}';
      },
      validator: (phone) {
        if (phone == null || phone.number.trim().isEmpty) {
          return 'Veuillez entrer votre numéro de téléphone';
        }
        return null; // `IntlPhoneField` valide le format lui-même.
      },
    );
  }

  Widget _bascule(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            _isLogin ? 'Pas encore de compte ?' : 'Vous avez déjà un compte ?',
            style: AppTypography.bodyMd(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        TextButton(
          onPressed: _isLoading ? null : _basculer,
          child: Text(
            _isLogin ? 'S’inscrire' : 'Se connecter',
            style: AppTypography.labelLg(color: theme.colorScheme.primary),
          ),
        ),
      ],
    );
  }

  Widget _mentionsLegales(ThemeData theme) {
    // Les liens de la maquette ne sont pas cliquables : aucun document n'est
    // publié à une adresse stable (BR-013). Un lien qui n'ouvre rien est pire
    // qu'une phrase — celle-ci dit au moins la vérité.
    return Text(
      'En continuant, vous acceptez nos conditions d’utilisation et notre '
      'politique de confidentialité.',
      textAlign: TextAlign.center,
      style: AppTypography.bodyMd(color: theme.colorScheme.onSurfaceVariant),
    );
  }

  // ------------------------------------------------------------ validateurs

  String? _validerNom(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Veuillez entrer votre nom';
    }
    if (value.trim().length < 2) {
      return 'Le nom doit contenir au moins 2 caractères';
    }
    final sanitizeResult =
        InputSanitizer.validateAndSanitize(value, fieldName: 'Nom');
    if (!sanitizeResult.isValid) return sanitizeResult.errorMessage;
    return null;
  }

  String? _validerEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Veuillez entrer votre email';
    }
    final sanitizeResult =
        InputSanitizer.validateAndSanitize(value, fieldName: 'Email');
    if (!sanitizeResult.isValid) return sanitizeResult.errorMessage;
    if (!InputSanitizer.isValidEmailSafe(value.trim())) {
      return 'Veuillez entrer un email valide';
    }
    return null;
  }

  /// Exigences de mot de passe.
  ///
  /// **En connexion, la vérification reste légère** : le mot de passe a été
  /// choisi sous des règles peut-être antérieures, et refuser localement une
  /// saisie que le serveur accepterait enfermerait dehors un client existant.
  /// À l'inscription, les règles sont celles du serveur.
  String? _validerMotDePasse(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez entrer votre mot de passe';
    }

    if (_isLogin) {
      if (value.length < 6) {
        return 'Le mot de passe doit contenir au moins 6 caractères';
      }
      return null;
    }

    if (value.length < 8) {
      return 'Le mot de passe doit contenir au moins 8 caractères';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Le mot de passe doit contenir au moins une majuscule';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Le mot de passe doit contenir au moins un chiffre';
    }
    if (!RegExp(r'[!@#%^&*()\-_=+\[\]{};:,.<>?/|~`]').hasMatch(value)) {
      return 'Le mot de passe doit contenir au moins un caractère spécial '
          '(!@#%…)';
    }
    return null;
  }

  // --------------------------------------------------------------- soumission

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final appService = Provider.of<AppService>(context, listen: false);

      if (_isLogin) {
        await appService.login(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        // Le numéro complet, indicatif compris.
        final phoneToRegister = _fullPhoneNumber.isNotEmpty
            ? _fullPhoneNumber
            : _phoneController.text.trim();
        final success = await appService.register(
          _nameController.text.trim(),
          _emailController.text.trim(),
          phoneToRegister,
          _passwordController.text,
        );

        if (!success) {
          throw Exception(
            'Impossible de créer votre compte. Veuillez réessayer plus tard.',
          );
        }
      }

      if (mounted) {
        final user = appService.currentUser!;
        try {
          NavigationService.navigateBasedOnRole(context, user);
        } catch (e) {
          NavigationErrorHandler.handleNavigationError(
            context,
            e.toString(),
            user,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        // `ApiException` porte le message serveur (RFC 9457, ADR-009) — le
        // reste (garde de rôle, panne réseau) retombe sur `toString()`.
        final message = e is ApiException
            ? e.detail
            : e.toString().replaceFirst('Exception: ', '');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

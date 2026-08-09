import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/navigation/navigation_service.dart';
import 'package:elcora_fast/widgets/navigation_error_handler.dart';
import 'package:elcora_fast/widgets/auth_style_text_field.dart';
import 'package:elcora_fast/widgets/auth_style_button.dart';
import 'package:elcora_fast/widgets/auth_style_card.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/utils/input_sanitizer.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  bool _isLogin = true;
  bool _isLoading = false;

  // Stocke le numéro de téléphone complet (avec indicatif pays) lors de l'inscription
  String _fullPhoneNumber = '';

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  final String _initialCountryCode = 'TG';

  late AnimationController _animationController;
  late AnimationController _logoAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: DesignConstants.animationExtraSlow,
      vsync: this,
    );

    _logoAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _logoScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _logoAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    _logoRotationAnimation = Tween<double>(
      begin: -0.1,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _logoAnimationController,
        curve: Curves.easeOut,
      ),
    );

    _logoAnimationController.forward();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _logoAnimationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = DesignConstants.isMobile(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.primaryGradient,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isMobile
                  ? DesignConstants.spacingL
                  : DesignConstants.spacingXL,
              vertical: isMobile
                  ? DesignConstants.spacingM
                  : DesignConstants.spacingL,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: screenHeight -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: isMobile
                            ? DesignConstants.spacingL
                            : DesignConstants.spacingXL,
                      ),
                      _buildLogo(),
                      SizedBox(
                        height: isMobile
                            ? DesignConstants.spacingL
                            : DesignConstants.spacingXL,
                      ),
                      _buildAuthCard(),
                      SizedBox(
                        height: isMobile
                            ? DesignConstants.spacingM
                            : DesignConstants.spacingL,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return ScaleTransition(
      scale: _logoScaleAnimation,
      child: RotationTransition(
        turns: _logoRotationAnimation,
        child: Column(
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 30,
                    spreadRadius: 3,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 20,
                    spreadRadius: -5,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/logo/logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: AppColors.primaryGradient,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 4,
                        ),
                      ),
                      child: const Icon(
                        Icons.restaurant_rounded,
                        size: 70,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: DesignConstants.spacingM),
            Text(
              'El Corazón',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: DesignConstants.spacingXS),
            Text(
              'Authentification',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w500,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthCard() {
    return AnimatedSwitcher(
      duration: DesignConstants.animationNormal,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.1),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: AuthStyleCard(
        key: ValueKey(_isLogin),
        padding:
            EdgeInsets.all(DesignConstants.isMobile(context) ? 20.0 : 28.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTabSelector(),
              SizedBox(height: DesignConstants.isMobile(context) ? 24 : 32),
              AnimatedSize(
                duration: DesignConstants.animationNormal,
                curve: Curves.easeInOut,
                child: Column(
                  children: [
                    if (!_isLogin) ...[
                      AuthStyleTextField(
                        controller: _nameController,
                        label: 'Nom complet',
                        icon: Icons.person_outline,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Veuillez entrer votre nom';
                          }
                          if (value.trim().length < 2) {
                            return 'Le nom doit contenir au moins 2 caractères';
                          }
                          // 🛡️ Protection contre les injections SQL et XSS
                          final sanitizeResult =
                              InputSanitizer.validateAndSanitize(
                            value,
                            fieldName: 'Nom',
                          );
                          if (!sanitizeResult.isValid) {
                            return sanitizeResult.errorMessage;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: DesignConstants.spacingM),
                      _buildPhoneField(),
                      const SizedBox(height: DesignConstants.spacingM),
                    ],
                  ],
                ),
              ),
              AuthStyleTextField(
                controller: _emailController,
                label: 'Email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Veuillez entrer votre email';
                  }
                  // 🛡️ Protection contre les injections SQL et XSS
                  final sanitizeResult = InputSanitizer.validateAndSanitize(
                    value,
                    fieldName: 'Email',
                  );
                  if (!sanitizeResult.isValid) {
                    return sanitizeResult.errorMessage;
                  }
                  // Valider le format email
                  if (!InputSanitizer.isValidEmailSafe(value.trim())) {
                    return 'Veuillez entrer un email valide';
                  }
                  return null;
                },
              ),
              const SizedBox(height: DesignConstants.spacingM),
              AuthStyleTextField(
                controller: _passwordController,
                label: 'Mot de passe',
                icon: Icons.lock_outline,
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer votre mot de passe';
                  }
                  // En connexion : vérification légère (le serveur valide le reste)
                  if (_isLogin) {
                    if (value.length < 6) {
                      return 'Le mot de passe doit contenir au moins 6 caractères';
                    }
                    return null;
                  }
                  // En inscription : robustesse renforcée basée sur les contraintes DB
                  if (value.length < 8) {
                    return 'Le mot de passe doit contenir au moins 8 caractères';
                  }
                  if (!RegExp(r'[A-Z]').hasMatch(value)) {
                    return 'Le mot de passe doit contenir au moins une majuscule';
                  }
                  if (!RegExp(r'[0-9]').hasMatch(value)) {
                    return 'Le mot de passe doit contenir au moins un chiffre';
                  }
                  if (!RegExp(r'[!@#%^&*()\-_=+\[\]{};:,.<>?/|~`]')
                      .hasMatch(value)) {
                    return 'Le mot de passe doit contenir au moins un caractère spécial (!@#%...)';
                  }
                  return null;
                },
              ),
              AnimatedSize(
                duration: DesignConstants.animationNormal,
                curve: Curves.easeInOut,
                child: Column(
                  children: [
                    if (!_isLogin) ...[
                      const SizedBox(height: DesignConstants.spacingM),
                      AuthStyleTextField(
                        controller: _confirmPasswordController,
                        label: 'Confirmer le mot de passe',
                        icon: Icons.lock_outline,
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez confirmer votre mot de passe';
                          }
                          if (value != _passwordController.text) {
                            return 'Les mots de passe ne correspondent pas';
                          }
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: DesignConstants.isMobile(context) ? 24 : 32),
              AuthStyleButton(
                text: _isLogin ? 'Se connecter' : 'Créer un compte',
                onPressed: _isLoading ? null : _handleAuth,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DesignConstants.radiusLarge),
        boxShadow: DesignConstants.shadowSoft,
      ),
      child: IntlPhoneField(
        controller: _phoneController,
        decoration: InputDecoration(
          labelText: 'Téléphone',
          labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DesignConstants.radiusLarge),
            borderSide: BorderSide(
              color: AppColors.textTertiary.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DesignConstants.radiusLarge),
            borderSide: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(DesignConstants.radiusLarge),
            borderSide: BorderSide(
              color: Theme.of(context).primaryColor,
              width: 2,
            ),
          ),
          filled: true,
          fillColor: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : AppColors.surfaceElevated,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: DesignConstants.spacingL + DesignConstants.spacingXS,
            vertical: DesignConstants.spacingM + DesignConstants.spacingXS,
          ),
        ),
        initialCountryCode: _initialCountryCode,
        languageCode: 'fr',
        // Stocker le numéro complet avec indicatif pays
        onChanged: (phone) {
          _fullPhoneNumber = phone.completeNumber;
        },
        validator: (phone) {
          if (phone == null || phone.number.trim().isEmpty) {
            return 'Veuillez entrer votre numéro de téléphone';
          }
          return null; // IntlPhoneField valide le format automatiquement
        },
        onCountryChanged: (country) {
          _fullPhoneNumber = '+${country.dialCode}${_phoneController.text}';
        },
      ),
    );
  }

  // La connexion/inscription téléphone+OTP, Google et « mot de passe oublié »
  // n'ont pas d'équivalent côté backend Django (Phase 6) — voir
  // `docs/architecture/04-migration-flutter.md`. Les méthodes correspondantes
  // de `DatabaseService` restent en place (inertes), seuls leurs déclencheurs
  // dans cet écran ont été retirés.

  Widget _buildTabSelector() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest
            : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(DesignConstants.radiusLarge),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.2),
        ),
        boxShadow: DesignConstants.shadowSoft,
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!_isLogin) {
                  setState(() => _isLogin = true);
                }
              },
              child: AnimatedContainer(
                duration: DesignConstants.animationNormal,
                curve: DesignConstants.curveStandard,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: _isLogin
                      ? const LinearGradient(
                          colors: AppColors.primaryGradient,
                        )
                      : null,
                  color: _isLogin ? null : Colors.transparent,
                  borderRadius: DesignConstants.borderRadiusMedium,
                  boxShadow: _isLogin ? DesignConstants.shadowPrimary : null,
                ),
                child: Text(
                  'Connexion',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: _isLogin
                        ? AppColors.textLight
                        : theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_isLogin) {
                  setState(() => _isLogin = false);
                }
              },
              child: AnimatedContainer(
                duration: DesignConstants.animationNormal,
                curve: DesignConstants.curveStandard,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: !_isLogin
                      ? const LinearGradient(
                          colors: AppColors.primaryGradient,
                        )
                      : null,
                  color: !_isLogin ? null : Colors.transparent,
                  borderRadius: DesignConstants.borderRadiusMedium,
                  boxShadow: !_isLogin ? DesignConstants.shadowPrimary : null,
                ),
                child: Text(
                  'Inscription',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: !_isLogin
                        ? AppColors.textLight
                        : theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
        // Utiliser le numéro complet avec indicatif pays
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

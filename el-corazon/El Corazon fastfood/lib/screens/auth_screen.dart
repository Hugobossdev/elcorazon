import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/services/database_service.dart';
import 'package:elcora_fast/navigation/navigation_service.dart';
import 'package:elcora_fast/navigation/app_router.dart';
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
              SizedBox(height: DesignConstants.isMobile(context) ? 20 : 24),
              _buildDivider(),
              SizedBox(height: DesignConstants.isMobile(context) ? 20 : 24),
              _buildSocialAuthButtons(),
              if (_isLogin) ...[
                const SizedBox(height: DesignConstants.spacingM),
                _buildForgotPasswordButton(),
              ],
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

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Divider(
            thickness: 1,
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignConstants.spacingM,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignConstants.spacingM + DesignConstants.spacingXS,
              vertical: DesignConstants.spacingXS,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : AppColors.surfaceVariant,
              borderRadius: DesignConstants.borderRadiusSmall,
            ),
            child: Text(
              'OU',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
            ),
          ),
        ),
        Expanded(
          child: Divider(
            thickness: 1,
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialAuthButtons() {
    return Column(
      children: [
        _buildPhoneAuthButton(),
        const SizedBox(
          height: DesignConstants.spacingM + DesignConstants.spacingXS,
        ),
        _buildGoogleAuthButton(),
      ],
    );
  }

  Widget _buildPhoneAuthButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _handlePhoneAuth,
        borderRadius: BorderRadius.circular(DesignConstants.radiusLarge),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: DesignConstants.spacingM,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(DesignConstants.radiusLarge),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: DesignConstants.shadowSoft,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: DesignConstants.paddingS,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: DesignConstants.borderRadiusSmall,
                ),
                child: Icon(
                  Icons.phone_rounded,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(
                width: DesignConstants.spacingM + DesignConstants.spacingXS,
              ),
              Text(
                'Continuer avec le téléphone',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                      letterSpacing: 0.2,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleAuthButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _handleGoogleAuth,
        borderRadius: BorderRadius.circular(DesignConstants.radiusLarge),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: DesignConstants.spacingM,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(DesignConstants.radiusLarge),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: DesignConstants.shadowSoft,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: DesignConstants.paddingS,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: DesignConstants.borderRadiusSmall,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/icons/google.png',
                  width: 20,
                  height: 20,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.g_mobiledata_rounded,
                      color: Color(0xFF4285F4),
                      size: 20,
                    );
                  },
                ),
              ),
              const SizedBox(
                width: DesignConstants.spacingM + DesignConstants.spacingXS,
              ),
              Text(
                'Continuer avec Google',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                      letterSpacing: 0.2,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForgotPasswordButton() {
    return TextButton(
      onPressed: _handleForgotPassword,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      child: Text(
        'Mot de passe oublié ?',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
      ),
    );
  }

  Future<void> _handlePhoneAuth() async {
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignConstants.radiusXLarge),
        ),
        child: Container(
          padding: DesignConstants.paddingL,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(DesignConstants.radiusXLarge),
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Authentification par téléphone',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: DesignConstants.spacingS),
                Text(
                  'Entrez votre numéro de téléphone pour recevoir un code de vérification',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: DesignConstants.spacingL),
                AuthStyleTextField(
                  controller: phoneController,
                  label: 'Numéro de téléphone',
                  hintText: '+225 07 12 34 56 78',
                  icon: Icons.phone_rounded,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Veuillez entrer votre numéro';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: DesignConstants.spacingL),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: DesignConstants.spacingM,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              DesignConstants.radiusLarge,
                            ),
                          ),
                        ),
                        child: Text(
                          'Annuler',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                    ),
                    const SizedBox(
                      width:
                          DesignConstants.spacingM + DesignConstants.spacingXS,
                    ),
                    Expanded(
                      flex: 2,
                      child: AuthStyleButton(
                        text: 'Envoyer le code',
                        onPressed: () {
                          if (formKey.currentState!.validate()) {
                            Navigator.pop(context, phoneController.text);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      // Validation du numéro avant envoi
      if (!InputSanitizer.isValidPhoneSafe(result)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Numéro invalide. Utilisez le format international (ex: +22890123456).',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      setState(() => _isLoading = true);
      try {
        final databaseService = DatabaseService();
        await databaseService.signInWithPhone(result);

        if (mounted) {
          unawaited(
            Navigator.pushReplacementNamed(
              context,
              AppRouter.otpVerification,
              arguments: {'phone': result},
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: ${e.toString()}'),
              backgroundColor: Colors.red,
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

  Future<void> _handleGoogleAuth() async {
    setState(() => _isLoading = true);
    try {
      final databaseService = DatabaseService();
      await databaseService.signInWithGoogle();

      // Note: Google OAuth will redirect to callback URL
      // The auth state will be handled by Supabase auth listener
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignConstants.radiusXLarge),
          ),
          child: Container(
            padding: DesignConstants.paddingL,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(DesignConstants.radiusXLarge),
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: AppColors.primaryGradient,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_reset_rounded,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: DesignConstants.spacingM),
                  Text(
                    'Réinitialiser le mot de passe',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: DesignConstants.spacingS),
                  Text(
                    'Entrez votre adresse email et nous vous enverrons un lien pour réinitialiser votre mot de passe',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: DesignConstants.spacingL),
                  AuthStyleTextField(
                    controller: emailController,
                    label: 'Email',
                    hintText: 'votre@email.com',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !isLoading,
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
                  const SizedBox(height: DesignConstants.spacingL),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: isLoading
                              ? null
                              : () => Navigator.pop(dialogContext),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: DesignConstants.spacingM,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                DesignConstants.radiusLarge,
                              ),
                            ),
                          ),
                          child: Text(
                            'Annuler',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: DesignConstants.spacingM +
                            DesignConstants.spacingXS,
                      ),
                      Expanded(
                        flex: 2,
                        child: AuthStyleButton(
                          text: 'Envoyer le lien',
                          onPressed: isLoading
                              ? null
                              : () async {
                                  if (formKey.currentState!.validate()) {
                                    setState(() => isLoading = true);
                                    try {
                                      final databaseService = DatabaseService();
                                      await databaseService.resetPassword(
                                        emailController.text.trim(),
                                      );

                                      if (context.mounted) {
                                        Navigator.pop(dialogContext);
                                        if (mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.check_circle,
                                                    color: Colors.white,
                                                    size: 20,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      'Email de réinitialisation envoyé avec succès ! Vérifiez votre boîte de réception.',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.copyWith(
                                                            color: Colors.white,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              backgroundColor:
                                                  AppColors.success,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                  DesignConstants.radiusMedium,
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    } catch (e) {
                                      setState(() => isLoading = false);
                                      if (context.mounted && mounted) {
                                        final errorMessage = e
                                                .toString()
                                                .contains('Invalid')
                                            ? 'Adresse email invalide. Veuillez vérifier votre email.'
                                            : e.toString().contains('Network')
                                                ? 'Erreur de connexion. Vérifiez votre connexion internet.'
                                                : 'Une erreur est survenue. Veuillez réessayer plus tard.';

                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Row(
                                              children: [
                                                const Icon(
                                                  Icons.error_outline,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    errorMessage,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodyMedium
                                                        ?.copyWith(
                                                          color: Colors.white,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            backgroundColor: AppColors.error,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                DesignConstants.radiusMedium,
                                              ),
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                          isLoading: isLoading,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

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
        final message = e is AuthException
            ? (e.message.isNotEmpty
                ? e.message
                : 'Identifiants invalides, veuillez réessayer.')
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_dely/l10n/app_localizations.dart';
import '../../services/app_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/el_corazon_logo.dart';

/// Connexion uniquement (Phase 6) : le backend Django n'a aucun endpoint de
/// création de compte livreur — `/api/v1/auth/register/` ne crée que des
/// comptes `customer`, et l'API livraison n'expose la lecture des dossiers
/// livreur que pour le personnel (`StaffCourierViewSet`, lecture seule).
/// L'inscription en self-service (`registerDriver`,
/// `registerDriverWithDocuments*` dans `AppService`) reste dans le code, sur
/// Supabase, mais n'est plus accessible depuis cet écran tant que le backend
/// n'a pas d'équivalent — voir `docs/architecture/04-migration-flutter.md`.
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
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final appService = Provider.of<AppService>(context, listen: false);

      await appService.loginDriver(
        _emailController.text,
        _passwordController.text,
      );

      if (mounted) {
        // Navigate to delivery home screen
        Navigator.pushReplacementNamed(context, '/delivery-home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de connexion: $e'),
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Fallback if l10n is null (should not happen if setup is correct)
    if (l10n == null) return const SizedBox.shrink();

    return Scaffold(
      body: _isLoading
          ? const LoadingWidget(message: 'Connexion en cours...')
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),

                    // Logo and title
                    Column(
                      children: [
                        const ElCorazonLogo(size: 120, showText: false),
                        const SizedBox(height: 24),
                        Text(
                          l10n.appTitle,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.loginTitle,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),

                    const SizedBox(height: 48),

                    // Auth form
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          CustomTextField(
                            label: l10n.email,
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: Icons.email,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Veuillez entrer votre email';
                              }
                              if (!value.contains('@')) {
                                return 'Email invalide';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: l10n.password,
                              prefixIcon: const Icon(Icons.lock),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 24),
                          CustomButton(
                            text: l10n.loginButton,
                            onPressed: _login,
                            icon: Icons.login,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Additional info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue[700],
                            size: 24,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Pour devenir livreur, contactez El Corazón :',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'l\'inscription se fait pour l\'instant par notre '
                            'équipe, qui vérifie permis, pièce d\'identité et '
                            'véhicule avant de créer votre compte.',
                            style: TextStyle(
                              color: Colors.blue[600],
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

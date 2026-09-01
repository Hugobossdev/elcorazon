import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_dely/services/app_service.dart';
import 'package:elcora_dely/services/error_handler_service.dart';
import 'package:elcora_dely/utils/validators.dart';

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _licenseController = TextEditingController();
  final _vehicleController = TextEditingController();
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isLoadingDriverData = true;


  /// Dossier livreur servi par `/delivery/me/` — l'unique source des champs
  /// affichés ici (véhicule, statut de vérification, compteurs, note).
  eccore.CourierProfile? get _courier =>
      Provider.of<AppService>(context, listen: false).courierProfile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _licenseController.dispose();
    _vehicleController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final appService = Provider.of<AppService>(context, listen: false);
    final user = appService.currentUser;

    if (user != null) {
      _nameController.text = user.fullName;
      _phoneController.text = user.phone ?? '';
      _emailController.text = user.email;
      
      await _loadDriverData(user.id);
    }
  }

  Future<void> _loadDriverData(String userId) async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingDriverData = true;
    });

    try {
      // Le dossier livreur vient de `/delivery/me/` : identité, véhicule,
      // statut de vérification, compteurs et note y sont déjà. Les quatre
      // requêtes Supabase qu'il remplace lisaient une vue `drivers_with_user_info`
      // et des tables de badges et d'avis qui n'existent pas en v2.
      //
      // Les **badges livreur** et le détail des avis (ponctualité, service,
      // soin du colis) n'ont pas d'équivalent au contrat : la gamification y
      // est réservée aux clients, et la note du livreur est un agrégat
      // (`rating_average`, `rating_count`), pas une liste d'avis.
      final appService = Provider.of<AppService>(context, listen: false);
      final profile = appService.courierProfile;

      if (profile != null) {
        _licenseController.text = profile.vehiclePlate;
        _vehicleController.text = profile.vehicleType;
      }
    } catch (e) {
      eccore.Journal.trace('Erreur chargement données livreur: $e');
      // On ne bloque pas l'UI, mais on loggue l'erreur
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDriverData = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final appService = Provider.of<AppService>(context, listen: false);
      final user = appService.currentUser;

      if (user != null) {
        // `PATCH /auth/me/` : le compte modifié est celui du jeton, il ne se
        // désigne pas. L'ancienne version écrivait la table `users` avec un
        // dictionnaire libre, où rien n'interdisait `user_type` ni `email`.
        await appService.updateOwnProfile(
          fullName: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
        );
        await _loadProfile();

        setState(() {
          _isEditing = false;
          _isSaving = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profil mis à jour avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        final errorHandler =
            Provider.of<ErrorHandlerService>(context, listen: false);
        errorHandler.logError('Erreur sauvegarde profil', details: e);
        errorHandler.showErrorSnackBar(
            context, 'Erreur lors de la sauvegarde: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Profil'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _loadProfile();
                });
              },
            ),
        ],
      ),
      body: Consumer<AppService>(
        builder: (context, appService, child) {
          final user = appService.currentUser;
          if (user == null) {
            // Si l'utilisateur est null, on tente de le récupérer ou on affiche une erreur
            if (appService.isInitialized) {
               return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.orange),
                    const SizedBox(height: 16),
                    const Text('Profil introuvable'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => appService.initialize(),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              );
            }
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileHeader(user, isOnline: appService.isOnline),
                  const SizedBox(height: 24),
                  if (_isLoadingDriverData)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(),
                    ))
                  else ...[
                    _buildStatsSection(user),
                    const SizedBox(height: 24),
                            const SizedBox(height: 24),
                    _buildPersonalInfoSection(),
                    const SizedBox(height: 24),
                    _buildDriverInfoSection(),
                    const SizedBox(height: 24),
                            if (_isEditing) ...[
                      const SizedBox(height: 24),
                      _buildSaveButton(),
                    ],
                  ]
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // `isOnline` vient du dossier livreur, pas du compte.
  Widget _buildProfileHeader(eccore.User user, {required bool isOnline}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: Column(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white,
                  // Le dossier ne porte pas de photo : le contrat ne l'expose
                  // qu'au client qui suit sa livraison (`CourierPublic`).
                  child: Text(
                    user.fullName.substring(0, 2).toUpperCase(),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                if (_courier?.verificationStatus == 'approved')
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified,
                        color: Colors.blue,
                        size: 24,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              user.fullName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              user.email,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isOnline ? Colors.green : Colors.grey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isOnline ? 'En ligne' : 'Hors ligne',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Informations personnelles',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              enabled: _isEditing,
              decoration: const InputDecoration(
                labelText: 'Nom complet',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: Validators.validateName,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              enabled: false,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              enabled: _isEditing,
              decoration: const InputDecoration(
                labelText: 'Téléphone',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: Validators.validatePhone,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverInfoSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Informations livreur',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _licenseController,
              enabled: false, // On ne permet pas de modifier le permis ici pour l'instant
              decoration: const InputDecoration(
                labelText: 'Numéro de permis',
                prefixIcon: Icon(Icons.card_membership),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _vehicleController,
              enabled: false, // Idem pour le véhicule
              decoration: const InputDecoration(
                labelText: 'Véhicule',
                prefixIcon: Icon(Icons.directions_bike),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
             _buildVerificationStatus(),
          ],
        ),
      ),
    );
  }

  /// L'état du dossier, et ce qu'il implique concrètement.
  ///
  /// `suspended` — l'un des quatre états de `VerificationStatus` — tombait
  /// dans le `default` et s'affichait « En attente » : un livreur suspendu
  /// lisait donc que son dossier était en cours d'instruction, et attendait
  /// une validation qui ne viendrait pas.
  ///
  /// La phrase compte autant que le mot : « Rejeté » seul ne dit pas qu'aucune
  /// course ne sera plus proposée.
  Widget _buildVerificationStatus() {
    final (color, icon, text, detail) = switch (_courier?.verificationStatus) {
      'approved' => (
          Colors.green,
          Icons.check_circle,
          'Vérifié',
          'Vous pouvez recevoir des courses.',
        ),
      'rejected' => (
          Colors.red,
          Icons.cancel,
          'Rejeté',
          'Aucune course ne peut vous être proposée. Contactez El Corazón.',
        ),
      'suspended' => (
          Colors.red,
          Icons.pause_circle_filled,
          'Suspendu',
          'Votre compte est suspendu : aucune course ne vous sera proposée.',
        ),
      _ => (
          Colors.orange,
          Icons.hourglass_empty,
          'En attente de validation',
          'Aucune course ne vous sera proposée tant que le dossier n\'est '
              'pas validé.',
        ),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dossier : $text',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(detail, style: TextStyle(color: color, fontSize: 12)),
                // Les motifs saisis par le personnel lors du refus. Le champ
                // voyageait dans le dossier sans que rien ne l'affiche : le
                // livreur voyait « Rejeté » sans savoir ce qu'il devait
                // corriger.
                if ((_courier?.verificationNotes ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _courier!.verificationNotes,
                    style: TextStyle(color: color, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(eccore.User user) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Statistiques',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Livraisons',
                    _courier?.deliveriesCompleted.toString() ?? '0',
                    Icons.delivery_dining,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    'Note',
                    (_courier?.ratingAverage ?? 0.0).toStringAsFixed(1),
                    Icons.star,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    'Avis',
                    _courier?.ratingCount.toString() ?? '0',
                    Icons.comment,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Sauvegarder',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}

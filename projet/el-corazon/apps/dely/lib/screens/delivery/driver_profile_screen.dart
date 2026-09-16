import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_dely/presentation/pieces_du_dossier.dart';
import 'package:elcora_dely/presentation/vehicules.dart';
import 'package:elcora_dely/screens/auth/pieces_justificatives_screen.dart';
import 'package:elcora_dely/services/app_service.dart';
import 'package:elcora_dely/services/error_handler_service.dart';
import 'package:elcora_dely/utils/validators.dart';

/// Le profil du livreur — son compte d'un côté, son dossier de l'autre.
///
/// ## Deux objets, deux routes, un seul écran
///
/// Le **compte** (`User`) porte le nom et le téléphone : ils se corrigent par
/// `PATCH /auth/me/`, comme pour n'importe quel type de compte. Le **dossier**
/// (`CourierProfile`) porte le véhicule, la plaque et les numéros de pièces :
/// ils se corrigent par `PATCH /delivery/me/`. L'écran réunit les deux parce
/// que le livreur corrige « son profil », mais les deux écritures partent
/// séparément — et seule celle dont le contenu a bougé part.
///
/// ## Ce que cet écran affichait de faux
///
/// Un champ intitulé « Numéro de permis » était rempli avec la **plaque
/// d'immatriculation** — deux données sans rapport, et le livreur qui vérifiait
/// son dossier y lisait une valeur qui n'était pas la sienne. Le vrai numéro de
/// permis n'était nulle part : le sérialiseur ne le rendait pas.
///
/// Le champ « Véhicule » affichait la valeur brute du contrat — `motorcycle` —
/// là où le formulaire d'inscription proposait « Moto ».
///
/// Les deux champs étaient grisés, commentés « on ne permet pas de modifier ici
/// pour l'instant » : la route n'existait pas côté serveur. Elle existe
/// désormais, et ils sont modifiables.
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

  // Trois champs du **dossier**, distincts et nommés pour ce qu'ils sont. Le
  // premier s'appelait `_licenseController` et recevait la plaque.
  final _plaqueController = TextEditingController();
  final _permisController = TextEditingController();
  final _cniController = TextEditingController();

  /// Le code serveur du véhicule — `motorcycle`, `car`… Jamais son libellé.
  String? _vehicule;

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
    _plaqueController.dispose();
    _permisController.dispose();
    _cniController.dispose();
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
        // Chaque champ reçoit **sa** valeur. La plaque arrivait dans le champ
        // du permis, et le permis n'arrivait nulle part.
        _plaqueController.text = profile.vehiclePlate;
        _permisController.text = profile.licenceNumber;
        _cniController.text = profile.nationalIdNumber;
        _vehicule = profile.vehicleType;
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
        //
        // Envoyé seulement si quelque chose a bougé : le serveur accepterait
        // une requête sans changement, mais elle réécrirait `updated_at` sur
        // le compte à chaque ouverture de l'écran.
        final nom = _nameController.text.trim();
        final telephone = _phoneController.text.trim();
        if (nom != user.fullName || telephone != (user.phone ?? '')) {
          await appService.updateOwnProfile(fullName: nom, phone: telephone);
        }

        // `PATCH /delivery/me/` : le dossier, séparément — deux objets, deux
        // routes. Seuls les champs réellement modifiés partent : `null`
        // signifie « ne pas y toucher », et le serveur refuse un corps vide
        // plutôt que d'annoncer un enregistrement qui n'a rien enregistré.
        final dossier = appService.courierProfile;
        final corrections = <String, String?>{
          'vehicle_type': _vehicule != dossier?.vehicleType ? _vehicule : null,
          'vehicle_plate': _plaqueController.text.trim() != dossier?.vehiclePlate
              ? _plaqueController.text.trim()
              : null,
          'licence_number': _permisController.text.trim() != dossier?.licenceNumber
              ? _permisController.text.trim()
              : null,
          'national_id_number':
              _cniController.text.trim() != dossier?.nationalIdNumber
              ? _cniController.text.trim()
              : null,
        };
        if (corrections.values.any((valeur) => valeur != null)) {
          await appService.corrigerDossier(
            vehicleType: corrections['vehicle_type'],
            vehiclePlate: corrections['vehicle_plate'],
            licenceNumber: corrections['licence_number'],
            nationalIdNumber: corrections['national_id_number'],
          );
        }

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
              // E.164, comme à l'inscription et comme le serveur l'exige
              // (`phone_validator`). `validatePhone` acceptait « 90123456 »,
              // que le serveur refuse : l'enregistrement partait, échouait en
              // 400, et le message parlait d'un format que l'écran venait
              // d'accepter.
              validator: Validators.validatePhoneE164,
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

            // Le véhicule, par son libellé français et non par le code du
            // contrat. Un menu déroulant plutôt qu'un champ libre : la valeur
            // doit appartenir à `VehicleType`, et une saisie libre ferait
            // refuser l'enregistrement pour une faute de frappe.
            DropdownButtonFormField<String>(
              initialValue: Vehicule.depuisServeur(_vehicule) == null ? null : _vehicule,
              decoration: const InputDecoration(
                labelText: 'Véhicule',
                prefixIcon: Icon(Icons.two_wheeler),
                border: OutlineInputBorder(),
              ),
              items: [
                for (final vehicule in Vehicule.values)
                  DropdownMenuItem(
                    value: vehicule.code,
                    child: Row(
                      children: [
                        Icon(vehicule.icone, size: 20),
                        const SizedBox(width: 8),
                        Text(vehicule.libelle),
                      ],
                    ),
                  ),
              ],
              onChanged: _isEditing
                  ? (valeur) => setState(() => _vehicule = valeur ?? _vehicule)
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _plaqueController,
              enabled: _isEditing,
              decoration: const InputDecoration(
                labelText: 'Plaque d\'immatriculation',
                prefixIcon: Icon(Icons.confirmation_number_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _permisController,
              enabled: _isEditing,
              decoration: const InputDecoration(
                labelText: 'Numéro de permis',
                prefixIcon: Icon(Icons.card_membership),
                border: OutlineInputBorder(),
                // Le numéro, pas la photo : les deux se saisissent séparément,
                // et le second ne remplace pas le premier.
                helperText: 'La photo du permis se dépose dans vos pièces.',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cniController,
              enabled: _isEditing,
              decoration: const InputDecoration(
                labelText: 'Numéro de pièce d\'identité',
                prefixIcon: Icon(Icons.badge_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // Où il roule : ses zones, ou toutes celles de sa cuisine. Réglé par
            // l'exploitation, en lecture seule ici — c'est ce qui décide des
            // courses qu'on lui propose.
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.map_outlined),
              title: const Text('Zones de livraison'),
              subtitle: Text(
                (_courier?.serviceZones ?? const []).isEmpty
                    ? 'Toutes les zones de votre cuisine'
                    : _courier!.serviceZones.map((zone) => zone.name).join(', '),
              ),
            ),
            const SizedBox(height: 8),
            _buildPiecesTile(),
            const SizedBox(height: 16),
             _buildVerificationStatus(),
          ],
        ),
      ),
    );
  }

  /// L'accès aux pièces justificatives, et l'état de leur dépôt.
  ///
  /// L'écran n'en parlait pas du tout, et il n'y avait rien à en dire : aucune
  /// application ne savait téléverser une pièce. La tuile porte le compte de ce
  /// qui manque parce que c'est la seule chose qui bloque un dossier neuf, et
  /// qu'un livreur ne devine pas qu'on attend trois documents de lui.
  Widget _buildPiecesTile() {
    final dossier = _courier;
    final manquantes = dossier == null ? const <PieceDuDossier>[] : piecesManquantes(dossier);
    final exigence = ExigenceDuDossier.depuis(dossier);
    final theme = Theme.of(context);
    final alerte = exigence.appelleUneAction;

    return Card(
      elevation: 0,
      color: alerte
          ? theme.colorScheme.errorContainer.withValues(alpha: 0.5)
          : theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Icon(
          alerte ? Icons.upload_file : Icons.folder_shared_outlined,
          color: alerte ? theme.colorScheme.error : theme.colorScheme.primary,
        ),
        title: Text(exigence.action),
        subtitle: Text(
          switch (exigence) {
            ExigenceDuDossier.incomplet =>
              '${manquantes.length} pièce${manquantes.length > 1 ? 's' : ''} manquante'
                  '${manquantes.length > 1 ? 's' : ''}',
            ExigenceDuDossier.aCorriger =>
              'Déposez de nouvelles pièces pour un réexamen',
            ExigenceDuDossier.rienAFaire => 'Vos trois pièces sont déposées',
          },
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => unawaited(
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const PiecesJustificativesScreen(),
            ),
          ),
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:admin/services/driver_management_service.dart';
import 'package:admin/services/restaurant_scope_service.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:admin/presentation/statut_livreur.dart';
import 'package:admin/ui/ui.dart';
import 'package:admin/widgets/custom_button.dart';
import 'package:admin/widgets/custom_text_field.dart';

class DriverFormDialog extends StatefulWidget {
  final eccore.CourierProfile? driver;

  const DriverFormDialog({super.key, this.driver});

  @override
  State<DriverFormDialog> createState() => _DriverFormDialogState();
}

class _DriverFormDialogState extends State<DriverFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _vehicleNumberController = TextEditingController();

  /// Embaucher crée un **compte** : le mot de passe initial est donc exigé par
  /// le serveur. L'ancienne version insérait une ligne dans une table `drivers`
  /// sans compte associé — le livreur ne pouvait pas se connecter.
  final _passwordController = TextEditingController();

  /// Établissement de rattachement, lu sur `/restaurants/manage/` : embaucher,
  /// c'est rattacher quelqu'un à un établissement précis, et l'écrire dans le
  /// code rattachait tout le monde à la même enseigne.
  final RestaurantScopeService _scope = RestaurantScopeService();

  StatutLivreur _selectedStatus = StatutLivreur.disponible;
  String? _selectedVehicleType;
  bool _isLoading = false;

  /// Motif exigé quand on retire quelqu'un du service.
  ///
  /// Suspendre n'est pas corriger : c'est une décision qui prive quelqu'un de
  /// son travail, et le livreur doit savoir pourquoi. Le serveur la range sur
  /// une route distincte, sous une permission distincte.
  final _suspensionController = TextEditingController();

  /// Le statut du dossier à l'ouverture, pour savoir s'il a changé.
  ///
  /// Sans lui, enregistrer une correction de plaque rejouerait une
  /// « validation » du dossier à chaque fois — geste qui demande
  /// `couriers.approve` et qui n'a rien à voir avec ce que l'opérateur a
  /// demandé.
  StatutLivreur? _statutInitial;

  // Le bloc « Zones assignées » a été retiré. Il proposait cinq zones écrites
  // dans le code — « Zone Centre », « Zone Nord »… — que rien n'envoyait au
  // serveur et que rien ne relisait : `CourierProfile` n'a pas de zone, et le
  // rattachement d'un livreur se fait à un **établissement**. C'était un
  // contrôle décoratif, du même genre que le filtre par zone de l'ancien écran
  // des commandes. Les vraies zones de livraison vivent dans
  // `DeliveryZoneService`, et servent aux barèmes.

  @override
  void initState() {
    super.initState();
    if (widget.driver != null) {
      _initializeWithDriver();
    }
  }

  void _initializeWithDriver() {
    final driver = widget.driver!;
    _nameController.text = driver.fullName;
    _emailController.text = driver.email;
    // Le téléphone n'était pas prérempli : le formulaire proposait de modifier
    // un champ dont il n'affichait pas la valeur courante, et l'enregistrer
    // sans y toucher l'aurait effacé. Il est rendu par le serveur depuis que
    // `CourierProfileSerializer` le porte.
    _phoneController.text = driver.phone;
    _vehicleNumberController.text = driver.vehiclePlate;
    _selectedStatus = driver.statut;
    _statutInitial = driver.statut;
    _selectedVehicleType = driver.vehicleType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _vehicleNumberController.dispose();
    _passwordController.dispose();
    _suspensionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.9).clamp(500.0, 900.0);
    final dialogHeight = (screenSize.height * 0.85).clamp(500.0, 900.0);

    // IMPORTANT: Utiliser ConstrainedBox pour garantir les contraintes
    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: dialogWidth,
          maxWidth: dialogWidth,
          minHeight: dialogHeight,
          maxHeight: dialogHeight,
        ),
        child: SizedBox(
          width: dialogWidth,
          height: dialogHeight,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.driver == null ? 'Nouveau Livreur' : 'Modifier le Livreur',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    // IMPORTANT: Envelopper IconButton dans un Container avec des contraintes
                    // pour éviter l'erreur "Cannot hit test a render box with no size"
                    Container(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Contenu scrollable
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Informations de base
                        Text(
                          'Informations personnelles',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 16),

                        CustomTextField(
                          label: 'Nom complet',
                          controller: _nameController,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Veuillez entrer un nom';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        CustomTextField(
                          label: 'Email',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Veuillez entrer un email';
                            }
                            if (!value.contains('@')) {
                              return 'Email invalide';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        CustomTextField(
                          label: 'Téléphone',
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Veuillez entrer un numéro de téléphone';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Informations du véhicule
                        Text(
                          'Informations du véhicule',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 16),

                        // IMPORTANT: Envelopper DropdownButtonFormField dans un Container avec des contraintes
                        // pour éviter l'erreur "Cannot hit test a render box with no size"
                        Container(
                          constraints: const BoxConstraints(
                            minHeight: 56,
                          ),
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Type de véhicule',
                              border: OutlineInputBorder(),
                            ),
                            initialValue: _selectedVehicleType,
                            items: [
                              const DropdownMenuItem(
                                child: Text('Sélectionner un type'),
                              ),
                              ...['Moto', 'Vélo', 'Voiture', 'Scooter'].map((type) {
                                return DropdownMenuItem<String>(
                                  value: type,
                                  child: Row(
                                    children: [
                                      Text(type),
                                      const SizedBox(width: 8),
                                      Text(type),
                                    ],
                                  ),
                                );
                              }),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedVehicleType = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 16),

                        CustomTextField(
                          label: 'Numéro de véhicule',
                          controller: _vehicleNumberController,
                        ),
                        const SizedBox(height: 24),

                        // Statut
                        Text(
                          'Statut',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 16),

                        // IMPORTANT: Envelopper DropdownButtonFormField dans un Container avec des contraintes
                        // pour éviter l'erreur "Cannot hit test a render box with no size"
                        Container(
                          constraints: const BoxConstraints(
                            minHeight: 56,
                          ),
                          child: DropdownButtonFormField<StatutLivreur>(
                            decoration: const InputDecoration(
                              labelText: 'Statut du livreur',
                              border: OutlineInputBorder(),
                            ),
                            initialValue: _selectedStatus,
                            items: StatutLivreur.values.map((status) {
                              return DropdownMenuItem<StatutLivreur>(
                                value: status,
                                child: Row(
                                  children: [
                                    Icon(status.icone), // emoji n'est pas défini
                                    const SizedBox(width: 8),
                                    Text(status.libelle),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedStatus = value!;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Le champ de motif n'apparaît que pour une
                        // suspension : c'est le seul geste de cet écran
                        // qui prive quelqu'un de son travail, et le
                        // livreur doit pouvoir savoir pourquoi.
                        if (widget.driver != null &&
                            _selectedStatus == StatutLivreur.indisponible &&
                            _statutInitial != StatutLivreur.indisponible) ...[
                          CustomTextField(
                            controller: _suspensionController,
                            label: 'Motif de la suspension',
                            prefixIcon: Icons.report_outlined,
                            validator: (valeur) => (valeur ?? '').trim().length < 3
                                ? 'Indiquez le motif : il est rendu au livreur.'
                                : null,
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Préférences
                        Text(
                          'Préférences',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 16),

                        _buildPreferencesSection(),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // IMPORTANT: Envelopper TextButton dans un Container avec des contraintes
                    // pour éviter l'erreur "Cannot hit test a render box with no size"
                    Container(
                      constraints: const BoxConstraints(
                        minHeight: 48,
                      ),
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Annuler'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    CustomButton(
                      text: widget.driver == null ? 'Créer' : 'Modifier',
                      onPressed: _saveDriver,
                      isLoading: _isLoading,
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

  Widget _buildPreferencesSection() {
    return Card(
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, size: 20, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'Préférences de livraison',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildPreferenceItem(
              'Distance maximale (km)',
              '20',
              Icons.straighten,
            ),
            _buildPreferenceItem(
              'Heures de travail',
              '8h - 20h',
              Icons.schedule,
            ),
            _buildPreferenceItem(
              'Jours de travail',
              'Lun - Dim',
              Icons.calendar_today,
            ),
            _buildPreferenceItem(
              'Type de commandes préférées',
              'Toutes',
              Icons.restaurant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferenceItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveDriver() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final driverService = context.read<DriverManagementService>();
      bool success;

      if (widget.driver == null) {
        final etablissement = await _scope.requireSlug();
        if (etablissement == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(RestaurantScopeService.sansPerimetre),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // Embauche : le compte et le dossier naissent ensemble, côté serveur.
        success = await driverService.provisionDriver(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _nameController.text.trim(),
          restaurantSlug: etablissement,
          vehicleType: _selectedVehicleType ?? 'motorcycle',
          phone: _phoneController.text.trim(),
          vehiclePlate: _vehicleNumberController.text.trim(),
        );
      } else {
        // **Une vraie modification, enfin.**
        //
        // Cette branche envoyait `setVerification` — c'est-à-dire qu'elle
        // instruisait le statut du dossier et **jetait tout ce que l'opérateur
        // venait de saisir** : nom, téléphone, véhicule, plaque. Puis elle
        // annonçait « Livreur modifié avec succès ». Le formulaire était un
        // décor ; le seul effet réel était un changement de statut que rien à
        // l'écran ne présentait comme tel.
        //
        // La route existe maintenant (`PATCH /delivery/couriers/{id}/`), avec
        // sa liste blanche côté serveur. Le statut, lui, garde sa route : il
        // demande `couriers.approve`/`couriers.suspend`, et le confondre avec
        // une correction de plaque donnerait le droit de suspendre à qui n'a
        // que celui de corriger.
        success = await driverService.updateDriver(
          driverId: widget.driver!.id,
          fullName: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          vehicleType: _selectedVehicleType,
          vehiclePlate: _vehicleNumberController.text.trim(),
        );

        // Le statut du dossier suit **sa** route, et seulement s'il a changé.
        // Deux gestes, deux permissions : corriger une plaque demande
        // `couriers.write`, suspendre demande `couriers.suspend`. Les fondre
        // en un seul appel donnerait le second à quiconque a le premier.
        if (success && _selectedStatus != _statutInitial) {
          final suspend = _selectedStatus == StatutLivreur.indisponible;
          success = suspend
              ? await driverService.suspendDriver(
                  widget.driver!.id,
                  _suspensionController.text.trim(),
                )
              : await driverService.reactivateDriver(widget.driver!.id);
        }
      }

      if (!mounted) return;

      if (success) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.driver == null
                  ? 'Livreur embauché.'
                  : 'Dossier de ${_nameController.text.trim()} mis à jour.',
            ),
            backgroundColor:
                AdminColorTokens.semantic(Theme.of(context).colorScheme).success,
          ),
        );
        return;
      }

      // Le refus du serveur, tel qu'il l'a formulé : il dit lequel des champs
      // est en cause. « Une erreur est survenue » ferait ressaisir à
      // l'identique.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            driverService.error ??
                (widget.driver == null ? 'Embauche refusée.' : 'Modification refusée.'),
          ),
          backgroundColor:
              AdminColorTokens.semantic(Theme.of(context).colorScheme).danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/driver_management_service.dart';
import '../../models/driver.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class DriverFormDialog extends StatefulWidget {
  final Driver? driver;

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

  /// Établissement de rattachement. Le back-office ne gère qu'un établissement
  /// pour l'instant ; le jour où il en gérera plusieurs, ce champ devient un
  /// sélecteur alimenté par `/restaurants/`.
  static const String _restaurantSlug = 'el-corazon-lome';

  DriverStatus _selectedStatus = DriverStatus.available;
  String? _selectedVehicleType;
  List<String> _selectedZones = [];
  bool _isLoading = false;

  final List<String> _availableZones = [
    'Zone Centre',
    'Zone Nord',
    'Zone Sud',
    'Zone Est',
    'Zone Ouest',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.driver != null) {
      _initializeWithDriver();
    }
  }

  void _initializeWithDriver() {
    final driver = widget.driver!;
    _nameController.text = driver.name;
    _emailController.text = driver.email;
    _phoneController.text = driver.phone;
    _vehicleNumberController.text =
        driver.licensePlate ?? ''; // vehicleNumber n'est pas défini
    _selectedStatus = driver.status;
    _selectedVehicleType = driver.vehicleType;
    _selectedZones = <String>[]; // assignedZones n'est pas défini
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _vehicleNumberController.dispose();
    _passwordController.dispose();
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
                        widget.driver == null
                            ? 'Nouveau Livreur'
                            : 'Modifier le Livreur',
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
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
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
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
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
                                  value: null,
                                  child: Text('Sélectionner un type')),
                              ...['Moto', 'Vélo', 'Voiture', 'Scooter']
                                  .map((type) {
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
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
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
                          child: DropdownButtonFormField<DriverStatus>(
                            decoration: const InputDecoration(
                              labelText: 'Statut du livreur',
                              border: OutlineInputBorder(),
                            ),
                            initialValue: _selectedStatus,
                            items: DriverStatus.values.map((status) {
                              return DropdownMenuItem<DriverStatus>(
                                value: status,
                                child: Row(
                                  children: [
                                    Icon(status.icon), // emoji n'est pas défini
                                    const SizedBox(width: 8),
                                    Text(status.displayName),
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

                        // Zones assignées
                        Text(
                          'Zones de livraison',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 16),

                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _availableZones.map((zone) {
                            final isSelected = _selectedZones.contains(zone);
                            // IMPORTANT: Envelopper FilterChip dans un Container avec des contraintes
                            // pour éviter l'erreur "Cannot hit test a render box with no size"
                            return Container(
                              constraints: const BoxConstraints(
                                minHeight: 32,
                              ),
                              child: FilterChip(
                                label: Text(zone),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedZones.add(zone);
                                    } else {
                                      _selectedZones.remove(zone);
                                    }
                                  });
                                },
                                selectedColor: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.2),
                                checkmarkColor:
                                    Theme.of(context).colorScheme.primary,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        if (_selectedZones.isNotEmpty)
                          Text(
                            'Zones sélectionnées: ${_selectedZones.join(', ')}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        const SizedBox(height: 24),

                        // Préférences
                        Text(
                          'Préférences',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
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
        // Embauche : le compte et le dossier naissent ensemble, côté serveur.
        success = await driverService.provisionDriver(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _nameController.text.trim(),
          restaurantSlug: _restaurantSlug,
          vehicleType: _selectedVehicleType ?? 'motorcycle',
          phone: _phoneController.text.trim(),
          vehiclePlate: _vehicleNumberController.text.trim(),
        );
      } else {
        // Le contrat v2 n'a pas de route « modifier un livreur » : le livreur
        // tient son propre dossier (`/delivery/me/`), et le personnel en
        // **instruit le statut**. Retirer quelqu'un du service ou l'y remettre
        // sont les deux seuls gestes que l'exploitation exerce sur un dossier,
        // et ils demandent des permissions distinctes.
        success = await driverService.setVerification(
          widget.driver!.id,
          _selectedStatus == DriverStatus.unavailable ? 'suspended' : 'approved',
        );
      }

      if (success && mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.driver == null
                  ? 'Livreur créé avec succès'
                  : 'Livreur modifié avec succès',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
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

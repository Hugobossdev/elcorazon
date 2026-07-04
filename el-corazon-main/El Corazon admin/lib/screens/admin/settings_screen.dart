import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/admin_auth_service.dart';
import '../../services/paydunya_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../utils/dialog_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Tarifs de livraison
  final Map<String, double> _deliveryRates = {};
  final Map<String, TextEditingController> _rateControllers = {};

  // Horaires
  String _openingTime = '08:00';
  String _closingTime = '22:00';
  final Map<String, bool> _openingDays = {
    'Lundi': true,
    'Mardi': true,
    'Mercredi': true,
    'Jeudi': true,
    'Vendredi': true,
    'Samedi': true,
    'Dimanche': false,
  };

  // API Keys
  final _paydunyaMasterKeyController = TextEditingController();
  final _paydunyaPublicKeyController = TextEditingController();
  final _paydunyaPrivateKeyController = TextEditingController();
  final _paydunyaTokenController = TextEditingController();
  final _googleMapsApiKeyController = TextEditingController();

  // FAQ/CGV
  final _faqController = TextEditingController();
  final _cgvController = TextEditingController();

  // Auto-logout
  Duration _inactivityTimeout = const Duration(minutes: 30);
  bool _autoLogoutEnabled = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadSettings();
    _initializeDeliveryRates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _paydunyaMasterKeyController.dispose();
    _paydunyaPublicKeyController.dispose();
    _paydunyaPrivateKeyController.dispose();
    _paydunyaTokenController.dispose();
    _googleMapsApiKeyController.dispose();
    _faqController.dispose();
    _cgvController.dispose();
    for (final controller in _rateControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeDeliveryRates() {
    final zones = [
      'Zone Centre',
      'Zone Nord',
      'Zone Sud',
      'Zone Est',
      'Zone Ouest',
    ];
    for (final zone in zones) {
      _deliveryRates[zone] = 5.0;
      _rateControllers[zone] = TextEditingController(text: '5.0');
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Charger les tarifs
    for (final zone in _deliveryRates.keys) {
      final rate = prefs.getDouble('delivery_rate_$zone') ?? 5.0;
      _deliveryRates[zone] = rate;
      _rateControllers[zone]?.text = rate.toStringAsFixed(2);
    }

    // Charger les horaires
    _openingTime = prefs.getString('opening_time') ?? '08:00';
    _closingTime = prefs.getString('closing_time') ?? '22:00';
    for (final day in _openingDays.keys) {
      _openingDays[day] = prefs.getBool('opening_day_$day') ?? true;
    }

    // Charger les API keys
    _paydunyaMasterKeyController.text =
        prefs.getString('paydunya_master_key') ?? '';
    _paydunyaPublicKeyController.text =
        prefs.getString('paydunya_public_key') ?? '';
    _paydunyaPrivateKeyController.text =
        prefs.getString('paydunya_private_key') ?? '';
    _paydunyaTokenController.text = prefs.getString('paydunya_token') ?? '';
    _googleMapsApiKeyController.text =
        prefs.getString('google_maps_api_key') ?? '';

    // Charger FAQ/CGV
    _faqController.text = prefs.getString('faq_content') ?? '';
    _cgvController.text = prefs.getString('cgv_content') ?? '';

    // Charger les paramètres d'auto-logout
    final timeoutMinutes = prefs.getInt('inactivity_timeout_minutes') ?? 30;
    _inactivityTimeout = Duration(minutes: timeoutMinutes);
    _autoLogoutEnabled = prefs.getBool('auto_logout_enabled') ?? true;

    setState(() {});
  }

  Future<void> _saveSettings() async {
    // Capturer les valeurs nécessaires avant les gaps async
    if (!mounted) return;
    final inverseSurfaceColor =
        Theme.of(context).colorScheme.inverseSurface;
    
    final prefs = await SharedPreferences.getInstance();

    // Sauvegarder les tarifs
    for (final entry in _rateControllers.entries) {
      final rate = double.tryParse(entry.value.text) ?? 5.0;
      _deliveryRates[entry.key] = rate;
      await prefs.setDouble('delivery_rate_${entry.key}', rate);
    }

    // Sauvegarder les horaires
    await prefs.setString('opening_time', _openingTime);
    await prefs.setString('closing_time', _closingTime);
    for (final entry in _openingDays.entries) {
      await prefs.setBool('opening_day_${entry.key}', entry.value);
    }

    // Sauvegarder les API keys
    await prefs.setString(
      'paydunya_master_key',
      _paydunyaMasterKeyController.text,
    );
    await prefs.setString(
      'paydunya_public_key',
      _paydunyaPublicKeyController.text,
    );
    await prefs.setString(
      'paydunya_private_key',
      _paydunyaPrivateKeyController.text,
    );
    await prefs.setString('paydunya_token', _paydunyaTokenController.text);
    await prefs.setString(
      'google_maps_api_key',
      _googleMapsApiKeyController.text,
    );

    // Configurer PayDunya
    if (_paydunyaMasterKeyController.text.isNotEmpty &&
        _paydunyaPublicKeyController.text.isNotEmpty &&
        _paydunyaPrivateKeyController.text.isNotEmpty &&
        _paydunyaTokenController.text.isNotEmpty) {
      if (!mounted) return;
      final paydunyaService = context.read<PayDunyaService>();
      await paydunyaService.configure(
        masterKey: _paydunyaMasterKeyController.text,
        publicKey: _paydunyaPublicKeyController.text,
        privateKey: _paydunyaPrivateKeyController.text,
        token: _paydunyaTokenController.text,
      );
    }

    // Sauvegarder FAQ/CGV
    await prefs.setString('faq_content', _faqController.text);
    await prefs.setString('cgv_content', _cgvController.text);

    // Sauvegarder les paramètres d'auto-logout
    await prefs.setInt(
      'inactivity_timeout_minutes',
      _inactivityTimeout.inMinutes,
    );
    await prefs.setBool('auto_logout_enabled', _autoLogoutEnabled);

    // Appliquer les paramètres d'auto-logout
    if (!mounted) return;
    final authService = context.read<AdminAuthService>();
    authService.setInactivityTimeout(_inactivityTimeout);
    authService.setAutoLogoutEnabled(_autoLogoutEnabled);

    if (mounted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✅ Paramètres sauvegardés avec succès'),
          backgroundColor: inverseSurfaceColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.local_shipping), text: 'Tarifs'),
            Tab(icon: Icon(Icons.access_time), text: 'Horaires'),
            Tab(icon: Icon(Icons.vpn_key), text: 'API Keys'),
            Tab(icon: Icon(Icons.help_outline), text: 'FAQ/CGV'),
            Tab(icon: Icon(Icons.security), text: 'Sécurité'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDeliveryRatesTab(),
          _buildOpeningHoursTab(),
          _buildApiKeysTab(),
          _buildFaqCgvTab(),
          _buildSecurityTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveSettings,
        icon: const Icon(Icons.save),
        label: const Text('Sauvegarder'),
      ),
    );
  }

  Widget _buildDeliveryRatesTab() {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tarifs de livraison par zone',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Définissez les tarifs de livraison pour chaque zone',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          ..._deliveryRates.keys.map((zone) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        zone,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: CustomTextField(
                        controller: _rateControllers[zone]!,
                        label: 'Tarif (CFA)',
                        keyboardType: TextInputType.number,
                        prefixIcon: Icons.monetization_on,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildOpeningHoursTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Horaires d\'ouverture',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          // Heures d'ouverture/fermeture
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Heures',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          leading: const Icon(Icons.access_time),
                          title: const Text('Ouverture'),
                          subtitle: Text(_openingTime),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _selectTime(true),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ListTile(
                          leading: const Icon(Icons.access_time),
                          title: const Text('Fermeture'),
                          subtitle: Text(_closingTime),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _selectTime(false),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Jours d'ouverture
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Jours d\'ouverture',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ..._openingDays.keys.map((day) {
                    return Container(
                      constraints: const BoxConstraints(minHeight: 56),
                      child: SwitchListTile(
                        title: Text(day),
                        value: _openingDays[day]!,
                        onChanged: (value) {
                          setState(() {
                            _openingDays[day] = value;
                          });
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApiKeysTab() {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Clés API',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Configurez les clés API pour les services externes',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          // PayDunya
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.payment, color: scheme.tertiary),
                      const SizedBox(width: 8),
                      const Text(
                        'PayDunya',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _paydunyaMasterKeyController,
                    label: 'Master Key',
                    isPassword: true,
                    prefixIcon: Icons.vpn_key,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _paydunyaPublicKeyController,
                    label: 'Public Key',
                    isPassword: true,
                    prefixIcon: Icons.vpn_key,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _paydunyaPrivateKeyController,
                    label: 'Private Key',
                    isPassword: true,
                    prefixIcon: Icons.vpn_key,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _paydunyaTokenController,
                    label: 'Token',
                    isPassword: true,
                    prefixIcon: Icons.vpn_key,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Google Maps
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.map, color: scheme.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Google Maps',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _googleMapsApiKeyController,
                    label: 'API Key',
                    isPassword: true,
                    prefixIcon: Icons.vpn_key,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqCgvTab() {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FAQ et CGV',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Gérez le contenu statique de l\'application',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          // FAQ
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.help_outline),
                      SizedBox(width: 8),
                      Text(
                        'FAQ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _faqController,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      labelText: 'Contenu FAQ',
                      border: OutlineInputBorder(),
                      hintText: 'Entrez le contenu de la FAQ...',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // CGV
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.description),
                      SizedBox(width: 8),
                      Text(
                        'Conditions Générales de Vente',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _cgvController,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      labelText: 'Contenu CGV',
                      border: OutlineInputBorder(),
                      hintText: 'Entrez le contenu des CGV...',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sécurité',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          // Auto-logout
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: const Text('Déconnexion automatique'),
                    subtitle: const Text(
                      'Déconnecter automatiquement après une période d\'inactivité',
                    ),
                    value: _autoLogoutEnabled,
                    onChanged: (value) {
                      setState(() {
                        _autoLogoutEnabled = value;
                      });
                    },
                  ),
                  if (_autoLogoutEnabled) ...[
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.timer),
                      title: const Text('Délai d\'inactivité'),
                      subtitle: Text('${_inactivityTimeout.inMinutes} minutes'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _selectInactivityTimeout(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectTime(bool isOpening) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(
          (isOpening ? _openingTime : _closingTime).split(':')[0],
        ),
        minute: int.parse(
          (isOpening ? _openingTime : _closingTime).split(':')[1],
        ),
      ),
    );

    if (picked != null) {
      setState(() {
        final time =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        if (isOpening) {
          _openingTime = time;
        } else {
          _closingTime = time;
        }
      });
    }
  }

  Future<void> _selectInactivityTimeout() async {
    final minutes = await DialogHelper.showSafeDialog<int>(
      context: context,
      builder: (context) {
        final screenSize = MediaQuery.of(context).size;
        final dialogWidth = (screenSize.width * 0.9).clamp(400.0, 500.0);
        final dialogHeight = (screenSize.height * 0.6).clamp(400.0, 600.0);

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
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Délai d\'inactivité',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
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
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: RadioGroup<int>(
                        groupValue: _inactivityTimeout.inMinutes,
                        onChanged: (value) {
                          Navigator.of(context).pop(value);
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [15, 30, 45, 60, 90, 120].map((mins) {
                            return Container(
                              constraints: const BoxConstraints(minHeight: 56),
                              child: RadioListTile<int>(
                                title: Text('$mins minutes'),
                                value: mins,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (minutes != null && mounted) {
      setState(() {
        _inactivityTimeout = Duration(minutes: minutes);
      });
    }
  }
}

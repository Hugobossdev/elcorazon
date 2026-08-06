import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/admin_auth_service.dart';
import '../../services/delivery_zone_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../utils/dialog_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'zone_form_dialog.dart';
import 'zone_selection_tab.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Les tarifs de livraison ne sont plus tenus ici. Cet écran portait cinq
  // zones écrites en dur (« Zone Centre », « Zone Nord »…) dont les tarifs
  // étaient enregistrés dans les préférences locales du poste : ils
  // n'atteignaient jamais le serveur, ne correspondaient à aucune zone réelle,
  // et laissaient croire qu'on venait de changer un prix. Le barème vit dans
  // `DeliveryZoneService`, c'est-à-dire dans la base.

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
    _tabController = TabController(length: 6, vsync: this);
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _googleMapsApiKeyController.dispose();
    _faqController.dispose();
    _cgvController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Charger les horaires
    _openingTime = prefs.getString('opening_time') ?? '08:00';
    _closingTime = prefs.getString('closing_time') ?? '22:00';
    for (final day in _openingDays.keys) {
      _openingDays[day] = prefs.getBool('opening_day_$day') ?? true;
    }

    // Charger les API keys
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

    // Les tarifs ne sont plus enregistrés ici : chaque zone s'écrit sur le
    // serveur, depuis son propre formulaire, et le bouton global ne peut donc
    // pas les emporter par mégarde.

    // Sauvegarder les horaires
    await prefs.setString('opening_time', _openingTime);
    await prefs.setString('closing_time', _closingTime);
    for (final entry in _openingDays.entries) {
      await prefs.setBool('opening_day_${entry.key}', entry.value);
    }

    // Les clés du prestataire de paiement ne sont plus ici : elles vivent
    // côté serveur. Les saisir dans l'application revenait à distribuer, dans
    // chaque poste, de quoi déclencher un remboursement sans permission, sans
    // rattachement, sans trace et sans plafond.
    await prefs.setString(
      'google_maps_api_key',
      _googleMapsApiKeyController.text,
    );

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
            Tab(icon: Icon(Icons.map), text: 'Zones'),
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
          // Où l'on livre — la sélection des zones desservies.
          const ZoneSelectionTab(),
          // Ce que coûte la livraison — le barème de chaque zone.
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

  /// Barèmes de livraison — **les zones réelles**, lues et écrites sur le
  /// serveur.
  ///
  /// Cet onglet listait cinq zones inventées dont les tarifs allaient dans les
  /// préférences du poste. Personne ne facturait ces montants : le barème qui
  /// s'applique vit sur la `DeliveryZone`, en base, et c'est lui qu'on édite
  /// ici — seuil de livraison offerte compris, qui n'avait jusqu'ici aucune
  /// interface.
  Widget _buildDeliveryRatesTab() {
    final scheme = Theme.of(context).colorScheme;

    return Consumer<DeliveryZoneService>(
      builder: (context, service, child) {
        return RefreshIndicator(
          onRefresh: service.refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Barèmes de livraison par zone',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ces montants sont ceux que le serveur facture. Une '
                  'modification s’applique à la commande suivante, sans '
                  'republier les applications.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                if (service.isLoading && service.zones.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (service.error != null && service.zones.isEmpty)
                  _buildZonesError(service, scheme)
                else if (service.zones.isEmpty)
                  _buildNoZones(scheme)
                else
                  ...service.zones.map(
                    (zone) => _buildZoneCard(service, zone, scheme),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildZonesError(DeliveryZoneService service, ColorScheme scheme) {
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                service.error!,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
            TextButton(
              onPressed: service.refresh,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoZones(ColorScheme scheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Icon(Icons.map_outlined, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Aucune zone de livraison n’est enregistrée. Le contour d’une '
                'zone se dessine côté serveur ; les barèmes se règlent ensuite '
                'ici.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneCard(
    DeliveryZoneService service,
    DeliveryZone zone,
    ColorScheme scheme,
  ) {
    final devise = zone.currency == 'XOF' ? 'FCFA' : zone.currency;
    String montant(double valeur) => valeur == valeur.roundToDouble()
        ? valeur.toStringAsFixed(0)
        : valeur.toStringAsFixed(2);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        zone.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      // Deux villes peuvent avoir chacune leur « Centre-ville » :
                      // sans ce rappel, les deux lignes seraient indiscernables.
                      Text(
                        service.cityName(zone.cityId),
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!zone.isActive)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      label: const Text('Inactive'),
                      backgroundColor: scheme.surfaceContainerHighest,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                TextButton.icon(
                  onPressed: () => _editZone(zone),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Modifier'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                _buildZoneFact(
                  Icons.monetization_on_outlined,
                  'Forfait',
                  '${montant(zone.deliveryFee)} $devise',
                  scheme,
                ),
                _buildZoneFact(
                  Icons.straighten,
                  'Par kilomètre',
                  '${montant(zone.feePerKm)} $devise',
                  scheme,
                ),
                _buildZoneFact(
                  Icons.card_giftcard,
                  'Livraison offerte',
                  zone.freeDeliveryThreshold == null
                      ? 'Jamais'
                      : 'dès ${montant(zone.freeDeliveryThreshold!)} $devise',
                  scheme,
                ),
                _buildZoneFact(
                  Icons.schedule,
                  'Temps estimé',
                  '~${zone.estimatedTimeMinutes} min',
                  scheme,
                ),
                if (zone.minOrderAmount != null)
                  _buildZoneFact(
                    Icons.shopping_basket_outlined,
                    'Commande minimum',
                    '${montant(zone.minOrderAmount!)} $devise',
                    scheme,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneFact(
    IconData icone,
    String libelle,
    String valeur,
    ColorScheme scheme,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text('$libelle : ', style: TextStyle(color: scheme.onSurfaceVariant)),
        Text(valeur, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Future<void> _editZone(DeliveryZone zone) async {
    final enregistre = await ZoneFormDialog.show(context, zone);
    if (!enregistre || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Barème de « ${zone.name} » enregistré'),
        backgroundColor: Theme.of(context).colorScheme.inverseSurface,
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
                  const SizedBox(height: 12),
                  Text(
                    'Les clés marchandes sont détenues par le serveur et ne '
                    'transitent plus par cette application. Un remboursement '
                    'passe par une requête authentifiée, soumise à la '
                    'permission « orders.refund », au périmètre de votre '
                    "compte et au plafond de l'encaissement d'origine.",
                    style: TextStyle(color: scheme.onSurfaceVariant),
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

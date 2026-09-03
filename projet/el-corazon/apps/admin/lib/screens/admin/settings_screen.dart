import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:admin/services/admin_auth_service.dart';
import 'package:admin/services/delivery_zone_service.dart';
import 'package:admin/utils/dialog_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:admin/screens/admin/onglet_horaires.dart';
import 'package:admin/screens/admin/zone_form_dialog.dart';
import 'package:admin/screens/admin/zone_selection_tab.dart';

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

  // Les horaires ne sont plus tenus ici. Cet onglet portait une heure
  // d'ouverture, une heure de fermeture et sept interrupteurs, enregistrés
  // dans les préférences du poste : ils n'atteignaient jamais le serveur,
  // n'étaient relus par personne — pas même par cet écran — et les
  // applications client et livreur n'en voyaient rien. Ils vivent dans
  // `OpeningHoursService`, c'est-à-dire dans la base.
  //
  // La clé Google Maps et les contenus FAQ/CGV ont disparu pour la même
  // raison, sans remplacement : la clé de la carte vient du `.env` de
  // l'application (`geocoding_service.dart`), et le champ des réglages
  // n'était lu par aucun code ; quant à la FAQ et aux CGV, le contrat v2 n'a
  // pas de route pour les porter, et un éditeur qui écrit dans le
  // `SharedPreferences` d'un poste n'est pas une gestion de contenu — c'est
  // un bloc-notes qui prétend en être une.

  // Auto-logout
  Duration _inactivityTimeout = const Duration(minutes: 30);
  bool _autoLogoutEnabled = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this)
      // Le bouton d'enregistrement ne s'affiche que sur « Sécurité » :
      // sans cet écouteur, il resterait figé sur l'état du premier onglet.
      ..addListener(() {
        if (mounted) setState(() {});
      });
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Les seuls réglages qui restent **locaux au poste**, et qui doivent
  /// l'être : la déconnexion automatique après inactivité protège l'écran
  /// laissé ouvert dans une salle, ce qui est une propriété de ce poste et non
  /// du compte.
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final timeoutMinutes = prefs.getInt('inactivity_timeout_minutes') ?? 30;
    _inactivityTimeout = Duration(minutes: timeoutMinutes);
    _autoLogoutEnabled = prefs.getBool('auto_logout_enabled') ?? true;

    setState(() {});
  }

  Future<void> _saveSettings() async {
    // Capturer les valeurs nécessaires avant les gaps async
    if (!mounted) return;
    final inverseSurfaceColor = Theme.of(context).colorScheme.inverseSurface;

    final prefs = await SharedPreferences.getInstance();

    // Ce bouton n'enregistre plus que la déconnexion automatique, et son
    // libellé le dit désormais. Il portait aussi les tarifs, les horaires, une
    // clé d'API et deux pages de contenu : les tarifs s'écrivent zone par zone
    // sur le serveur, les horaires plage par plage, et les deux derniers
    // n'allaient nulle part. Un bouton « Sauvegarder » global au-dessus
    // d'onglets qui enregistrent chacun de leur côté laisse croire que rien
    // n'est enregistré tant qu'on ne l'a pas pressé.
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
          content: const Text('Déconnexion automatique enregistrée'),
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
          const OngletHoraires(),
          _buildSecurityTab(),
        ],
      ),
      // Le bouton ne suit plus que l'onglet « Sécurité » : les trois autres
      // écrivent au serveur, ligne par ligne, au moment du geste. Un bouton
      // global au-dessus d'eux laissait croire que rien n'était enregistré
      // avant de l'avoir pressé — et qu'y toucher enregistrait tout.
      floatingActionButton: _tabController.index == 3
          ? FloatingActionButton.extended(
              onPressed: _saveSettings,
              icon: const Icon(Icons.save),
              label: const Text('Enregistrer'),
            )
          : null,
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
        content: Text('Barème de « ${zone.name} » enregistré'),
        backgroundColor: Theme.of(context).colorScheme.inverseSurface,
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

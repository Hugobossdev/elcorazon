import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/app_service.dart';
import '../../services/location_service.dart';
import 'driver_profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _locationTrackingEnabled = true;
  bool _autoAcceptOrders = false;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  String _language = 'fr';
  String _theme = 'light';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        _locationTrackingEnabled =
            prefs.getBool('location_tracking_enabled') ?? true;
        _autoAcceptOrders = prefs.getBool('auto_accept_orders') ?? false;
        _soundEnabled = prefs.getBool('sound_enabled') ?? true;
        _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
        _language = prefs.getString('language') ?? 'fr';
        _theme = prefs.getString('theme') ?? 'light';
      });
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', _notificationsEnabled);
      await prefs.setBool(
          'location_tracking_enabled', _locationTrackingEnabled);
      await prefs.setBool('auto_accept_orders', _autoAcceptOrders);
      await prefs.setBool('sound_enabled', _soundEnabled);
      await prefs.setBool('vibration_enabled', _vibrationEnabled);
      await prefs.setString('language', _language);
      await prefs.setString('theme', _theme);

      // Update services based on settings
      final locationService =
          Provider.of<LocationService>(context, listen: false);

      if (_locationTrackingEnabled) {
        await locationService.requestLocationPermission();
      }

      // Notification settings are handled by the service itself
      // The service will respect the _notificationsEnabled flag

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paramètres sauvegardés'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sauvegarde: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProfileSection(),
          const SizedBox(height: 24),
          _buildNotificationsSection(),
          const SizedBox(height: 24),
          _buildLocationSection(),
          const SizedBox(height: 24),
          _buildDeliverySection(),
          const SizedBox(height: 24),
          _buildAppearanceSection(),
          const SizedBox(height: 24),
          _buildAboutSection(),
          const SizedBox(height: 24),
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    return Consumer<AppService>(
      builder: (context, appService, child) {
        final user = appService.currentUser;
        return Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              radius: 30,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                user?.name.substring(0, 2).toUpperCase() ?? 'DR',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              user?.name ?? 'Livreur',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(user?.email ?? 'driver@fasteat.ci'),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editProfile(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Notifications',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          SwitchListTile(
            title: const Text('Activer les notifications'),
            subtitle: const Text(
                'Recevoir des notifications pour les nouvelles commandes'),
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() {
                _notificationsEnabled = value;
              });
              _saveSettings();
            },
          ),
          SwitchListTile(
            title: const Text('Son'),
            subtitle: const Text('Activer les sons de notification'),
            value: _soundEnabled,
            onChanged: (value) {
              setState(() {
                _soundEnabled = value;
              });
              _saveSettings();
            },
          ),
          SwitchListTile(
            title: const Text('Vibration'),
            subtitle: const Text('Activer les vibrations'),
            value: _vibrationEnabled,
            onChanged: (value) {
              setState(() {
                _vibrationEnabled = value;
              });
              _saveSettings();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Localisation',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          SwitchListTile(
            title: const Text('Suivi GPS'),
            subtitle: const Text('Partager votre position en temps réel'),
            value: _locationTrackingEnabled,
            onChanged: (value) {
              setState(() {
                _locationTrackingEnabled = value;
              });
              _saveSettings();
            },
          ),
          ListTile(
            title: const Text('Permissions de localisation'),
            subtitle: const Text('Gérer les permissions'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _manageLocationPermissions(),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliverySection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Livraison',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          SwitchListTile(
            title: const Text('Accepter automatiquement'),
            subtitle:
                const Text('Accepter automatiquement les nouvelles commandes'),
            value: _autoAcceptOrders,
            onChanged: (value) {
              setState(() {
                _autoAcceptOrders = value;
              });
              _saveSettings();
            },
          ),
          ListTile(
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Apparence',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          ListTile(
            title: const Text('Langue'),
            subtitle: Text(_language == 'fr' ? 'Français' : 'English'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _selectLanguage(),
          ),
          ListTile(
            title: const Text('Thème'),
            subtitle: Text(_theme == 'light' ? 'Clair' : 'Sombre'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _selectTheme(),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'À propos',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          ListTile(
            title: const Text('Version'),
            subtitle: const Text('1.0.0'),
          ),
          ListTile(
            title: const Text('Politique de confidentialité'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showPrivacyPolicy(),
          ),
          ListTile(
            title: const Text('Conditions d\'utilisation'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showTermsOfService(),
          ),
          ListTile(
            title: const Text('Support'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _contactSupport(),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _saveSettings,
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: const Text(
        'Sauvegarder les paramètres',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _editProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DriverProfileScreen(),
      ),
    );
  }

  void _manageLocationPermissions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissions de localisation'),
        content: const Text(
          'Pour utiliser le suivi GPS, l\'application a besoin de l\'accès à votre localisation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final locationService =
                    Provider.of<LocationService>(context, listen: false);
                final hasPermission =
                    await locationService.requestLocationPermission();
                if (mounted) {
                  if (hasPermission) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Permission de localisation accordée'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Permission de localisation refusée'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
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
              }
            },
            child: const Text('Autoriser'),
          ),
        ],
      ),
    );
  }


  void _selectLanguage() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sélectionner la langue'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Français'),
              value: 'fr',
              groupValue: _language,
              onChanged: (value) {
                setState(() {
                  _language = value!;
                });
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('English'),
              value: 'en',
              groupValue: _language,
              onChanged: (value) {
                setState(() {
                  _language = value!;
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _selectTheme() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sélectionner le thème'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Clair'),
              value: 'light',
              groupValue: _theme,
              onChanged: (value) {
                setState(() {
                  _theme = value!;
                });
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Sombre'),
              value: 'dark',
              groupValue: _theme,
              onChanged: (value) {
                setState(() {
                  _theme = value!;
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Politique de confidentialité'),
        content: const SingleChildScrollView(
          child: Text(
            '''
Dernière mise à jour : 06 Décembre 2025

1. Collecte des informations
Nous collectons les informations suivantes lorsque vous utilisez notre application :
- Informations d'identification (nom, adresse e-mail, numéro de téléphone)
- Données de localisation (pour le suivi des livraisons)
- Historique des commandes et des paiements

2. Utilisation des données
Vos données sont utilisées pour :
- Traiter et livrer vos commandes
- Améliorer nos services
- Vous envoyer des mises à jour sur vos commandes
- Assurer la sécurité de votre compte

3. Partage des données
Nous ne vendons pas vos données personnelles. Elles peuvent être partagées avec :
- Les restaurants partenaires (pour la préparation)
- Les livreurs (pour la livraison)
- Les prestataires de paiement (pour la transaction)

4. Vos droits
Vous avez le droit d'accéder, de modifier ou de supprimer vos données personnelles à tout moment via les paramètres de l'application ou en contactant le support.

Pour plus de détails, veuillez contacter notre délégué à la protection des données.
            ''',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showTermsOfService() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conditions d\'utilisation'),
        content: const SingleChildScrollView(
          child: Text(
            '''
Dernière mise à jour : 06 Décembre 2025

1. Acceptation des conditions
En téléchargeant et en utilisant l'application El Corazon Dely, vous acceptez d'être lié par ces conditions d'utilisation.

2. Services
El Corazon Dely est une plateforme de livraison de repas connectant les utilisateurs avec notre restaurant et nos livreurs partenaires.

3. Commandes et Paiements
- Toutes les commandes sont sujettes à disponibilité.
- Les prix sont indiqués en FCFA et incluent les taxes applicables.
- Le paiement est dû au moment de la commande ou à la livraison selon l'option choisie.

4. Livraison
- Les temps de livraison sont des estimations et peuvent varier.
- Vous devez être présent à l'adresse indiquée pour réceptionner la commande.

5. Annulation
Vous pouvez annuler votre commande sans frais tant qu'elle n'a pas été confirmée par le restaurant.

6. Responsabilité
Nous nous efforçons de fournir un service de qualité, mais nous ne pouvons être tenus responsables des retards dus à des circonstances imprévues (météo, trafic, etc.).
            ''',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _contactSupport() {
    // Naviguer vers l'écran de chat avec le support
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Contactez le support',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.phone, color: Colors.white),
                ),
                title: const Text('Appeler le support'),
                subtitle: const Text('+225 01 02 03 04 05'),
                onTap: () {
                  Navigator.pop(context);
                  // Implémenter l'appel téléphonique
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Appel en cours...')),
                  );
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.green,
                  child: Icon(Icons.email, color: Colors.white),
                ),
                title: const Text('Envoyer un email'),
                subtitle: const Text('support@elcorazon.ci'),
                onTap: () {
                  Navigator.pop(context);
                  // Implémenter l'envoi d'email
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ouverture de l\'application mail...')),
                  );
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.purple,
                  child: Icon(Icons.chat, color: Colors.white),
                ),
                title: const Text('Chat en direct'),
                subtitle: const Text('Disponible 8h - 22h'),
                onTap: () {
                  Navigator.pop(context);
                  // Pour l'instant, afficher un message car nous n'avons pas accès facile à ChatScreen ici
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Chat de support indisponible depuis les paramètres')),
                  );
                },
              ),
            ],
          ),
        ),
      );
  }
}

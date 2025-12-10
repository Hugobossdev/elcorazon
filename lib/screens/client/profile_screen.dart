import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/services/theme_service.dart';
import 'package:elcora_fast/models/user.dart';
import 'package:elcora_fast/navigation/app_router.dart';
import 'package:elcora_fast/navigation/navigation_service.dart';
import 'package:elcora_fast/widgets/navigation_helper.dart';
import 'package:elcora_fast/theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Mon Profil',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: AppColors.primaryGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Consumer<AppService>(
        builder: (context, appService, child) {
          final user = appService.currentUser!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileHeader(context, user),
                const SizedBox(height: 24),
                if (_isClient(user.role)) ...[
                  _buildLoyaltyCard(context, user),
                  const SizedBox(height: 24),
                ],
                _buildAppearanceSection(context),
                const SizedBox(height: 24),
                _buildMenuSection(context, 'Paramètres', [
                  _MenuItem(
                    icon: Icons.person,
                    title: 'Informations personnelles',
                    subtitle: 'Modifier mon profil',
                    onTap: () => _showEditProfileDialog(context),
                  ),
                  _MenuItem(
                    icon: Icons.location_on,
                    title: 'Adresses',
                    subtitle: 'Gérer mes adresses de livraison',
                    onTap: () => Navigator.of(context)
                        .pushNamed(AppRouter.addressManagement),
                  ),
                  _MenuItem(
                    icon: Icons.payment,
                    title: 'Méthodes de paiement',
                    subtitle: 'Cartes et portefeuilles',
                    onTap: () => context.navigateToWallet(),
                  ),
                  _MenuItem(
                    icon: Icons.notifications,
                    title: 'Notifications',
                    subtitle: 'Paramètres de notifications',
                    onTap: () => context.navigateToNotifications(),
                  ),
                ]),
                const SizedBox(height: 24),
                _buildMenuSection(context, 'Fonctionnalités Avancées', [
                  _MenuItem(
                    icon: Icons.group,
                    title: 'Commandes Groupées',
                    subtitle: 'Commander avec des amis',
                    onTap: () =>
                        Navigator.of(context).pushNamed(AppRouter.groupOrder),
                  ),
                  _MenuItem(
                    icon: Icons.people,
                    title: 'Fonctionnalités Sociales',
                    subtitle: 'Groupes et événements',
                    onTap: () => _showSocialFeaturesDialog(context),
                  ),
                ]),
                const SizedBox(height: 24),
                _buildMenuSection(context, 'Aide & Support', [
                  _MenuItem(
                    icon: Icons.help,
                    title: 'Centre d\'aide',
                    subtitle: 'FAQ et guides',
                    onTap: () {},
                  ),
                  _MenuItem(
                    icon: Icons.chat,
                    title: 'Contacter le support',
                    subtitle: 'Chat en direct',
                    onTap: () =>
                        Navigator.of(context).pushNamed(AppRouter.support),
                  ),
                  _MenuItem(
                    icon: Icons.star_rate,
                    title: 'Évaluer l\'app',
                    subtitle: 'Donnez votre avis',
                    onTap: () {},
                  ),
                ]),
                const SizedBox(height: 24),
                _buildMenuSection(context, 'À propos', [
                  _MenuItem(
                    icon: Icons.info,
                    title: 'À propos d\'El Corazón',
                    subtitle: 'Version 1.0.0',
                    onTap: () {},
                  ),
                  _MenuItem(
                    icon: Icons.privacy_tip,
                    title: 'Politique de confidentialité',
                    subtitle: 'Vos données personnelles',
                    onTap: () {},
                  ),
                  _MenuItem(
                    icon: Icons.gavel,
                    title: 'Conditions d\'utilisation',
                    subtitle: 'Termes et conditions',
                    onTap: () {},
                  ),
                ]),
                const SizedBox(height: 24),
                _buildLogoutButton(context),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, user) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: user.profileImage != null
                  ? ClipOval(
                      child: Image.network(
                        user.profileImage!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Text(
                      user.name.substring(0, 2).toUpperCase(),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _getRoleEmoji(user.role),
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getRoleDisplayName(user.role),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.edit,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoyaltyCard(BuildContext context, user) {
    final progress = (user.loyaltyPoints % 100) / 100;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.secondary,
              Theme.of(context).colorScheme.tertiary,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.loyalty,
                  color: Theme.of(context).colorScheme.onSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Programme de fidélité',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${user.loyaltyPoints} points',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSecondary,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.onSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(100 - (user.loyaltyPoints % 100)).round()} points jusqu\'à votre prochaine récompense',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSecondary
                    .withValues(alpha: 0.9),
                fontSize: 14,
              ),
            ),
            if (user.badges.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Badges obtenus:',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: user.badges
                    .map(
                      (badge) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _getBadgeDisplayName(badge),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSection(
    BuildContext context,
    String title,
    List<_MenuItem> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Column(
                children: [
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        item.icon,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: item.subtitle != null
                        ? Text(
                            item.subtitle!,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          )
                        : null,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: item.onTap,
                  ),
                  if (index < items.length - 1) const Divider(height: 1),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _showLogoutDialog(context),
        icon: const Icon(Icons.logout),
        label: const Text('Se déconnecter'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
          foregroundColor: Theme.of(context).colorScheme.onError,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const EditProfileDialog(),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Se déconnecter'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final appService =
                  Provider.of<AppService>(context, listen: false);
              await appService.logout();
              if (context.mounted) {
                context.goBack(); // Close dialog
                NavigationService.navigateToAuth(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }

  void _showSocialFeaturesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fonctionnalités Sociales'),
        content: const Text(
          'Découvrez nos fonctionnalités sociales :\n\n'
          '• Créer des groupes de commande\n'
          '• Partager des événements\n'
          '• Suivre vos amis\n'
          '• Participer à des défis\n\n'
          'Ces fonctionnalités sont accessibles depuis l\'écran des commandes groupées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed(AppRouter.groupOrder);
            },
            child: const Text('Essayer'),
          ),
        ],
      ),
    );
  }

  String _getBadgeDisplayName(String badge) {
    switch (badge) {
      case 'first_order':
        return '🥇 Première commande';
      case 'loyal_customer':
        return '💎 Client fidèle';
      case 'big_spender':
        return '💰 Gros dépensier';
      case 'frequent_visitor':
        return '🔥 Visiteur fréquent';
      default:
        return badge;
    }
  }

  String _getRoleEmoji(UserRole role) {
    switch (role) {
      case UserRole.client:
        return '🍔';
      case UserRole.delivery:
        return '🛵';
      case UserRole.admin:
        return '👑';
    }
  }

  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.client:
        return 'Client';
      case UserRole.delivery:
        return 'Delivery Staff';
      case UserRole.admin:
        return 'Administrateur';
    }
  }

  bool _isClient(UserRole role) {
    return role == UserRole.client;
  }

  Widget _buildAppearanceSection(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apparence',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: SwitchListTile(
                secondary: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    themeService.isDarkMode
                        ? Icons.dark_mode
                        : Icons.light_mode,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Mode sombre',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  themeService.isDarkMode ? 'Activé' : 'Désactivé',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                value: themeService.isDarkMode,
                onChanged: (value) => themeService.toggleTheme(),
                activeThumbColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });
}

class EditProfileDialog extends StatefulWidget {
  const EditProfileDialog({super.key});

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AppService>(context, listen: false).currentUser!;
    _nameController.text = user.name;
    _phoneController.text = user.phone;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modifier le profil'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nom complet',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Téléphone',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () {
            // In a real app, would update the user profile
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profil mis à jour avec succès!')),
            );
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

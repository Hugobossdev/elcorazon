import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/admin_auth_service.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _darkModeEnabled = false;
  String _selectedLanguage = 'Français';

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.9).clamp(400.0, 600.0);
    final dialogHeight = (screenSize.height * 0.8).clamp(500.0, 800.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.settings,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Paramètres',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // IMPORTANT: Material + InkWell + Container avec taille explicite pour éviter l'erreur de hit testing
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.close,
                          color: Theme.of(context).colorScheme.onPrimary,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Contenu
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section Notifications
                    _buildSectionHeader('Notifications'),
                    const SizedBox(height: 12),
                    _buildSwitchTile(
                      'Activer les notifications',
                      'Recevoir des notifications pour les nouvelles commandes',
                      Icons.notifications,
                      _notificationsEnabled,
                      (value) => setState(() => _notificationsEnabled = value),
                    ),
                    _buildSwitchTile(
                      'Activer le son',
                      'Jouer un son lors des notifications',
                      Icons.volume_up,
                      _soundEnabled,
                      (value) => setState(() => _soundEnabled = value),
                    ),
                    const SizedBox(height: 24),
                    // Section Apparence
                    _buildSectionHeader('Apparence'),
                    const SizedBox(height: 12),
                    _buildSwitchTile(
                      'Mode sombre',
                      'Activer le thème sombre',
                      Icons.dark_mode,
                      _darkModeEnabled,
                      (value) => setState(() => _darkModeEnabled = value),
                    ),
                    const SizedBox(height: 24),
                    // Section Langue
                    _buildSectionHeader('Langue'),
                    const SizedBox(height: 12),
                    _buildLanguageSelector(),
                    const SizedBox(height: 24),
                    // Section Compte
                    _buildSectionHeader('Compte'),
                    const SizedBox(height: 12),
                    Consumer<AdminAuthService>(
                      builder: (context, adminAuthService, child) {
                        final admin = adminAuthService.currentAdmin;
                        final role = adminAuthService.currentRole;

                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      child: Text(
                                        admin?.name
                                                .substring(0, 1)
                                                .toUpperCase() ??
                                            'A',
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onPrimary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            admin?.name ?? 'Admin',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            role?.name ?? 'Rôle',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Divider(),
                                const SizedBox(height: 8),
                                _buildInfoRow(
                                  Icons.email,
                                  'Email',
                                  admin?.email ?? 'N/A',
                                ),
                                const SizedBox(height: 8),
                                _buildInfoRow(
                                  Icons.phone,
                                  'Téléphone',
                                  admin?.phone ?? 'N/A',
                                ),
                                const SizedBox(height: 8),
                                _buildInfoRow(
                                  Icons.security,
                                  'Permissions',
                                  '${role?.permissions.length ?? 0} permissions',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: TextButton(
                      onPressed: () {
                        // Réinitialiser les paramètres
                      },
                      child: const Text('Réinitialiser'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: ElevatedButton(
                      onPressed: () {
                        // Sauvegarder les paramètres
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Paramètres sauvegardés'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimary,
                      ),
                      child: const Text('Sauvegarder'),
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

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        child: ListTile(
          leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          trailing: Container(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        child: ListTile(
          leading: Icon(
            Icons.language,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: const Text(
            'Langue',
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
          subtitle: Text(
            _selectedLanguage,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Sélectionner la langue'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLanguageOption('Français'),
                    _buildLanguageOption('English'),
                    _buildLanguageOption('Español'),
                  ],
                ),
                actions: [
                  Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Fermer'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLanguageOption(String language) {
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      child: ListTile(
        title: Text(language),
        trailing: _selectedLanguage == language
            ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
            : null,
        onTap: () {
          setState(() => _selectedLanguage = language);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 13, color: Colors.grey[800]),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

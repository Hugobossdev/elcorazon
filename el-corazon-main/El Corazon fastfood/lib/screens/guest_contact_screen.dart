import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:elcora_fast/theme.dart';

class GuestContactScreen extends StatelessWidget {
  const GuestContactScreen({super.key});

  static const String _businessAddress = 'Abidjan, Côte d\'Ivoire';

  Future<void> _openAddressInMaps(BuildContext context, String address) async {
    try {
      // Utiliser une URL universelle (fonctionne iOS/Android/Web)
      final encoded = Uri.encodeComponent(address);
      final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');

      final ok = await canLaunchUrl(uri);
      if (!ok) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Impossible d\'ouvrir la carte sur cet appareil.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'ouverture de la carte: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<void> _sendEmail(String email) async {
    final Uri launchUri = Uri(
      scheme: 'mailto',
      path: email,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    final Uri launchUri = Uri.parse('https://wa.me/$phoneNumber');
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Contactez-nous',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Image or Icon
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.support_agent,
                  size: 60,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            Text(
              'Besoin d\'aide ?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Notre équipe est là pour vous aider. N\'hésitez pas à nous contacter pour toute question ou commande.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 32),

            // Contact Options
            _buildContactCard(
              context,
              icon: Icons.phone,
              title: 'Appelez-nous',
              subtitle: '+225 07 00 00 00 00',
              onTap: () => _makePhoneCall('+2250700000000'),
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            _buildContactCard(
              context,
              icon: Icons.message, // WhatsApp icon usually custom, using message for now
              title: 'WhatsApp',
              subtitle: 'Discutez avec nous',
              onTap: () => _openWhatsApp('2250700000000'),
              color: Colors.green.shade700,
            ),
            const SizedBox(height: 16),
            _buildContactCard(
              context,
              icon: Icons.email,
              title: 'Email',
              subtitle: 'contact@elcorazon.ci',
              onTap: () => _sendEmail('contact@elcorazon.ci'),
              color: Colors.blue,
            ),
            const SizedBox(height: 16),
            _buildContactCard(
              context,
              icon: Icons.location_on,
              title: 'Notre Adresse',
              subtitle: _businessAddress,
              onTap: () {
                _openAddressInMaps(context, _businessAddress);
              },
              color: Colors.red,
            ),
            
            const SizedBox(height: 48),
            
            // Social Media Placeholder
            const Center(
              child: Text(
                'Suivez-nous sur les réseaux sociaux',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSocialButton(Icons.facebook, Colors.blue[800]!, () {}),
                const SizedBox(width: 24),
                _buildSocialButton(Icons.camera_alt, Colors.pink, () {}), // Instagram
                const SizedBox(width: 24),
                _buildSocialButton(Icons.alternate_email, Colors.black, () {}), // X / Twitter
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: color),
      ),
    );
  }
}


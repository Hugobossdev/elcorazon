import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:elcora_fast/config/app_constants.dart';
import 'package:elcora_fast/navigation/app_router.dart';
import 'package:elcora_fast/theme.dart';

/// Les moyens de joindre l'établissement, pour un visiteur non connecté.
///
/// ## Ce que cet écran affichait
///
/// Une adresse à Abidjan, un numéro ivoirien, un WhatsApp sur ce même numéro,
/// une adresse électronique en `.ci`, et trois boutons de réseaux sociaux dont
/// le rappel était `() {}`. L'établissement est à Lomé : le numéro composé
/// aboutissait chez un inconnu, à supposer qu'il existe, et le pays affiché
/// n'était pas le sien.
///
/// Le reste de l'application avait déjà été rassemblé sur [AppConstants] — une
/// seule ville, un seul pays, un seul numéro de support. Cet écran était resté
/// en arrière avec ses valeurs en dur : c'est le genre d'oubli que la
/// centralisation existe pour rendre visible.
///
/// [AppConstants.supportPhone] est vide tant que le vrai numéro n'est pas
/// renseigné, et les gestes qui en dépendent disparaissent alors plutôt que de
/// composer un numéro inventé. Le support écrit, lui, existe pour de bon
/// (`/support/tickets/`) et prend le relais — même choix que l'écran de suivi
/// de livraison.
class GuestContactScreen extends StatelessWidget {
  const GuestContactScreen({super.key});

  /// Ce que Google Maps doit chercher. La ville vient du réglage commun :
  /// l'établissement n'en a qu'une, et elle est à Lomé.
  static const String _businessAddress =
      'El Corazón, ${AppConstants.defaultCityName}';

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

            // Les moyens de contact.
            //
            // Le téléphone et WhatsApp ne s'affichent que si un numéro est
            // réellement configuré. Les deux qui figuraient ici étaient
            // ivoiriens et inventés : mieux vaut ne rien proposer qu'un
            // appel qui sonne chez quelqu'un d'autre.
            if (AppConstants.supportPhone.isNotEmpty) ...[
              _buildContactCard(
                context,
                icon: Icons.phone,
                title: 'Appelez-nous',
                subtitle: AppConstants.supportPhone,
                onTap: () => _makePhoneCall(AppConstants.supportPhone),
                color: Colors.green,
              ),
              const SizedBox(height: 16),
              _buildContactCard(
                context,
                icon: Icons.message,
                title: 'WhatsApp',
                subtitle: 'Discutez avec nous',
                // `wa.me` veut le numéro sans `+` ni séparateurs.
                onTap: () => _openWhatsApp(
                  AppConstants.supportPhone.replaceAll(RegExp(r'[^0-9]'), ''),
                ),
                color: Colors.green.shade700,
              ),
              const SizedBox(height: 16),
            ],

            // Le support écrit existe pour de bon — il est adossé aux tickets
            // (`/support/tickets/`) — mais il demande un compte : le serveur
            // rattache chaque ticket à son auteur, et cet écran n'est montré
            // qu'aux visiteurs **non connectés**. Y envoyer directement
            // remplacerait un numéro qui ne répond pas par un écran qui
            // répond 401.
            //
            // La carte mène donc à la connexion, et le dit.
            _buildContactCard(
              context,
              icon: Icons.support_agent,
              title: 'Écrivez-nous',
              subtitle: 'Connectez-vous pour ouvrir une demande suivie',
              onTap: () => Navigator.of(context).pushNamed(AppRouter.auth),
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            if (AppConstants.supportEmail.isNotEmpty) ...[
              _buildContactCard(
                context,
                icon: Icons.email,
                title: 'Email',
                subtitle: AppConstants.supportEmail,
                onTap: () => _sendEmail(AppConstants.supportEmail),
                color: Colors.blue,
              ),
              const SizedBox(height: 16),
            ],
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

            // Les trois boutons de réseaux sociaux qui suivaient ont été
            // retirés : leur rappel était `() {}`. Un rond qui s'enfonce sous
            // le doigt et ne mène nulle part se lit comme une panne de
            // l'application, alors qu'il n'y avait simplement aucun compte à
            // ouvrir. Ils reviendront le jour où il y aura des adresses à y
            // mettre.
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

}


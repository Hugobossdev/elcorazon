import 'package:flutter/material.dart';

class HelpDialog extends StatelessWidget {
  const HelpDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.9).clamp(400.0, 700.0);
    final dialogHeight = (screenSize.height * 0.8).clamp(500.0, 800.0);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
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
                    Icons.help_outline,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Aide et Support',
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
                    _buildHelpSection(
                      context,
                      'Guide de démarrage',
                      Icons.rocket_launch,
                      [
                        '1. Accédez au Dashboard pour voir un aperçu de votre activité',
                        '2. Gérez vos produits dans la section "Produits"',
                        '3. Suivez les commandes dans la section "Commandes"',
                        '4. Gérez vos livreurs dans la section "Livreurs"',
                        '5. Consultez les statistiques dans "Analytics"',
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildHelpSection(
                      context,
                      'Gestion des Produits',
                      Icons.restaurant,
                      [
                        '• Ajouter un produit : Cliquez sur le bouton "+" dans la barre d\'actions',
                        '• Modifier un produit : Cliquez sur l\'icône de modification',
                        '• Filtrer les produits : Utilisez le bouton de filtre',
                        '• Rechercher : Tapez dans la barre de recherche',
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildHelpSection(
                      context,
                      'Gestion des Commandes',
                      Icons.shopping_cart,
                      [
                        '• Voir les détails : Cliquez sur une commande',
                        '• Changer le statut : Utilisez les boutons d\'action',
                        '• Filtrer par statut : Utilisez les onglets',
                        '• Exporter les données : Utilisez le bouton d\'export',
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildHelpSection(
                      context,
                      'Gestion des Livreurs',
                      Icons.delivery_dining,
                      [
                        '• Ajouter un livreur : Cliquez sur le bouton "+"',
                        '• Suivre en temps réel : Consultez la carte de suivi',
                        '• Voir les performances : Consultez les statistiques',
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildHelpSection(
                      context,
                      'Astuces et Raccourcis',
                      Icons.lightbulb,
                      [
                        '• Utilisez la barre de recherche pour trouver rapidement',
                        '• Les notifications vous alertent des nouvelles commandes',
                        '• Consultez les Analytics pour optimiser vos ventes',
                        '• Utilisez les promotions pour booster vos ventes',
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildContactSection(context),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    constraints: const BoxConstraints(
                      minHeight: 48,
                    ),
                    child: TextButton.icon(
                      onPressed: () {
                        // Ouvrir la documentation
                      },
                      icon: const Icon(Icons.description),
                      label: const Text('Documentation'),
                    ),
                  ),
                  Container(
                    constraints: const BoxConstraints(
                      minHeight: 48,
                    ),
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Fermer'),
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

  Widget _buildHelpSection(
    BuildContext context,
    String title,
    IconData icon,
    List<String> items,
  ) {
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
                Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 6, right: 12),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          item,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildContactSection(BuildContext context) {
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
                Icon(
                  Icons.contact_support,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Besoin d\'aide ?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Si vous avez des questions ou rencontrez des problèmes, contactez notre équipe de support.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: 48,
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Ouvrir l'email
                      },
                      icon: const Icon(Icons.email),
                      label: const Text('Envoyer un email'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: 48,
                    ),
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Ouvrir le chat
                      },
                      icon: const Icon(Icons.chat),
                      label: const Text('Chat en direct'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}




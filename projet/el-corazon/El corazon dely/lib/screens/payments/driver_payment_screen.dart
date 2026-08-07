import 'package:flutter/material.dart';

import 'package:elcora_dely/models/order.dart';

/// Ce que le livreur doit encaisser — **en consultation seule**.
///
/// L'écran précédent faisait saisir au livreur le numéro de carte, la date
/// d'expiration et le CVV du client, puis appelait PayDunya depuis l'appareil
/// avec les clés marchandes. Trois conséquences en découlaient :
///
/// * les clés voyageaient dans chaque téléphone de la flotte ;
/// * un livreur manipulait des données de carte, ce qu'aucune application non
///   certifiée ne doit faire ;
/// * l'application décidait qu'un paiement avait abouti.
///
/// Aucune des trois n'a de contrepartie côté serveur, et c'est délibéré. Le
/// client règle depuis son application (`POST /payments/{commande}/initiate/`),
/// ou en espèces à la livraison. Le statut du règlement est écrit par le
/// webhook signé du prestataire, jamais par un client.
///
/// Il reste donc au livreur la seule question qui le concerne : **combien
/// dois-je encaisser en arrivant ?**
class DriverPaymentScreen extends StatelessWidget {
  const DriverPaymentScreen({
    required this.order, required this.amount, super.key,
  });

  final Order order;
  final double amount;

  bool get _enEspeces => order.paymentMethod == PaymentMethod.cash;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Encaissement')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      _enEspeces
                          ? Icons.payments_outlined
                          : Icons.verified_outlined,
                      size: 48,
                      color: _enEspeces ? scheme.primary : scheme.tertiary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _enEspeces ? 'À encaisser' : 'Déjà réglée',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _enEspeces
                          ? '${amount.toStringAsFixed(0)} FCFA'
                          : order.paymentMethod.displayName,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ligne(theme, 'Commande', '#${_reference()}'),
                    _ligne(theme, 'Adresse', order.deliveryAddress),
                    _ligne(
                      theme,
                      'Mode de règlement',
                      order.paymentMethod.displayName,
                    ),
                    _ligne(
                      theme,
                      'Total',
                      '${order.total.toStringAsFixed(0)} FCFA',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 20, color: scheme.outline),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _enEspeces
                          ? 'Encaissez le montant à la remise, puis marquez la '
                                'course comme livrée.'
                          : "Cette commande a été réglée depuis l'application du "
                                "client. Vous n'avez rien à encaisser.",
                      style: theme.textTheme.bodySmall,
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

  /// Référence courte, lisible à voix haute au téléphone.
  String _reference() =>
      order.id.length <= 8 ? order.id : order.id.substring(0, 8).toUpperCase();

  Widget _ligne(ThemeData theme, String libelle, String valeur) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              libelle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              valeur,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

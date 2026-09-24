import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:admin/presentation/echec.dart';
import 'package:admin/services/payments_service.dart';
import 'package:admin/utils/dialog_helper.dart';
import 'package:admin/utils/price_formatter.dart';

/// Le remboursement d'une commande, depuis sa fiche.
///
/// Pourquoi ce fichier existe
/// --------------------------
///
/// Le remboursement était écrit, complet, et **injoignable**. Deux raisons se
/// cumulaient :
///
/// 1. il vivait dans `order_management_screen`, un écran qu'aucune entrée de
///    navigation n'ouvre — on n'y arrivait qu'en cliquant un résultat de la
///    recherche transverse, laquelle ouvrait la liste entière et non la
///    commande cherchée ;
/// 2. il sélectionnait l'encaissement à rembourser avec `status == 'succeeded'`.
///    Ce mot n'existe nulle part dans le contrat : `PaymentStatus`
///    (`backend/apps/payments/models.py`) connaît `pending`, `processing`,
///    `completed`, `failed`, `cancelled` et `refunded`. Le filtre ne renvoyait
///    donc jamais rien, et l'écran répondait « aucun encaissement abouti sur
///    cette commande » — sur des commandes payées.
///
/// Ce que ce dialogue ne fait pas, et ne peut pas faire : joindre le
/// prestataire. Les clés marchandes sont côté serveur, qui vérifie le
/// rattachement de la commande au périmètre du compte et applique l'invariant
/// P3 — la somme des remboursements d'une transaction ne dépasse jamais ce
/// qu'elle a encaissé. Le message d'erreur du serveur est affiché **tel quel**
/// plutôt que reformulé : il dit exactement combien reste remboursable.
Future<bool> rembourserCommande({
  required BuildContext context,
  required eccore.Order order,
  required List<eccore.Transaction> encaissements,
}) async {
  final aboutis = encaissements.where((t) => t.status == statutEncaisse).toList();

  if (aboutis.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Aucun encaissement abouti sur cette commande : il n’y a rien à '
          'rembourser.',
        ),
      ),
    );
    return false;
  }

  final demande = await DialogHelper.showSafeDialog<eccore.Refund>(
    context: context,
    builder: (context) => _RemboursementCommande(
      order: order,
      encaissements: aboutis,
    ),
  );

  if (demande == null) return false;
  if (!context.mounted) return true;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Remboursement de ${formatMontant(demande.amount)} enregistré.'),
      backgroundColor: Theme.of(context).colorScheme.inverseSurface,
    ),
  );
  return true;
}

/// La valeur que le serveur donne à un encaissement abouti — `PaymentStatus`.
const String statutEncaisse = 'completed';

class _RemboursementCommande extends StatefulWidget {
  const _RemboursementCommande({
    required this.order,
    required this.encaissements,
  });

  final eccore.Order order;
  final List<eccore.Transaction> encaissements;

  @override
  State<_RemboursementCommande> createState() => _RemboursementCommandeState();
}

class _RemboursementCommandeState extends State<_RemboursementCommande> {
  late eccore.Transaction _transaction = widget.encaissements.first;
  late final TextEditingController _montant = TextEditingController(
    text: _enSaisie(_transaction.amount.toMajorUnits()),
  );

  String get _devise => _transaction.amount.currency;
  bool _enCours = false;
  Echec? _echec;
  final _motif = TextEditingController();

  @override
  void dispose() {
    _montant.dispose();
    _motif.dispose();
    super.dispose();
  }

  double get _plafond => _transaction.amount.toMajorUnits();

  /// Un montant majeur tel qu'on le saisit, avec les décimales de la devise
  /// de l'encaissement.
  String _enSaisie(double montant) => montantPourSaisie(montant, _devise);

  /// Exécute le remboursement **avant** de fermer : un refus du serveur
  /// s'affiche dans le dialogue, la saisie intacte.
  Future<void> _rembourser() async {
    final montant = eccore.Money.fromMajorUnits(_saisi!, _transaction.amount.currency);
    setState(() {
      _enCours = true;
      _echec = null;
    });
    try {
      final rembourse = await context.read<PaymentsService>().refund(
            orderId: widget.order.id,
            transactionId: _transaction.id,
            amount: montant,
            reason: _motif.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(rembourse);
    } on eccore.ApiException catch (e) {
      if (mounted) setState(() => _echec = Echec.de(e));
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  double? get _saisi {
    final valeur = double.tryParse(_montant.text.replaceAll(',', '.'));
    if (valeur == null || valeur <= 0) return null;
    return valeur;
  }

  /// Le plafond est vérifié ici **et** côté serveur, et ce n'est pas une
  /// redondance inutile : celui du serveur tient compte des remboursements
  /// déjà passés, que cet écran ne connaît pas. Celui-ci évite seulement
  /// l'aller-retour évident — saisir plus que l'encaissement lui-même.
  bool get _valide {
    final montant = _saisi;
    return montant != null && montant <= _plafond && _motif.text.trim().length >= 3;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final largeur = (MediaQuery.of(context).size.width * 0.9).clamp(400.0, 560.0);

    return Dialog(
      child: SizedBox(
        width: largeur,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.currency_exchange, color: scheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Rembourser ${widget.order.reference}',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Le choix de l'encaissement n'est offert que s'il y en a
                    // plusieurs — un paiement partagé. « Rembourser la
                    // commande » sans dire lequel ne voudrait rien dire, mais
                    // choisir dans une liste d'un seul élément non plus.
                    if (widget.encaissements.length > 1) ...[
                      DropdownButtonFormField<String>(
                        initialValue: _transaction.id,
                        decoration: const InputDecoration(
                          labelText: 'Encaissement à rembourser',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final transaction in widget.encaissements)
                            DropdownMenuItem(
                              value: transaction.id,
                              child: Text(
                                '${formatMontant(transaction.amount)}'
                                ' · ${transaction.provider}',
                              ),
                            ),
                        ],
                        onChanged: (id) {
                          if (id == null) return;
                          setState(() {
                            _transaction =
                                widget.encaissements.firstWhere((t) => t.id == id);
                            _montant.text =
                                _enSaisie(_transaction.amount.toMajorUnits());
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      'Encaissé : ${formatMontant(_transaction.amount)}'
                      '${_transaction.providerReference.isEmpty ? '' : ' · réf. ${_transaction.providerReference}'}',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _montant,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Montant à rembourser',
                        // La devise de l'encaissement choisi : un « CFA »
                        // écrit ici s'affichait aussi sous un paiement en GHS.
                        suffixText: _devise,
                        border: const OutlineInputBorder(),
                        errorText: _montant.text.isEmpty || _saisi != null
                            ? (_saisi != null && _saisi! > _plafond
                                ? 'Au-delà de l’encaissement '
                                    '(${formatMontant(_transaction.amount)}).'
                                : null)
                            : 'Montant illisible.',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ActionChip(
                          label: const Text('Total'),
                          onPressed: () => setState(() {
                            _montant.text = _enSaisie(_plafond);
                          }),
                        ),
                        ActionChip(
                          label: const Text('Moitié'),
                          onPressed: () => setState(() {
                            _montant.text = _enSaisie(eccore.Money.fromMajorUnits(_plafond / 2, _transaction.amount.currency).toMajorUnits());
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _motif,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Motif du remboursement',
                        helperText: 'Exigé par le serveur : un remboursement sans '
                            'raison est un écart de caisse.',
                        helperMaxLines: 2,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              if (_echec != null) BandeauEchec(echec: _echec!),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _enCours ? null : () => Navigator.of(context).pop(),
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _valide && !_enCours ? () => unawaited(_rembourser()) : null,
                      child: _enCours
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Rembourser'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

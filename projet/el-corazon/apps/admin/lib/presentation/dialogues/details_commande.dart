import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:admin/presentation/anciennete_commande.dart';
import 'package:admin/presentation/commande.dart';
import 'package:admin/presentation/dialogues/annulation_commande.dart';
import 'package:admin/presentation/dialogues/remboursement_commande.dart';
import 'package:admin/services/assignment_service.dart';
import 'package:admin/services/order_management_service.dart';
import 'package:admin/services/payments_service.dart';
import 'package:admin/ui/ui.dart';
import 'package:admin/utils/dialog_helper.dart';
import 'package:admin/utils/price_formatter.dart';
import 'package:admin/widgets/order_timeline_widget.dart';

/// Le détail d'une commande, ouvert depuis la liste du back-office.
///
/// Pourquoi ce fichier a été repris
/// --------------------------------
///
/// Il affichait la commande **telle que la liste la portait**, et la liste ne
/// porte pas grand-chose. `GET /orders/manage/` rend `OrderSerializer`, où ne
/// figurent ni `lines` ni `status_events` — ces deux champs n'existent que sur
/// `OrderDetailSerializer`, c'est-à-dire sur `GET /orders/manage/{id}/`. La
/// fiche recevait donc systématiquement une commande sans lignes, et affichait
/// « Aucun article trouvé dans cette commande » sur toutes, y compris celles de
/// dix plats. **Le back-office ne permettait pas de savoir ce qui avait été
/// commandé.**
///
/// Trois autres manques suivaient du même endroit, et le cahier des charges les
/// nomme un par un : le client, le paiement et le livreur.
///
/// * le **client** était sur la commande depuis le début (`recipient_name`,
///   `recipient_phone`) et n'était simplement pas affiché ;
/// * le **paiement** demande les transactions de la commande
///   (`/payments/transactions/?order=…`), une seconde lecture ;
/// * le **livreur** demande la course (`/delivery/manage/assignments/`), parce
///   que la commande ne le connaît pas et ne le connaîtra pas — `apps.orders`
///   ne dépend pas d'`apps.delivery`.
///
/// D'où un dialogue avec état : il ouvre immédiatement sur ce que la liste sait
/// déjà, puis complète chaque bloc à mesure que les trois lectures reviennent.
/// L'inverse — attendre les trois avant d'afficher quoi que ce soit — ferait
/// patienter devant un écran vide pour lire un numéro de téléphone.
void afficherDetailsCommande(BuildContext context, eccore.Order order) {
  DialogHelper.showSafeDialog(
    context: context,
    builder: (context) => _DetailsCommande(apercu: order),
  );
}

class _DetailsCommande extends StatefulWidget {
  const _DetailsCommande({required this.apercu});

  /// La commande telle que la liste la connaît : sans ses lignes.
  final eccore.Order apercu;

  @override
  State<_DetailsCommande> createState() => _DetailsCommandeState();
}

class _DetailsCommandeState extends State<_DetailsCommande> {
  eccore.Order? _detail;
  eccore.Assignment? _course;
  List<eccore.Transaction> _encaissements = const [];
  bool _chargement = true;

  eccore.Order get _commande => _detail ?? widget.apercu;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  Future<void> _charger() async {
    final commandes = context.read<OrderManagementService>();
    final courses = context.read<AssignmentService>();
    final paiements = context.read<PaymentsService>();

    // Les trois lectures en parallèle : elles ne dépendent pas les unes des
    // autres, et les enchaîner tripleraient l'attente pour rien.
    final resultats = await Future.wait([
      commandes.loadDetail(widget.apercu.id),
      courses.loadFor(widget.apercu.id),
      paiements.transactionsOf(widget.apercu.id),
    ]);

    if (!mounted) return;
    setState(() {
      _detail = resultats[0] as eccore.Order?;
      _course = resultats[1] as eccore.Assignment?;
      _encaissements = resultats[2]! as List<eccore.Transaction>;
      _chargement = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ecran = MediaQuery.of(context).size;
    final scheme = Theme.of(context).colorScheme;
    final commande = _commande;

    return Dialog(
      child: SizedBox(
        width: (ecran.width * 0.9).clamp(500.0, 900.0),
        height: (ecran.height * 0.85).clamp(500.0, 900.0),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          // La référence plutôt que huit caractères d'UUID :
                          // c'est elle que le client donne au téléphone.
                          'Commande ${commande.reference}',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${commande.restaurantName} · '
                          '${ancienneteCommande(commande.passeeLe)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_chargement)
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Informations(order: commande),
                    const SizedBox(height: 16),
                    _Destinataire(order: commande),
                    const SizedBox(height: 16),
                    if (commande.lines.isNotEmpty)
                      _ArticlesCommandes(order: commande)
                    else
                      _AucunArticle(chargement: _chargement),
                    const SizedBox(height: 16),
                    _AdresseLivraison(order: commande),
                    const SizedBox(height: 16),
                    _Livreur(course: _course, chargement: _chargement),
                    const SizedBox(height: 16),
                    _Encaissements(
                      transactions: _encaissements,
                      chargement: _chargement,
                    ),
                    if (commande.statusEvents.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      // `OrderTimelineWidget` plutôt qu'une chronologie
                      // maison : il existait déjà, il s'appuie sur
                      // `chronologie_commande.dart` — dont les règles sont
                      // testées — et il était orphelin depuis que l'écran de
                      // supervision secondaire a été retiré. Deux
                      // chronologies pour la même commande finiraient par ne
                      // plus dire la même chose.
                      OrderTimelineWidget(order: commande),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            _BarreDActions(
              order: commande,
              encaissements: _encaissements,
              onFait: () {
                if (mounted) Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Une étiquette de largeur fixe, puis sa valeur.
class LigneDeDetail extends StatelessWidget {
  const LigneDeDetail({required this.label, required this.valeur, super.key});

  final String label;
  final String valeur;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              valeur,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un bloc encadré, avec son titre et son icône.
class _Bloc extends StatelessWidget {
  const _Bloc({
    required this.titre,
    required this.icone,
    required this.enfants,
    this.couleur,
  });

  final String titre;
  final IconData icone;
  final List<Widget> enfants;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: couleur ?? scheme.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                titre,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...enfants,
        ],
      ),
    );
  }
}

class _Informations extends StatelessWidget {
  const _Informations({required this.order});

  final eccore.Order order;

  @override
  Widget build(BuildContext context) {
    final nombre = order.lines.length;

    return _Bloc(
      titre: 'Informations',
      icone: Icons.info_outline,
      enfants: [
        LigneDeDetail(label: 'Statut', valeur: order.statut.libelle),
        LigneDeDetail(
          label: 'Sous-total',
          valeur: PriceFormatter.format(order.sousTotalAffiche),
        ),
        LigneDeDetail(
          label: 'Livraison',
          valeur: PriceFormatter.format(order.fraisLivraisonAffiches),
        ),
        // La remise n'apparaît que s'il y en a une : une ligne « Remise :
        // 0 CFA » sur chaque commande fait chercher un code promo inexistant.
        if (order.remiseAffichee != 0)
          LigneDeDetail(
            label: 'Remise',
            valeur: '− ${PriceFormatter.format(order.remiseAffichee)}',
          ),
        LigneDeDetail(
          label: 'Total',
          valeur: PriceFormatter.format(order.totalAffiche),
        ),
        if (nombre > 0)
          LigneDeDetail(
            label: 'Articles',
            valeur: '$nombre ligne${nombre > 1 ? 's' : ''}',
          ),
        LigneDeDetail(
          label: 'Moyen de paiement',
          valeur: order.moyenPaiement.libelle,
        ),
        if (order.estimatedDeliveryAt != null)
          LigneDeDetail(
            label: 'Annoncée pour',
            valeur: _horodatage(order.estimatedDeliveryAt!),
          ),
        if (order.deliveredAt != null)
          LigneDeDetail(
            label: 'Livrée le',
            valeur: _horodatage(order.deliveredAt!),
          ),
        if (order.cancelledAt != null)
          LigneDeDetail(
            label: 'Annulée le',
            valeur: _horodatage(order.cancelledAt!),
          ),
        if (order.cancellationReason.isNotEmpty)
          LigneDeDetail(
            label: "Motif d'annulation",
            valeur: order.cancellationReason,
          ),
      ],
    );
  }
}

/// Le destinataire — celui qu'on appelle si la livraison coince.
///
/// Ce bloc n'existait pas. Le nom et le téléphone étaient sur la commande
/// depuis le premier jour ; la fiche ne les affichait simplement pas, si bien
/// qu'un opérateur ayant une commande à débloquer ne pouvait joindre personne
/// depuis l'écran qui la montre.
class _Destinataire extends StatelessWidget {
  const _Destinataire({required this.order});

  final eccore.Order order;

  @override
  Widget build(BuildContext context) {
    return _Bloc(
      titre: 'Destinataire',
      icone: Icons.person_outline,
      enfants: [
        LigneDeDetail(
          label: 'Nom',
          valeur: order.recipientName.isEmpty ? 'Non renseigné' : order.recipientName,
        ),
        LigneDeDetail(
          label: 'Téléphone',
          valeur: order.recipientPhone.isEmpty ? 'Non renseigné' : order.recipientPhone,
        ),
        if (order.consignes case final consignes?)
          LigneDeDetail(label: 'Consignes', valeur: consignes),
      ],
    );
  }
}

/// Qui porte la commande.
///
/// Lu sur la course, pas sur la commande : le sérialiseur de supervision ne
/// rend pas le livreur, et ne le rendra pas.
class _Livreur extends StatelessWidget {
  const _Livreur({required this.course, required this.chargement});

  final eccore.Assignment? course;
  final bool chargement;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final course = this.course;

    if (course == null) {
      return _Bloc(
        titre: 'Livreur',
        icone: Icons.delivery_dining_outlined,
        enfants: [
          Text(
            chargement
                ? 'Lecture de la course…'
                : 'Aucun livreur affecté pour le moment.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      );
    }

    return _Bloc(
      titre: 'Livreur',
      icone: Icons.delivery_dining_outlined,
      enfants: [
        LigneDeDetail(label: 'Nom', valeur: course.courier.fullName),
        LigneDeDetail(label: 'Véhicule', valeur: course.courier.vehicleType),
        LigneDeDetail(label: 'État de la course', valeur: _etat(course.status)),
        if (course.acceptedAt != null)
          LigneDeDetail(
            label: 'Acceptée le',
            valeur: _horodatage(course.acceptedAt!),
          ),
        if (course.pickedUpAt != null)
          LigneDeDetail(
            label: 'Récupérée le',
            valeur: _horodatage(course.pickedUpAt!),
          ),
      ],
    );
  }

  static String _etat(String status) => switch (status) {
        eccore.DeliveryStatus.offered => 'Proposée, en attente de réponse',
        eccore.DeliveryStatus.accepted => 'Acceptée',
        eccore.DeliveryStatus.pickedUp => 'Commande récupérée',
        eccore.DeliveryStatus.onTheWay => 'En route',
        eccore.DeliveryStatus.delivered => 'Livrée',
        eccore.DeliveryStatus.declined => 'Refusée',
        eccore.DeliveryStatus.cancelled => 'Annulée',
        _ => status,
      };
}

/// Les encaissements de la commande.
///
/// Consultation seule, et c'est structurel : le statut d'une transaction
/// n'avance que sur webhook signé du prestataire (`apps/payments/services.py`).
/// Aucun geste de cet écran ne peut le changer — le remboursement lui-même crée
/// un objet distinct et laisse l'encaissement d'origine intact.
class _Encaissements extends StatelessWidget {
  const _Encaissements({required this.transactions, required this.chargement});

  final List<eccore.Transaction> transactions;
  final bool chargement;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (transactions.isEmpty) {
      return _Bloc(
        titre: 'Encaissement',
        icone: Icons.receipt_long_outlined,
        enfants: [
          Text(
            chargement
                ? 'Lecture des transactions…'
                : 'Aucune transaction : commande réglée à la livraison, ou '
                    'paiement jamais engagé.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      );
    }

    return _Bloc(
      titre: 'Encaissement',
      icone: Icons.receipt_long_outlined,
      enfants: [
        for (final transaction in transactions) ...[
          LigneDeDetail(
            label: libelleStatutPaiement(transaction.status),
            valeur: '${PriceFormatter.format(transaction.amount.toMajorUnits())}'
                ' · ${transaction.provider}',
          ),
          if (transaction.providerReference.isNotEmpty)
            LigneDeDetail(
              label: 'Référence',
              valeur: transaction.providerReference,
            ),
          LigneDeDetail(
            label: 'Date',
            valeur: _horodatage(transaction.completedAt ?? transaction.createdAt),
          ),
          if (transaction.failureReason.isNotEmpty)
            LigneDeDetail(label: 'Échec', valeur: transaction.failureReason),
          const SizedBox(height: 4),
        ],
      ],
    );
  }
}

class _ArticlesCommandes extends StatelessWidget {
  const _ArticlesCommandes({required this.order});

  final eccore.Order order;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Articles commandés',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outline.withValues(alpha: 0.25)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              for (final item in order.lines) _LigneArticle(item: item),
            ],
          ),
        ),
      ],
    );
  }
}

class _LigneArticle extends StatelessWidget {
  const _LigneArticle({required this.item});

  final eccore.OrderLine item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final personnalisations = item.personnalisations;

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VignetteArticle(image: item.itemImage ?? ''),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName.isEmpty ? 'Article' : item.itemName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.quantity}x ${PriceFormatter.format(item.prixUnitaireAffiche)} '
                  '= ${PriceFormatter.format(item.prixTotalAffiche)}',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
                if (personnalisations.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  for (final choix in personnalisations)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        '• $choix',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.primary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
                if (item.note case final note?) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Note: $note',
                    style: TextStyle(
                      fontSize: 10,
                      color: scheme.onTertiaryContainer,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            PriceFormatter.format(item.prixTotalAffiche),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _VignetteArticle extends StatelessWidget {
  const _VignetteArticle({required this.image});

  final String image;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final substitut = Icon(
      Icons.fastfood,
      size: 20,
      color: scheme.onSurfaceVariant,
    );

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: image.isEmpty
          ? substitut
          : ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                image,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => substitut,
              ),
            ),
    );
  }
}

/// Ce qui s'affiche à la place des articles.
///
/// Deux messages distincts pour deux situations distinctes. Le message unique
/// d'avant — « Aucun article trouvé dans cette commande » — s'affichait pendant
/// la lecture **et** après, et surtout il s'affichait toujours, puisque la
/// fiche ne lisait jamais la forme détaillée. Une commande réellement vide
/// n'existe pas : le serveur refuse un panier sans ligne.
class _AucunArticle extends StatelessWidget {
  const _AucunArticle({required this.chargement});

  final bool chargement;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (chargement) {
      return Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            'Chargement des articles…',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, size: 16, color: scheme.onTertiaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Les articles n’ont pas pu être lus. Réessayez, ou vérifiez que '
              'ce compte a bien la permission « orders.read ».',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onTertiaryContainer,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdresseLivraison extends StatelessWidget {
  const _AdresseLivraison({required this.order});

  final eccore.Order order;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return _Bloc(
      titre: 'Adresse de livraison',
      icone: Icons.location_on_outlined,
      couleur: scheme.primaryContainer,
      enfants: [
        SelectableText(
          order.adresseComplete,
          style: TextStyle(fontSize: 12, color: scheme.onSurface),
        ),
      ],
    );
  }
}

/// Les gestes possibles depuis la fiche.
///
/// Le pied de page n'offrait que « Fermer ». L'annulation et le remboursement
/// existaient tous deux côté service, avec leur permission et leur route, et
/// n'étaient joignables depuis aucun écran atteignable par la navigation.
class _BarreDActions extends StatelessWidget {
  const _BarreDActions({
    required this.order,
    required this.encaissements,
    required this.onFait,
  });

  final eccore.Order order;
  final List<eccore.Transaction> encaissements;
  final VoidCallback onFait;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final danger = AdminColorTokens.semantic(scheme).danger;

    final annulable = order.allowedTransitions.contains('cancelled');
    final remboursable = encaissements.any((t) => t.status == statutEncaisse);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (remboursable)
            TextButton.icon(
              icon: const Icon(Icons.currency_exchange, size: 18),
              label: const Text('Rembourser'),
              onPressed: () async {
                final fait = await rembourserCommande(
                  context: context,
                  order: order,
                  encaissements: encaissements,
                );
                if (fait) onFait();
              },
            ),
          const Spacer(),
          if (annulable)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: danger),
              onPressed: () async {
                final fait = await annulerCommande(
                  context: context,
                  order: order,
                  orderService: context.read<OrderManagementService>(),
                );
                if (fait) onFait();
              },
              child: const Text('Annuler la commande'),
            ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}

/// Libellé français d'un statut de transaction.
String libelleStatutPaiement(String statut) => switch (statut) {
      'pending' => 'En attente',
      'processing' => 'En cours',
      'completed' => 'Encaissé',
      'failed' => 'Échoué',
      'cancelled' => 'Annulé',
      'refunded' => 'Remboursé',
      _ => statut,
    };

/// Un horodatage lisible : `12/08/2026 à 19:42`.
///
/// En heure **locale** du poste : l'API rend de l'UTC, et « livrée à 19:42 »
/// affiché en UTC décale d'une heure toute lecture faite depuis Lomé.
String _horodatage(DateTime moment) {
  final local = moment.toLocal();
  String deuxChiffres(int valeur) => valeur.toString().padLeft(2, '0');
  return '${deuxChiffres(local.day)}/${deuxChiffres(local.month)}/${local.year}'
      ' à ${deuxChiffres(local.hour)}:${deuxChiffres(local.minute)}';
}

import 'package:flutter/material.dart';
import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/navigation/app_router.dart';
import 'package:elcora_fast/presentation/suivi_commande.dart';
import 'package:elcora_fast/repositories/django_order_repository.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/utils/price_formatter.dart';
import 'package:elcora_fast/widgets/design/design.dart';
import 'package:elcora_fast/widgets/navigation_helper.dart';
import 'package:elcorazon_core/elcorazon_core.dart' show ApiException, Journal;

/// Détail d'une commande.
///
/// ## Le défaut que cette refonte corrige
///
/// L'écran recevait un `Order` **en argument de route** et ne le relisait
/// jamais. Le statut affiché était donc celui du moment où la liste avait été
/// chargée : on ouvrait « En préparation » sur une commande livrée depuis
/// vingt minutes. Or la maquette `order_details` met précisément une
/// **chronologie de statut** au premier plan — l'information la plus
/// périssable de l'écran.
///
/// La commande reçue sert désormais de premier rendu — l'écran s'ouvre plein,
/// sans attente — et `GET /orders/{id}/` la remplace dès qu'il répond. Une
/// panne de réseau laisse la version connue à l'affichage, avec un bandeau qui
/// le dit, plutôt qu'un écran vide.
///
/// ## Trois données que l'adaptateur jetait
///
/// Corrigées dans `django_order_repository.dart`, elles arrivent enfin ici :
///
/// * `reference` — le numéro lisible (« EC-4921 ») que le support demande au
///   téléphone. L'écran affichait les huit premiers caractères de l'UUID ;
/// * `statusEvents` — chaque changement de statut avec son horodatage, ce qui
///   donne à la chronologie ses heures réelles ;
/// * les `options` de chaque ligne — « sans oignons » avait traversé tout le
///   chemin du panier au serveur pour être jeté à la dernière marche.
class OrderDetailsScreen extends StatefulWidget {
  final Order order;

  const OrderDetailsScreen({
    required this.order,
    super.key,
  });

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  late Order _commande;
  bool _relecture = false;
  bool _relectureEchouee = false;

  @override
  void initState() {
    super.initState();
    _commande = widget.order;
    WidgetsBinding.instance.addPostFrameCallback((_) => _relire());
  }

  Future<void> _relire() async {
    if (!mounted) return;
    setState(() {
      _relecture = true;
      _relectureEchouee = false;
    });

    try {
      final fraiche = await DjangoOrderRepository().getOrderById(_commande.id);
      if (!mounted) return;
      setState(() {
        // `null` = 404 : la commande n'est plus visible. On garde ce qu'on
        // avait plutôt que de vider l'écran — c'est encore ce que le client a
        // vu de plus récent.
        if (fraiche != null) _commande = fraiche;
        _relecture = false;
      });
    } on ApiException catch (e) {
      Journal.trace('Relecture de la commande ${_commande.id}: ${e.code}');
      if (!mounted) return;
      setState(() {
        _relecture = false;
        _relectureEchouee = true;
      });
    } catch (e) {
      Journal.trace('Relecture de la commande ${_commande.id}: $e');
      if (!mounted) return;
      setState(() {
        _relecture = false;
        _relectureEchouee = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: GlassAppBar(
        title: 'Commande ${_reference()}',
        actions: [
          GlassIconButton(
            icon: Icons.help_outline_rounded,
            tooltip: 'Aide sur cette commande',
            filled: false,
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRouter.support),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _relire,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            DesignConstants.edgeMargin,
            DesignConstants.spacingM,
            DesignConstants.edgeMargin,
            DesignConstants.spacingXL,
          ),
          children: [
            if (_relectureEchouee) ...[
              _bandeauHorsLigne(theme),
              const SizedBox(height: DesignConstants.spacingM),
            ],
            _chronologie(theme),
            const SizedBox(height: DesignConstants.spacingL),
            _livraison(theme),
            const SizedBox(height: DesignConstants.spacingL),
            _articles(theme),
            const SizedBox(height: DesignConstants.spacingL),
            _recapitulatif(theme),
            const SizedBox(height: DesignConstants.spacingL),
            ..._actions(theme),
          ],
        ),
      ),
    );
  }

  /// La référence du serveur, ou le début de l'identifiant à défaut.
  String _reference() {
    if (_commande.reference.isNotEmpty) return '#${_commande.reference}';
    if (_commande.id.isEmpty) return '#—';
    final court =
        _commande.id.length <= 8 ? _commande.id : _commande.id.substring(0, 8);
    return '#${court.toUpperCase()}';
  }

  Widget _bandeauHorsLigne(ThemeData theme) {
    return SectionCard(
      color: theme.colorScheme.errorContainer,
      shadow: false,
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: DesignConstants.iconSizeMedium,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: DesignConstants.spacingM),
          Expanded(
            child: Text(
              'Statut non actualisé — voici la dernière version connue. '
              'Tirez vers le bas pour réessayer.',
              style: AppTypography.bodyMd(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------- chronologie

  /// Les quatre jalons de la maquette, marqués depuis le statut **réel**.
  ///
  /// L'horodatage de chaque étape vient de `statusEvents` quand le serveur
  /// l'a enregistrée. Une étape franchie sans événement correspondant reste
  /// cochée sans heure : on sait qu'elle a eu lieu, on ne prétend pas savoir
  /// quand.
  Widget _chronologie(ThemeData theme) {
    final etapes = etapesDeSuivi(_commande);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: SectionHeader(title: 'Suivi')),
            if (_relecture)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: DesignConstants.spacingS),
        SectionCard(
          child: Column(
            children: [
              for (var i = 0; i < etapes.length; i++)
                _jalon(theme, etapes[i], dernier: i == etapes.length - 1),
            ],
          ),
        ),
      ],
    );
  }

  Widget _jalon(ThemeData theme, EtapeDeSuivi etape, {required bool dernier}) {
    final Color teinte;
    if (etape.annulation) {
      teinte = theme.colorScheme.error;
    } else if (etape.franchie) {
      teinte = AppColors.success;
    } else {
      teinte = theme.colorScheme.outlineVariant;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: etape.franchie || etape.annulation
                      ? teinte
                      : theme.colorScheme.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  etape.annulation
                      ? Icons.close_rounded
                      : etape.franchie
                          ? Icons.check_rounded
                          : _icone(etape.jalon),
                  size: 16,
                  color: etape.franchie || etape.annulation
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (!dernier)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: etape.franchie
                        ? teinte
                        : theme.colorScheme.outlineVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(width: DesignConstants.spacingM),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: dernier ? 0 : DesignConstants.spacingL,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          etape.annulation
                              ? libelleDeSortie(_commande.status)
                              : etape.jalon.libelle,
                          style: AppTypography.titleLg(
                            color: etape.franchie || etape.annulation
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (etape.horodatage != null)
                        Text(
                          _heure(etape.horodatage!),
                          style: AppTypography.bodyMd(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  if (etape.courante && !etape.annulation) ...[
                    const SizedBox(height: 2),
                    Text(
                      etape.jalon.description,
                      style: AppTypography.bodyMd(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
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

  // ------------------------------------------------------------- livraison

  Widget _livraison(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Livraison'),
        const SizedBox(height: DesignConstants.spacingS),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ligneInfo(
                theme,
                Icons.location_on_outlined,
                'Adresse',
                _commande.deliveryAddress.isEmpty
                    ? 'Adresse non renseignée'
                    : _commande.deliveryAddress,
              ),
              if (_commande.estimatedDeliveryTime != null) ...[
                const SizedBox(height: DesignConstants.spacingM),
                _ligneInfo(
                  theme,
                  Icons.schedule_rounded,
                  'Arrivée estimée',
                  _heure(_commande.estimatedDeliveryTime!),
                ),
              ],
              if ((_commande.deliveryNotes ?? '').isNotEmpty) ...[
                const SizedBox(height: DesignConstants.spacingM),
                _ligneInfo(
                  theme,
                  Icons.sticky_note_2_outlined,
                  'Consignes',
                  _commande.deliveryNotes!,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _ligneInfo(
    ThemeData theme,
    IconData icone,
    String libelle,
    String valeur,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icone,
          size: DesignConstants.iconSizeMedium,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: DesignConstants.spacingM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                libelle,
                style: AppTypography.labelLg(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                valeur,
                style: AppTypography.bodyLg(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------- articles

  Widget _articles(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Articles',
          subtitle: _commande.items.length <= 1
              ? '${_commande.items.length} article'
              : '${_commande.items.length} articles',
        ),
        const SizedBox(height: DesignConstants.spacingS),
        SectionCard(
          child: Column(
            children: [
              for (var i = 0; i < _commande.items.length; i++) ...[
                _ligneArticle(theme, _commande.items[i]),
                if (i < _commande.items.length - 1)
                  Divider(
                    height: DesignConstants.spacingL,
                    color:
                        theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _ligneArticle(ThemeData theme, OrderItem article) {
    // Les options du serveur, groupe par groupe — « Cuisson : bien cuit ».
    final options = article.customizations.entries
        .where((e) => e.value.trim().isNotEmpty)
        .map((e) => '${e.key} : ${e.value}')
        .toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignConstants.spacingS,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: DesignConstants.borderRadiusSmall,
          ),
          child: Text(
            '${article.quantity}×',
            style: AppTypography.labelLg(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: DesignConstants.spacingM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                article.name,
                style: AppTypography.titleLg(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              for (final option in options) ...[
                const SizedBox(height: 2),
                Text(
                  option,
                  style: AppTypography.bodyMd(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if ((article.notes ?? '').isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  article.notes!,
                  style: AppTypography.bodyMd(
                    color: theme.colorScheme.onSurfaceVariant,
                  ).copyWith(fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: DesignConstants.spacingS),
        Text(
          PriceFormatter.format(article.totalPrice),
          style: AppTypography.titleLg(color: theme.colorScheme.onSurface),
        ),
      ],
    );
  }

  // --------------------------------------------------------- récapitulatif

  Widget _recapitulatif(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Récapitulatif'),
        const SizedBox(height: DesignConstants.spacingS),
        SectionCard(
          child: Column(
            children: [
              SummaryRow(
                label: 'Sous-total',
                value: PriceFormatter.format(_commande.subtotal),
              ),
              SummaryRow(
                label: 'Frais de livraison',
                value: PriceFormatter.format(_commande.deliveryFee),
              ),
              if (_commande.discount > 0)
                SummaryRow(
                  // Le code promotionnel n'est pas porté par la commande — le
                  // serveur ne le publie pas sur `OrderSerializer`. Le montant,
                  // lui, est exact : c'est celui qui a été déduit.
                  label: (_commande.promoCode ?? '').isEmpty
                      ? 'Remise'
                      : 'Remise (${_commande.promoCode})',
                  value: '-${PriceFormatter.format(_commande.discount)}',
                  isDiscount: true,
                ),
              const SummaryDivider(),
              SummaryRow(
                label: 'Total',
                value: PriceFormatter.format(_commande.total),
                isTotal: true,
              ),
              const SizedBox(height: DesignConstants.spacingM),
              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: DesignConstants.iconSizeSmall,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: DesignConstants.spacingS),
                  Expanded(
                    child: Text(
                      'Réglé par ${_commande.paymentMethod.displayName}',
                      style: AppTypography.bodyMd(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------- actions

  List<Widget> _actions(ThemeData theme) {
    final enCours = _commande.status != OrderStatus.delivered &&
        _commande.status != OrderStatus.cancelled &&
        _commande.status != OrderStatus.refunded &&
        _commande.status != OrderStatus.failed;

    return [
      if (enCours)
        ActionButton(
          label: 'Suivre la livraison',
          emphasis: ActionEmphasis.gradient,
          icon: Icons.navigation_rounded,
          onPressed: () => context.navigateToDeliveryTracking(_commande.id),
        )
      else if (_commande.status == OrderStatus.delivered)
        ActionButton(
          label: 'Noter cette commande',
          emphasis: ActionEmphasis.gradient,
          icon: Icons.star_outline_rounded,
          onPressed: () => Navigator.of(context).pushNamed(
            AppRouter.orderRating,
            arguments: {'order': _commande},
          ),
        ),
      const SizedBox(height: DesignConstants.spacingS),
      ActionButton(
        label: 'Besoin d’aide ?',
        emphasis: ActionEmphasis.outlined,
        icon: Icons.support_agent_rounded,
        onPressed: () => Navigator.of(context).pushNamed(AppRouter.support),
      ),
    ];
  }

  String _heure(DateTime date) {
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  IconData _icone(JalonDeSuivi jalon) {
    switch (jalon) {
      case JalonDeSuivi.confirmee:
        return Icons.receipt_long_rounded;
      case JalonDeSuivi.enPreparation:
        return Icons.local_fire_department_rounded;
      case JalonDeSuivi.enRoute:
        return Icons.two_wheeler_rounded;
      case JalonDeSuivi.livree:
        return Icons.task_alt_rounded;
    }
  }
}

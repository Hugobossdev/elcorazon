import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/models/order.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/services/driver_rating_service.dart';
import 'package:elcora_fast/services/review_rating_service.dart';
import 'package:elcora_fast/services/design_enhancement_service.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/widgets/design/design.dart';
import 'package:elcorazon_core/elcorazon_core.dart' show Journal;

class OrderRatingScreen extends StatefulWidget {
  final Order order;

  const OrderRatingScreen({
    required this.order,
    super.key,
  });

  @override
  State<OrderRatingScreen> createState() => _OrderRatingScreenState();
}

class _OrderRatingScreenState extends State<OrderRatingScreen> {
  // Notation du livreur
  int _driverRating = 0;
  Set<String> _driverAppreciations = <String>{};
  final _driverCommentController = TextEditingController();

  // Notation par plat
  final Map<String, int> _itemRatings = {};
  final Map<String, Set<String>> _itemAppreciations = {};
  final Map<String, TextEditingController> _itemComments = {};

  bool _isLoading = false;

  /// Les puces de la maquette `rate_your_meal`, traduites.
  static const _appreciationsDuPlat = [
    'Très bon',
    'Bien assaisonné',
    'Servi chaud',
    'Portion généreuse',
    'Bien emballé',
  ];

  /// Celles de `rate_delivery`.
  static const _appreciationsDeLivraison = [
    'Ponctuel',
    'Professionnel',
    'Aimable',
    'Consignes respectées',
  ];

  @override
  void initState() {
    super.initState();
    // Initialize controllers for each item
    for (final item in widget.order.items) {
      _itemComments[item.menuItemId] = TextEditingController();
      _itemRatings[item.menuItemId] = 0;
      _itemAppreciations[item.menuItemId] = <String>{};
    }
  }

  @override
  void dispose() {
    _driverCommentController.dispose();
    for (final controller in _itemComments.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submitRatings() async {
    setState(() => _isLoading = true);

    try {
      final appService = Provider.of<AppService>(context, listen: false);
      final driverRatingService = DriverRatingService();
      final reviewRatingService =
          Provider.of<ReviewRatingService>(context, listen: false);
      final currentUser = appService.currentUser;

      if (currentUser == null) {
        if (mounted) {
          context.showErrorMessage('Connectez-vous pour déposer un avis.');
        }
        return;
      }

      int successCount = 0;
      int totalActions = 0;

      // 1. Submit Driver Rating (if rated)
      if (_driverRating > 0 && widget.order.deliveryPersonId != null) {
        totalActions++;
        final success = await driverRatingService.submitRating(
          orderId: widget.order.id,
          rating: _driverRating,
          comment: _joindre(
            _driverAppreciations,
            _driverCommentController.text.trim(),
          ),
        );
        if (success) successCount++;
      }

      // 2. Submit Item Ratings (only those with a rating > 0)
      for (final item in widget.order.items) {
        final rating = _itemRatings[item.menuItemId] ?? 0;
        if (rating > 0) {
          totalActions++;

          // `is_verified_purchase` n'est plus déclaré ici : le serveur le
          // déduit de l'historique d'achat au moment du dépôt (S1).
          final success = await reviewRatingService.addReview(
            menuItemId: item.menuItemId,
            rating: rating,
            // Le `title` existait au contrat et partait vide à chaque avis :
            // les puces d'appréciation lui donnent enfin un contenu.
            title: (_itemAppreciations[item.menuItemId] ?? const <String>{})
                .join(', '),
            comment: _itemComments[item.menuItemId]?.text.trim() ?? '',
          );
          if (success) successCount++;
        }
      }

      if (mounted) {
        if (totalActions == 0) {
          context.showErrorMessage('Donnez au moins une note avant d’envoyer.');
        } else if (successCount > 0) {
          // Le compte des réussites est annoncé tel quel : sur trois avis
          // dont un refusé (un plat déjà noté), « Merci pour vos avis » seul
          // laisserait croire que les trois sont partis.
          context.showSuccessMessage(
            successCount == totalActions
                ? 'Merci, vos avis sont enregistrés.'
                : '$successCount avis sur $totalActions enregistré'
                    '${successCount > 1 ? 's' : ''}.',
          );
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur lors de l\'envoi des avis')),
          );
        }
      }
    } catch (e) {
      Journal.trace('Error submitting ratings: $e');
      if (mounted) {
        context.showErrorMessage('Envoi impossible pour le moment.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Les puces retenues, puis le texte libre.
  ///
  /// Le contrat n'a pas de champ d'étiquettes côté livraison : les joindre au
  /// commentaire est le seul moyen de les transmettre. Les collecter sans les
  /// envoyer aurait été pire que de ne pas les proposer.
  String _joindre(Set<String> puces, String libre) {
    if (puces.isEmpty) return libre;
    final jointes = puces.join(', ');
    return libre.isEmpty ? jointes : '$jointes — $libre';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: const GlassAppBar(title: 'Noter ma commande'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          DesignConstants.edgeMargin,
          DesignConstants.spacingM,
          DesignConstants.edgeMargin,
          DesignConstants.spacingXL,
        ),
        children: [
          Text(
            'Comment était votre repas ?',
            style: AppTypography.headlineSm(color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: DesignConstants.spacingXS),
          Text(
            'Notez ce que vous voulez — rien n’est obligatoire.',
            style: AppTypography.bodyMd(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: DesignConstants.spacingL),
          for (final article in widget.order.items) ...[
            _carteDArticle(theme, article),
            const SizedBox(height: DesignConstants.spacingM),
          ],
          if (widget.order.deliveryPersonId != null) ...[
            const SizedBox(height: DesignConstants.spacingS),
            _sectionLivreur(theme),
          ],
          const SizedBox(height: DesignConstants.spacingL),
          ActionButton(
            label: 'Envoyer mes avis',
            emphasis: ActionEmphasis.gradient,
            icon: Icons.send_rounded,
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _submitRatings,
          ),
        ],
      ),
    );
  }

  /// Un plat, sa note et ses appréciations.
  ///
  /// Les puces alimentent le `title` de l'avis — un champ qui existe au
  /// contrat et que l'écran laissait systématiquement vide.
  Widget _carteDArticle(ThemeData theme, OrderItem article) {
    final note = _itemRatings[article.menuItemId] ?? 0;
    final retenues = _itemAppreciations[article.menuItemId] ?? <String>{};

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: DesignConstants.borderRadiusMedium,
                child: SizedBox(
                  width: DesignConstants.avatarSizeMedium,
                  height: DesignConstants.avatarSizeMedium,
                  child: FoodImage(
                    url: article.menuItemImage.isEmpty
                        ? null
                        : article.menuItemImage,
                    iconSize: 24,
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
                    if (article.customizations.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        article.customizations.values.join(' · '),
                        style: AppTypography.bodyMd(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignConstants.spacingM),
          RatingStars(
            note: note,
            taille: 34,
            onChanged: (valeur) => setState(
              () => _itemRatings[article.menuItemId] = valeur,
            ),
          ),
          if (note > 0) ...[
            const SizedBox(height: DesignConstants.spacingM),
            AppreciationChips(
              options: _appreciationsDuPlat,
              retenues: retenues,
              onChanged: (suite) => setState(
                () => _itemAppreciations[article.menuItemId] = suite,
              ),
            ),
            const SizedBox(height: DesignConstants.spacingM),
            TextField(
              controller: _itemComments[article.menuItemId],
              maxLines: 3,
              style: AppTypography.bodyLg(color: theme.colorScheme.onSurface),
              decoration: const InputDecoration(
                hintText: 'Un mot sur ce plat (facultatif)',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionLivreur(ThemeData theme) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.two_wheeler_rounded,
                color: theme.colorScheme.primary,
                size: DesignConstants.iconSizeMedium,
              ),
              const SizedBox(width: DesignConstants.spacingS),
              Expanded(
                child: Text(
                  'Et la livraison ?',
                  style: AppTypography.titleLg(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignConstants.spacingM),
          RatingStars(
            note: _driverRating,
            taille: 34,
            onChanged: (valeur) => setState(() => _driverRating = valeur),
          ),
          if (_driverRating > 0) ...[
            const SizedBox(height: DesignConstants.spacingM),
            AppreciationChips(
              options: _appreciationsDeLivraison,
              retenues: _driverAppreciations,
              onChanged: (suite) =>
                  setState(() => _driverAppreciations = suite),
            ),
            const SizedBox(height: DesignConstants.spacingM),
            TextField(
              controller: _driverCommentController,
              maxLines: 3,
              style: AppTypography.bodyLg(color: theme.colorScheme.onSurface),
              decoration: const InputDecoration(
                hintText: 'Un mot sur la livraison (facultatif)',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

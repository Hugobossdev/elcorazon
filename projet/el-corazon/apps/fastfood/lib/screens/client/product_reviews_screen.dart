import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcorazon_core/elcorazon_core.dart' show Review;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:elcora_fast/services/review_rating_service.dart';
import 'package:elcora_fast/services/design_enhancement_service.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/widgets/design/design.dart';
import 'package:elcora_fast/widgets/loading_widget.dart';
// import '../../widgets/enhanced_animations.dart'; // Supprimé

/// Initiale affichée dans l'avatar — `full_name` peut être vide côté serveur.
String _initial(String fullName) =>
    fullName.isEmpty ? '?' : fullName[0].toUpperCase();

/// Écran des reviews et ratings d'un produit
class ProductReviewsScreen extends StatefulWidget {
  final eccore.MenuItem menuItem;

  const ProductReviewsScreen({
    required this.menuItem, super.key,
  });

  @override
  State<ProductReviewsScreen> createState() => _ProductReviewsScreenState();
}

class _ProductReviewsScreenState extends State<ProductReviewsScreen> {
  /// `recent` ou `rating`.
  String _sortBy = 'recent';

  /// `all`, ou le nombre d'étoiles sous forme de chaîne.
  String _filterBy = 'all';

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    final service = context.read<ReviewRatingService>();
    await service.loadReviews(widget.menuItem.id);
    await service.loadRating(widget.menuItem.id);
  }

  /// Ouvre le formulaire d'avis en feuille.
  ///
  /// La version précédente en faisait un **onglet**, à côté de « Avis ». Un
  /// onglet est une destination : on y va, on en revient, il reste là. Or
  /// écrire un avis est un geste ponctuel, qu'on accomplit une fois et qui se
  /// referme. L'onglet occupait donc en permanence la moitié de la barre pour
  /// une action que la plupart des visiteurs ne feront jamais — et il masquait
  /// la liste, qui est ce qu'on est venu lire.
  Future<void> _ecrireUnAvis() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: DesignConstants.edgeMargin,
          right: DesignConstants.edgeMargin,
          top: DesignConstants.spacingS,
          // Laisse la place au clavier : sans ce décalage, le champ de
          // commentaire se retrouve dessous dès qu'on le touche.
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom +
              DesignConstants.spacingL,
        ),
        child: SingleChildScrollView(
          child: _ReviewFormDialog(
            menuItem: widget.menuItem,
            onSubmit: () async {
              Navigator.of(sheetContext).pop();
              await _loadReviews();
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: GlassAppBar(title: widget.menuItem.name),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ecrireUnAvis,
        icon: const Icon(Icons.rate_review_rounded),
        label: const Text('Donner mon avis'),
      ),
      body: Consumer<ReviewRatingService>(
        builder: (context, service, child) {
          if (service.isLoading && service.reviews.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final avis = _trierEtFiltrer(service.reviews);

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              DesignConstants.edgeMargin,
              DesignConstants.spacingM,
              DesignConstants.edgeMargin,
              // De quoi passer sous le bouton flottant sans que la dernière
              // carte disparaisse dessous.
              96,
            ),
            children: [
              _syntheseDesNotes(service),
              const SizedBox(height: DesignConstants.spacingL),
              _filtres(),
              const SizedBox(height: DesignConstants.spacingM),
              if (avis.isEmpty)
                EmptyStateWidget(
                  title: _filterBy == 'all'
                      ? 'Aucun avis pour l’instant'
                      : 'Aucun avis à $_filterBy étoile${_filterBy == '1' ? '' : 's'}',
                  message: _filterBy == 'all'
                      ? 'Soyez le premier à donner le vôtre.'
                      : 'Essayez un autre filtre.',
                  icon: Icons.rate_review_outlined,
                )
              else
                for (final review in avis) _buildReviewCard(review),
            ],
          );
        },
      ),
    );
  }

  List<Review> _trierEtFiltrer(List<Review> source) {
    // Copie modifiable : `service.reviews` ne l'est pas.
    var avis = List<Review>.from(source);

    if (_filterBy != 'all') {
      final note = int.parse(_filterBy);
      avis = avis.where((r) => r.rating == note).toList();
    }

    switch (_sortBy) {
      case 'rating':
        avis.sort((a, b) => b.rating.compareTo(a.rating));
      default:
        avis.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return avis;
  }

  /// Note moyenne à gauche, répartition à droite.
  ///
  /// C'est le bloc « Rating Overview » de la maquette. La répartition compte
  /// autant que la moyenne : 4,2 obtenu avec des 4 et des 5 ne dit pas la même
  /// chose que 4,2 obtenu avec des 5 et des 1.
  Widget _syntheseDesNotes(ReviewRatingService service) {
    final theme = Theme.of(context);
    final note = service.ratings[widget.menuItem.id];

    if (note == null || note.totalReviews == 0) {
      return SectionCard(
        child: Row(
          children: [
            Icon(
              Icons.star_outline_rounded,
              size: 32,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: DesignConstants.spacingM),
            Expanded(
              child: Text(
                'Ce plat n’a pas encore été noté.',
                style: AppTypography.bodyLg(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SectionCard(
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                note.averageRating.toStringAsFixed(1),
                style: AppTypography.displayLg(
                  color: theme.colorScheme.primary,
                ),
              ),
              RatingBarIndicator(
                rating: note.averageRating,
                itemBuilder: (context, index) => Icon(
                  Icons.star_rounded,
                  color: theme.colorScheme.secondary,
                ),
                itemSize: 16,
              ),
              const SizedBox(height: 4),
              Text(
                '${note.totalReviews} avis',
                style: AppTypography.bodyMd(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(width: DesignConstants.spacingL),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final etoiles in [5, 4, 3, 2, 1])
                  _ligneDeRepartition(
                    etoiles,
                    note.ratingDistribution[etoiles] ?? 0,
                    note.totalReviews,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ligneDeRepartition(int etoiles, int nombre, int total) {
    final theme = Theme.of(context);
    final part = total > 0 ? nombre / total : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 12,
            child: Text(
              '$etoiles',
              textAlign: TextAlign.end,
              style: AppTypography.labelLg(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: part,
                minHeight: 6,
                backgroundColor: theme.colorScheme.surfaceContainerHigh,
                valueColor:
                    AlwaysStoppedAnimation<Color>(theme.colorScheme.secondary),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 24,
            child: Text(
              '$nombre',
              style: AppTypography.labelLg(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Filtres et tri, en puces.
  ///
  /// Les deux menus déroulants d'avant demandaient trois gestes pour un
  /// filtre — ouvrir, faire défiler, choisir — et ne montraient pas les
  /// options disponibles tant qu'on ne les avait pas ouverts.
  ///
  /// « Plus utiles » reste absent du tri : le contrat expose `helpful_count`
  /// mais aucune route pour voter. Trier sur un compteur que personne ne peut
  /// incrémenter n'afficherait qu'un ordre figé.
  Widget _filtres() {
    const filtres = ['all', '5', '4', '3', '2', '1'];
    const libelles = ['Tous', '5 ★', '4 ★', '3 ★', '2 ★', '1 ★'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CategoryChipBar(
          labels: libelles,
          selectedIndex: filtres.indexOf(_filterBy),
          padding: EdgeInsets.zero,
          onSelected: (index) => setState(() => _filterBy = filtres[index]),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => setState(
              () => _sortBy = _sortBy == 'recent' ? 'rating' : 'recent',
            ),
            icon: const Icon(Icons.swap_vert_rounded, size: 18),
            label: Text(
              _sortBy == 'recent' ? 'Les plus récents' : 'Les mieux notés',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewCard(Review review) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: DesignConstants.spacingM),
      child: SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor:
                      theme.colorScheme.primary.withValues(alpha: 0.12),
                  child: Text(
                    _initial(review.author.fullName),
                    style: AppTypography.titleLg(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: DesignConstants.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        review.author.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleLg(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      RatingBarIndicator(
                        rating: review.rating.toDouble(),
                        itemBuilder: (context, index) => Icon(
                          Icons.star_rounded,
                          color: theme.colorScheme.secondary,
                        ),
                        itemSize: 14,
                      ),
                    ],
                  ),
                ),
                if (review.isVerifiedPurchase)
                  StatusChip(
                    label: 'Vérifié',
                    icon: Icons.verified_rounded,
                    dense: true,
                    background: AppColors.success.withValues(alpha: 0.12),
                    foreground: AppColors.success,
                  ),
              ],
            ),
            if (review.title.isNotEmpty) ...[
              const SizedBox(height: DesignConstants.spacingM),
              Text(
                review.title,
                style: AppTypography.titleLg(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
            if (review.comment.isNotEmpty) ...[
              const SizedBox(height: DesignConstants.spacingS),
              Text(
                review.comment,
                style: AppTypography.bodyLg(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            // Photos d'avis et bouton « Utile » restent absents : ni les unes
            // ni l'autre n'existent dans le contrat (`ReviewSerializer` n'a
            // pas de champ photo, et rien n'incrémente `helpful_count`).
            const SizedBox(height: DesignConstants.spacingM),
            Text(
              _depuis(review.createdAt),
              style: AppTypography.labelLg(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ancienneté d'un avis, en clair.
///
/// La version précédente écrivait toujours « Il y a N jours », ce qui donnait
/// « Il y a 0 jours » pour un avis déposé le matin même — la formule la plus
/// sûre pour faire douter de la fraîcheur de la page.
String _depuis(DateTime date) {
  final ecart = DateTime.now().difference(date);

  if (ecart.inMinutes < 1) return "À l'instant";
  if (ecart.inHours < 1) return 'Il y a ${ecart.inMinutes} min';
  if (ecart.inDays < 1) {
    final h = ecart.inHours;
    return 'Il y a $h heure${h > 1 ? 's' : ''}';
  }
  if (ecart.inDays < 7) {
    final j = ecart.inDays;
    return 'Il y a $j jour${j > 1 ? 's' : ''}';
  }
  if (ecart.inDays < 31) {
    final semaines = ecart.inDays ~/ 7;
    return 'Il y a $semaines semaine${semaines > 1 ? 's' : ''}';
  }
  final mois = ecart.inDays ~/ 30;
  if (mois < 12) return 'Il y a $mois mois';
  final ans = mois ~/ 12;
  return 'Il y a $ans an${ans > 1 ? 's' : ''}';
}

/// Dialog de formulaire de review (utilisé aussi dans le TabView)
class _ReviewFormDialog extends StatefulWidget {
  final eccore.MenuItem menuItem;
  final VoidCallback onSubmit;

  const _ReviewFormDialog({
    required this.menuItem,
    required this.onSubmit,
  });

  @override
  State<_ReviewFormDialog> createState() => _ReviewFormDialogState();
}

class _ReviewFormDialogState extends State<_ReviewFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _commentController = TextEditingController();
  double _rating = 5.0;

  @override
  void dispose() {
    _titleController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (!_formKey.currentState!.validate()) return;

    final reviewService = context.read<ReviewRatingService>();

    final success = await reviewService.addReview(
      menuItemId: widget.menuItem.id,
      rating: _rating.round(),
      title: _titleController.text,
      comment: _commentController.text,
    );

    if (!mounted) return;

    if (success) {
      context.showSuccessMessage('Merci pour votre avis !');
      widget.onSubmit();
    } else {
      // Porte le motif du serveur : avis déjà déposé (409), quota d'écriture
      // atteint (429), ou session absente (401).
      context.showErrorMessage(
        reviewService.error ?? 'Erreur lors de l\'ajout de l\'avis',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey[200],
                    ),
                    child: widget.menuItem.image != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              widget.menuItem.image!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(Icons.restaurant,
                            size: 40, color: Colors.grey,),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.menuItem.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.menuItem.description,
                          style: TextStyle(color: Colors.grey[600]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // La bannière « achat vérifié » annonçait un verdict que le client
          // calculait lui-même en interrogeant les commandes. C'est le serveur
          // qui le décide à la soumission (S1) : on annonce donc la règle, pas
          // son résultat.
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Votre avis sera marqué « Achat vérifié » si vous avez déjà '
                    'reçu ce produit. Un seul avis par produit.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          // Rating
          const Text(
            'Votre note',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          RatingBar.builder(
            initialRating: _rating,
            minRating: 1,
            itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
            itemBuilder: (context, _) => const Icon(
              Icons.star,
              color: Colors.amber,
            ),
            onRatingUpdate: (rating) {
              setState(() => _rating = rating);
            },
          ),
          const SizedBox(height: 32),

          // Title
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Titre (optionnel)',
              hintText: 'Donnez un titre à votre avis',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // Comment
          TextFormField(
            controller: _commentController,
            decoration: const InputDecoration(
              labelText: 'Votre avis',
              hintText: 'Partagez votre expérience...',
              border: OutlineInputBorder(),
            ),
            maxLines: 5,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Veuillez entrer votre avis';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitReview,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Publier mon avis',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

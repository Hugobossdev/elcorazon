import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:elcora_fast/services/review_rating_service.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/services/design_enhancement_service.dart';
import 'package:elcora_fast/models/menu_item.dart';
import 'package:elcora_fast/theme.dart';
// import '../../widgets/enhanced_animations.dart'; // Supprimé

/// Écran des reviews et ratings d'un produit
class ProductReviewsScreen extends StatefulWidget {
  final MenuItem menuItem;

  const ProductReviewsScreen({
    required this.menuItem, super.key,
  });

  @override
  State<ProductReviewsScreen> createState() => _ProductReviewsScreenState();
}

class _ProductReviewsScreenState extends State<ProductReviewsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _sortBy = 'recent';
  String _filterBy = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadReviews();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    final service = context.read<ReviewRatingService>();
    await service.loadReviews(widget.menuItem.id);
    await service.loadRating(widget.menuItem.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Avis et Notes'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.onPrimary,
          labelColor: Theme.of(context).colorScheme.onPrimary,
          unselectedLabelColor: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
          tabs: const [
            Tab(text: 'Avis', icon: Icon(Icons.rate_review)),
            Tab(text: 'Noter', icon: Icon(Icons.star_outline)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReviewsTab(),
          _buildReviewFormTab(),
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    return Column(
      children: [
        // Rating overview
        Consumer<ReviewRatingService>(
          builder: (context, service, child) {
            final rating = service.ratings[widget.menuItem.id];

            if (rating == null || rating.totalReviews == 0) {
              return Container(
                padding: const EdgeInsets.all(24),
                child: const Center(
                  child: Text('Aucun avis pour ce produit'),
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Rating display
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rating.averageRating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          RatingBarIndicator(
                            rating: rating.averageRating,
                            itemBuilder: (context, index) => const Icon(
                              Icons.star,
                              color: Colors.amber,
                            ),
                            itemSize: 20,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${rating.totalReviews} avis',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 24),
                      // Rating distribution
                      Expanded(
                        child: Column(
                          children: [5, 4, 3, 2, 1].map((stars) {
                            final count = rating.ratingDistribution[stars] ?? 0;
                            final percentage = rating.totalReviews > 0
                                ? count / rating.totalReviews
                                : 0.0;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Text(
                                    '$stars',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: LinearProgressIndicator(
                                      value: percentage,
                                      backgroundColor: Colors.grey[200],
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                              Colors.amber,),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$count',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),

        // Filter and sort
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  value: _filterBy,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(
                        value: 'all', child: Text('Tous les avis'),),
                    DropdownMenuItem(value: '5', child: Text('5 étoiles')),
                    DropdownMenuItem(value: '4', child: Text('4 étoiles')),
                    DropdownMenuItem(value: '3', child: Text('3 étoiles')),
                    DropdownMenuItem(value: '2', child: Text('2 étoiles')),
                    DropdownMenuItem(value: '1', child: Text('1 étoile')),
                  ],
                  onChanged: (value) {
                    setState(() => _filterBy = value ?? 'all');
                  },
                ),
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _sortBy,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'recent', child: Text('Plus récent')),
                  DropdownMenuItem(
                      value: 'helpful', child: Text('Plus utiles'),),
                  DropdownMenuItem(value: 'rating', child: Text('Mieux notés')),
                ],
                onChanged: (value) {
                  setState(() => _sortBy = value ?? 'recent');
                },
              ),
            ],
          ),
        ),

        // Reviews list
        Expanded(
          child: Consumer<ReviewRatingService>(
            builder: (context, service, child) {
              if (service.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              // Créer une copie modifiable de la liste (service.reviews est non modifiable)
              var reviews = List<ProductReview>.from(service.reviews);

              // Apply filter
              if (_filterBy != 'all') {
                final rating = int.parse(_filterBy);
                reviews =
                    reviews.where((r) => r.rating.round() == rating).toList();
              }

              // Apply sort
              switch (_sortBy) {
                case 'helpful':
                  reviews.sort((a, b) =>
                      (b.isHelpful ? 1 : 0).compareTo(a.isHelpful ? 1 : 0),);
                  break;
                case 'rating':
                  reviews.sort((a, b) => b.rating.compareTo(a.rating));
                  break;
                default:
                  reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
              }

              if (reviews.isEmpty) {
                return const Center(
                  child: Text('Aucun avis correspondant aux filtres'),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: reviews.length,
                itemBuilder: (context, index) {
                  return _buildReviewCard(reviews[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReviewCard(ProductReview review) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
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
                  backgroundColor: AppColors.primary,
                  child: Text(
                    review.userName[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              review.userName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (review.isVerifiedPurchase)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified,
                                      size: 12, color: Colors.white,),
                                  SizedBox(width: 4),
                                  Text(
                                    'Achat vérifié',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      RatingBarIndicator(
                        rating: review.rating,
                        itemBuilder: (context, index) => const Icon(
                          Icons.star,
                          color: Colors.amber,
                        ),
                        itemSize: 16,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (review.title.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                review.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              review.comment,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            if (review.photos != null && review.photos!.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: review.photos!.length,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: NetworkImage(review.photos![index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Il y a ${DateTime.now().difference(review.createdAt).inDays} jours',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    context.read<ReviewRatingService>().markHelpful(review.id);
                  },
                  icon: const Icon(Icons.thumb_up_outlined, size: 16),
                  label: Text(
                    review.isHelpful ? 'Utile' : 'Utile',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewFormTab() {
    return Consumer2<AppService, ReviewRatingService>(
      builder: (context, appService, reviewService, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _ReviewFormDialog(
            menuItem: widget.menuItem,
            onSubmit: () async {
              await _loadReviews();
              _tabController.animateTo(0);
            },
          ),
        );
      },
    );
  }
}

/// Dialog de formulaire de review (utilisé aussi dans le TabView)
class _ReviewFormDialog extends StatefulWidget {
  final MenuItem menuItem;
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
  final List<String> _photos = [];
  bool _checkingPurchase = true;
  bool _hasPurchased = false;

  @override
  void initState() {
    super.initState();
    _checkPurchaseStatus();
  }

  Future<void> _checkPurchaseStatus() async {
    final appService = context.read<AppService>();
    final reviewService = context.read<ReviewRatingService>();

    if (appService.currentUser != null) {
      final hasPurchased = await reviewService.hasPurchasedProduct(
        appService.currentUser!.id,
        widget.menuItem.id,
      );
      if (mounted) {
        setState(() {
          _hasPurchased = hasPurchased;
          _checkingPurchase = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _checkingPurchase = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (!_formKey.currentState!.validate()) return;

    final appService = context.read<AppService>();
    final reviewService = context.read<ReviewRatingService>();

    if (appService.currentUser == null) {
      context.showErrorMessage('Vous devez être connecté pour noter');
      return;
    }

    // Vérifier si l'utilisateur a acheté ce produit
    final hasPurchased = await reviewService.hasPurchasedProduct(
      appService.currentUser!.id,
      widget.menuItem.id,
    );

    final review = ProductReview(
      id: '',
      menuItemId: widget.menuItem.id,
      userId: appService.currentUser!.id,
      userName: appService.currentUser!.name,
      rating: _rating,
      title: _titleController.text,
      comment: _commentController.text,
      photos: _photos.isEmpty ? null : _photos,
      isVerifiedPurchase: hasPurchased,
      createdAt: DateTime.now(),
    );

    final success = await reviewService.addReview(review);

    if (success && mounted) {
      context.showSuccessMessage('Merci pour votre avis !');
      widget.onSubmit();
    } else if (mounted) {
      context.showErrorMessage('Erreur lors de l\'ajout de l\'avis');
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
                    child: widget.menuItem.imageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              widget.menuItem.imageUrl!,
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

          // Purchase Status Banner
          if (!_checkingPurchase)
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _hasPurchased
                    ? AppColors.success.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _hasPurchased
                      ? AppColors.success.withValues(alpha: 0.5)
                      : Colors.grey.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _hasPurchased ? Icons.verified : Icons.info_outline,
                    color: _hasPurchased ? AppColors.success : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _hasPurchased
                          ? 'Vous avez acheté ce produit. Votre avis sera marqué comme "Achat vérifié".'
                          : 'Vous n\'avez pas encore acheté ce produit. Votre avis ne sera pas marqué comme vérifié.',
                      style: TextStyle(
                        color: _hasPurchased
                            ? AppColors.success
                            : Theme.of(context).textTheme.bodyMedium?.color,
                        fontSize: 13,
                      ),
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

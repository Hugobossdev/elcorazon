import 'dart:async';

import 'package:elcora_fast/navigation/navigation_service.dart';
import 'package:elcora_fast/presentation/catalogue.dart';
import 'package:elcora_fast/screens/client/widgets/quick_actions_widget.dart';
import 'package:elcora_fast/services/address_service.dart';
import 'package:elcora_fast/services/ai_recommendation_service.dart';
import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/services/design_enhancement_service.dart';
import 'package:elcora_fast/services/favorites_service.dart';
import 'package:elcora_fast/services/notification_database_service.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/widgets/design/design.dart';
import 'package:elcora_fast/widgets/loading_widget.dart';
import 'package:elcora_fast/widgets/menu_item_card.dart';
import 'package:elcora_fast/widgets/navigation_helper.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Accueil du client.
///
/// ## L'ordre des sections, et pourquoi il est celui-là
///
/// La maquette range l'accueil du plus général au plus personnel : on cherche,
/// on découvre une mise en avant, on filtre par catégorie, puis on parcourt.
/// Cet écran suit le même ordre, en y insérant ce que l'application sait de
/// vous et que la maquette ignore — vos suggestions et vos favoris — juste
/// avant la liste générale : ce qui vous est propre passe avant ce qui est
/// commun à tous.
///
/// ## Ce qui a disparu, et pourquoi ce n'est pas une perte
///
/// Le carrousel « Bienvenue chez El Corazón » proposait quatre destinations :
/// Menu, Commandes groupées, Livraison rapide, Récompenses. Les deux premières
/// et la quatrième sont déjà dans les actions rapides, juste dessous ; la
/// troisième ouvrait l'onglet Commandes, que la barre du bas atteint en un
/// geste. C'était donc 200 px de hauteur, quatre pages à faire défiler et une
/// animation permanente pour proposer une seconde fois ce qui était déjà à
/// portée. Aucune destination n'est devenue inatteignable.
///
/// ## La bannière ne promet rien qu'on ne puisse tenir
///
/// La maquette y affiche « Livraison offerte ». Il n'existe **aucune route
/// publique de promotion** — `/promotions/` est réservé au back-office, et
/// `PromotionRepository` le documente — si bien qu'annoncer une offre ici
/// reviendrait à l'inventer. La bannière met donc en avant un vrai plat du
/// catalogue, avec sa vraie note et son vrai prix : la même place, la même
/// intention commerciale, et rien qui ne vienne du serveur.
class ClientHomeScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;

  const ClientHomeScreen({
    super.key,
    this.onNavigateToTab,
  });

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _apparition;
  late Animation<double> _fondu;
  late Animation<Offset> _montee;

  /// Catégorie mise en avant dans le rail de puces. `-1` = « Tout ».
  ///
  /// Elle **filtre la liste de cet écran** plutôt que d'ouvrir le menu : la
  /// maquette montre un rail qui réordonne le contenu sous lui, et renvoyer
  /// vers un autre écran à chaque puce ferait perdre la position de lecture.
  int _categorieRetenue = -1;

  @override
  void initState() {
    super.initState();
    _apparition = AnimationController(
      duration: DesignConstants.animationSlow,
      vsync: this,
    );
    _fondu = CurvedAnimation(parent: _apparition, curve: Curves.easeOut);
    _montee = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _apparition, curve: Curves.easeOutCubic),
    );
    _apparition.forward();
  }

  @override
  void dispose() {
    _apparition.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      // `extendBodyBehindAppBar` : sans lui, le flou de la barre n'aurait rien
      // à filtrer — le contenu s'arrêterait à son bord inférieur.
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        showBack: false,
        centerTitle: false,
        titleWidget: const _EnteteLivraison(),
        actions: [_Cloche(onTap: () => context.navigateToNotifications())],
      ),
      body: FadeTransition(
        opacity: _fondu,
        child: SlideTransition(
          position: _montee,
          child: RefreshIndicator(
            onRefresh: () => context.read<AppService>().initialize(),
            child: CustomScrollView(
              slivers: [
                // Compense la barre translucide, qui recouvre le haut du
                // contenu.
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: GlassAppBar.hauteur +
                        MediaQuery.paddingOf(context).top +
                        DesignConstants.spacingM,
                  ),
                ),
                const SliverToBoxAdapter(child: _BarreDeRecherche()),
                const SliverToBoxAdapter(
                  child: SizedBox(height: DesignConstants.spacingL),
                ),
                const SliverToBoxAdapter(child: _BanniereDuJour()),
                const SliverToBoxAdapter(
                  child: SizedBox(height: DesignConstants.spacingL),
                ),
                SliverToBoxAdapter(child: _railDeCategories()),
                const SliverToBoxAdapter(
                  child: SizedBox(height: DesignConstants.spacingL),
                ),
                SliverToBoxAdapter(child: _actionsRapides()),
                SliverToBoxAdapter(child: _suggestions()),
                SliverToBoxAdapter(child: _favoris()),
                SliverToBoxAdapter(child: _platsALaUne()),
                const SliverToBoxAdapter(
                  child: SizedBox(height: DesignConstants.spacingXL),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- sections

  Widget _railDeCategories() {
    return Consumer<AppService>(
      builder: (context, appService, child) {
        final categories = appService.menuCategories;
        if (categories.isEmpty) return const SizedBox.shrink();

        // « Tout » n'est pas une catégorie du serveur : c'est l'absence de
        // filtre, placée en tête parce que c'est l'état initial et celui vers
        // lequel on revient.
        final libelles = ['Tout', for (final c in categories) c.name];

        return CategoryChipBar(
          labels: libelles,
          selectedIndex: _categorieRetenue + 1,
          // « Tout » n'illustre rien : c'est l'absence de filtre.
          leadingBuilder: (index) =>
              index == 0 ? null : categories[index - 1].illustration,
          onSelected: (index) =>
              setState(() => _categorieRetenue = index - 1),
        );
      },
    );
  }

  Widget _actionsRapides() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: DesignConstants.edgeMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Actions rapides',
            subtitle: 'Vos raccourcis, à portée de pouce',
          ),
          QuickActionsWidget(),
        ],
      ),
    );
  }

  Widget _suggestions() {
    return Consumer2<AIRecommendationService, AppService>(
      builder: (context, aiService, appService, child) {
        // L'identifiant **du compte connecté**, et non la chaîne
        // `'current_user'` : les suggestions sont rangées sous l'identifiant
        // avec lequel elles ont été calculées, si bien que cette clé inventée
        // ne désignait jamais rien. La section restait vide quoi qu'il arrive.
        final identifiant = appService.currentUser?.id;
        if (identifiant == null) return const SizedBox.shrink();

        // Le classement est fait par le service, sur trois signaux du serveur
        // — historique du compte, `is_popular`, note moyenne. L'écran n'en
        // reprend que les six premiers.
        //
        // Le filtre qui se trouvait ici, `isPopular && ratingAverage > 4.0`,
        // rendait la section **structurellement vide** : le serveur ouvre tout
        // article à `rating_average: 0.00` et n'a encore aucun avis en base.
        // Aucun plat ne pouvait franchir 4,0, si bien que « Nos suggestions »
        // ne s'est jamais affichée — sans erreur nulle part pour le dire.
        final suggestions = aiService
            .getRecommendationsForUser(identifiant)
            .take(6)
            .toList();

        if (suggestions.isEmpty) return const SizedBox.shrink();

        return _Carrousel(
          titre: 'Nos suggestions',
          sousTitre: 'Inspirées de vos commandes récentes',
          articles: suggestions,
        );
      },
    );
  }

  Widget _favoris() {
    return Consumer<FavoritesService>(
      builder: (context, favoritesService, child) {
        final favoris = favoritesService.favorites;
        if (favoris.isEmpty) return const SizedBox.shrink();

        final pluriel = favoris.length > 1 ? 's' : '';

        return _Carrousel(
          titre: 'Mes favoris',
          sousTitre:
              '${favoris.length} plat$pluriel sauvegardé$pluriel',
          articles: favoris,
          actionLibelle: 'Voir tout',
          onAction: () => widget.onNavigateToTab?.call(1),
        );
      },
    );
  }

  /// Liste principale — des cartes pleine largeur, comme la maquette.
  ///
  /// Le filtre du rail de catégories s'applique ici, et le titre le dit :
  /// laisser « Plats à la une » au-dessus d'une liste filtrée par « Boissons »
  /// donnerait l'impression que le filtre n'a pas pris.
  Widget _platsALaUne() {
    return Consumer<AppService>(
      builder: (context, appService, child) {
        final categorie = _categorieRetenue >= 0 &&
                _categorieRetenue < appService.menuCategories.length
            ? appService.menuCategories[_categorieRetenue]
            : null;

        final articles = appService.menuItems
            .where((item) => item.isAvailable)
            .where(
              (item) =>
                  categorie == null || item.categorySlug == categorie.slug,
            )
            .where((item) => categorie != null || item.isPopular)
            .take(8)
            .toList();

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignConstants.edgeMargin,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: categorie?.name ?? 'Plats à la une',
                subtitle: categorie == null
                    ? 'Les préférés de nos clients'
                    : 'Toute la carte de cette catégorie',
                actionLabel: 'Tout voir',
                onActionPressed: () => widget.onNavigateToTab?.call(1),
              ),
              const SizedBox(height: DesignConstants.spacingM),
              if (!appService.isInitialized && articles.isEmpty)
                const FoodCardSkeletonList(padding: EdgeInsets.zero)
              else if (articles.isEmpty)
                EmptyStateWidget(
                  title: categorie == null
                      ? 'Le menu arrive'
                      : 'Rien dans « ${categorie.name} »',
                  message: categorie == null
                      ? 'Aucun plat populaire pour le moment.'
                      : 'Essayez une autre catégorie.',
                  icon: Icons.restaurant_menu_rounded,
                )
              else
                for (final article in articles) ...[
                  _CarteDePlat(article: article),
                  const SizedBox(height: DesignConstants.spacingM),
                ],
            ],
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------------ entête

/// « Livrer à » suivi de l'adresse retenue.
///
/// L'adresse est celle que le carnet a sélectionnée, à défaut celle marquée
/// par défaut. Sans carnet — visiteur, ou client qui n'a rien enregistré — la
/// ligne invite à en ajouter une plutôt que d'afficher un vide : c'est l'étape
/// qui bloquera le règlement, autant la proposer maintenant.
class _EnteteLivraison extends StatelessWidget {
  const _EnteteLivraison();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer2<AddressService, AppService>(
      builder: (context, addressService, appService, child) {
        final adresse =
            addressService.selectedAddress ?? addressService.defaultAddress;
        final libelle = adresse == null
            ? 'Ajouter une adresse'
            : (adresse.label.isNotEmpty ? adresse.label : adresse.line1);

        return InkWell(
          onTap: () {
            if (appService.isLoggedIn) {
              context.navigateToAddressManagement();
            } else {
              NavigationService.navigateToAuth(context);
            }
          },
          borderRadius: BorderRadius.circular(DesignConstants.radiusMedium),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignConstants.spacingS,
              vertical: 4,
            ),
            child: Row(
              children: [
                _Avatar(utilisateur: appService.currentUser),
                const SizedBox(width: DesignConstants.spacingS + 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Livrer à',
                        style: AppTypography.bodyMd(
                          color: theme.colorScheme.onSurfaceVariant,
                        ).copyWith(fontSize: 12, height: 1.2),
                      ),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              libelle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.titleLg(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.expand_more_rounded,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Photo du compte, ou son initiale.
///
/// `User.avatar` est facultatif côté serveur : la pastille à initiale n'est
/// pas un état d'erreur mais le cas courant, et elle doit donc être aussi
/// soignée que la photo.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.utilisateur});

  final eccore.User? utilisateur;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatar = utilisateur?.avatar;
    final nom = utilisateur?.fullName ?? '';
    final initiale = nom.isEmpty ? '?' : nom.characters.first.toUpperCase();

    return ClipOval(
      child: SizedBox(
        width: 40,
        height: 40,
        child: (avatar != null && avatar.isNotEmpty)
            ? FoodImage(
                url: avatar,
                icon: Icons.person_rounded,
                iconSize: 22,
              )
            : ColoredBox(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                child: Center(
                  child: Text(
                    initiale,
                    style: AppTypography.titleLg(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// Cloche de notifications, avec le compte de non-lues.
class _Cloche extends StatelessWidget {
  const _Cloche({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationDatabaseService>(
      builder: (context, service, child) {
        final nonLues = service.unreadCount;
        return GlassIconButton(
          icon: nonLues > 0
              ? Icons.notifications_active_rounded
              : Icons.notifications_none_rounded,
          tooltip: nonLues > 0
              ? '$nonLues notification${nonLues > 1 ? 's' : ''} non lue${nonLues > 1 ? 's' : ''}'
              : 'Notifications',
          badge: nonLues,
          onPressed: onTap,
        );
      },
    );
  }
}

// ----------------------------------------------------------------- recherche

/// Barre de recherche en mode bouton : elle ouvre l'écran de recherche
/// avancée au lieu de déplier le clavier ici.
///
/// C'est un choix de la maquette, et il tient : la recherche de l'accueil ne
/// peut rien filtrer sur place — les plats affichés sont une sélection, pas la
/// carte — alors que l'écran dédié cherche dans tout le catalogue.
class _BarreDeRecherche extends StatelessWidget {
  const _BarreDeRecherche();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignConstants.edgeMargin,
      ),
      child: AppSearchField(
        onTap: () => context.navigateToAdvancedSearch(),
      ),
    );
  }
}

// ----------------------------------------------------------------- bannière

/// Mise en avant d'un plat réel du catalogue.
///
/// Le choix est déterministe — le mieux noté parmi les populaires disponibles,
/// à égalité le premier dans l'ordre du serveur — pour que la bannière ne
/// change pas d'un rendu à l'autre. Une bannière qui tourne à chaque
/// reconstruction du widget se lit comme un défaut, pas comme une rotation
/// éditoriale.
class _BanniereDuJour extends StatelessWidget {
  const _BanniereDuJour();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppService>(
      builder: (context, appService, child) {
        final candidats = appService.menuItems
            .where((item) => item.isAvailable && item.isPopular)
            .toList()
          ..sort((a, b) => b.ratingAverage.compareTo(a.ratingAverage));

        if (candidats.isEmpty) return const SizedBox.shrink();
        final vedette = candidats.first;

        final details = <String>[
          if (vedette.ratingAverage > 0)
            '${vedette.ratingAverage.toStringAsFixed(1)}/5',
          if (vedette.preparationMinutes > 0)
            'prêt en ${vedette.preparationMinutes} min',
          vedette.price.format(),
        ];

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignConstants.edgeMargin,
          ),
          child: PromoBanner(
            title: vedette.name,
            subtitle: details.join(' · '),
            actionLabel: 'Commander',
            imageUrl: vedette.image,
            onPressed: () => context.navigateToItemCustomization(vedette),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------- carrousels

/// Rangée horizontale de cartes compactes — suggestions, favoris.
///
/// La hauteur est **demandée à la carte** plutôt que devinée : c'est ce qui
/// empêche le prix et le bouton d'ajout de passer sous le bandeau de
/// débordement quand le système grossit la police.
class _Carrousel extends StatelessWidget {
  const _Carrousel({
    required this.titre,
    required this.articles,
    this.sousTitre,
    this.actionLibelle,
    this.onAction,
  });

  final String titre;
  final String? sousTitre;
  final List<eccore.MenuItem> articles;
  final String? actionLibelle;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final petitEcran = MediaQuery.sizeOf(context).width < 360;
    final largeurCarte = petitEcran ? 170.0 : 190.0;
    final hauteur = MenuItemCard.hauteurPour(context, largeurCarte) +
        (petitEcran ? 4 : 8);

    return Padding(
      padding: const EdgeInsets.only(bottom: DesignConstants.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: titre,
            subtitle: sousTitre,
            actionLabel: actionLibelle,
            onActionPressed: onAction,
            padding: const EdgeInsets.symmetric(
              horizontal: DesignConstants.edgeMargin,
            ),
          ),
          const SizedBox(height: DesignConstants.spacingM),
          SizedBox(
            height: hauteur,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: DesignConstants.edgeMargin,
              ),
              itemCount: articles.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: DesignConstants.spacingM),
              itemBuilder: (context, index) => SizedBox(
                width: largeurCarte,
                child: _CarteCompacte(article: articles[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte compacte branchée sur le panier et les favoris réels.
class _CarteCompacte extends StatelessWidget {
  const _CarteCompacte({required this.article});

  final eccore.MenuItem article;

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoritesService>(
      builder: (context, favoritesService, child) {
        final estFavori = favoritesService.isFavorite(article);

        return MenuItemCard(
          item: article,
          onTap: () => context.navigateToItemCustomization(article),
          onAddToCart: () => _ajouterAuPanier(context, article),
          onFavoriteTap: () {
            favoritesService.toggleFavorite(article);
            context.showSuccessMessage(
              estFavori
                  ? '${article.name} retiré des favoris'
                  : '${article.name} ajouté aux favoris',
            );
          },
          isFavorite: estFavori,
        );
      },
    );
  }
}

/// Carte pleine largeur de la liste principale.
class _CarteDePlat extends StatelessWidget {
  const _CarteDePlat({required this.article});

  final eccore.MenuItem article;

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoritesService>(
      builder: (context, favoritesService, child) {
        final estFavori = favoritesService.isFavorite(article);

        return FoodCard(
          item: article,
          isFavorite: estFavori,
          onTap: () => context.navigateToItemCustomization(article),
          onFavoriteTap: () {
            favoritesService.toggleFavorite(article);
            context.showSuccessMessage(
              estFavori
                  ? '${article.name} retiré des favoris'
                  : '${article.name} ajouté aux favoris',
            );
          },
        );
      },
    );
  }
}

/// Ajout au panier — ou personnalisation quand la carte impose un choix.
///
/// Un burger sans cuisson, une pizza sans taille : le serveur les refuse
/// (`validate_selection`). Le raccourci ne vaut donc que pour les articles
/// qui n'attendent rien de plus.
void _ajouterAuPanier(BuildContext context, eccore.MenuItem article) {
  unawaited(context.addToCartOrCustomize(article));
}

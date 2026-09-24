import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcorazon_core/elcorazon_core.dart' show AppEmoji;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/core/utils/admin_helpers.dart';
import 'package:admin/presentation/autorisations.dart';
import 'package:admin/presentation/commande.dart';
import 'package:admin/presentation/couleur_statut.dart';
import 'package:admin/presentation/echec.dart';
import 'package:admin/presentation/statut_commande.dart';
import 'package:admin/screens/admin/send_notification_dialog.dart';
import 'package:admin/services/admin_auth_service.dart';
import 'package:admin/services/analytics_service.dart';
import 'package:admin/services/order_management_service.dart';
import 'package:admin/ui/ui.dart';
import 'package:admin/utils/dialog_helper.dart';
import 'package:admin/utils/price_formatter.dart';
import 'package:admin/widgets/modern/enhanced_stat_card.dart';

/// Les écrans qu'un raccourci du tableau de bord ouvre — les index de la
/// navigation (`AdminNavigationScreen`), avec la **même** permission que
/// l'entrée de la barre latérale.
///
/// Les raccourcis poussaient chacun un écran par `Navigator.push`, hors de
/// la navigation et hors de son filtre : un Opérateur voyait « Promotions »
/// et « Notifications » sur son tableau de bord alors que la barre latérale
/// les lui cachait, et le serveur le refusait en 403 une fois le formulaire
/// rempli. Ils passent maintenant par la navigation, sous la même règle.
abstract final class EcranDuTableauDeBord {
  static const commandes = (index: 2, permission: 'orders.read');
  static const menu = (index: 1, permission: 'catalog.read');
  static const analyses = (index: 4, permission: 'analytics.read');
  static const promotions = (index: 9, permission: 'promotions.read');
  static const documents = (index: 15, permission: 'couriers.read');
  static const livraisons = (index: 14, permission: 'orders.read');
  static const clients = (index: 5, permission: 'customers.read');
  static const livreurs = (index: 3, permission: 'couriers.read');
}

/// Tableau de bord — ce qu'on regarde en ouvrant le back-office.
///
/// ## Ce qu'il ne fait plus
///
/// Il téléchargeait **toutes** les commandes jamais passées (`AppService`,
/// sans borne de date, vingt par page) et tout le catalogue, à chaque
/// ouverture, pour en afficher des compteurs et cinq lignes. Le temps
/// d'ouverture croissait avec l'historique de la plateforme. Chaque chiffre
/// vient désormais d'un agrégat serveur :
///
/// * la journée (`/analytics/reports/overview/`, `analytics.read`) —
///   commandes, livraisons, chiffre d'affaires **par devise**, livreurs
///   disponibles, clients, carte ;
/// * le service en cours (`/orders/manage/counts/`, `orders.read`) — un
///   `COUNT … GROUP BY` ;
/// * les cinq commandes récentes — une page de cinq.
///
/// ## Ce que chaque rôle y voit
///
/// L'écran reste ouvert à tout le personnel (c'est la page d'accueil), mais
/// chaque bloc n'apparaît qu'avec la permission que sa route exige. Un bloc
/// absent n'est pas une panne : c'est un rôle qui n'y a pas accès, et l'écran
/// le dit une fois plutôt que d'afficher des 403.
///
/// L'onglet « Analyses » qu'il portait dupliquait l'écran Analyses — mêmes
/// graphiques, sans contrôle de permission — et en divergeait déjà. Un lien y
/// mène désormais.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({this.ouvrirEcran, super.key});

  /// Ouvre un écran de la navigation par son index. Nul hors de la
  /// navigation (tests) : les raccourcis sont alors inertes.
  final ValueChanged<int>? ouvrirEcran;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Future<Map<StatutCommande, int>>? _enCours;
  Future<List<eccore.Order>>? _recentes;
  Future<List<Map<String, dynamic>>>? _meilleuresVentes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _charger();
    });
  }

  /// Lance les lectures **permises** — et seulement elles : demander un
  /// rapport sans `analytics.read` produirait un 403 que l'écran n'aurait
  /// rien à faire d'autre qu'afficher.
  void _charger() {
    final auth = context.read<AdminAuthService>();
    final commandes = context.read<OrderManagementService>();
    setState(() {
      if (auth.can('orders.read')) {
        _enCours = commandes.compterEnCours();
        _recentes = commandes.recentes();
      }
      if (auth.can('analytics.read')) {
        _meilleuresVentes = context.read<AnalyticsService>().getTopSellingItems(
              startDate: DateTime.now().subtract(const Duration(days: 30)),
            );
      }
    });
    if (auth.can('analytics.read')) {
      unawaited(context.read<AnalyticsService>().chargerLaJournee());
    }
  }

  void _ouvrir(({int index, String permission}) ecran) => widget.ouvrirEcran?.call(ecran.index);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AdminAuthService>();
    final voitAnalyses = context.peut('analytics.read');
    final voitCommandes = context.peut('orders.read');

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: () async => _charger(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Accueil(nom: auth.currentAdmin?.fullName),
              const SizedBox(height: 20),
              if (voitAnalyses) ...[
                _Journee(onOuvrir: _ouvrir),
                const SizedBox(height: 20),
              ],
              if (voitCommandes) ...[
                _ServiceEnCours(compteurs: _enCours, onOuvrir: _ouvrir),
                const SizedBox(height: 20),
              ],
              if (!voitAnalyses && !voitCommandes)
                const Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: Text(
                    'Votre rôle ne donne accès à aucun indicateur du tableau de bord. '
                    'Les écrans auxquels il donne accès sont dans le menu.',
                  ),
                ),
              _Raccourcis(onOuvrir: _ouvrir),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, contraintes) {
                  final recentes = voitCommandes
                      ? _CommandesRecentes(commandes: _recentes, onOuvrir: _ouvrir)
                      : null;
                  final ventes =
                      voitAnalyses ? _MeilleuresVentes(lignes: _meilleuresVentes) : null;
                  if (contraintes.maxWidth > 900 && recentes != null && ventes != null) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: recentes),
                        const SizedBox(width: 20),
                        Expanded(flex: 2, child: ventes),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      if (recentes != null) recentes,
                      if (recentes != null && ventes != null) const SizedBox(height: 20),
                      if (ventes != null) ventes,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef _Ouvrir = void Function(({int index, String permission}) ecran);

String _montant(int mineur, String devise) =>
    formatMontant(eccore.Money(amountMinor: mineur, currency: devise));

class _Accueil extends StatelessWidget {
  const _Accueil({required this.nom});

  final String? nom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final heure = DateTime.now().hour;
    final salut = heure < 12 ? 'Bonjour' : (heure < 18 ? 'Bon après-midi' : 'Bonsoir');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$salut, ${nom ?? 'Admin'}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Voici ce qui se passe aujourd’hui chez El Corazón',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onPrimary.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.restaurant, color: scheme.onPrimary, size: 32),
        ],
      ),
    );
  }
}

/// La journée de l'établissement — `analytics.read`.
///
/// Le chiffre d'affaires et le panier moyen s'affichent **une tuile par
/// devise** : un siège qui supervise Lomé (XOF) et Douala (XAF) n'a pas un
/// chiffre d'affaires, il en a deux.
class _Journee extends StatelessWidget {
  const _Journee({required this.onOuvrir});

  final _Ouvrir onOuvrir;

  @override
  Widget build(BuildContext context) {
    final analyses = context.watch<AnalyticsService>();
    final journee = analyses.journee;
    final echec = analyses.echecJournee;
    final scheme = Theme.of(context).colorScheme;
    final sem = AdminColorTokens.semantic(scheme);

    if (echec != null && journee == null) {
      return BandeauEchec(
        echec: echec,
        onReessayer: () => unawaited(context.read<AnalyticsService>().chargerLaJournee()),
      );
    }

    String valeur(String Function(JourneeDExploitation j) lire) =>
        journee == null ? '—' : lire(journee);
    void analysesOuvertes() => onOuvrir(EcranDuTableauDeBord.analyses);

    final tuiles = <Widget>[
      EnhancedStatCard(
        title: journee?.libelle ?? 'Journée',
        value: valeur((j) => '${j.commandesDuJour}'),
        icon: Icons.receipt_long,
        color: sem.info,
        subtitle: journee == null
            ? 'Chargement…'
            : '${journee.livraisonsDuJour} livrée(s), ${journee.annulationsDuJour} annulée(s)',
        onTap: analysesOuvertes,
      ),
      if (journee != null && journee.revenusDuJour.isEmpty)
        EnhancedStatCard(
          title: 'Chiffre d’affaires du jour',
          value: 'Aucune livraison',
          icon: Icons.payments_outlined,
          color: sem.success,
          subtitle: 'Seules les commandes livrées comptent',
          onTap: analysesOuvertes,
        ),
      for (final ligne in journee?.revenusDuJour ?? const <eccore.CurrencyRevenue>[]) ...[
        EnhancedStatCard(
          title: 'Chiffre d’affaires du jour (${ligne.currency})',
          value: _montant(ligne.revenueMinor, ligne.currency),
          icon: Icons.payments_outlined,
          color: sem.success,
          subtitle: 'Semaine : ${_montant(journee!.revenusDeLaSemaine[ligne.currency] ?? 0, ligne.currency)}',
          onTap: analysesOuvertes,
        ),
        EnhancedStatCard(
          title: 'Panier moyen (${ligne.currency})',
          value: _montant(ligne.averageBasketMinor, ligne.currency),
          icon: Icons.shopping_basket,
          color: scheme.tertiary,
          subtitle: 'Par commande livrée, sur ${ligne.ordersDelivered} livraison(s)',
          onTap: analysesOuvertes,
        ),
      ],
      EnhancedStatCard(
        title: 'Livreurs disponibles',
        value: valeur((j) => '${j.apercu.couriersOnline}'),
        icon: Icons.delivery_dining,
        color: sem.warning,
        subtitle: 'En ligne, dossier validé, compte actif',
        onTap: () => onOuvrir(EcranDuTableauDeBord.livreurs),
      ),
      EnhancedStatCard(
        title: 'Carte',
        value: valeur((j) => '${j.apercu.menuItemsAvailable} / ${j.apercu.menuItemsTotal}'),
        icon: Icons.restaurant_menu,
        color: scheme.primary,
        subtitle: 'Articles disponibles',
        onTap: () => onOuvrir(EcranDuTableauDeBord.menu),
      ),
      EnhancedStatCard(
        title: 'Clients',
        value: valeur((j) => '${j.apercu.customersCount}'),
        icon: Icons.people_outline,
        color: scheme.secondary,
        subtitle: 'Comptes du périmètre',
        onTap: () => onOuvrir(EcranDuTableauDeBord.clients),
      ),
    ];

    return _Grille(tuiles: tuiles);
  }
}

/// Le service en cours — `orders.read`, un compte par statut.
class _ServiceEnCours extends StatelessWidget {
  const _ServiceEnCours({required this.compteurs, required this.onOuvrir});

  final Future<Map<StatutCommande, int>>? compteurs;
  final _Ouvrir onOuvrir;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<Map<StatutCommande, int>>(
      future: compteurs,
      builder: (context, instantane) {
        if (instantane.hasError) {
          return BandeauEchec(echec: Echec.de(instantane.error!));
        }
        final comptes = instantane.data;
        final total = comptes?.values.fold<int>(0, (a, b) => a + b);
        return _Grille(
          tuiles: [
            EnhancedStatCard(
              title: 'Commandes en cours',
              value: total?.toString() ?? '—',
              icon: Icons.pending_actions,
              color: AdminColorTokens.semantic(scheme).warning,
              subtitle: 'Ni livrées ni annulées',
              onTap: () => onOuvrir(EcranDuTableauDeBord.commandes),
            ),
            for (final statut in [
              StatutCommande.enAttente,
              StatutCommande.enPreparation,
              StatutCommande.prete,
              StatutCommande.enRoute,
            ])
              EnhancedStatCard(
                title: statut.libelle,
                value: comptes?[statut]?.toString() ?? '—',
                icon: Icons.circle,
                color: couleurDeStatut(statut, scheme),
                onTap: () => onOuvrir(EcranDuTableauDeBord.commandes),
              ),
          ],
        );
      },
    );
  }
}

class _Grille extends StatelessWidget {
  const _Grille({required this.tuiles});

  final List<Widget> tuiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, contraintes) {
        final colonnes = contraintes.maxWidth > 1100 ? 4 : (contraintes.maxWidth > 700 ? 2 : 1);
        const espace = 16.0;
        final largeur = (contraintes.maxWidth - (colonnes - 1) * espace) / colonnes;
        return Wrap(
          spacing: espace,
          runSpacing: espace,
          children: [for (final tuile in tuiles) SizedBox(width: largeur, child: tuile)],
        );
      },
    );
  }
}

/// Raccourcis — **les mêmes permissions que la barre latérale**.
class _Raccourcis extends StatelessWidget {
  const _Raccourcis({required this.onOuvrir});

  final _Ouvrir onOuvrir;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sem = AdminColorTokens.semantic(scheme);

    Widget vers(String libelle, IconData icone, Color couleur, ({int index, String permission}) e) =>
        _Raccourci(libelle, icone, couleur, () => onOuvrir(e));

    final boutons = <Widget>[
      if (context.peut(EcranDuTableauDeBord.commandes.permission))
        vers('Commandes', Icons.shopping_cart, sem.info, EcranDuTableauDeBord.commandes),
      if (context.peut(EcranDuTableauDeBord.menu.permission))
        vers('Menu', Icons.restaurant_menu, sem.success, EcranDuTableauDeBord.menu),
      if (context.peut(EcranDuTableauDeBord.promotions.permission))
        vers('Promotions', Icons.local_offer, sem.warning, EcranDuTableauDeBord.promotions),
      if (context.peut(EcranDuTableauDeBord.documents.permission))
        vers('Documents', Icons.verified_user, scheme.secondary, EcranDuTableauDeBord.documents),
      if (context.peut(EcranDuTableauDeBord.livraisons.permission))
        vers('Livraisons', Icons.local_shipping, sem.danger, EcranDuTableauDeBord.livraisons),
      if (context.peut(EcranDuTableauDeBord.analyses.permission))
        vers('Analyses', Icons.analytics_outlined, scheme.primary, EcranDuTableauDeBord.analyses),
      // Une campagne part vers toute la clientèle : `notifications.send` ne
      // suffit pas, le serveur la réserve au siège (`assert_unscoped`).
      if (context.peut('notifications.send') && context.estSiege)
        _Raccourci('Notification', Icons.send, scheme.tertiary, () {
          DialogHelper.showSafeDialog(
            context: context,
            builder: (_) => const SendNotificationDialog(),
          );
        }),
    ];

    if (boutons.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions rapides',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, contraintes) {
            final colonnes = contraintes.maxWidth > 900 ? 7 : (contraintes.maxWidth > 600 ? 4 : 2);
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: colonnes,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: boutons,
            );
          },
        ),
      ],
    );
  }
}

class _Raccourci extends StatelessWidget {
  const _Raccourci(this.libelle, this.icone, this.couleur, this.onTap);

  final String libelle;
  final IconData icone;
  final Color couleur;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, color: couleur, size: 28),
            const SizedBox(height: 8),
            Text(
              libelle,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _CommandesRecentes extends StatelessWidget {
  const _CommandesRecentes({required this.commandes, required this.onOuvrir});

  final Future<List<eccore.Order>>? commandes;
  final _Ouvrir onOuvrir;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Commandes récentes',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => onOuvrir(EcranDuTableauDeBord.commandes),
                  child: const Text('Voir tout'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<eccore.Order>>(
              future: commandes,
              builder: (context, instantane) {
                if (instantane.hasError) {
                  return BandeauEchec(echec: Echec.de(instantane.error!));
                }
                if (!instantane.hasData) {
                  return const Center(
                    child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
                  );
                }
                final liste = instantane.data!;
                if (liste.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: Text('Aucune commande dans votre périmètre.')),
                  );
                }
                return Column(
                  children: [
                    for (final order in liste)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor:
                              couleurDeStatut(order.statut, scheme).withValues(alpha: 0.12),
                          child: AppEmoji(
                            order.statut.illustration,
                            size: AppEmoji.tailleXS,
                            decoratif: true,
                          ),
                        ),
                        title: Text(order.reference),
                        subtitle: Text(
                          // La forme de liste porte `items_count` ; elle ne
                          // porte pas `lines`, qui valait donc toujours zéro.
                          '${AdminHelpers.formatRelativeTime(order.placedAt)} • '
                          '${order.itemsCount} article(s) • ${order.restaurantName}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatMontant(order.total),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              order.statut.libelle,
                              style: TextStyle(
                                fontSize: 12,
                                color: couleurDeStatut(order.statut, scheme),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MeilleuresVentes extends StatelessWidget {
  const _MeilleuresVentes({required this.lignes});

  final Future<List<Map<String, dynamic>>>? lignes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sem = AdminColorTokens.semantic(scheme);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Meilleures ventes (30 jours)',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: lignes,
              builder: (context, instantane) {
                if (instantane.hasError) {
                  return BandeauEchec(echec: Echec.de(instantane.error!));
                }
                if (!instantane.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final produits = instantane.data!;
                if (produits.isEmpty) {
                  return const Text('Aucune vente livrée sur la période.');
                }
                return Column(
                  children: [
                    for (final (rang, produit) in produits.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: scheme.primaryContainer,
                              child: Text(
                                '${rang + 1}',
                                style: TextStyle(
                                  color: scheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    produit['menu_item_name'] as String? ?? 'Produit',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    '${produit['total_quantity']} vendu(s)',
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(color: scheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              formatMajeur(
                                (produit['total_revenue'] as num).toDouble(),
                                produit['currency'] as String,
                              ),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: sem.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

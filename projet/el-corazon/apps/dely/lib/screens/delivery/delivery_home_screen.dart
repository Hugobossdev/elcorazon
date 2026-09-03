import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_dely/services/app_service.dart';
import 'package:elcora_dely/services/error_handler_service.dart';
import 'package:elcora_dely/services/performance_service.dart';
import 'package:elcora_dely/services/realtime_tracking_service.dart';
import 'package:elcora_dely/presentation/libelles_course.dart';
import 'package:elcora_dely/repositories/django_delivery_repository.dart';
import 'package:elcora_dely/screens/payments/earnings_screen.dart';
import 'package:elcora_dely/screens/communication/chat_screen.dart';
import 'package:elcora_dely/screens/delivery/real_time_tracking_screen.dart';
import 'package:elcora_dely/screens/delivery/driver_profile_screen.dart';
import 'package:elcora_dely/screens/delivery/settings_screen.dart';
import 'package:elcora_dely/presentation/messages_erreur.dart';
import 'package:elcorazon_core/elcorazon_core.dart'
    show AppEmoji, AppEmojis, Journal, User;

class DeliveryHomeScreen extends StatefulWidget {
  const DeliveryHomeScreen({super.key});

  @override
  State<DeliveryHomeScreen> createState() => _DeliveryHomeScreenState();
}

class _DeliveryHomeScreenState extends State<DeliveryHomeScreen> {
  Timer? _refreshTimer;
  bool _isLoading = false;
  bool _isRefreshing = false;
  DateTime? _lastRefreshTime;

  /// Le dernier rechargement a-t-il échoué ?
  ///
  /// L'écran gardait sa liste en cache sans rien dire quand la requête
  /// échouait — un rafraîchissement « silencieux » ne montrait même pas de
  /// message. Le livreur lisait donc des courses vieilles de plusieurs
  /// minutes en croyant les voir à jour, ce qui est précisément ce qu'il ne
  /// faut pas laisser croire en perte de réseau.
  bool _lastRefreshFailed = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    // Refresh orders every 30 seconds
    _startPeriodicRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted && !_isRefreshing) {
        _refreshOrders(silent: true);
      }
    });
  }

  Future<void> _refreshOrders({bool silent = false}) async {
    // Debounce: Ne pas rafraîchir si le dernier rafraîchissement était il y a moins de 5 secondes
    if (_lastRefreshTime != null &&
        DateTime.now().difference(_lastRefreshTime!) <
            const Duration(seconds: 5)) {
      return;
    }

    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
      _lastRefreshTime = DateTime.now();
    });

    try {
      final appService = Provider.of<AppService>(context, listen: false);
      await appService.loadAvailableOrders();
      if (mounted) setState(() => _lastRefreshFailed = false);

      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Commandes mises à jour'),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _lastRefreshFailed = true);
        final errorHandler = Provider.of<ErrorHandlerService>(
          context,
          listen: false,
        );
        errorHandler.logError('Erreur rafraîchissement commandes', details: e);
        if (!silent) {
          errorHandler.showErrorSnackBar(
            context,
            'Erreur lors du rafraîchissement',
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _initializeServices() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final appService = Provider.of<AppService>(context, listen: false);

      // Ensure AppService is fully initialized
      if (!appService.isInitialized) {
        await appService.initialize();
      }

      // Aucune initialisation de paiement : l'encaissement passe par le
      // serveur, qui détient les clés du prestataire. Le bloc retiré ici
      // injectait des clés marchandes dans le téléphone du livreur.

      // Load available orders from database (essentiel)
      try {
        await appService
            .loadAvailableOrders(forceRefresh: true)
            .timeout(const Duration(seconds: 15));
      } catch (e) {
        Journal.trace('⚠️ Failed to load orders: $e');
        // Ne pas bloquer l'application si le chargement échoue
        // Les commandes seront chargées lors du rafraîchissement
      }

      if (mounted) {
        Journal.trace('✅ Services initialisés');
      }
    } catch (e) {
      if (mounted) {
        Journal.trace('❌ Erreur initialisation services: $e');
        final errorHandler = Provider.of<ErrorHandlerService>(
          context,
          listen: false,
        );
        errorHandler.logError('Erreur initialisation services', details: e);
        // Ne pas afficher d'erreur si c'est juste un service optionnel qui a échoué
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accueil Livreur'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          Consumer<AppService>(
            builder: (context, appService, child) {
              final user = appService.currentUser;
              if (user == null) {
                return const SizedBox.shrink();
              }
              return IconButton(
                onPressed: () => _toggleOnlineStatus(context),
                icon: Icon(
                  appService.isOnline
                      ? Icons.online_prediction
                      : Icons.offline_pin,
                  color: appService.isOnline ? Colors.green : Colors.grey,
                ),
              );
            },
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const EarningsScreen()),
            ),
            icon: const Icon(Icons.account_balance_wallet),
            tooltip: 'Mes gains',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DriverProfileScreen(),
                    ),
                  );
                  break;
                case 'settings':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, size: 20),
                    SizedBox(width: 8),
                    Text('Mon profil'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 20),
                    SizedBox(width: 8),
                    Text('Paramètres'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<AppService>(
              builder: (context, appService, child) {
                final user = appService.currentUser;

                // Si l'initialisation est terminée mais pas d'utilisateur, c'est une erreur
                if (user == null && appService.isInitialized) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.orange,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Impossible de charger le profil',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Votre session a peut-être expiré ou le profil est incomplet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () {
                              _initializeServices();
                            },
                            child: const Text('Réessayer'),
                          ),
                          TextButton(
                            // Pas de navigation à la suite : `DriverGate`
                            // écoute la session et remplace l'écran de
                            // lui-même. La ligne qui était ici poussait
                            // `/login`, une route qui n'a jamais existé — elle
                            // tombait dans le cas par défaut d'`onGenerateRoute`
                            // et ne marchait que par accident.
                            onPressed: () => unawaited(appService.logout()),
                            child: const Text('Se déconnecter'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (user == null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Chargement du profil...',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                try {
                  final assignedDeliveries = appService.assignedDeliveries;

                  // Les courses qu'on me propose. Ce filtre cherchait
                  // auparavant un statut « prête » qu'aucune course ne portait
                  // jamais : la section restait vide en toutes circonstances.
                  final availableOrders = appService.pendingOffers;

                  return RefreshIndicator(
                    onRefresh: () => _refreshOrders(),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isRefreshing)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Mise à jour...',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          _buildLiaisonBanner(),
                          _buildStatusCard(context, user, appService),
                          const SizedBox(height: 20),
                          _buildStatsCard(context, assignedDeliveries),
                          const SizedBox(height: 20),
                          _buildAvailableOrders(context, availableOrders),
                          const SizedBox(height: 20),
                          _buildMyDeliveries(context, assignedDeliveries),
                        ],
                      ),
                    ),
                  );
                } catch (e) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red[300],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Erreur de chargement',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            e.toString(),
                            style: TextStyle(color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              _initializeServices();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              },
            ),
    );
  }

  // Le statut « en ligne » vient du dossier livreur, pas du compte : il est
  // passé en paramètre plutôt que lu sur `user`, où il était recopié.
  /// L'en-tête du livreur : qui il est, et s'il peut travailler.
  ///
  /// « En ligne » ne suffit pas. L'éligibilité réelle est `can_accept_orders`,
  /// calculée par le serveur : en ligne **et** dossier validé **et** compte
  /// actif (L1). Un livreur dont le dossier est en attente pouvait se déclarer
  /// en ligne, voir la pastille passer au vert, et attendre indéfiniment des
  /// courses que le serveur ne lui proposerait jamais — sans que rien ne le
  /// lui dise.
  Widget _buildStatusCard(
    BuildContext context,
    User user,
    AppService appService,
  ) {
    final isOnline = appService.isOnline;
    final peutTravailler = appService.canAcceptOrders;
    final dossier = appService.courierProfile?.verificationStatus;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: isOnline
                ? [Colors.green, Colors.teal]
                : [Colors.grey[600]!, Colors.grey[800]!],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Text(
                    user.fullName.substring(0, 2).toUpperCase(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isOnline ? Colors.green : Colors.grey[600],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bonjour, ${user.fullName}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isOnline
                                  ? Colors.greenAccent
                                  : Colors.grey[400],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isOnline ? 'En ligne' : 'Hors ligne',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!isOnline)
              _buildStatusNotice(
                Icons.info,
                'Vous êtes hors ligne. Activez votre statut pour recevoir '
                'des courses.',
              )
            else if (!peutTravailler)
              // En ligne mais inéligible : le cas que rien ne signalait.
              _buildStatusNotice(
                Icons.warning_amber_rounded,
                switch (dossier) {
                  'pending' =>
                    'Votre dossier est en cours de validation : aucune course '
                        'ne vous sera proposée tant qu\'il n\'est pas validé.',
                  'rejected' =>
                    'Votre dossier a été rejeté. Contactez El Corazón : aucune '
                        'course ne peut vous être proposée.',
                  'suspended' =>
                    'Votre compte est suspendu : aucune course ne peut vous '
                        'être proposée.',
                  _ =>
                    'Vous êtes en ligne, mais votre dossier ne permet pas '
                        'encore de recevoir des courses.',
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Dit quand l'écran ne peut plus garantir ce qu'il montre.
  ///
  /// Deux causes, deux conséquences distinctes pour le livreur :
  ///
  /// * la **file temps réel** est fermée — les courses proposées n'arriveront
  ///   plus d'elles-mêmes, seulement au prochain rechargement ;
  /// * le **dernier rechargement a échoué** — ce qui est affiché date d'avant,
  ///   et une course peut avoir été prise par un collègue entre-temps.
  ///
  /// Rien n'était dit ni dans un cas ni dans l'autre.
  Widget _buildLiaisonBanner() {
    return Consumer<RealtimeTrackingService>(
      builder: (context, tracking, child) {
        final fileFermee = !tracking.isConnected;
        if (!fileFermee && !_lastRefreshFailed) return const SizedBox.shrink();

        final grave = _lastRefreshFailed;
        final couleur = grave ? Colors.red : Colors.orange;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: couleur.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: couleur.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(Icons.cloud_off, color: couleur, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  grave
                      ? 'Impossible de joindre le serveur. Les courses '
                          'affichées datent du dernier chargement réussi.'
                      : 'Alertes temps réel interrompues. Les nouvelles '
                          'courses apparaîtront au prochain rafraîchissement.',
                  style: TextStyle(color: couleur, fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: () => _refreshOrders(),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusNotice(IconData icone, String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icone, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context, List<Course> assignedDeliveries) {
    // La date qui compte est celle de la **livraison**, horodatée par le
    // serveur. Ce compteur lisait `passeeLe`, c'est-à-dire — le détail d'une
    // course livrée n'étant pas relu — le moment où la course avait été
    // *proposée*. Une course proposée avant minuit et livrée après comptait
    // pour la veille.
    final completedToday = assignedDeliveries
        .where(
          (order) =>
              order.etape == EtapeCourse.livree &&
              order.livreeLe != null &&
              _isToday(order.livreeLe!),
        )
        .length;

    final activeDeliveries = assignedDeliveries
        .where(
          (order) =>
              order.etape.estEnCours,
        )
        .length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context,
            'Livraisons du jour',
            '$completedToday',
            Icons.check_circle,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            context,
            'En cours',
            '$activeDeliveries',
            Icons.delivery_dining,
            Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableOrders(
    BuildContext context,
    List<Course> availableOrders,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Commandes disponibles',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${availableOrders.length}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (availableOrders.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.delivery_dining,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    const Text('Aucune commande disponible'),
                    Text(
                      'Les nouvelles commandes apparaîtront ici',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...availableOrders
              .take(3)
              .map((order) => _buildAvailableOrderCard(context, order)),
      ],
    );
  }

  Widget _buildAvailableOrderCard(BuildContext context, Course order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: AppEmoji(
                      AppEmojis.newOrder,
                      size: AppEmoji.tailleXS,
                      decoratif: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.reference,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        // Le restaurant décide s'il vaut la peine de traverser
                        // la ville ; le nombre d'articles, non.
                        '${order.assignment.restaurantName} · '
                        '${order.articles.length} article'
                        '${order.articles.length > 1 ? 's' : ''}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Text(
                    order.total?.format() ?? '—',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    order.adresseLivraison,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Refuser était impossible : `AppService.declineDelivery` existait,
            // le contrat expose `/assignments/{id}/decline/`, et aucun écran ne
            // les appelait. Un livreur à qui on proposait une course qu'il ne
            // pouvait pas prendre — trop loin, fin de service, panne — n'avait
            // d'autre choix que de la laisser expirer, en la retenant tout ce
            // temps loin d'un collègue disponible.
            //
            // Les deux gestes ne s'affichent que si le serveur les déclare
            // permis (`allowed_transitions`).
            Row(
              children: [
                if (order.peutRefuser)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _declineOrder(context, order),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Refuser'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                if (order.peutRefuser && order.peutAccepter)
                  const SizedBox(width: 12),
                if (order.peutAccepter)
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => _acceptOrder(context, order),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Accepter'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
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

  Widget _buildMyDeliveries(BuildContext context, List<Course> myDeliveries) {
    final activeDeliveries = myDeliveries
        .where(
          (order) =>
              order.etape.estEnCours,
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mes livraisons',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (activeDeliveries.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.assignment_turned_in,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    const Text('Aucune livraison en cours'),
                    Text(
                      'Vos livraisons assignées apparaîtront ici',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...activeDeliveries.map(
            (order) => _buildMyDeliveryCard(context, order),
          ),
      ],
    );
  }

  Widget _buildMyDeliveryCard(BuildContext context, Course order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getStatusColor(order.etape).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: AppEmoji(
                      order.etape.illustration,
                      size: AppEmoji.tailleXS,
                      decoratif: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.reference,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        order.etape.libelle,
                        style: TextStyle(
                          color: _getStatusColor(order.etape),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Text(
                    order.total?.format() ?? '—',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    order.adresseLivraison,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _navigateToOrder(context, order),
                    icon: const Icon(Icons.navigation, size: 18),
                    label: const Text('Navigation'),
                  ),
                ),
                const SizedBox(width: 8),
                // Le bouton n'apparaît que si le serveur a une étape à offrir
                // depuis l'état courant. Il était affiché en toutes
                // circonstances, y compris sur une course livrée où il ne
                // faisait rien.
                if (order.prochaineEtape != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateDeliveryStatus(context, order),
                      icon:
                          Icon(_getNextActionIcon(order.prochaineEtape), size: 18),
                      label: Text(_getNextActionText(order.prochaineEtape)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Un seul bouton de discussion. Le second, « Support », ouvrait le
            // même canal `ws/orders/{id}/chat/` que le premier, avec pour
            // seule différence un en-tête disant « Support » : le message du
            // livreur partait donc **chez le client** sous une étiquette qui
            // lui faisait croire l'inverse. Le contrat n'expose aucun canal de
            // support pour un livreur (`/support/*` est réservé aux clients).
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openChat(context, order),
                icon: const Icon(Icons.chat, size: 18),
                label: const Text('Écrire au client'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleOnlineStatus(BuildContext context) async {
    final appService = Provider.of<AppService>(context, listen: false);
    final user = appService.currentUser;
    if (user == null) return;

    try {
      // Mettre à jour le statut dans la base de données
      final newStatus = !appService.isOnline;
      await appService.updateOnlineStatus(newStatus);

      if (context.mounted) {
        // Le serveur rend le dossier à jour : c'est `canAcceptOrders` (L1),
        // pas `isOnline`, qui dit si des courses arriveront. Se déclarer en
        // ligne avec un dossier non validé ne change rien, et l'annoncer
        // comme un succès laissait le livreur attendre des courses qui ne
        // pouvaient pas lui être proposées.
        final enLigneEtEligible = appService.isOnline &&
            appService.canAcceptOrders;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              !appService.isOnline
                  ? 'Vous êtes maintenant hors ligne'
                  : enLigneEtEligible
                      ? 'Vous êtes en ligne : les courses peuvent arriver'
                      : 'Vous êtes en ligne, mais votre dossier n\'est pas '
                          'validé : aucune course ne vous sera proposée',
            ),
            backgroundColor: !appService.isOnline
                ? Colors.grey
                : enLigneEtEligible
                    ? Colors.green
                    : Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
        // Rafraîchir l'interface
        setState(() {});
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            // Le serveur refuse la bascule d'un dossier non validé par
            // un 409 dont le `detail` dit exactement pourquoi ; l'afficher
            // brut donnait « ApiException(409, business_rule_violation, … ) ».
            content: Text(messageErreur(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _acceptOrder(BuildContext context, Course order) async {
    try {
      final appService = Provider.of<AppService>(context, listen: false);
      final performanceService = Provider.of<PerformanceService>(
        context,
        listen: false,
      );

      // Mesurer les performances
      performanceService.startTimer('accept_delivery');

      await appService.acceptDelivery(order.orderId);

      performanceService.stopTimer('accept_delivery');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Course ${order.reference} acceptée',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Forcer le rafraîchissement pour charger les commandes assignées
        await appService.loadAvailableOrders(forceRefresh: true);

        // Rafraîchir l'interface
        setState(() {});
      }
    } catch (e) {
      if (context.mounted) {
        final errorHandler = Provider.of<ErrorHandlerService>(
          context,
          listen: false,
        );
        errorHandler.logError('Erreur acceptation livraison', details: e);
        // Une course prise par un collègue revient en 409 avec sa
        // raison : « Cette course a déjà été acceptée. »
        errorHandler.showErrorSnackBar(context, messageErreur(e));
      }
    }
  }

  /// Refuse une course proposée, avec sa raison.
  ///
  /// Distinct d'une annulation : décliner une proposition n'incrémente pas le
  /// compteur d'annulations du livreur (`deliveries_cancelled`), et la raison
  /// remonte au personnel qui réaffecte.
  Future<void> _declineOrder(BuildContext context, Course order) async {
    final raison = await showDialog<String>(
      context: context,
      builder: (context) {
        final controleur = TextEditingController();
        return AlertDialog(
          title: const Text('Refuser la course'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'La course ${order.reference} sera proposée à un collègue.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controleur,
                autofocus: true,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Raison (facultative)',
                  hintText: 'Trop loin, fin de service, panne…',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controleur.text.trim()),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Refuser'),
            ),
          ],
        );
      },
    );

    if (raison == null || !context.mounted) return;

    try {
      final appService = Provider.of<AppService>(context, listen: false);
      await appService.declineDelivery(order.orderId, reason: raison);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Course ${order.reference} refusée'),
            backgroundColor: Colors.grey,
          ),
        );
        setState(() {});
      }
    } catch (e) {
      if (context.mounted) {
        Provider.of<ErrorHandlerService>(context, listen: false)
            .showErrorSnackBar(context, messageErreur(e));
      }
    }
  }

  void _navigateToOrder(BuildContext context, Course order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RealTimeTrackingScreen(order: order),
      ),
    );
  }

  Future<void> _updateDeliveryStatus(BuildContext context, Course order) async {
    // L'étape suivante est celle que le **serveur** déclare atteignable, et
    // non un `switch` recopié ici : la table des transitions vit dans
    // `DELIVERY_MACHINE`, et chaque copie côté client finit par diverger.
    final suivante = order.prochaineEtape;
    if (suivante == null) return;

    if (suivante == EtapeCourse.livree &&
        !await _confirmerLivraison(context, order)) {
      return;
    }
    if (!context.mounted) return;

    try {
      final appService = Provider.of<AppService>(context, listen: false);
      await appService.updateOrderStatus(order.orderId, suivante);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Commande mise à jour: ${suivante.libelle}'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh orders after status update
        await _refreshOrders(silent: true);
      }
    } catch (e) {
      if (context.mounted) {
        final errorHandler = Provider.of<ErrorHandlerService>(
          context,
          listen: false,
        );
        errorHandler.logError('Erreur mise à jour statut', details: e);
        errorHandler.showErrorSnackBar(context, messageErreur(e));
      }
    }
  }

  /// Demande confirmation avant de déclarer la livraison faite.
  ///
  /// L'étape est irréversible côté serveur — la machine est acyclique, et
  /// c'est elle qui crédite la rémunération. Elle rappelle le montant quand
  /// il y a de l'argent à encaisser : partir sans avoir été payé ne se
  /// rattrape pas.
  Future<bool> _confirmerLivraison(BuildContext context, Course order) async {
    final montant =
        order.moyenPaiement.aEncaisser ? order.total?.format() : null;

    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la livraison'),
        content: Text(
          montant == null
              ? 'La commande ${order.reference} a bien été remise au client ?'
                  '\n\nCette étape est définitive.'
              : 'La commande ${order.reference} a bien été remise, et vous '
                  'avez encaissé $montant ?\n\nCette étape est définitive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Pas encore'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Oui, c\'est livré'),
          ),
        ],
      ),
    );
    return confirme ?? false;
  }

  /// Ce que le bouton fait faire, nommé par le geste et non par l'état.
  String _getNextActionText(EtapeCourse? etape) => switch (etape) {
        EtapeCourse.recuperee => 'Récupérée',
        EtapeCourse.enRoute => 'En route',
        EtapeCourse.livree => 'Livré',
        _ => 'Suivant',
      };

  IconData _getNextActionIcon(EtapeCourse? etape) => switch (etape) {
        EtapeCourse.recuperee => Icons.shopping_bag,
        EtapeCourse.enRoute => Icons.delivery_dining,
        EtapeCourse.livree => Icons.check_circle,
        _ => Icons.arrow_forward,
      };

  Color _getStatusColor(EtapeCourse etape) {
    switch (etape) {
      case EtapeCourse.recuperee:
        return Colors.teal;
      case EtapeCourse.enRoute:
        return Colors.indigo;
      case EtapeCourse.livree:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _openChat(BuildContext context, Course order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(order: order),
      ),
    );
  }

  bool _isToday(DateTime dateTime) {
    final now = DateTime.now();
    return dateTime.day == now.day &&
        dateTime.month == now.month &&
        dateTime.year == now.year;
  }
}

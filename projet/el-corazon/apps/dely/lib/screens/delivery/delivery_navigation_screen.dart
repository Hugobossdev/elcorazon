import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_dely/services/app_service.dart';
import 'package:elcora_dely/services/error_handler_service.dart';
import 'package:elcora_dely/services/performance_service.dart';
import 'package:elcora_dely/screens/delivery/delivery_home_screen.dart';
import 'package:elcora_dely/screens/delivery/delivery_orders_screen.dart';
import 'package:elcora_dely/screens/delivery/analytics_screen.dart';
import 'package:elcora_dely/screens/delivery/settings_screen.dart';
import 'package:elcora_dely/screens/delivery/driver_profile_screen.dart';
import 'package:elcora_dely/screens/payments/earnings_screen.dart';
import 'package:elcora_dely/screens/payments/driver_payment_screen.dart';
import 'package:elcora_dely/screens/communication/chat_screen.dart';
import 'package:elcora_dely/presentation/messages_erreur.dart';

class DeliveryNavigationScreen extends StatefulWidget {
  const DeliveryNavigationScreen({super.key});

  @override
  State<DeliveryNavigationScreen> createState() =>
      _DeliveryNavigationScreenState();
}

class _DeliveryNavigationScreenState extends State<DeliveryNavigationScreen> {
  int _currentIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initializeServices();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    if (!mounted) return;

    try {
      await Provider.of<PerformanceService>(context, listen: false)
          .initialize()
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      await Provider.of<ErrorHandlerService>(context, listen: false)
          .initialize()
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      if (mounted) {
        final errorHandler =
            Provider.of<ErrorHandlerService>(context, listen: false);
        errorHandler.logError('Erreur initialisation services', details: e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: const [
          DeliveryHomeScreen(),
          DeliveryOrdersScreen(),
          AnalyticsScreen(),
          EarningsScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey[600],
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.delivery_dining),
            label: 'Livraisons',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Gains',
          ),
        ],
      ),
      drawer: _buildDrawer(),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildDrawerHeader(),
          _buildDrawerItem(
            icon: Icons.home,
            title: 'Accueil',
            onTap: () => _navigateToPage(0),
          ),
          _buildDrawerItem(
            icon: Icons.delivery_dining,
            title: 'Mes livraisons',
            onTap: () => _navigateToPage(1),
          ),
          _buildDrawerItem(
            icon: Icons.analytics,
            title: 'Analytics & Performance',
            onTap: () => _navigateToPage(2),
          ),
          _buildDrawerItem(
            icon: Icons.account_balance_wallet,
            title: 'Mes gains',
            onTap: () => _navigateToPage(3),
          ),
          _buildDrawerItem(
            icon: Icons.payment,
            title: 'Encaissement',
            onTap: () => _navigateToPayments(),
          ),
          _buildDrawerItem(
            icon: Icons.chat,
            title: 'Écrire au client',
            onTap: () => _navigateToClientChat(),
          ),
          const Divider(),
          _buildDrawerItem(
            icon: Icons.person,
            title: 'Mon profil',
            onTap: () => _navigateToProfile(),
          ),
          _buildDrawerItem(
            icon: Icons.settings,
            title: 'Paramètres',
            onTap: () => _navigateToSettings(),
          ),
          _buildDrawerItem(
            icon: Icons.logout,
            title: 'Déconnexion',
            onTap: () => _logout(),
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return Consumer<AppService>(
      builder: (context, appService, child) {
        final user = appService.currentUser;
        return DrawerHeader(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _navigateToProfile();
                  },
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Text(
                      user?.fullName.substring(0, 2).toUpperCase() ?? 'DR',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.fullName ?? 'Livreur',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Text(
                  // `driver@fasteat.ci` s'affichait ici en repli : une adresse
                  // inventée, sous une marque qui n'est pas la nôtre, montrée
                  // comme si c'était celle du livreur connecté.
                  user?.email ?? '',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: appService.isOnline ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        appService.isOnline ? 'En ligne' : 'Hors ligne',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
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

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red : null,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : null,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: _showQuickActions,
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
      child: const Icon(Icons.add),
    );
  }

  void _navigateToPage(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _navigateToPayments() {
    final appService = Provider.of<AppService>(context, listen: false);
    final assignedDeliveries = appService.assignedDeliveries;

    if (assignedDeliveries.isNotEmpty) {
      final order = assignedDeliveries.first;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DriverPaymentScreen(
            order: order,
            amount: order.total,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucune commande disponible pour le paiement'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  /// Ouvre la discussion avec le client de la course en cours.
  ///
  /// Cette entrée s'appelait « Support » et ouvrait le canal
  /// `ws/orders/{id}/chat/` — celui du **client**. Le nom promettait
  /// l'entreprise, le canal livrait le client. Elle dit maintenant ce qu'elle
  /// fait ; il n'existe pas de canal de support pour un livreur au contrat.
  void _navigateToClientChat() {
    final appService = Provider.of<AppService>(context, listen: false);
    final course = appService.activeCourse;

    if (course == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucune course en cours : pas de discussion à ouvrir.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChatScreen(order: course)),
    );
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DriverProfileScreen(),
      ),
    );
  }

  void _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      try {
        if (!mounted) return;
        final appService = Provider.of<AppService>(context, listen: false);
        await appService.logout();

        if (mounted) {
          unawaited(Navigator.of(context).pushNamedAndRemoveUntil(
            '/',
            (route) => false,
          ));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(messageErreur(e)),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showQuickActions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Actions rapides',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.payment,
                    title: 'Encaissement',
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToPayments();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.chat,
                    title: 'Client',
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToClientChat();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.person,
                    title: 'Profil',
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToProfile();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionButton(
                    icon: Icons.settings,
                    title: 'Paramètres',
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToSettings();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

}

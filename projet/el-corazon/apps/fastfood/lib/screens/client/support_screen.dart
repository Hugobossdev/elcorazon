import 'package:elcorazon_core/elcorazon_core.dart' show SupportTicket;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/support_service.dart';
import 'package:elcora_fast/theme.dart';
// import '../../widgets/enhanced_animations.dart'; // Supprimé
import 'package:elcora_fast/services/design_enhancement_service.dart';

/// Écran de support client
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // L'écran n'avait jamais déclenché de chargement : la liste des tickets
    // était donc vide en permanence, quel que soit le backend.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<SupportService>().loadTickets();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support Client'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Mes Tickets', icon: Icon(Icons.inbox)),
            Tab(text: 'Nouveau Ticket', icon: Icon(Icons.add_circle_outline)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _SupportTicketsList(),
          _CreateTicketTab(),
        ],
      ),
    );
  }
}

/// Libellés des valeurs de `TicketCategory` servies par l'API.
const Map<String, String> _categoryLabels = {
  'order': 'Commande',
  'payment': 'Paiement',
  'delivery': 'Livraison',
  'account': 'Compte',
  'other': 'Autre',
};

/// Liste des tickets de support
class _SupportTicketsList extends StatelessWidget {
  const _SupportTicketsList();

  @override
  Widget build(BuildContext context) {
    return Consumer<SupportService>(
      builder: (context, supportService, child) {
        if (supportService.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final tickets = supportService.tickets;

        if (tickets.isEmpty) {
          // Une liste vide et un chargement en échec ne disent pas la même
          // chose au client — l'ancienne version confondait les deux.
          final error = supportService.error;
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  error == null ? Icons.inbox_outlined : Icons.cloud_off,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(error ?? 'Aucun ticket de support'),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: supportService.loadTickets,
                    child: const Text('Réessayer'),
                  ),
                ],
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: supportService.loadTickets,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tickets.length,
            itemBuilder: (context, index) {
              final ticket = tickets[index];
              return _buildTicketCard(context, ticket);
            },
          ),
        );
      },
    );
  }

  Widget _buildTicketCard(BuildContext context, SupportTicket ticket) {
    Color statusColor;
    IconData statusIcon;

    switch (ticket.status) {
      case 'open':
        statusColor = Colors.blue;
        statusIcon = Icons.mail_outline;
        break;
      case 'in_progress':
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        break;
      case 'resolved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
        break;
      case 'closed':
        statusColor = Colors.grey;
        statusIcon = Icons.close;
        break;
      default:
        statusColor = Colors.blue;
        statusIcon = Icons.mail;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor,
          child: Icon(statusIcon, color: Colors.white),
        ),
        title: Text(
          ticket.subject,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              _categoryLabels[ticket.category] ?? ticket.category,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Il y a ${DateTime.now().difference(ticket.createdAt).inDays} jours',
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                ticket.status.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        onTap: () {
          // Navigate to ticket details
        },
      ),
    );
  }
}

/// Onglet de création de ticket
class _CreateTicketTab extends StatefulWidget {
  const _CreateTicketTab();

  @override
  State<_CreateTicketTab> createState() => _CreateTicketTabState();
}

class _CreateTicketTabState extends State<_CreateTicketTab> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedCategory = 'other';

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;

    // Plus de garde « connecté ? » ici : la requête part avec le jeton de
    // session, et c'est le serveur qui refuse (401) s'il n'y en a pas.
    final service = context.read<SupportService>();

    final success = await service.createTicket(
      category: _selectedCategory,
      subject: _subjectController.text,
      description: _descriptionController.text,
    );

    if (!mounted) return;

    if (success) {
      context.showSuccessMessage('Ticket créé avec succès !');
      _subjectController.clear();
      _descriptionController.clear();
    } else {
      context.showErrorMessage(
        service.error ?? 'Erreur lors de la création du ticket',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Catégorie',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Sélectionner une catégorie',
              ),
              // Valeurs de `TicketCategory` côté serveur, à la lettre : il n'y
              // a pas de catégorie « général », et une valeur inconnue serait
              // refusée en 400.
              items: const [
                DropdownMenuItem(value: 'order', child: Text('Commande')),
                DropdownMenuItem(value: 'payment', child: Text('Paiement')),
                DropdownMenuItem(value: 'delivery', child: Text('Livraison')),
                DropdownMenuItem(value: 'account', child: Text('Compte')),
                DropdownMenuItem(value: 'other', child: Text('Autre')),
              ],
              onChanged: (value) {
                setState(() => _selectedCategory = value ?? 'other');
              },
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _subjectController,
              decoration: const InputDecoration(
                labelText: 'Sujet',
                hintText: 'Résumez votre demande',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Veuillez entrer un sujet';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Décrivez votre problème en détail...',
                border: OutlineInputBorder(),
              ),
              maxLines: 8,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Veuillez entrer une description';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitTicket,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Envoyer le ticket',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

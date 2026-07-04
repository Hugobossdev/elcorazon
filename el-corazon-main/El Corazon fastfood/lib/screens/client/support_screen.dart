import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/support_service.dart';
import 'package:elcora_fast/services/app_service.dart';
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
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Aucun ticket de support'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: tickets.length,
          itemBuilder: (context, index) {
            final ticket = tickets[index];
            return _buildTicketCard(context, ticket);
          },
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
              ticket.category,
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
  String _selectedCategory = 'general';

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;

    final appService = context.read<AppService>();
    final currentUser = appService.currentUser;
    
    if (currentUser == null) {
      if (mounted) {
        context.showErrorMessage('Vous devez être connecté pour créer un ticket');
      }
      return;
    }

    final service = context.read<SupportService>();

    final ticket = SupportTicket(
      id: '',
      userId: currentUser.id,
      category: _selectedCategory,
      subject: _subjectController.text,
      description: _descriptionController.text,
      createdAt: DateTime.now(),
    );

    final success = await service.createTicket(ticket);

    if (success && mounted) {
      context.showSuccessMessage('Ticket créé avec succès !');
      _subjectController.clear();
      _descriptionController.clear();
    } else if (mounted) {
      context.showErrorMessage('Erreur lors de la création du ticket');
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
              items: const [
                DropdownMenuItem(value: 'general', child: Text('Général')),
                DropdownMenuItem(value: 'order', child: Text('Commande')),
                DropdownMenuItem(value: 'payment', child: Text('Paiement')),
                DropdownMenuItem(value: 'delivery', child: Text('Livraison')),
                DropdownMenuItem(value: 'account', child: Text('Compte')),
              ],
              onChanged: (value) {
                setState(() => _selectedCategory = value ?? 'general');
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

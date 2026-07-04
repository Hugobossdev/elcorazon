import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/driver_document.dart';
import '../../services/driver_document_service.dart' as svc;
import '../../services/driver_management_service.dart';
import 'driver_document_validation_screen.dart';

import '../../models/driver.dart';

class DriverDocumentsDashboardScreen extends StatefulWidget {
  const DriverDocumentsDashboardScreen({super.key});

  @override
  State<DriverDocumentsDashboardScreen> createState() =>
      _DriverDocumentsDashboardScreenState();
}

class _DriverDocumentsDashboardScreenState
    extends State<DriverDocumentsDashboardScreen>
    with SingleTickerProviderStateMixin {
  final svc.DriverDocumentService _documentService = svc.DriverDocumentService();
  late TabController _tabController;
  bool _isLoading = false;

  List<DriverDocument> _pendingDocuments = [];
  List<DriverDocument> _attentionDocuments = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Charger les données après le build initial
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final pending = await _documentService.getPendingDocuments();
      final attention = await _documentService.getDocumentsNeedingAttention();

      setState(() {
        _pendingDocuments = pending;
        _attentionDocuments = attention;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur chargement: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _runExpirationCheck() async {
    setState(() => _isLoading = true);
    try {
      await _documentService.checkExpiredDocuments();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vérification des expirations terminée'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Centre de Validation Documents'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: 'En attente (${_pendingDocuments.length})',
              icon: const Icon(Icons.pending_actions),
            ),
            Tab(
              text: 'À surveiller (${_attentionDocuments.length})',
              icon: const Icon(Icons.warning_amber),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Actualiser',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'check_expired') {
                _runExpirationCheck();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'check_expired',
                child: Row(
                  children: [
                    Icon(Icons.timer_off, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Vérifier les expirations'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDocumentList(_pendingDocuments, isPending: true),
                _buildDocumentList(_attentionDocuments, isPending: false),
              ],
            ),
    );
  }

  Widget _buildDocumentList(List<DriverDocument> documents,
      {required bool isPending}) {
    if (documents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPending ? Icons.check_circle_outline : Icons.verified_user,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              isPending
                  ? 'Aucun document en attente'
                  : 'Aucun document nécessitant une attention',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: documents.length,
      itemBuilder: (context, index) {
        final doc = documents[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isPending ? Colors.orange[100] : Colors.red[100],
              child: Icon(
                _getIconForType(doc.type),
                color: isPending ? Colors.orange[800] : Colors.red[800],
              ),
            ),
            title: Text(doc.type.displayName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Livreur: ${doc.driverName ?? "Inconnu"}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Date: ${_formatDate(doc.updatedAt)}'),
                if (doc.status == DocumentValidationStatus.expired)
                  Text(
                    'Expiré le: ${_formatDate(doc.expiryDate!)}',
                    style: const TextStyle(color: Colors.red),
                  ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              _navigateToValidation(doc);
            },
          ),
        );
      },
    );
  }

  Future<void> _navigateToValidation(DriverDocument doc) async {
    final driverService = context.read<DriverManagementService>();
    
    // Essayer de trouver le livreur dans la liste chargée
    Driver? driver;
    try {
      driver = driverService.drivers.firstWhere(
        (d) => d.userId == doc.userId || d.id == doc.userId,
      );
    } catch (_) {
      // Si non trouvé dans la liste (ex: pas chargé), créer un objet temporaire
      // ou idéalement charger le livreur spécifique
      if (doc.driverName != null) {
        driver = Driver(
          id: doc.userId,
          userId: doc.userId,
          authUserId: doc.userId,
          name: doc.driverName!,
          email: doc.driverEmail ?? '',
          phone: doc.driverPhone ?? '',
          status: DriverStatus.unavailable, // Statut par défaut
          isActive: false,
          rating: 0,
          totalDeliveries: 0,
          totalEarnings: 0,
          createdAt: DateTime.now(),
        );
      }
    }

    if (driver != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              DriverDocumentValidationScreen(driver: driver!),
        ),
      );
      // Recharger les données au retour
      _loadData();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de trouver les informations du livreur'),
          ),
        );
      }
    }
  }

  IconData _getIconForType(DocumentType type) {
    switch (type) {
      case DocumentType.license:
        return Icons.drive_eta;
      case DocumentType.identity:
        return Icons.badge;
      case DocumentType.vehicle:
        return Icons.directions_car;
      case DocumentType.insurance:
        return Icons.security;
      case DocumentType.registration:
        return Icons.description;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}


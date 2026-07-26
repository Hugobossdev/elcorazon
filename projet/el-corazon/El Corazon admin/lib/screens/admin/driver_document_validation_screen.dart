import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/driver.dart';
import '../../models/driver_document.dart';
import '../../services/driver_document_service.dart' as svc;
import '../../models/document_history.dart';
import '../../ui/ui.dart';

class DriverDocumentValidationScreen extends StatefulWidget {
  final Driver driver;

  const DriverDocumentValidationScreen({super.key, required this.driver});

  @override
  State<DriverDocumentValidationScreen> createState() =>
      _DriverDocumentValidationScreenState();
}

class _DriverDocumentValidationScreenState
    extends State<DriverDocumentValidationScreen> {
  final svc.DriverDocumentService _documentService =
      svc.DriverDocumentService();
  final SupabaseClient _supabase = Supabase.instance.client;

  // Documents chargés depuis la base de données
  final Map<DocumentType, DriverDocument?> _documents = {};

  // Historique des documents
  final Map<String, List<DocumentHistory>> _documentHistory = {};

  // Notes de validation
  final Map<DocumentType, TextEditingController> _notesControllers = {
    DocumentType.license: TextEditingController(),
    DocumentType.identity: TextEditingController(),
    DocumentType.vehicle: TextEditingController(),
    DocumentType.insurance: TextEditingController(),
  };

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDocumentStatus();
  }

  @override
  void dispose() {
    for (var controller in _notesControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDocumentStatus() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = widget.driver.userId ?? widget.driver.id;
      if (userId.isEmpty) {
        throw Exception('L\'ID utilisateur du livreur n\'est pas disponible');
      }

      final documents = await _documentService.getDriverDocuments(userId);

      // Organiser les documents par type et charger l'historique
      for (var doc in documents) {
        _documents[doc.type] = doc;
        // Charger les notes existantes
        final controller = _notesControllers[doc.type];
        if (controller != null && doc.validationNotes != null) {
          controller.text = doc.validationNotes!;
        }

        // Charger l'historique pour ce document
        try {
          final history = await _documentService.getDocumentHistory(doc.id);
          _documentHistory[doc.id] = history;
        } catch (e) {
          debugPrint('Erreur chargement historique pour ${doc.id}: $e');
        }
      }

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur lors du chargement: $e';
        });
      }
      debugPrint('Erreur chargement documents: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _validateDocument(
    DocumentType type,
    DocumentValidationStatus status,
    String notes,
  ) async {
    // Capturer les valeurs nécessaires avant le gap async
    final scheme = Theme.of(context).colorScheme;
    final sem = AdminColorTokens.semantic(scheme);
    final inverseSurfaceColor = scheme.inverseSurface;
    final document = _documents[type];
    if (document == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Aucun document trouvé pour ce type'),
          backgroundColor: scheme.inverseSurface,
        ),
      );
      return;
    }

    if (status == DocumentValidationStatus.rejected && notes.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Veuillez indiquer une raison pour le rejet dans les notes',
          ),
          backgroundColor: scheme.inverseSurface,
        ),
      );
      return;
    }

    // Confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          status == DocumentValidationStatus.approved
              ? 'Confirmer l\'approbation'
              : 'Confirmer le rejet',
        ),
        content: Text(
          status == DocumentValidationStatus.approved
              ? 'Êtes-vous sûr de vouloir approuver ce document ?'
              : 'Êtes-vous sûr de vouloir rejeter ce document ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: status == DocumentValidationStatus.approved
                  ? sem.success
                  : sem.danger,
              foregroundColor: scheme.onPrimary,
            ),
            child: Text(
              status == DocumentValidationStatus.approved
                  ? 'Approuver'
                  : 'Rejeter',
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Récupérer l'ID de l'admin actuel
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      bool success = false;
      if (status == DocumentValidationStatus.approved) {
        success = await _documentService.approveDocument(document.id);
      } else if (status == DocumentValidationStatus.rejected) {
        success = await _documentService.rejectDocument(
          document.id,
          notes.isNotEmpty ? notes : 'Document non conforme',
        );
      }

      if (success) {
        // Recharger les documents
        await _loadDocumentStatus();

        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Document ${type.displayName} ${status.displayName}',
              ),
              backgroundColor: status == DocumentValidationStatus.approved
                  ? sem.success
                  : sem.danger,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: inverseSurfaceColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateExpiryDate(DriverDocument document) async {
    // Capturer les valeurs nécessaires avant le gap async
    final inverseSurfaceColor =
        Theme.of(context).colorScheme.inverseSurface;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: document.expiryDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );

    if (picked != null && picked != document.expiryDate) {
      final success = await _documentService.updateDocumentExpiry(
        document.id,
        picked,
      );

      if (success) {
        await _loadDocumentStatus();
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Date d\'expiration mise à jour'),
              backgroundColor: inverseSurfaceColor,
            ),
          );
        }
      } else {
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Erreur lors de la mise à jour'),
              backgroundColor: inverseSurfaceColor,
            ),
          );
        }
      }
    }
  }

  Future<void> _viewDocument(DriverDocument document) async {
    if (document.fileUrl == null) return;

    final url = document.fileUrl!;
    final isImage = url.toLowerCase().endsWith('.jpg') ||
        url.toLowerCase().endsWith('.jpeg') ||
        url.toLowerCase().endsWith('.png') ||
        url.toLowerCase().endsWith('.webp');

    if (isImage) {
      await showDialog(
        context: context,
        builder: (context) => Dialog(
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  url,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return SizedBox(
                      height: 200,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => const Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(Icons.error, size: 40),
                        SizedBox(height: 8),
                        Text('Erreur lors du chargement de l\'image'),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.85),
                  child: IconButton(
                    icon: Icon(
                      Icons.close,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossible d\'ouvrir le document')),
          );
        }
      }
    }
  }

  DocumentValidationStatus _getDocumentStatus(DocumentType type) {
    final doc = _documents[type];
    if (doc == null) return DocumentValidationStatus.pending;
    return doc.status;
  }

  void _showHistoryDialog(DriverDocument document) {
    final history = _documentHistory[document.id] ?? [];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Historique - ${document.type.displayName}'),
        content: SizedBox(
          width: double.maxFinite,
          child: history.isEmpty
              ? const Center(child: Text('Aucun historique disponible'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final item = history[index];
                    return ListTile(
                      leading: _buildStatusIcon(item.newStatus),
                      title: Text(
                        '${item.previousStatus ?? "Nouveau"} ➔ ${item.newStatus}',
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Par: ${item.changedByName ?? "Système"}'),
                          if (item.changeReason != null)
                            Text('Raison: ${item.changeReason}'),
                          Text(
                            _formatDateWithTime(item.changedAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(String? status) {
    IconData icon;
    final sem = AdminColorTokens.semantic(Theme.of(context).colorScheme);
    final scheme = Theme.of(context).colorScheme;
    Color color;

    switch (status) {
      case 'approved':
        icon = Icons.check_circle;
        color = sem.success;
        break;
      case 'rejected':
        icon = Icons.cancel;
        color = sem.danger;
        break;
      case 'expired':
        icon = Icons.timer_off;
        color = sem.warning;
        break;
      default:
        icon = Icons.hourglass_empty;
        color = scheme.onSurfaceVariant;
    }

    return Icon(icon, color: color);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Validation des documents - ${widget.driver.name}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Informations du livreur
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        widget.driver.name.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.driver.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Text(widget.driver.email),
                          Text(widget.driver.phone),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Documents
            Text(
              'Documents à valider',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              )
            else ...[
              _buildDocumentCard(
                DocumentType.license,
                'Permis de conduire',
                Icons.drive_eta,
                _getDocumentStatus(DocumentType.license),
                _notesControllers[DocumentType.license]!,
                _documents[DocumentType.license],
              ),
              _buildDocumentCard(
                DocumentType.identity,
                'Pièce d\'identité',
                Icons.badge,
                _getDocumentStatus(DocumentType.identity),
                _notesControllers[DocumentType.identity]!,
                _documents[DocumentType.identity],
              ),
              _buildDocumentCard(
                DocumentType.vehicle,
                'Documents du véhicule',
                Icons.directions_car,
                _getDocumentStatus(DocumentType.vehicle),
                _notesControllers[DocumentType.vehicle]!,
                _documents[DocumentType.vehicle],
              ),
              _buildDocumentCard(
                DocumentType.insurance,
                'Assurance',
                Icons.security,
                _getDocumentStatus(DocumentType.insurance),
                _notesControllers[DocumentType.insurance]!,
                _documents[DocumentType.insurance],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentCard(
    DocumentType type,
    String title,
    IconData icon,
    DocumentValidationStatus status,
    TextEditingController notesController,
    DriverDocument? document,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                _buildStatusChip(status),
              ],
            ),
            const SizedBox(height: 16),
            // Zone d'affichage du document
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: document?.fileUrl != null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.description,
                          size: 48,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          document!.fileName ?? 'Document',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (document.fileSize != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${(document.fileSize! / 1024).toStringAsFixed(1)} KB',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        if (document.expiryDate != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Expire le: ${_formatDate(document.expiryDate!)}',
                                style: TextStyle(
                                  color: document.isExpired
                                      ? Theme.of(context).colorScheme.error
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                  fontWeight: document.isExpired
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              const SizedBox(width: 4),
                              InkWell(
                                onTap: () => _updateExpiryDate(document),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Icon(
                                    Icons.edit_calendar,
                                    size: 16,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          const SizedBox(height: 4),
                          TextButton.icon(
                            onPressed: () => _updateExpiryDate(document),
                            icon: const Icon(Icons.calendar_month, size: 16),
                            label: const Text('Définir expiration'),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 32),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () => _viewDocument(document),
                          icon: const Icon(Icons.visibility),
                          label: const Text('Voir le document'),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => _showHistoryDialog(document),
                          icon: const Icon(Icons.history),
                          label: const Text('Voir l\'historique'),
                        ),
                      ],
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cloud_upload,
                            size: 48,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.6),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Document non téléchargé',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Le livreur doit télécharger ce document',
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant
                                    .withValues(alpha: 0.85),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            if (document?.rejectionReason != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.error.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Raison du rejet: ${document!.rejectionReason}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            // Notes
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Ajouter des notes sur ce document...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
            ),
            const SizedBox(height: 16),
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: (_isLoading || document == null)
                      ? null
                      : () => _validateDocument(
                            type,
                            DocumentValidationStatus.rejected,
                            notesController.text,
                          ),
                  icon: const Icon(Icons.close),
                  label: const Text('Rejeter'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: (_isLoading || document == null)
                      ? null
                      : () => _validateDocument(
                            type,
                            DocumentValidationStatus.approved,
                            notesController.text,
                          ),
                  icon: const Icon(Icons.check),
                  label: const Text('Approuver'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminColorTokens.semantic(
                      Theme.of(context).colorScheme,
                    ).success,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(DocumentValidationStatus status) {
    final scheme = Theme.of(context).colorScheme;
    final sem = AdminColorTokens.semantic(scheme);
    Color color;
    String label;

    switch (status) {
      case DocumentValidationStatus.pending:
        color = sem.warning;
        label = 'En attente';
        break;
      case DocumentValidationStatus.approved:
        color = sem.success;
        label = 'Approuvé';
        break;
      case DocumentValidationStatus.rejected:
        color = sem.danger;
        label = 'Rejeté';
        break;
      case DocumentValidationStatus.expired:
        color = sem.danger;
        label = 'Expiré';
        break;
    }

    return Chip(
      label: Text(
        label,
        style: TextStyle(
          color: scheme.onPrimary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateWithTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/driver.dart';
import '../../models/driver_document.dart';
import '../../services/driver_document_service.dart' as svc;
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

  // Documents chargés depuis la base de données
  final Map<DocumentType, DriverDocument?> _documents = {};


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

      await _documentService.refresh();
      final courier = _documentService.courierById(userId);
      if (courier == null) {
        throw Exception('Dossier introuvable dans votre périmètre');
      }

      // Les trois pièces portent le statut **du dossier** : c'est la seule
      // décision qui existe côté serveur. Approuver le permis en rejetant la
      // carte grise laissait le compte dans un état que personne ne savait
      // lire — le livreur pouvait-il travailler ?
      for (final doc in _documentService.documentsOf(courier)) {
        _documents[doc.type] = doc;
        final controller = _notesControllers[doc.type];
        if (controller != null && doc.validationNotes != null) {
          controller.text = doc.validationNotes!;
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
      // L'auteur de la décision vient du jeton, côté serveur : une trace qu'on
      // renseigne soi-même ne trace rien. La décision porte sur le **dossier**,
      // pas sur la pièce affichée.
      bool success = false;
      if (status == DocumentValidationStatus.approved) {
        success = await _documentService.approveCourier(
          document.userId,
          notes: notes,
        );
      } else if (status == DocumentValidationStatus.rejected) {
        success = await _documentService.rejectCourier(
          document.userId,
          notes.isNotEmpty ? notes : 'Dossier non conforme',
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
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () => _viewDocument(document),
                          icon: const Icon(Icons.visibility),
                          label: const Text('Voir le document'),
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

}

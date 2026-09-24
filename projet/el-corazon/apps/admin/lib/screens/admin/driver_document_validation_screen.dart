import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:admin/presentation/autorisations.dart';
import 'package:admin/presentation/documents_livreur.dart';
import 'package:admin/presentation/expiration_piece.dart';
import 'package:admin/services/driver_document_service.dart' as svc;
import 'package:admin/ui/ui.dart';
import 'package:elcorazon_core/elcorazon_core.dart' show Journal;
import 'package:admin/presentation/messages_erreur.dart';

class DriverDocumentValidationScreen extends StatefulWidget {
  final eccore.CourierProfile driver;

  const DriverDocumentValidationScreen({required this.driver, super.key});

  @override
  State<DriverDocumentValidationScreen> createState() =>
      _DriverDocumentValidationScreenState();
}

class _DriverDocumentValidationScreenState
    extends State<DriverDocumentValidationScreen> {
  final svc.DriverDocumentService _documentService =
      svc.DriverDocumentService();

  // Documents chargés depuis la base de données
  final Map<PieceDossier, PieceLivreur?> _documents = {};


  // Notes de validation
  final Map<PieceDossier, TextEditingController> _notesControllers = {
    PieceDossier.permis: TextEditingController(),
    PieceDossier.identite: TextEditingController(),
    PieceDossier.carteGrise: TextEditingController(),
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
    for (final controller in _notesControllers.values) {
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
      final userId = widget.driver.id;
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
        _documents[doc.piece] = doc;
        final controller = _notesControllers[doc.piece];
        if (controller != null && doc.notes != null) {
          controller.text = doc.notes!;
        }
      }

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur lors du chargement: $e';
        });
      }
      Journal.trace('Erreur chargement documents: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _validateDocument(
    PieceDossier type,
    StatutVerification status,
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

    if (status == StatutVerification.refuse && notes.trim().isEmpty) {
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
          status == StatutVerification.approuve
              ? 'Confirmer l\'approbation'
              : 'Confirmer le rejet',
        ),
        content: Text(
          status == StatutVerification.approuve
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
              backgroundColor: status == StatutVerification.approuve
                  ? sem.success
                  : sem.danger,
              foregroundColor: scheme.onPrimary,
            ),
            child: Text(
              status == StatutVerification.approuve
                  ? 'Approuver'
                  : 'Rejeter',
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // L'auteur de la décision vient du jeton, côté serveur : une trace qu'on
      // renseigne soi-même ne trace rien. La décision porte sur le **dossier**,
      // pas sur la pièce affichée.
      bool success = false;
      if (status == StatutVerification.approuve) {
        success = await _documentService.approveCourier(
          document.courierId,
          notes: notes,
        );
      } else if (status == StatutVerification.refuse) {
        success = await _documentService.rejectCourier(
          document.courierId,
          notes.isNotEmpty ? notes : 'Dossier non conforme',
        );
      }

      if (!success) {
        // Le refus du serveur passait sous silence : le bouton semblait sans
        // effet, et l'opérateur recommençait. Il dit maintenant pourquoi — une
        // pièce expirée, un dossier déjà décidé.
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_documentService.error ?? 'Décision refusée par le serveur.'),
              backgroundColor: inverseSurfaceColor,
            ),
          );
        }
      }

      if (success) {
        // Recharger les documents
        await _loadDocumentStatus();

        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Document ${type.libelle} ${status.libelle}',
              ),
              backgroundColor: status == StatutVerification.approuve
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
            content: Text(messageErreur(e)),
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

  Future<void> _enregistrerExpiration(PieceLivreur document, DateTime date) async {
    final messager = ScaffoldMessenger.of(context);
    final ok = await _documentService.enregistrerExpiration(
      document.courierId,
      document.piece,
      date,
    );
    if (!mounted) return;
    messager.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Date d’expiration de la ${document.piece.libelle.toLowerCase()} enregistrée'
              : _documentService.error ?? 'Date refusée par le serveur.',
        ),
      ),
    );
    if (ok) await _loadDocumentStatus();
  }

  Future<void> _viewDocument(PieceLivreur document) async {
    if (document.url == null) return;

    final url = document.url!;
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

  StatutVerification _getDocumentStatus(PieceDossier type) {
    final doc = _documents[type];
    if (doc == null) return StatutVerification.enAttente;
    return doc.statut;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Validation des documents - ${widget.driver.fullName}'),
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
                        widget.driver.fullName.substring(0, 1).toUpperCase(),
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
                            widget.driver.fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Text(widget.driver.email),
                          Text(widget.driver.vehicleType),
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
                PieceDossier.permis,
                'Permis de conduire',
                Icons.drive_eta,
                _getDocumentStatus(PieceDossier.permis),
                _notesControllers[PieceDossier.permis]!,
                _documents[PieceDossier.permis],
              ),
              _buildDocumentCard(
                PieceDossier.identite,
                'Pièce d\'identité',
                Icons.badge,
                _getDocumentStatus(PieceDossier.identite),
                _notesControllers[PieceDossier.identite]!,
                _documents[PieceDossier.identite],
              ),
              _buildDocumentCard(
                PieceDossier.carteGrise,
                'Carte grise',
                Icons.directions_car,
                _getDocumentStatus(PieceDossier.carteGrise),
                _notesControllers[PieceDossier.carteGrise]!,
                _documents[PieceDossier.carteGrise],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentCard(
    PieceDossier type,
    String title,
    IconData icon,
    StatutVerification status,
    TextEditingController notesController,
    PieceLivreur? document,
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
              child: document?.url != null
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
                          document!.piece.libelle,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
            if (document != null && document.estDeposee) ...[
              const SizedBox(height: 8),
              _LigneExpiration(
                document: document,
                onChoisir: (date) => _enregistrerExpiration(document, date),
              ),
            ],
            if (document?.motifDeRefus != null) ...[
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
                        'Raison du rejet: ${document!.motifDeRefus}',
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
            //
            // Instruire un dossier demande `couriers.approve` : sans lui,
            // l'écran offrait « Approuver » et « Rejeter » à qui ne peut que
            // consulter, et le refus n'arrivait qu'après le clic.
            if (!context.peut('couriers.approve'))
              Text(
                'Instruire un dossier demande le droit « Valider les livreurs » '
                '(couriers.approve).',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: (_isLoading || document == null)
                      ? null
                      : () => _validateDocument(
                            type,
                            StatutVerification.refuse,
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
                            StatutVerification.approuve,
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

  Widget _buildStatusChip(StatutVerification status) {
    final scheme = Theme.of(context).colorScheme;
    final sem = AdminColorTokens.semantic(scheme);
    Color color;
    String label;

    switch (status) {
      case StatutVerification.enAttente:
        color = sem.warning;
        label = 'En attente';
        break;
      case StatutVerification.approuve:
        color = sem.success;
        label = 'Approuvé';
        break;
      case StatutVerification.refuse:
        color = sem.danger;
        label = 'Rejeté';
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

/// La date d'expiration d'une pièce, et de quoi la saisir.
///
/// Elle se relève pièce en main : le bouton ouvre un calendrier borné à partir
/// d'aujourd'hui — saisir une date passée reviendrait à consigner une pièce
/// déjà invalide, que le serveur refuserait de toute façon à la validation.
class _LigneExpiration extends StatelessWidget {
  const _LigneExpiration({required this.document, required this.onChoisir});

  final PieceLivreur document;
  final ValueChanged<DateTime> onChoisir;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sem = AdminColorTokens.semantic(scheme);
    final etat = EtatExpiration.de(document.expireLe);
    final couleur = switch (etat) {
      EtatExpiration.expiree => sem.danger,
      EtatExpiration.bientot => sem.warning,
      EtatExpiration.valide => sem.success,
      EtatExpiration.inconnue => scheme.onSurfaceVariant,
    };

    return Row(
      children: [
        Icon(Icons.event_rounded, size: 18, color: couleur),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            libelleExpiration(document.expireLe),
            style: TextStyle(color: couleur, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ),
        TextButton(
          onPressed: () async {
            final aujourdhui = DateTime.now();
            final choisie = await showDatePicker(
              context: context,
              firstDate: DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day),
              lastDate: DateTime(aujourdhui.year + 30),
              initialDate: document.expireLe != null && !document.expireLe!.isBefore(aujourdhui)
                  ? document.expireLe!
                  : aujourdhui,
              helpText: 'Date d’expiration de la pièce',
            );
            if (choisie != null) onChoisir(choisie);
          },
          child: Text(document.expireLe == null ? 'Saisir' : 'Modifier'),
        ),
      ],
    );
  }
}


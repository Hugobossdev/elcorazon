import 'package:flutter/material.dart';
import 'package:elcora_fast/services/design_enhancement_service.dart';
import 'package:elcora_fast/services/driver_rating_service.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/widgets/design/design.dart';
import 'package:elcorazon_core/elcorazon_core.dart' show Journal;

/// Notation de la livraison.
///
/// ## Ce que la maquette demande, et ce qui manque au serveur
///
/// `rate_delivery` propose des étoiles, des puces d'appréciation
/// (« Professional », « Fast Delivery »…) **et un pourboire** — 500, 1 000 ou
/// 2 000 F, avec la mention « 100 % of the tip goes directly to Koffi A. ».
///
/// Le pourboire n'est **pas dessiné**. Aucune route n'encaisse de
/// gratification : ni `POST /delivery/orders/{id}/rating/`, qui n'accepte
/// qu'un score et un commentaire, ni `/payments/`. Un sélecteur de pourboire
/// qui ne débite rien est le pire cas de figure sur un écran d'argent — le
/// client croit avoir donné, le livreur ne reçoit rien, et personne ne s'en
/// aperçoit avant longtemps. C'est **BR-002** de
/// `docs/STITCH_BACKEND_REQUIREMENTS.md`.
///
/// Les puces, elles, partent réellement : elles ouvrent le commentaire, seul
/// champ libre du contrat.
class DriverRatingScreen extends StatefulWidget {
  final String orderId;
  final String driverId;
  final String? driverName;

  const DriverRatingScreen({
    required this.orderId,
    required this.driverId,
    this.driverName,
    super.key,
  });

  @override
  State<DriverRatingScreen> createState() => _DriverRatingScreenState();
}

class _DriverRatingScreenState extends State<DriverRatingScreen> {
  final _commentController = TextEditingController();
  final _ratingService = DriverRatingService();
  int _note = 0;
  Set<String> _appreciations = <String>{};
  bool _isLoading = false;

  /// Les quatre appréciations de la maquette, traduites.
  static const _appreciationsPossibles = [
    'Ponctuel',
    'Professionnel',
    'Aimable',
    'Consignes respectées',
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_note == 0) {
      context.showErrorMessage('Choisissez une note avant d’envoyer.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Le livreur et l'auteur ne voyagent plus : le serveur les déduit de la
      // course et du jeton.
      final success = await _ratingService.submitRating(
        orderId: widget.orderId,
        rating: _note,
        comment: _commentaireComplet(),
      );

      if (!mounted) return;
      if (success) {
        context.showSuccessMessage('Merci, votre avis est enregistré.');
        Navigator.of(context).pop(true);
      } else {
        // `submitRating` rend `false` sur 409 (déjà noté) et 404 (course non
        // livrée, ou commande d'autrui). Le message le dit plutôt que
        // d'accuser le réseau.
        context.showErrorMessage(
          'Avis non enregistré : cette livraison a peut-être déjà été notée.',
        );
      }
    } catch (e) {
      Journal.trace('Notation du livreur: $e');
      if (mounted) {
        context.showErrorMessage('Envoi impossible pour le moment.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Les puces retenues, puis le commentaire libre.
  ///
  /// Le contrat n'a pas de champ d'étiquettes ; les joindre au commentaire est
  /// le seul moyen de les faire parvenir. Les collecter sans les envoyer aurait
  /// été pire que de ne pas les proposer.
  String _commentaireComplet() {
    final libre = _commentController.text.trim();
    if (_appreciations.isEmpty) return libre;

    final puces = _appreciations.join(', ');
    return libre.isEmpty ? puces : '$puces — $libre';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nom = widget.driverName ?? 'votre livreur';

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: const GlassAppBar(title: 'Noter la livraison'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          DesignConstants.edgeMargin,
          DesignConstants.spacingL,
          DesignConstants.edgeMargin,
          DesignConstants.spacingXL,
        ),
        children: [
          Center(
            child: Container(
              width: DesignConstants.avatarSizeLarge + 16,
              height: DesignConstants.avatarSizeLarge + 16,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.two_wheeler_rounded,
                size: 40,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: DesignConstants.spacingL),
          Text(
            'Comment s’est passée la livraison ?',
            textAlign: TextAlign.center,
            style: AppTypography.headlineSm(color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: DesignConstants.spacingS),
          Text(
            'Votre retour sur $nom reste anonyme pour lui.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMd(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: DesignConstants.spacingL),
          RatingStars(
            note: _note,
            onChanged: (note) => setState(() => _note = note),
          ),
          // Les puces n'apparaissent qu'une fois la note posée : demander ce
          // qui s'est bien passé avant de savoir si quelque chose s'est bien
          // passé met la charrue devant les bœufs.
          if (_note > 0) ...[
            const SizedBox(height: DesignConstants.spacingL),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _note >= 4 ? 'Qu’est-ce qui a plu ?' : 'Que s’est-il passé ?',
                    style: AppTypography.titleLg(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: DesignConstants.spacingM),
                  AppreciationChips(
                    options: _appreciationsPossibles,
                    retenues: _appreciations,
                    onChanged: (suite) =>
                        setState(() => _appreciations = suite),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: DesignConstants.spacingM),
          SectionCard(
            child: TextField(
              controller: _commentController,
              maxLines: 4,
              style: AppTypography.bodyLg(color: theme.colorScheme.onSurface),
              decoration: const InputDecoration(
                hintText: 'Ajouter un commentaire (facultatif)',
              ),
            ),
          ),
          const SizedBox(height: DesignConstants.spacingL),
          ActionButton(
            label: 'Envoyer mon avis',
            emphasis: ActionEmphasis.gradient,
            icon: Icons.send_rounded,
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _submitRating,
          ),
        ],
      ),
    );
  }
}

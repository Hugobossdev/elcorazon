import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:elcora_dely/presentation/messages_erreur.dart';
import 'package:elcora_dely/presentation/pieces_du_dossier.dart';
import 'package:elcora_dely/services/app_service.dart';
import 'package:elcora_dely/widgets/custom_button.dart';

/// Dépôt des pièces justificatives — `POST /delivery/me/`.
///
/// ## L'étape qui manquait au parcours
///
/// L'inscription créait un compte et un dossier **vide**, puis l'application
/// annonçait au candidat qu'El Corazón vérifiait ses pièces. Il n'y en avait
/// aucune : aucune des trois applications ne savait en téléverser. L'écran de
/// validation du back-office montrait trois emplacements vides pour tout le
/// monde, et un dossier refusé n'avait aucune issue — le mur d'état ne
/// proposait que « Actualiser » et « Se déconnecter ».
///
/// Cet écran ferme les deux bouts : il complète un dossier neuf, et il corrige
/// un dossier refusé.
///
/// ## Ce que déposer déclenche vraiment
///
/// **Le dépôt rouvre l'instruction** (L5) quand le dossier était validé ou
/// refusé, et remet le livreur hors ligne. L'écran le dit avant l'envoi, pas
/// après : un livreur validé qui remplace sa carte grise entre deux courses
/// doit savoir qu'il repasse en attente, sinon il découvre la bascule au
/// moment où une course ne lui arrive pas.
///
/// ## Pourquoi les octets et non un chemin
///
/// `XFile.readAsBytes()` plutôt que le chemin du fichier : le chemin n'existe
/// pas sur le web, et le dépôt part en `multipart` depuis
/// `DeliveryRepository.submitDocuments`, qui attend des octets. Le coût est de
/// tenir la photo en mémoire, ce qui est sans conséquence à cette taille — les
/// images sont d'ailleurs réduites à la prise (voir [_maxLargeur]).
///
/// ## Ce que cet écran n'affiche pas
///
/// **Aucun statut par pièce.** Le serveur n'en a pas : le dossier porte une
/// seule décision de vérification, valable pour l'ensemble. Afficher « permis :
/// validé » laisserait croire qu'une pièce peut être approuvée seule, et
/// aucun champ ne le permettrait. Ce qui se dit d'une pièce est : déposée, ou
/// pas — et le motif d'un refus, qui porte sur le dossier, s'affiche une fois
/// en haut.
class PiecesJustificativesScreen extends StatefulWidget {
  const PiecesJustificativesScreen({super.key});

  @override
  State<PiecesJustificativesScreen> createState() => _PiecesJustificativesScreenState();
}

class _PiecesJustificativesScreenState extends State<PiecesJustificativesScreen> {
  /// Les pièces choisies mais pas encore envoyées, par emplacement.
  ///
  /// Un dépôt en attente n'est **pas** une pièce du dossier : tant que l'envoi
  /// n'a pas abouti, le serveur n'en sait rien. Les tenir séparées de
  /// `courierProfile` est ce qui évite d'afficher comme acquise une pièce que
  /// le réseau a perdue.
  final Map<PieceDuDossier, _PieceChoisie> _enAttenteDEnvoi = {};

  final ImagePicker _selecteur = ImagePicker();

  bool _envoiEnCours = false;
  String? _erreur;

  /// Les photos sont réduites avant l'envoi.
  ///
  /// Un appareil récent produit des fichiers de plusieurs mégaoctets ; un
  /// livreur en 3G les enverrait pendant une minute, et un instructeur n'a
  /// besoin que de lire un numéro. 1600 px de large suffisent largement pour
  /// une carte d'identité.
  static const double _maxLargeur = 1600;

  Future<void> _choisir(PieceDuDossier piece, ImageSource source) async {
    setState(() => _erreur = null);
    try {
      final fichier = await _selecteur.pickImage(
        source: source,
        maxWidth: _maxLargeur,
        imageQuality: 85,
      );
      // Annulation : l'utilisateur a fermé la galerie. Ce n'est pas une erreur,
      // et afficher un message le laisserait croire que quelque chose a échoué.
      if (fichier == null) return;

      final octets = await fichier.readAsBytes();
      if (!mounted) return;
      setState(() {
        _enAttenteDEnvoi[piece] = _PieceChoisie(
          nom: fichier.name,
          octets: octets,
          typeMime: fichier.mimeType,
        );
      });
    } catch (erreur) {
      if (!mounted) return;
      // Permission refusée, appareil photo indisponible, fichier illisible :
      // trois causes, un seul écran, et le message du système est ce qui
      // renseigne le mieux.
      setState(() => _erreur = messageErreur(erreur));
    }
  }

  Future<void> _proposerLaSource(PieceDuDossier piece) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    await _choisir(piece, source);
  }

  /// Prévient qu'un dépôt va rouvrir l'instruction, et attend un accord.
  ///
  /// Uniquement quand le dossier est **validé** : c'est le seul cas où le
  /// livreur perd quelque chose en déposant — son éligibilité aux courses. Un
  /// dossier en attente ou refusé n'a rien à perdre, et lui poser la question
  /// ajouterait une étape à un parcours qui n'en demande pas.
  Future<bool> _accordPourRouvrirLInstruction(String? statut) async {
    if (statut != 'approved') return true;

    final accord = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Votre dossier repassera en attente'),
        content: const Text(
          'Remplacer une pièce annule la validation en cours : El Corazón doit '
          'relire votre dossier, et vous ne recevrez pas de course pendant ce '
          'temps. Vous serez également remis hors ligne.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Envoyer quand même'),
          ),
        ],
      ),
    );
    return accord ?? false;
  }

  Future<void> _envoyer() async {
    if (_envoiEnCours || _enAttenteDEnvoi.isEmpty) return;

    final app = context.read<AppService>();
    if (!await _accordPourRouvrirLInstruction(app.courierProfile?.verificationStatus)) {
      return;
    }
    if (!mounted) return;

    setState(() {
      _envoiEnCours = true;
      _erreur = null;
    });

    try {
      await app.deposerPieces(
        identite: _enAttenteDEnvoi[PieceDuDossier.identite]?.versContrat(),
        permis: _enAttenteDEnvoi[PieceDuDossier.permis]?.versContrat(),
        carteGrise: _enAttenteDEnvoi[PieceDuDossier.carteGrise]?.versContrat(),
      );
      if (!mounted) return;

      // Vidées seulement maintenant : tant que l'envoi n'a pas abouti, ces
      // pièces sont la seule copie de ce que le livreur a choisi, et les
      // perdre sur une coupure réseau lui ferait tout reprendre en photo.
      setState(() => _enAttenteDEnvoi.clear());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pièces envoyées. El Corazón vous répondra après les avoir lues.',
          ),
        ),
      );
    } catch (erreur) {
      if (!mounted) return;
      setState(() => _erreur = messageErreur(erreur));
    } finally {
      if (mounted) setState(() => _envoiEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = context.watch<AppService>();
    final dossier = app.courierProfile;
    final motif = dossier?.verificationNotes ?? '';
    final aQuelqueChoseAEnvoyer = _enAttenteDEnvoi.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Mes pièces justificatives')),
      body: SafeArea(
        child: dossier == null
            ? const _DossierIllisible()
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const _Encart(
                    icone: Icons.info_outline,
                    texte:
                        'Ces pièces ne sont visibles que par El Corazón. Elles '
                        'sont conservées dans un espace privé et ne sont jamais '
                        'montrées aux clients.',
                  ),

                  // Le motif du refus, en haut et une seule fois : il porte sur
                  // le dossier entier, pas sur une pièce. Le répéter sous
                  // chacune laisserait croire que les trois sont en cause.
                  if (dossier.verificationStatus == 'rejected' && motif.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _Encart(
                      icone: Icons.error_outline,
                      erreur: true,
                      titre: 'Motif du refus',
                      texte: motif,
                    ),
                  ],

                  const SizedBox(height: 24),
                  for (final piece in PieceDuDossier.values) ...[
                    _CartePiece(
                      piece: piece,
                      dejaDeposee: piece.estDeposeeSur(dossier),
                      choisie: _enAttenteDEnvoi[piece],
                      enabled: !_envoiEnCours,
                      onChoisir: () => unawaited(_proposerLaSource(piece)),
                      onRetirer: () => setState(() => _enAttenteDEnvoi.remove(piece)),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_erreur != null) ...[
                    const SizedBox(height: 8),
                    _Encart(icone: Icons.error_outline, erreur: true, texte: _erreur!),
                  ],

                  const SizedBox(height: 12),
                  Text(
                    aQuelqueChoseAEnvoyer
                        ? 'Vous pouvez n\'envoyer qu\'une partie de vos pièces : '
                              'celles que vous ne joignez pas restent inchangées.'
                        : 'Choisissez au moins une pièce à envoyer.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 16),
                  CustomButton(
                    text: 'Envoyer',
                    icon: Icons.cloud_upload_outlined,
                    isLoading: _envoiEnCours,
                    // Désactivé tant que rien n'est choisi : le serveur
                    // refuserait un dépôt vide, et laisser le bouton actif
                    // ferait payer un aller-retour pour l'apprendre.
                    onPressed: aQuelqueChoseAEnvoyer ? _envoyer : null,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
      ),
    );
  }
}

/// Une pièce choisie sur l'appareil, pas encore partie.
@immutable
class _PieceChoisie {
  const _PieceChoisie({required this.nom, required this.octets, this.typeMime});

  final String nom;
  final Uint8List octets;
  final String? typeMime;

  eccore.PieceJustificative versContrat() =>
      eccore.PieceJustificative(filename: nom, bytes: octets, contentType: typeMime);
}

/// Un emplacement du dossier : ce qu'on attend, ce qui y est, ce qu'on y met.
class _CartePiece extends StatelessWidget {
  const _CartePiece({
    required this.piece,
    required this.dejaDeposee,
    required this.choisie,
    required this.enabled,
    required this.onChoisir,
    required this.onRetirer,
  });

  final PieceDuDossier piece;
  final bool dejaDeposee;
  final _PieceChoisie? choisie;
  final bool enabled;
  final VoidCallback onChoisir;
  final VoidCallback onRetirer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aRemplacer = choisie;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(piece.icone, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(piece.libelle, style: theme.textTheme.titleMedium),
                ),
                _Pastille(dejaDeposee: dejaDeposee, aEnvoyer: aRemplacer != null),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              piece.precision,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),

            // L'aperçu de ce qui va partir. Il vaut une vérification : la
            // photo la plus souvent rejetée est celle qu'on a prise de travers
            // sans la regarder.
            if (aRemplacer != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  aRemplacer.octets,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  // Un fichier que l'appareil a rendu mais que Flutter ne sait
                  // pas décoder — un PDF choisi dans la galerie, par exemple.
                  // Il partira quand même ; seul l'aperçu manque.
                  errorBuilder: (context, error, stack) => Container(
                    height: 80,
                    alignment: Alignment.center,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Text(
                      aRemplacer.nom,
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: enabled ? onChoisir : null,
                    icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                    label: Text(
                      aRemplacer != null
                          ? 'Changer'
                          : dejaDeposee
                          ? 'Remplacer'
                          : 'Ajouter',
                    ),
                  ),
                ),
                if (aRemplacer != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Retirer ce choix',
                    onPressed: enabled ? onRetirer : null,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// L'état d'un emplacement, en un mot.
///
/// Trois états, et pas quatre : il n'y a pas de « validée ». La décision porte
/// sur le dossier entier, et le serveur n'expose aucun statut par pièce.
class _Pastille extends StatelessWidget {
  const _Pastille({required this.dejaDeposee, required this.aEnvoyer});

  final bool dejaDeposee;
  final bool aEnvoyer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (libelle, couleur) = aEnvoyer
        ? ('À envoyer', theme.colorScheme.primary)
        : dejaDeposee
        ? ('Déposée', Colors.green.shade700)
        : ('Manquante', theme.colorScheme.error);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: couleur.withValues(alpha: 0.4)),
      ),
      child: Text(
        libelle,
        style: theme.textTheme.labelSmall?.copyWith(
          color: couleur,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Le dossier n'a pas encore été lu — ou sa lecture a échoué.
///
/// Sans les URL des pièces, l'écran ne peut pas dire lesquelles manquent, et
/// afficher trois emplacements « manquants » ferait redéposer des pièces déjà
/// présentes.
class _DossierIllisible extends StatelessWidget {
  const _DossierIllisible();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_off_outlined, size: 56),
            const SizedBox(height: 16),
            const Text(
              'Votre dossier n\'a pas pu être lu. Sans lui, impossible de savoir '
              'quelles pièces vous avez déjà déposées.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () =>
                  unawaited(context.read<AppService>().rechargerDossier()),
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Encart extends StatelessWidget {
  const _Encart({
    required this.icone,
    required this.texte,
    this.titre,
    this.erreur = false,
  });

  final IconData icone;
  final String texte;
  final String? titre;
  final bool erreur;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final couleur = erreur ? theme.colorScheme.error : theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: couleur.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: couleur, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (titre != null) ...[
                  Text(
                    titre!,
                    style: theme.textTheme.labelLarge?.copyWith(color: couleur),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  texte,
                  style: theme.textTheme.bodyMedium?.copyWith(color: couleur),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

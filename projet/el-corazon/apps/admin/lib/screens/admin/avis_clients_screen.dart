import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/presentation/messages_erreur.dart';
import 'package:admin/screens/admin/versements/communs.dart';
import 'package:admin/services/admin_auth_service.dart';

/// Ce que la clientèle dit des plats — et la modération.
///
/// Les avis se lisaient dans l'application cliente et nulle part au
/// back-office : ni les mécontents à rappeler, ni l'insulte à retirer. Le
/// module du serveur le disait lui-même — « ce sont des gestes de modération,
/// qui appellent une trace d'audit et une permission dédiée » — sans qu'aucun
/// n'existe.
///
/// Un avis se **masque**, motif exigé ; il ne s'efface pas. Masqué, il sort de
/// la vitrine et de la note moyenne, et le geste est au journal d'audit.
enum FiltreAvis {
  tous('Tous'),
  mecontents('≤ 2 étoiles'),
  visibles('Visibles'),
  masques('Masqués');

  const FiltreAvis(this.libelle);
  final String libelle;
}

class AvisClientsService extends ChangeNotifier {
  AvisClientsService({eccore.ManagedReviewRepository? depot}) : _depotInjecte = depot;

  final eccore.ManagedReviewRepository? _depotInjecte;

  eccore.ManagedReviewRepository get _depot =>
      _depotInjecte ?? eccore.ManagedReviewRepository(apiClient: AdminAuthService().apiClient);

  List<eccore.ManagedReview> _avis = const [];
  FiltreAvis filtre = FiltreAvis.mecontents;
  bool _chargement = false;
  String? _erreur;
  final Set<String> _enCours = {};

  List<eccore.ManagedReview> get avis => List.unmodifiable(_avis);
  bool get chargement => _chargement;
  String? get erreur => _erreur;
  bool enCours(String id) => _enCours.contains(id);

  Future<void> charger({FiltreAvis? filtre}) async {
    this.filtre = filtre ?? this.filtre;
    _chargement = true;
    _erreur = null;
    notifyListeners();
    try {
      final page = await _depot.reviews(
        masques: switch (this.filtre) {
          FiltreAvis.visibles => false,
          FiltreAvis.masques => true,
          _ => null,
        },
        noteMax: this.filtre == FiltreAvis.mecontents ? 2 : null,
      );
      _avis = page.results;
    } on eccore.ApiException catch (e) {
      _erreur = messageErreur(e);
    } finally {
      _chargement = false;
      notifyListeners();
    }
  }

  /// Rend `null` en cas de succès, sinon la phrase du refus.
  Future<String?> masquer(String id, String motif) =>
      _geste(id, () => _depot.hide(reviewId: id, reason: motif));

  Future<String?> reafficher(String id) => _geste(id, () => _depot.show(id));

  Future<String?> _geste(String id, Future<eccore.ManagedReview> Function() action) async {
    if (_enCours.contains(id)) return 'Envoi déjà en cours.';
    _enCours.add(id);
    notifyListeners();
    try {
      final maj = await action();
      _avis = [
        for (final a in _avis)
          if (a.id != maj.id)
            a
          // Dans un filtre par visibilité, l'avis qui change d'état sort de
          // la liste ; ailleurs, il reste avec son nouvel état.
          else if (!((filtre == FiltreAvis.visibles && maj.estMasque) ||
              (filtre == FiltreAvis.masques && !maj.estMasque)))
            maj,
      ];
      return null;
    } on eccore.ApiException catch (e) {
      return messageErreur(e);
    } finally {
      _enCours.remove(id);
      notifyListeners();
    }
  }
}

class AvisClientsScreen extends StatefulWidget {
  const AvisClientsScreen({super.key});

  @override
  State<AvisClientsScreen> createState() => _AvisClientsScreenState();
}

class _AvisClientsScreenState extends State<AvisClientsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<AvisClientsService>().charger());
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<AvisClientsService>();
    final peutModerer = context.watch<AdminAuthService>().can('catalog.write');

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final option in FiltreAvis.values)
                  ChoiceChip(
                    label: Text(option.libelle),
                    selected: service.filtre == option,
                    onSelected: (_) => unawaited(service.charger(filtre: option)),
                  ),
                IconButton(
                  tooltip: 'Recharger',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () => unawaited(service.charger()),
                ),
              ],
            ),
          ),
          Expanded(
            child: EtatDeListe(
              chargement: service.chargement,
              erreur: service.erreur,
              vide: service.avis.isEmpty,
              messageVide: 'Aucun avis pour ce filtre.',
              onReessayer: () => unawaited(service.charger()),
              liste: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final avis in service.avis) _CarteAvis(avis: avis, peutModerer: peutModerer),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CarteAvis extends StatelessWidget {
  const _CarteAvis({required this.avis, required this.peutModerer});

  final eccore.ManagedReview avis;
  final bool peutModerer;

  Future<void> _masquer(BuildContext context) async {
    final service = context.read<AvisClientsService>();
    final messager = ScaffoldMessenger.of(context);
    final motif = await demanderTexte(
      context,
      titre: 'Masquer cet avis',
      explication: 'Il sortira de l’application cliente et de la note moyenne du plat. '
          'Le motif est conservé au journal d’audit.',
      libelle: 'Motif',
      action: 'Masquer',
      destructif: true,
    );
    if (motif == null) return;
    final refus = await service.masquer(avis.id, motif);
    messager.showSnackBar(SnackBar(content: Text(refus ?? 'Avis masqué.')));
  }

  Future<void> _reafficher(BuildContext context) async {
    final service = context.read<AvisClientsService>();
    final messager = ScaffoldMessenger.of(context);
    final refus = await service.reafficher(avis.id);
    messager.showSnackBar(SnackBar(content: Text(refus ?? 'Avis réaffiché.')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final occupe = context.watch<AvisClientsService>().enCours(avis.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: avis.estMasque ? theme.colorScheme.surfaceContainerHighest : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '★' * avis.rating + '☆' * (5 - avis.rating),
                  style: TextStyle(color: theme.colorScheme.tertiary, fontSize: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    avis.menuItemName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (avis.estMasque)
                  const Chip(label: Text('Masqué'), visualDensity: VisualDensity.compact),
              ],
            ),
            if (avis.title.isNotEmpty)
              Text(avis.title, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (avis.comment.isNotEmpty) Text(avis.comment),
            const SizedBox(height: 4),
            Text(
              '${avis.authorName}${avis.isVerifiedPurchase ? ' · achat vérifié' : ''} · '
              '${avis.restaurantName} · ${dateCourte(avis.createdAt)}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
            if (avis.estMasque)
              Text(
                'Masqué${avis.hiddenByName == null ? '' : ' par ${avis.hiddenByName}'} : '
                '${avis.hiddenReason}',
                style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              ),
            if (peutModerer)
              Align(
                alignment: Alignment.centerRight,
                child: avis.estMasque
                    ? TextButton(
                        onPressed: occupe ? null : () => unawaited(_reafficher(context)),
                        child: const Text('Réafficher'),
                      )
                    : TextButton(
                        onPressed: occupe ? null : () => unawaited(_masquer(context)),
                        child: const Text('Masquer…'),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

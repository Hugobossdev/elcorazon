import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/presentation/inventaire.dart';
import 'package:admin/presentation/messages_erreur.dart';
import 'package:admin/screens/inventaire/saisie_de_stock.dart';
import 'package:admin/services/admin_auth_service.dart';
import 'package:admin/ui/ui.dart';

/// Le stock d'une cuisine — ce qu'elle détient, ce qu'elle a promis, ce qui
/// manque bientôt.
///
/// ## Pourquoi cet écran existe
///
/// Recettes, réservation de matière et rupture existaient côté serveur — et
/// personne ne pouvait enregistrer une livraison autrement que par un `shell`.
/// Le mécanisme était en place et dormant.
///
/// ## Ce qu'il ne fait pas
///
/// **Écrire un stock.** Aucun champ n'y touche : une livraison se reçoit, une
/// perte se déclare, un écart se compte, et le serveur tient le journal. Le
/// plafond de la cuisine décide si une perte passe seule ; l'écran se contente
/// de dire ce qui s'est passé.
///
/// Les boutons suivent les permissions du compte : ils ne s'affichent que pour
/// ce que le serveur acceptera. Masquer n'accorde ni ne retire rien — le
/// serveur reste l'autorité.
class StockScreen extends StatefulWidget {
  const StockScreen({required this.restaurant, super.key});

  final eccore.ManagedRestaurant restaurant;

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  eccore.ManagedInventoryRepository get _depot =>
      eccore.ManagedInventoryRepository(apiClient: AdminAuthService().apiClient);

  List<eccore.StockLine> _lignes = const [];
  bool _chargement = true;
  bool _seulementEnAlerte = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    unawaited(_charger());
  }

  @override
  void didUpdateWidget(StockScreen ancien) {
    super.didUpdateWidget(ancien);
    // Le sélecteur d'établissement a changé de cuisine : relire, sans quoi
    // l'écran montrerait le stock de la précédente sous le nom de la nouvelle.
    if (ancien.restaurant.slug != widget.restaurant.slug) unawaited(_charger());
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final lignes = await _depot.stockLines(
        restaurantSlug: widget.restaurant.slug,
        lowOnly: _seulementEnAlerte,
      );
      if (mounted) setState(() => _lignes = lignes);
    } catch (erreur) {
      if (mounted) setState(() => _erreur = messageErreur(erreur));
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  void _annoncer(String? message) {
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    unawaited(_charger());
  }

  Future<void> _recevoir(eccore.StockLine ligne) async {
    final message = await showDialog<String>(
      context: context,
      builder: (_) => DialogueDeSaisie(
        titre: 'Réception — ${ligne.ingredientName}',
        dimension: ligne.dimension,
        libelleQuantite: 'Quantité livrée',
        avecPrix: true,
        devise: widget.restaurant.currency,
        avecReference: true,
        pourUneLivraison: true,
        envoyer: (saisie) async {
          final mouvement = await _depot.receive(
            stockLineId: ligne.id,
            quantity: saisie.quantite,
            totalCost: saisie.prix,
            reference: saisie.reference,
            idempotencyKey: saisie.cle,
          );
          return 'Réception enregistrée : ${mouvement.quantity.label} de ${ligne.ingredientName}.';
        },
      ),
    );
    _annoncer(message);
  }

  Future<void> _declarerPerte(eccore.StockLine ligne) async {
    final message = await showDialog<String>(
      context: context,
      builder: (_) => DialogueDeSaisie(
        titre: 'Perte — ${ligne.ingredientName}',
        explication: 'Au-delà du plafond de la cuisine, la perte attend la validation '
            'd’une autre personne avant de sortir du stock.',
        dimension: ligne.dimension,
        libelleQuantite: 'Quantité perdue',
        motifObligatoire: true,
        envoyer: (saisie) async {
          final declaration = await _depot.declareWaste(
            stockLineId: ligne.id,
            quantity: saisie.quantite,
            reason: saisie.motif,
            idempotencyKey: saisie.cle,
          );
          return issueDeDeclaration(declaration, quoi: 'Perte');
        },
      ),
    );
    _annoncer(message);
  }

  Future<void> _compter(eccore.StockLine ligne) async {
    final message = await showDialog<String>(
      context: context,
      builder: (_) => DialogueDeSaisie(
        titre: 'Comptage — ${ligne.ingredientName}',
        explication: 'Indiquez ce que vous trouvez sur l’étagère. Le système en déduit '
            'l’écart avec son stock (${ligne.onHand.label}).',
        dimension: ligne.dimension,
        libelleQuantite: 'Quantité comptée',
        motifObligatoire: true,
        pourUneLivraison: true,
        envoyer: (saisie) async {
          final declaration = await _depot.declareCount(
            stockLineId: ligne.id,
            counted: saisie.quantite,
            reason: saisie.motif,
            idempotencyKey: saisie.cle,
          );
          return issueDeDeclaration(declaration, quoi: 'Correction');
        },
      ),
    );
    _annoncer(message);
  }

  Future<void> _fixerSeuil(eccore.StockLine ligne) async {
    final message = await showDialog<String>(
      context: context,
      builder: (_) => DialogueDeSaisie(
        titre: 'Seuil d’alerte — ${ligne.ingredientName}',
        explication: 'La ligne passe en alerte quand le disponible — détenu moins '
            'promis — descend à ce seuil.',
        dimension: ligne.dimension,
        libelleQuantite: 'Seuil',
        pourUneLivraison: true,
        envoyer: (saisie) async {
          await _depot.setLowStockThreshold(ligne.id, saisie.quantite);
          return 'Seuil fixé à ${saisie.quantite.label}.';
        },
      ),
    );
    _annoncer(message);
  }

  Future<void> _ouvrirLigne() async {
    final message = await showDialog<String>(
      context: context,
      builder: (_) => _OuvertureDeLigne(
        depot: _depot,
        restaurantSlug: widget.restaurant.slug,
        dejaOuverts: {for (final ligne in _lignes) ligne.ingredientId},
      ),
    );
    _annoncer(message);
  }

  Future<void> _voirJournal(eccore.StockLine ligne) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _Journal(depot: _depot, ligne: ligne),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AdminAuthService>();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Stock — ${widget.restaurant.name}', style: theme.textTheme.titleLarge),
              FilterChip(
                label: const Text('Au seuil d’alerte'),
                selected: _seulementEnAlerte,
                onSelected: (valeur) {
                  setState(() => _seulementEnAlerte = valeur);
                  unawaited(_charger());
                },
              ),
              IconButton(
                tooltip: 'Relire',
                onPressed: _chargement ? null : _charger,
                icon: const Icon(Icons.refresh),
              ),
              if (auth.can('inventory.write'))
                FilledButton.tonalIcon(
                  onPressed: _ouvrirLigne,
                  icon: const Icon(Icons.add),
                  label: const Text('Suivre un ingrédient'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: _corps(theme, auth)),
        ],
      ),
    );
  }

  Widget _corps(ThemeData theme, AdminAuthService auth) {
    if (_chargement && _lignes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_erreur != null) {
      return _Etat(
        icone: Icons.cloud_off_rounded,
        titre: 'Stock illisible',
        detail: _erreur!,
        action: FilledButton.tonal(onPressed: _charger, child: const Text('Réessayer')),
      );
    }
    if (_lignes.isEmpty) {
      return _Etat(
        icone: Icons.inventory_2_outlined,
        titre: _seulementEnAlerte ? 'Aucune ligne en alerte' : 'Aucun ingrédient suivi',
        detail: _seulementEnAlerte
            ? 'Toutes les lignes sont au-dessus de leur seuil.'
            : 'Un ingrédient sans ligne de stock n’est jamais décompté : les plats '
                'qui l’emploient restent commandables quoi qu’il reste en chambre froide.',
      );
    }

    return ListView.separated(
      itemCount: _lignes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, rang) {
        final ligne = _lignes[rang];
        return _CarteDeLigne(
          ligne: ligne,
          onRecevoir: auth.can('inventory.receive') ? () => _recevoir(ligne) : null,
          onPerte: auth.can('inventory.adjust') ? () => _declarerPerte(ligne) : null,
          onCompter: auth.can('inventory.adjust') ? () => _compter(ligne) : null,
          onSeuil: auth.can('inventory.write') ? () => _fixerSeuil(ligne) : null,
          onJournal: () => _voirJournal(ligne),
        );
      },
    );
  }
}

class _CarteDeLigne extends StatelessWidget {
  const _CarteDeLigne({
    required this.ligne,
    required this.onJournal,
    this.onRecevoir,
    this.onPerte,
    this.onCompter,
    this.onSeuil,
  });

  final eccore.StockLine ligne;
  final VoidCallback? onRecevoir;
  final VoidCallback? onPerte;
  final VoidCallback? onCompter;
  final VoidCallback? onSeuil;
  final VoidCallback onJournal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantique = AdminColorTokens.semantic(theme.colorScheme);
    final seuil = ligne.lowStockThreshold;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(ligne.ingredientName, style: theme.textTheme.titleMedium),
                ),
                if (ligne.isLow)
                  Chip(
                    avatar: Icon(Icons.warning_amber_rounded, color: semantique.danger, size: 18),
                    label: const Text('Seuil atteint'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              ligne.available.label,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: ligne.isLow ? semantique.danger : null,
              ),
              semanticsLabel: 'Disponible : ${ligne.available.label}',
            ),
            Text(
              [
                'Détenu ${ligne.onHand.label}',
                'promis ${ligne.reserved.label}',
                if (seuil != null) 'seuil ${seuil.label}',
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              [
                libelleCout(ligne.unitCost, ligne.costUnit),
                if (ligne.stockValue != null) 'valeur ${ligne.stockValue!.format()}',
              ].join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              children: [
                if (onRecevoir != null)
                  TextButton.icon(
                    onPressed: onRecevoir,
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: const Text('Réception'),
                  ),
                if (onPerte != null)
                  TextButton.icon(
                    onPressed: onPerte,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Perte'),
                  ),
                if (onCompter != null)
                  TextButton.icon(
                    onPressed: onCompter,
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Comptage'),
                  ),
                if (onSeuil != null)
                  TextButton.icon(
                    onPressed: onSeuil,
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: const Text('Seuil'),
                  ),
                TextButton.icon(
                  onPressed: onJournal,
                  icon: const Icon(Icons.history),
                  label: const Text('Journal'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Le journal d'une ligne, page par page — par curseur, comme le serveur le rend.
class _Journal extends StatefulWidget {
  const _Journal({required this.depot, required this.ligne});

  final eccore.ManagedInventoryRepository depot;
  final eccore.StockLine ligne;

  @override
  State<_Journal> createState() => _JournalState();
}

class _JournalState extends State<_Journal> {
  final List<eccore.StockMovement> _mouvements = [];
  String? _suivante;
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    unawaited(_charger());
  }

  Future<void> _charger({bool suite = false}) async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final page = await widget.depot.movements(
        stockLineId: widget.ligne.id,
        next: suite ? _suivante : null,
      );
      if (!mounted) return;
      setState(() {
        if (!suite) _mouvements.clear();
        _mouvements.addAll(page.results);
        _suivante = page.next;
      });
    } catch (erreur) {
      if (mounted) setState(() => _erreur = messageErreur(erreur));
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          Text('Journal — ${widget.ligne.ingredientName}', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_erreur != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_erreur!, style: TextStyle(color: theme.colorScheme.error)),
            ),
          Expanded(
            child: _mouvements.isEmpty && !_chargement
                ? const Center(child: Text('Aucun mouvement pour cette ligne.'))
                : ListView.builder(
                    itemCount: _mouvements.length + 1,
                    itemBuilder: (context, rang) {
                      if (rang == _mouvements.length) {
                        if (_chargement) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return _suivante == null
                            ? const SizedBox.shrink()
                            : TextButton(
                                onPressed: () => _charger(suite: true),
                                child: const Text('Mouvements plus anciens'),
                              );
                      }
                      final mouvement = _mouvements[rang];
                      final details = [
                        if (mouvement.actorName.isNotEmpty) mouvement.actorName,
                        if (mouvement.reference.isNotEmpty) mouvement.reference,
                        if (mouvement.reason.isNotEmpty) mouvement.reason,
                      ].join(' · ');
                      return ListTile(
                        dense: true,
                        title: Text(
                          '${libelleMouvement(mouvement.kind)} ${mouvement.quantity.label}',
                        ),
                        subtitle: Text(
                          [
                            MaterialLocalizations.of(context)
                                .formatShortDate(mouvement.createdAt.toLocal()),
                            if (details.isNotEmpty) details,
                          ].join(' — '),
                        ),
                        trailing: mouvement.value == null ? null : Text(mouvement.value!.format()),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Ouvre le suivi d'un ingrédient dans la cuisine.
class _OuvertureDeLigne extends StatefulWidget {
  const _OuvertureDeLigne({
    required this.depot,
    required this.restaurantSlug,
    required this.dejaOuverts,
  });

  final eccore.ManagedInventoryRepository depot;
  final String restaurantSlug;
  final Set<String> dejaOuverts;

  @override
  State<_OuvertureDeLigne> createState() => _OuvertureDeLigneState();
}

class _OuvertureDeLigneState extends State<_OuvertureDeLigne> {
  List<eccore.Ingredient>? _candidats;
  eccore.Ingredient? _choisi;
  bool _envoi = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    unawaited(_charger());
  }

  Future<void> _charger() async {
    try {
      final actifs = await widget.depot.ingredients(isActive: true);
      if (!mounted) return;
      setState(() {
        _candidats = [
          for (final ingredient in actifs)
            if (!widget.dejaOuverts.contains(ingredient.id)) ingredient,
        ];
      });
    } catch (erreur) {
      if (mounted) setState(() => _erreur = messageErreur(erreur));
    }
  }

  Future<void> _ouvrir() async {
    final choisi = _choisi;
    if (choisi == null) return;
    setState(() {
      _envoi = true;
      _erreur = null;
    });
    try {
      await widget.depot.openStockLine(
        restaurantSlug: widget.restaurantSlug,
        ingredientId: choisi.id,
      );
      if (mounted) Navigator.of(context).pop('« ${choisi.name} » est désormais suivi.');
    } catch (erreur) {
      if (mounted) {
        setState(() {
          _envoi = false;
          _erreur = messageErreur(erreur);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidats = _candidats;
    return AlertDialog(
      title: const Text('Suivre un ingrédient'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'La ligne part à zéro : enregistrez ensuite une réception pour y faire '
              'entrer la matière.',
            ),
            const SizedBox(height: 16),
            if (candidats == null && _erreur == null)
              const Center(child: CircularProgressIndicator())
            else if (candidats != null && candidats.isEmpty)
              const Text('Tous les ingrédients actifs du référentiel sont déjà suivis ici.')
            else if (candidats != null)
              DropdownButton<eccore.Ingredient>(
                isExpanded: true,
                value: _choisi,
                hint: const Text('Ingrédient'),
                items: [
                  for (final ingredient in candidats)
                    DropdownMenuItem(
                      value: ingredient,
                      child: Text('${ingredient.name} — ${libelleDimension(ingredient.dimension)}'),
                    ),
                ],
                onChanged: _envoi ? null : (choix) => setState(() => _choisi = choix),
              ),
            if (_erreur != null) ...[
              const SizedBox(height: 12),
              Text(_erreur!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _envoi ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _envoi || _choisi == null ? null : _ouvrir,
          child: const Text('Suivre'),
        ),
      ],
    );
  }
}

/// Un état d'écran — vide ou en erreur — avec ce qu'il faut faire.
class _Etat extends StatelessWidget {
  const _Etat({required this.icone, required this.titre, required this.detail, this.action});

  final IconData icone;
  final String titre;
  final String detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 48, color: theme.hintColor),
            const SizedBox(height: 12),
            Text(titre, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(detail, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

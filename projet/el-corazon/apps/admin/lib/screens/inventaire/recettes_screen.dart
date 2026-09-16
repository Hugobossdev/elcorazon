import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/presentation/inventaire.dart';
import 'package:admin/presentation/messages_erreur.dart';
import 'package:admin/services/admin_auth_service.dart';
import 'package:admin/ui/ui.dart';

/// Les recettes d'une carte — ce que chaque plat sort de la chambre froide.
///
/// ## Ce que l'écran met en tête
///
/// **La couverture.** Un plat sans recette ne consomme rien au stock : c'est
/// voulu pendant la bascule, et indistinguable, depuis un inventaire, d'un plat
/// qui ne consomme réellement rien. Tant que la liste n'est pas vide, le coût
/// matière de la cuisine est incomplet — l'écran le dit avant de montrer quoi
/// que ce soit d'autre.
///
/// ## Les options
///
/// Un supplément fromage consomme du fromage ; « sans oignon » en retire. Leur
/// recette se compose au même endroit que celle du plat, et une quantité
/// négative n'y est acceptée que sur une option — le serveur refuse le reste.
class RecettesScreen extends StatefulWidget {
  const RecettesScreen({required this.restaurant, super.key});

  final eccore.ManagedRestaurant restaurant;

  @override
  State<RecettesScreen> createState() => _RecettesScreenState();
}

class _RecettesScreenState extends State<RecettesScreen> {
  eccore.ApiClient get _api => AdminAuthService().apiClient;

  List<eccore.ManagedMenuItem> _plats = const [];
  Map<String, eccore.Recipe> _parCible = const {};
  eccore.RecipeCoverage? _couverture;
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    unawaited(_charger());
  }

  @override
  void didUpdateWidget(RecettesScreen ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.restaurant.slug != widget.restaurant.slug) unawaited(_charger());
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final recettes = eccore.ManagedRecipeRepository(apiClient: _api);
      final resultats = await Future.wait([
        eccore.ManagedCatalogRepository(apiClient: _api)
            .menuItems(restaurantSlug: widget.restaurant.slug),
        recettes.recipes(restaurantSlug: widget.restaurant.slug),
        recettes.coverage(restaurantSlug: widget.restaurant.slug),
      ]);
      if (!mounted) return;
      setState(() {
        _plats = resultats[0] as List<eccore.ManagedMenuItem>;
        _parCible = indexerParCible(resultats[1] as List<eccore.Recipe>);
        _couverture = resultats[2] as eccore.RecipeCoverage;
      });
    } catch (erreur) {
      if (mounted) setState(() => _erreur = messageErreur(erreur));
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _editer(eccore.ManagedMenuItem plat) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _EditeurDeRecettes(
          plat: plat,
          recettes: _parCible,
          ecriture: context.read<AdminAuthService>().can('recipes.write'),
        ),
      ),
    );
    if (mounted) unawaited(_charger());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final couverture = _couverture;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recettes — ${widget.restaurant.name}',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Relire',
                onPressed: _chargement ? null : _charger,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (couverture != null) _Couverture(couverture: couverture),
          const SizedBox(height: 12),
          Expanded(child: _corps(theme)),
        ],
      ),
    );
  }

  Widget _corps(ThemeData theme) {
    if (_chargement && _plats.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_erreur != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_erreur!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: _charger, child: const Text('Réessayer')),
          ],
        ),
      );
    }
    if (_plats.isEmpty) {
      return const Center(child: Text('La carte de cette cuisine ne compte aucun plat.'));
    }

    final semantique = AdminColorTokens.semantic(theme.colorScheme);
    return ListView.separated(
      itemCount: _plats.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, rang) {
        final plat = _plats[rang];
        final recette = _parCible[plat.id];
        return ListTile(
          title: Text(plat.name),
          subtitle: Text(resumeDeRecette(recette)),
          trailing: recette == null || recette.lines.isEmpty
              ? Icon(Icons.warning_amber_rounded, color: semantique.warning, semanticLabel: 'Sans recette')
              : Icon(Icons.check_circle_outline, color: semantique.success, semanticLabel: 'Recette saisie'),
          onTap: () => _editer(plat),
        );
      },
    );
  }
}

/// Indexe les recettes par leur cible — plat ou option.
Map<String, eccore.Recipe> indexerParCible(List<eccore.Recipe> recettes) => {
      for (final recette in recettes) (recette.menuItemId ?? recette.optionId)!: recette,
    };

/// « 3 ingrédients », ou « Sans recette — ne consomme rien au stock ».
String resumeDeRecette(eccore.Recipe? recette) {
  final nombre = recette?.lines.length ?? 0;
  if (nombre == 0) return 'Sans recette — ne consomme rien au stock';
  return nombre == 1 ? '1 ingrédient' : '$nombre ingrédients';
}

class _Couverture extends StatelessWidget {
  const _Couverture({required this.couverture});

  final eccore.RecipeCoverage couverture;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantique = AdminColorTokens.semantic(theme.colorScheme);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${couverture.itemsWithRecipe} plat(s) sur ${couverture.itemsTotal} ont une recette',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: couverture.ratio,
              color: couverture.isComplete ? semantique.success : semantique.warning,
            ),
            if (!couverture.isComplete) ...[
              const SizedBox(height: 8),
              Text(
                'Les autres ne consomment rien au stock, et leur coût matière est inconnu : '
                'la marge de la cuisine ne peut pas encore être crue.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// La recette du plat et celles de ses options, sur un même écran.
class _EditeurDeRecettes extends StatefulWidget {
  const _EditeurDeRecettes({required this.plat, required this.recettes, required this.ecriture});

  final eccore.ManagedMenuItem plat;
  final Map<String, eccore.Recipe> recettes;
  final bool ecriture;

  @override
  State<_EditeurDeRecettes> createState() => _EditeurDeRecettesState();
}

class _EditeurDeRecettesState extends State<_EditeurDeRecettes> {
  eccore.ApiClient get _api => AdminAuthService().apiClient;
  late final Map<String, eccore.Recipe> _recettes = Map.of(widget.recettes);
  List<eccore.Ingredient> _ingredients = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_chargerIngredients());
  }

  Future<void> _chargerIngredients() async {
    try {
      final actifs =
          await eccore.ManagedInventoryRepository(apiClient: _api).ingredients(isActive: true);
      if (mounted) setState(() => _ingredients = actifs);
    } catch (erreur) {
      if (mounted) _annoncer(messageErreur(erreur));
    }
  }

  void _annoncer(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _ajouter({String? platId, String? optionId}) async {
    final ligne = await showDialog<({eccore.Ingredient ingredient, eccore.Quantity quantite})>(
      context: context,
      builder: (_) => _NouvelleLigne(ingredients: _ingredients, pourUneOption: optionId != null),
    );
    if (ligne == null || !mounted) return;

    final depot = eccore.ManagedRecipeRepository(apiClient: _api);
    final cible = (platId ?? optionId)!;
    try {
      final existante = _recettes[cible] ??
          await depot.create(menuItemId: platId, optionId: optionId);
      final composee = await depot.setLine(
        recipeId: existante.id,
        ingredientId: ligne.ingredient.id,
        quantity: ligne.quantite,
      );
      if (mounted) setState(() => _recettes[cible] = composee);
    } catch (erreur) {
      if (mounted) _annoncer(messageErreur(erreur));
    }
  }

  Future<void> _retirer(String cible, eccore.RecipeLine ligne) async {
    final recette = _recettes[cible];
    if (recette == null) return;
    try {
      final videe = await eccore.ManagedRecipeRepository(apiClient: _api)
          .removeLine(recipeId: recette.id, ingredientId: ligne.ingredientId);
      if (mounted) setState(() => _recettes[cible] = videe);
    } catch (erreur) {
      if (mounted) _annoncer(messageErreur(erreur));
    }
  }

  @override
  Widget build(BuildContext context) {
    final plat = widget.plat;
    return Scaffold(
      appBar: AppBar(title: Text('Recette — ${plat.name}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Bloc(
            titre: 'Le plat',
            recette: _recettes[plat.id],
            ecriture: widget.ecriture,
            onAjouter: () => _ajouter(platId: plat.id),
            onRetirer: (ligne) => _retirer(plat.id, ligne),
          ),
          for (final groupe in plat.optionGroups)
            for (final option in groupe.options)
              _Bloc(
                titre: '${groupe.name} › ${option.name}',
                recette: _recettes[option.id],
                ecriture: widget.ecriture,
                onAjouter: () => _ajouter(optionId: option.id),
                onRetirer: (ligne) => _retirer(option.id, ligne),
              ),
        ],
      ),
    );
  }
}

class _Bloc extends StatelessWidget {
  const _Bloc({
    required this.titre,
    required this.recette,
    required this.ecriture,
    required this.onAjouter,
    required this.onRetirer,
  });

  final String titre;
  final eccore.Recipe? recette;
  final bool ecriture;
  final VoidCallback onAjouter;
  final ValueChanged<eccore.RecipeLine> onRetirer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lignes = recette?.lines ?? const <eccore.RecipeLine>[];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titre, style: theme.textTheme.titleMedium),
            if (lignes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Aucune matière.', style: theme.textTheme.bodySmall),
              ),
            for (final ligne in lignes)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(ligne.ingredientName),
                subtitle: Text(
                  ligne.quantity.isNegative
                      ? '${ligne.quantity.label} — retirés de la recette du plat'
                      : ligne.quantity.label,
                ),
                trailing: ecriture
                    ? IconButton(
                        tooltip: 'Retirer ${ligne.ingredientName}',
                        onPressed: () => onRetirer(ligne),
                        icon: const Icon(Icons.remove_circle_outline),
                      )
                    : null,
              ),
            if (ecriture)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onAjouter,
                  icon: const Icon(Icons.add),
                  label: const Text('Ingrédient'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NouvelleLigne extends StatefulWidget {
  const _NouvelleLigne({required this.ingredients, required this.pourUneOption});

  final List<eccore.Ingredient> ingredients;
  final bool pourUneOption;

  @override
  State<_NouvelleLigne> createState() => _NouvelleLigneState();
}

class _NouvelleLigneState extends State<_NouvelleLigne> {
  eccore.Ingredient? _ingredient;
  String? _unite;
  final _quantite = TextEditingController();
  String? _erreur;

  @override
  void dispose() {
    _quantite.dispose();
    super.dispose();
  }

  void _valider() {
    final ingredient = _ingredient;
    final unite = _unite;
    if (ingredient == null || unite == null) return;
    try {
      final quantite = eccore.Quantity.saisie(_quantite.text, unite);
      if (quantite.isZero) {
        setState(() => _erreur = 'Une ligne à zéro ne veut rien dire : retirez l’ingrédient plutôt.');
        return;
      }
      if (quantite.isNegative && !widget.pourUneOption) {
        setState(
          () => _erreur = 'Une quantité négative n’a de sens que sur une option qui retire '
              '— « sans oignon ».',
        );
        return;
      }
      Navigator.of(context).pop((ingredient: ingredient, quantite: quantite));
    } on FormatException catch (erreur) {
      setState(() => _erreur = erreur.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ingredient = _ingredient;
    return AlertDialog(
      title: const Text('Ajouter un ingrédient'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButton<eccore.Ingredient>(
              isExpanded: true,
              value: ingredient,
              hint: const Text('Ingrédient'),
              items: [
                for (final candidat in widget.ingredients)
                  DropdownMenuItem(value: candidat, child: Text(candidat.name)),
              ],
              onChanged: (choix) => setState(() {
                _ingredient = choix;
                _unite = choix == null ? null : unitesDeSaisie(choix.dimension).first;
              }),
            ),
            if (ingredient != null)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _quantite,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      decoration: InputDecoration(
                        labelText: 'Par portion',
                        helperText: widget.pourUneOption
                            ? 'Négative pour une option qui retire de la matière.'
                            : null,
                        errorText: _erreur,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _unite,
                    items: [
                      for (final unite in unitesDeSaisie(ingredient.dimension))
                        DropdownMenuItem(value: unite, child: Text(libelleUnite(unite))),
                    ],
                    onChanged: (unite) => setState(() => _unite = unite),
                  ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        FilledButton(
          onPressed: ingredient == null ? null : _valider,
          child: const Text('Ajouter'),
        ),
      ],
    );
  }
}

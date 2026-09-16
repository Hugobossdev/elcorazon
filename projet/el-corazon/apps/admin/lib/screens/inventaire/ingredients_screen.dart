import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/presentation/inventaire.dart';
import 'package:admin/presentation/messages_erreur.dart';
import 'package:admin/services/admin_auth_service.dart';

/// Le référentiel d'achat de l'enseigne.
///
/// ## Réservé au siège, et dit comme tel
///
/// Un ingrédient n'appartient à aucune cuisine — une tomate est une tomate à
/// Lomé comme à Abidjan. Le serveur réserve donc ses écritures aux comptes non
/// cloisonnés, comme un pays ou une zone.
///
/// Le compte, côté application, ne dit pas s'il est cloisonné : l'écran ne
/// peut donc pas masquer le bouton aux seuls comptes rattachés. Il l'annonce en
/// tête, et un compte rattaché qui essaie reçoit la phrase du serveur — « … relève
/// du siège » — plutôt qu'une erreur générique. Élargir le contrat de compte
/// pour un seul bouton aurait dupliqué, côté client, une règle que le serveur
/// tient déjà.
///
/// ## Pas de suppression
///
/// Une référence employée par une recette ou portée par un journal se
/// **retire** : on n'en reçoit plus, une recette ne peut plus l'employer, et
/// son histoire reste lisible.
class IngredientsScreen extends StatefulWidget {
  const IngredientsScreen({super.key});

  @override
  State<IngredientsScreen> createState() => _IngredientsScreenState();
}

class _IngredientsScreenState extends State<IngredientsScreen> {
  eccore.ManagedInventoryRepository get _depot =>
      eccore.ManagedInventoryRepository(apiClient: AdminAuthService().apiClient);

  List<eccore.Ingredient> _ingredients = const [];
  bool _chargement = true;
  bool _retiresAussi = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    unawaited(_charger());
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final liste = await _depot.ingredients(isActive: _retiresAussi ? null : true);
      if (mounted) setState(() => _ingredients = liste);
    } catch (erreur) {
      if (mounted) setState(() => _erreur = messageErreur(erreur));
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _creer() async {
    final cree = await showDialog<eccore.Ingredient>(
      context: context,
      builder: (_) => _NouvelIngredient(depot: _depot),
    );
    if (cree != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('« ${cree.name} » ajouté au référentiel.')),
      );
      unawaited(_charger());
    }
  }

  Future<void> _basculer(eccore.Ingredient ingredient) async {
    final messager = ScaffoldMessenger.of(context);
    try {
      await _depot.updateIngredient(ingredient.id, isActive: !ingredient.isActive);
      unawaited(_charger());
    } catch (erreur) {
      messager.showSnackBar(SnackBar(content: Text(messageErreur(erreur))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AdminAuthService>();
    final ecriture = auth.can('inventory.write');

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
              Text('Ingrédients', style: theme.textTheme.titleLarge),
              FilterChip(
                label: const Text('Retirés inclus'),
                selected: _retiresAussi,
                onSelected: (valeur) {
                  setState(() => _retiresAussi = valeur);
                  unawaited(_charger());
                },
              ),
              if (ecriture)
                FilledButton.tonalIcon(
                  onPressed: _creer,
                  icon: const Icon(Icons.add),
                  label: const Text('Nouvel ingrédient'),
                ),
            ],
          ),
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Le référentiel est commun à toutes les cuisines : ses écritures sont '
                'réservées au siège.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
              ),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: _chargement && _ingredients.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _erreur != null
                    ? Center(child: Text(_erreur!, textAlign: TextAlign.center))
                    : _ingredients.isEmpty
                        ? const Center(child: Text('Le référentiel est vide.'))
                        : ListView.separated(
                            itemCount: _ingredients.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, rang) {
                              final ingredient = _ingredients[rang];
                              return ListTile(
                                title: Text(ingredient.name),
                                subtitle: Text(
                                  [
                                    libelleDimension(ingredient.dimension),
                                    if (ingredient.allergens.isNotEmpty)
                                      'allergènes : ${ingredient.allergens.join(', ')}',
                                    if (!ingredient.isActive) 'retiré',
                                  ].join(' · '),
                                ),
                                trailing: ecriture
                                    ? TextButton(
                                        onPressed: () => _basculer(ingredient),
                                        child: Text(ingredient.isActive ? 'Retirer' : 'Rétablir'),
                                      )
                                    : null,
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _NouvelIngredient extends StatefulWidget {
  const _NouvelIngredient({required this.depot});

  final eccore.ManagedInventoryRepository depot;

  @override
  State<_NouvelIngredient> createState() => _NouvelIngredientState();
}

class _NouvelIngredientState extends State<_NouvelIngredient> {
  final _nom = TextEditingController();
  final _allergenes = TextEditingController();
  String _dimension = 'mass';
  bool _envoi = false;
  String? _erreur;

  @override
  void dispose() {
    _nom.dispose();
    _allergenes.dispose();
    super.dispose();
  }

  Future<void> _creer() async {
    final nom = _nom.text.trim();
    final slug = slugDIngredient(nom);
    if (slug.isEmpty) {
      setState(() => _erreur = 'Donnez un nom à l’ingrédient.');
      return;
    }
    setState(() {
      _envoi = true;
      _erreur = null;
    });
    try {
      final cree = await widget.depot.createIngredient(
        name: nom,
        slug: slug,
        dimension: _dimension,
        allergens: _allergenes.text.split(',').map((code) => code.trim()).where((c) => c.isNotEmpty).toList(),
      );
      if (mounted) Navigator.of(context).pop(cree);
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
    return AlertDialog(
      title: const Text('Nouvel ingrédient'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nom,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nom'),
            ),
            const SizedBox(height: 12),
            DropdownButton<String>(
              isExpanded: true,
              value: _dimension,
              items: const [
                DropdownMenuItem(value: 'mass', child: Text('Masse — se pèse')),
                DropdownMenuItem(value: 'volume', child: Text('Volume — se mesure')),
                DropdownMenuItem(value: 'count', child: Text('Unités — se compte')),
              ],
              onChanged: _envoi ? null : (valeur) => setState(() => _dimension = valeur!),
            ),
            const Text(
              'La dimension ne change plus après la création : elle donne leur sens à '
              'tous les mouvements de stock.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _allergenes,
              decoration: const InputDecoration(
                labelText: 'Allergènes — séparés par des virgules',
              ),
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
        FilledButton(onPressed: _envoi ? null : _creer, child: const Text('Créer')),
      ],
    );
  }
}

/// « Piment frais d'Afrique » → `piment-frais-d-afrique` : le slug que le
/// serveur exige, dérivé du nom sans demander à l'opérateur d'en inventer un.
String slugDIngredient(String nom) {
  const accents = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'ç': 'c', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'î': 'i', 'ï': 'i', 'ô': 'o', 'ö': 'o', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ÿ': 'y',
    'œ': 'oe', 'æ': 'ae',
  };
  final bas = nom.toLowerCase().split('').map((lettre) => accents[lettre] ?? lettre).join();
  return bas.replaceAll(RegExp('[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
}

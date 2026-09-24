import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/presentation/autorisations.dart';
import 'package:admin/presentation/dialogue_formulaire.dart';
import 'package:admin/presentation/echec.dart';
import 'package:admin/presentation/retours.dart';
import 'package:admin/services/category_management_service.dart';
import 'package:admin/services/restaurant_scope_service.dart';
import 'package:admin/ui/ui.dart';
import 'package:admin/widgets/custom_button.dart';

/// Les catégories de la carte — **d'un établissement**.
///
/// ## Ce que l'écran faisait de travers (23 septembre 2026)
///
/// * **Il mêlait les établissements.** La liste était chargée sans filtre : un
///   siège voyait « Boissons » autant de fois qu'il a de cuisines, et les
///   faisait glisser dans un ordre commun qui n'existe pas — `sort_order` est
///   propre à chaque établissement. L'écran suit désormais le sélecteur de la
///   barre de navigation.
/// * **Le rangement n'était pas atomique.** Un `PATCH` par catégorie déplacée,
///   en série ; au quatrième refus, les trois premiers rangs étaient écrits, et
///   l'écran affichait l'ordre d'avant. Une seule route, transactionnelle, s'en
///   charge.
/// * **Rien ne se supprimait.** La route existe, le service l'appelait, aucun
///   bouton ne s'en servait.
/// * **Les refus étaient muets** — « Erreur lors de l'enregistrement » en
///   place de la phrase du serveur, qui nomme ce qui bloque (un nom déjà pris,
///   une catégorie qui contient encore des articles).
/// * **Le dialogue se fermait avant la réponse**, si bien qu'un enregistrement
///   refusé fermait le formulaire et perdait la saisie.
class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  /// L'établissement de la liste affichée, pour la recharger quand le
  /// sélecteur de la barre change.
  String? _slugAffiche;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_recharger());
    });
  }

  Future<void> _recharger() =>
      context.read<CategoryManagementService>().chargerPour(_slugAffiche);

  /// Suit le sélecteur de la barre de navigation.
  ///
  /// La lecture du périmètre se fait dans `build` — `context.watch` n'est
  /// valable que là — et le rechargement est reporté après la frame : appeler
  /// un service pendant un `build` le ferait notifier ses auditeurs au milieu
  /// de la construction de l'arbre.
  void _suivreLePerimetre(String? slug) {
    if (slug == _slugAffiche) return;
    _slugAffiche = slug;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_recharger());
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sem = AdminColorTokens.semantic(scheme);
    final peutEcrire = context.peut('catalog.write');
    final etablissement = context.watch<RestaurantScopeService>().current;
    _suivreLePerimetre(etablissement?.slug);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Catégories de la carte'),
            if (etablissement != null)
              Text(
                etablissement.name,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Recharger',
            icon: const Icon(Icons.refresh),
            onPressed: () => unawaited(_recharger()),
          ),
        ],
      ),
      body: Consumer<CategoryManagementService>(
        builder: (context, categoryService, child) {
          final echec = categoryService.echec;

          return Column(
            children: [
              if (echec != null)
                BandeauEchec(echec: echec, onReessayer: () => unawaited(_recharger())),
              if (!peutEcrire)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 16, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Lecture seule : tenir la carte demande le droit '
                          '« Modifier le catalogue » (catalog.write).',
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: _corps(
                  context,
                  categoryService,
                  peutEcrire: peutEcrire,
                  scheme: scheme,
                  sem: sem,
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: peutEcrire
          ? FloatingActionButton(
              onPressed: () => unawaited(_ouvrirLeFormulaire()),
              tooltip: 'Nouvelle catégorie',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _corps(
    BuildContext context,
    CategoryManagementService categoryService, {
    required bool peutEcrire,
    required ColorScheme scheme,
    required AdminSemanticColors sem,
  }) {
    if (categoryService.isLoading && categoryService.categories.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final categories = categoryService.categories;

    if (categories.isEmpty) {
      // Le bandeau dit déjà pourquoi quand la lecture a échoué : proposer
      // « Créer une catégorie » devant un 403 enverrait droit sur un second
      // refus.
      if (categoryService.echec != null) return const SizedBox.shrink();

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 64, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            const Text('Aucune catégorie dans cet établissement'),
            const SizedBox(height: 24),
            if (peutEcrire)
              CustomButton(
                text: 'Créer une catégorie',
                onPressed: () => unawaited(_ouvrirLeFormulaire()),
                icon: Icons.add,
              ),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) {
        if (oldIndex < newIndex) newIndex -= 1;
        final ordreVoulu = List<eccore.ManagedCategory>.from(categories);
        ordreVoulu.insert(newIndex, ordreVoulu.removeAt(oldIndex));
        unawaited(_ranger(ordreVoulu));
      },
      itemBuilder: (context, index) {
        final category = categories[index];
        return Card(
          key: ValueKey(category.id),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              // L'emoji tel que l'établissement l'a saisi. Il reste affiché en
              // Unicode, et c'est voulu : c'est **ici qu'on le compose**, et
              // l'opérateur doit voir exactement ce qu'il enregistre.
              //
              // Le repli, lui, tombe : afficher `'🍽️'` quand le champ est vide
              // rendait une catégorie sans emoji impossible à distinguer d'une
              // catégorie ayant l'assiette pour emoji.
              child: category.emoji.isEmpty
                  ? Icon(Icons.label_off_outlined, size: 20, color: scheme.onSurfaceVariant)
                  : Text(category.emoji, style: const TextStyle(fontSize: 20)),
            ),
            title: Text(
              category.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${category.description.isEmpty ? 'Pas de description' : category.description}'
              ' • ${category.isActive ? 'Active' : 'Inactive'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    category.isActive ? Icons.visibility : Icons.visibility_off,
                    color: category.isActive ? sem.success : scheme.onSurfaceVariant,
                  ),
                  onPressed: peutEcrire ? () => unawaited(_basculer(category)) : null,
                  tooltip: category.isActive ? 'Désactiver' : 'Activer',
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed:
                      peutEcrire ? () => unawaited(_ouvrirLeFormulaire(category: category)) : null,
                  tooltip: 'Modifier',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: peutEcrire ? () => unawaited(_supprimer(category)) : null,
                  tooltip: 'Supprimer',
                ),
                if (peutEcrire)
                  ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.drag_handle),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _ranger(List<eccore.ManagedCategory> ordreVoulu) async {
    try {
      await context.read<CategoryManagementService>().reorderCategories(ordreVoulu);
    } on eccore.ApiException catch (e) {
      // L'ordre est revenu à celui de la base — la route est transactionnelle,
      // rien n'a été écrit. Le dire évite que l'opérateur reglisse la même
      // ligne en croyant avoir mal visé.
      if (mounted) annoncerEchec(context, Echec.de(e));
    }
  }

  Future<void> _basculer(eccore.ManagedCategory category) async {
    try {
      await context.read<CategoryManagementService>().toggleCategoryStatus(category.id);
    } on eccore.ApiException catch (e) {
      if (mounted) annoncerEchec(context, Echec.de(e));
    }
  }

  Future<void> _supprimer(eccore.ManagedCategory category) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer « ${category.name} » ?'),
        content: const Text(
          'La catégorie disparaîtra de la carte. Le serveur refuse la '
          'suppression si elle contient encore des articles — désactivez-la '
          'plutôt pour la retirer de la vue des clients.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;

    try {
      await context.read<CategoryManagementService>().deleteCategory(category.id);
      if (mounted) annoncer(context, 'Catégorie supprimée');
    } on eccore.ApiException catch (e) {
      if (mounted) annoncerEchec(context, Echec.de(e));
    }
  }

  /// Le formulaire **attend le serveur** : il ne se ferme qu'une fois la
  /// catégorie enregistrée, et un refus s'affiche dedans, la saisie intacte.
  Future<void> _ouvrirLeFormulaire({eccore.ManagedCategory? category}) async {
    final nom = TextEditingController(text: category?.name);
    final description = TextEditingController(text: category?.description);
    // Vide pour une nouvelle catégorie, et non `'🍽️'` : le champ étant
    // prérempli, toute catégorie créée sans y toucher partait au serveur avec
    // une assiette que personne n'avait choisie.
    final emoji = TextEditingController(text: category?.emoji ?? '');

    final service = context.read<CategoryManagementService>();
    final enregistre = await DialogueDeFormulaire.ouvrir(
      context,
      titre: category == null ? 'Nouvelle catégorie' : 'Modifier la catégorie',
      corps: (context, echec) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: TextFormField(
                controller: emoji,
                decoration: InputDecoration(
                  labelText: 'Emoji',
                  border: const OutlineInputBorder(),
                  counterText: '',
                  errorText: echec?.pourLeChamp('emoji'),
                ),
                textAlign: TextAlign.center,
                maxLength: 2,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: nom,
                decoration: InputDecoration(
                  labelText: 'Nom',
                  border: const OutlineInputBorder(),
                  // Le serveur nomme le champ fautif : un slug déjà pris se
                  // pose sous le nom, d'où il vient.
                  errorText: echec?.pourLeChamp('name') ?? echec?.pourLeChamp('slug'),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: Valider.requis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
          TextFormField(
            controller: description,
            decoration: InputDecoration(
              labelText: 'Description',
              border: const OutlineInputBorder(),
              errorText: echec?.pourLeChamp('description'),
            ),
            maxLines: 2,
          ),
        ],
      ),
      enregistrer: () async {
        if (category == null) {
          await service.createCategory(
            name: nom.text,
            displayName: nom.text,
            emoji: emoji.text,
            description: description.text,
          );
        } else {
          await service.updateCategory(
            category.copyWith(
              name: nom.text,
              emoji: emoji.text,
              description: description.text,
            ),
          );
        }
      },
    );

    if (enregistre && mounted) annoncer(context, 'Catégorie enregistrée');
  }
}

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/screens/admin/category_management_screen.dart';
import 'package:admin/screens/admin/driver_management_screen.dart';
import 'package:admin/screens/admin/menu_management_screen.dart';
import 'package:admin/screens/admin/onglet_horaires.dart';
import 'package:admin/screens/admin/reseau/etablissement_form_dialog.dart';
import 'package:admin/services/network_service.dart';
import 'package:admin/services/restaurant_scope_service.dart';

/// Provisionnement d'un établissement : ce qui manque, et où aller le remplir.
///
/// ## Pourquoi cet écran ne contient presque rien
///
/// Configurer un restaurant, c'est remplir sa carte, ses horaires, ses zones et
/// sa flotte — et le back-office a **déjà** un écran pour chacun. Les recopier
/// ici en produirait des doublons qui divergeraient au premier correctif. Cet
/// écran est donc un aiguillage : il bascule le périmètre sur l'établissement
/// choisi, puis ouvre l'écran existant.
///
/// La bascule du périmètre est la partie qui compte. `MenuService`,
/// `CategoryManagementService`, `OpeningHoursService` et
/// `DriverManagementService` écrivent tous sur `RestaurantScopeService.slug` :
/// sans elle, on croirait configurer Abidjan en remplissant la carte de Lomé.
///
/// ## D'où vient la liste des manques
///
/// Du serveur, à chaque lecture (`configuration_gaps`), et non d'un calcul
/// local : elle dépend du catalogue, des horaires et de la flotte, qui vivent
/// dans trois applications différentes. Une version calculée ici serait fausse
/// dès qu'un collègue supprime une catégorie depuis un autre poste — et c'est
/// précisément la liste qui autorise, ou non, la mise en service.
class ProvisionnementScreen extends StatefulWidget {
  const ProvisionnementScreen({required this.slug, super.key});

  final String slug;

  @override
  State<ProvisionnementScreen> createState() => _ProvisionnementScreenState();
}

class _ProvisionnementScreenState extends State<ProvisionnementScreen> {
  @override
  void initState() {
    super.initState();
    // Le périmètre bascule dès l'ouverture : les écrans qu'on lancera d'ici
    // écrivent tous sur l'établissement courant, et non sur celui qu'on croit
    // regarder.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<RestaurantScopeService>().select(widget.slug);
    });
  }

  eccore.ManagedRestaurant? _etablissement(NetworkService reseau) =>
      reseau.restaurantBySlug(widget.slug);

  /// Ouvre un écran de configuration, puis relit l'établissement au retour.
  ///
  /// La relecture n'est pas cosmétique : `configuration_gaps` est calculée
  /// côté serveur, si bien qu'ajouter une catégorie ne fait disparaître la
  /// ligne correspondante qu'après un aller-retour. Sans elle, l'exploitant
  /// remplirait tout et verrait la même liste de manques.
  Future<void> _ouvrir(Widget ecran) async {
    final reseau = context.read<NetworkService>();
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ecran));
    await reseau.refreshRestaurant(widget.slug);
  }

  Future<void> _transiter(eccore.RestaurantLifecycle cible) async {
    final reseau = context.read<NetworkService>();
    final maj = await reseau.setRestaurantStatus(slug: widget.slug, status: cible);

    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          maj == null
              ? (reseau.error ?? "La transition n'a pas abouti.")
              : 'Établissement ${maj.status.label.toLowerCase()}.',
        ),
        backgroundColor: maj == null ? scheme.error : null,
        duration: Duration(seconds: maj == null ? 8 : 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkService>(
      builder: (context, reseau, _) {
        final etablissement = _etablissement(reseau);

        return Scaffold(
          appBar: AppBar(
            title: Text(etablissement?.name ?? 'Établissement'),
            actions: [
              IconButton(
                tooltip: 'Relire la fiche',
                onPressed: () => reseau.refreshRestaurant(widget.slug),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: etablissement == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => reseau.refreshRestaurant(widget.slug),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      _CarteEtat(etablissement: etablissement),
                      const SizedBox(height: 16),
                      _CarteIdentite(
                        etablissement: etablissement,
                        onModifier: () async {
                          final enregistre = await EtablissementFormDialog.show(
                            context,
                            existant: etablissement,
                          );
                          if (enregistre) await reseau.refreshRestaurant(widget.slug);
                        },
                      ),
                      const SizedBox(height: 16),
                      _CarteEtapes(
                        etablissement: etablissement,
                        onHoraires: () => _ouvrir(
                          const Scaffold(
                            body: SafeArea(child: OngletHoraires()),
                          ),
                        ),
                        onCategories: () => _ouvrir(const CategoryManagementScreen()),
                        onMenu: () => _ouvrir(const MenuManagementScreen()),
                        onLivreurs: () => _ouvrir(const DriverManagementScreen()),
                      ),
                      const SizedBox(height: 16),
                      _CarteCycleDeVie(
                        etablissement: etablissement,
                        enCours: reseau.isLoading,
                        onTransition: _transiter,
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

/// L'état courant, et ce qu'il veut dire pour un client.
class _CarteEtat extends StatelessWidget {
  const _CarteEtat({required this.etablissement});

  final eccore.ManagedRestaurant etablissement;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final publie = etablissement.status.isPublished;

    return Card(
      color: publie ? scheme.primaryContainer : scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              publie ? Icons.storefront : Icons.construction,
              size: 32,
              color: publie ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    etablissement.status.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: publie ? scheme.onPrimaryContainer : scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    publie
                        ? 'Visible des clients, et prêt à recevoir des commandes.'
                        : "Invisible des clients : l'application ne rend que les "
                              'établissements en service.',
                    style: TextStyle(
                      fontSize: 13,
                      color: publie ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarteIdentite extends StatelessWidget {
  const _CarteIdentite({required this.etablissement, required this.onModifier});

  final eccore.ManagedRestaurant etablissement;
  final VoidCallback onModifier;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Identité et localisation',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onModifier,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Modifier'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _Ligne('Identifiant', etablissement.slug),
            _Ligne(
              'Marché',
              '${etablissement.cityName} (${etablissement.countryIsoCode}) — '
                  '${etablissement.currency}, ${etablissement.timezone}',
            ),
            _Ligne('Zone', etablissement.zoneName),
            _Ligne('Adresse', etablissement.address),
            _Ligne(
              'Position',
              '${etablissement.latitude.toStringAsFixed(5)}, '
                  '${etablissement.longitude.toStringAsFixed(5)}',
            ),
            _Ligne('Téléphone', etablissement.phone ?? '—'),
            _Ligne(
              'Préparation',
              '${etablissement.defaultPreparationMinutes} min',
            ),
          ],
        ),
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne(this.label, this.valeur);

  final String label;
  final String valeur;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ),
          Expanded(child: Text(valeur, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

/// Les étapes de configuration, chacune ouvrant l'écran qui existe déjà.
class _CarteEtapes extends StatelessWidget {
  const _CarteEtapes({
    required this.etablissement,
    required this.onHoraires,
    required this.onCategories,
    required this.onMenu,
    required this.onLivreurs,
  });

  final eccore.ManagedRestaurant etablissement;
  final VoidCallback onHoraires;
  final VoidCallback onCategories;
  final VoidCallback onMenu;
  final VoidCallback onLivreurs;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final manques = etablissement.configurationGaps;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configuration',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              manques.isEmpty
                  ? 'Tout est en place : cet établissement peut être mis en service.'
                  : '${manques.length} point(s) à régler avant la mise en service.',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            if (manques.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final manque in manques)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 16,
                              color: scheme.onErrorContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                manque,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: scheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            _Etape(
              icone: Icons.access_time,
              titre: 'Horaires',
              sousTitre: "Plages d'ouverture, service de nuit compris",
              onTap: onHoraires,
            ),
            _Etape(
              icone: Icons.category_outlined,
              titre: 'Catégories',
              sousTitre: 'La structure de la carte',
              onTap: onCategories,
            ),
            _Etape(
              icone: Icons.restaurant_menu,
              titre: 'Articles et prix',
              sousTitre: 'Propres à cet établissement — un autre peut vendre autre chose',
              onTap: onMenu,
            ),
            _Etape(
              icone: Icons.delivery_dining,
              titre: 'Livreurs',
              sousTitre: 'Au moins un dossier approuvé pour honorer les courses',
              onTap: onLivreurs,
            ),
          ],
        ),
      ),
    );
  }
}

class _Etape extends StatelessWidget {
  const _Etape({
    required this.icone,
    required this.titre,
    required this.sousTitre,
    required this.onTap,
  });

  final IconData icone;
  final String titre;
  final String sousTitre;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icone),
      title: Text(titre),
      subtitle: Text(sousTitre, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// Les transitions disponibles depuis l'état courant.
///
/// Les boutons suivent `RestaurantLifecycle.nextStates`, recopié du serveur.
/// **Ce n'est pas un contrôle** : le serveur refait la vérification et c'est lui
/// qui décide. Une liste qui divergerait ferait au pire proposer une action
/// refusée en 409, jamais autoriser ce qui ne l'est pas.
class _CarteCycleDeVie extends StatelessWidget {
  const _CarteCycleDeVie({
    required this.etablissement,
    required this.enCours,
    required this.onTransition,
  });

  final eccore.ManagedRestaurant etablissement;
  final bool enCours;
  final ValueChanged<eccore.RestaurantLifecycle> onTransition;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final suivants = etablissement.status.nextStates.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cycle de vie',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final cible in suivants)
                  _BoutonTransition(
                    cible: cible,
                    // La mise en service est le seul geste que la complétude
                    // garde. Le bouton reste visible mais désactivé : le
                    // masquer laisserait croire que la transition n'existe pas,
                    // alors qu'il manque seulement quelque chose à remplir.
                    active: !enCours &&
                        (cible != eccore.RestaurantLifecycle.active ||
                            etablissement.isReadyToPublish),
                    onPressed: () => onTransition(cible),
                  ),
              ],
            ),
            if (etablissement.status == eccore.RestaurantLifecycle.ready &&
                !etablissement.isReadyToPublish) ...[
              const SizedBox(height: 12),
              Text(
                'La mise en service attend que la liste ci-dessus soit vide.',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BoutonTransition extends StatelessWidget {
  const _BoutonTransition({
    required this.cible,
    required this.active,
    required this.onPressed,
  });

  final eccore.RestaurantLifecycle cible;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final publication = cible == eccore.RestaurantLifecycle.active;

    return publication
        ? FilledButton.icon(
            onPressed: active ? onPressed : null,
            icon: const Icon(Icons.rocket_launch_outlined, size: 18),
            label: const Text('Mettre en service'),
          )
        : OutlinedButton(
            onPressed: active ? onPressed : null,
            child: Text(cible.label),
          );
  }
}

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/screens/admin/reseau/etablissement_form_dialog.dart';
import 'package:admin/screens/admin/reseau/pays_form_dialog.dart';
import 'package:admin/screens/admin/reseau/provisionnement_screen.dart';
import 'package:admin/screens/admin/reseau/ville_form_dialog.dart';
import 'package:admin/screens/admin/reseau/zone_creation_dialog.dart';
import 'package:admin/services/delivery_zone_service.dart';
import 'package:admin/services/network_service.dart';

/// Le réseau : marchés, villes, établissements.
///
/// Trois onglets dans l'ordre où l'on provisionne, parce que c'est un ordre
/// **imposé par le schéma** et non une préférence d'ergonomie : une ville se
/// rattache à un pays, une zone à une ville, un établissement à une zone. Un
/// écran qui laisserait commencer par la fin ne ferait qu'échouer plus tard,
/// avec un message de clé étrangère.
///
/// Chaque onglet montre les entités **fermées comprises** : c'est d'ici qu'on
/// rouvre un marché, et masquer les fermés rendrait le geste impossible depuis
/// l'écran même qui sert à le faire.
class ReseauScreen extends StatefulWidget {
  const ReseauScreen({super.key});

  @override
  State<ReseauScreen> createState() => _ReseauScreenState();
}

class _ReseauScreenState extends State<ReseauScreen> with SingleTickerProviderStateMixin {
  late final TabController _onglets;

  @override
  void initState() {
    super.initState();
    _onglets = TabController(length: 3, vsync: this)
      ..addListener(() {
        if (mounted) setState(() {});
      });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NetworkService>().resolve();
    });
  }

  @override
  void dispose() {
    _onglets.dispose();
    super.dispose();
  }

  Future<void> _ajouter() async {
    final reseau = context.read<NetworkService>();
    switch (_onglets.index) {
      case 0:
        if (await PaysFormDialog.show(context)) await reseau.refresh();
      case 1:
        if (mounted && await VilleFormDialog.show(context)) await reseau.refresh();
      case 2:
        if (mounted && await EtablissementFormDialog.show(context)) await reseau.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkService>(
      builder: (context, reseau, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Réseau'),
            bottom: TabBar(
              controller: _onglets,
              tabs: const [
                Tab(icon: Icon(Icons.public), text: 'Marchés'),
                Tab(icon: Icon(Icons.location_city), text: 'Villes'),
                Tab(icon: Icon(Icons.storefront), text: 'Établissements'),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Recharger',
                onPressed: reseau.isLoading ? null : reseau.refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: Column(
            children: [
              if (reseau.error != null) _Bandeau(message: reseau.error!),
              if (reseau.isLoading) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: TabBarView(
                  controller: _onglets,
                  children: const [
                    _OngletPays(),
                    _OngletVilles(),
                    _OngletEtablissements(),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: reseau.isLoading ? null : _ajouter,
            icon: const Icon(Icons.add),
            label: Text(
              switch (_onglets.index) {
                0 => 'Ouvrir un marché',
                1 => 'Ouvrir une ville',
                _ => 'Ouvrir un établissement',
              },
            ),
          ),
        );
      },
    );
  }
}

class _Bandeau extends StatelessWidget {
  const _Bandeau({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: scheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}

class _OngletPays extends StatelessWidget {
  const _OngletPays();

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkService>(
      builder: (context, reseau, _) {
        if (reseau.countries.isEmpty) {
          return const _Vide(
            icone: Icons.public_off,
            titre: 'Aucun marché',
            texte: "Un marché porte la devise et le fuseau de tout ce qu'on ouvrira "
                'dedans. Commencez par là.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          itemCount: reseau.countries.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final pays = reseau.countries[index];
            final villes = reseau.citiesOf(pays.isoCode).length;

            return Card(
              child: ListTile(
                leading: CircleAvatar(child: Text(pays.isoCode)),
                title: Text(pays.name),
                subtitle: Text(
                  '${pays.currency} · ${pays.timezone} · ${pays.phonePrefix} · '
                  '$villes ville(s)',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Switch(
                  value: pays.isActive,
                  onChanged: reseau.isLoading
                      ? null
                      : (actif) => reseau.setCountryActive(pays.isoCode, actif),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _OngletVilles extends StatelessWidget {
  const _OngletVilles();

  @override
  Widget build(BuildContext context) {
    return Consumer2<NetworkService, DeliveryZoneService>(
      builder: (context, reseau, zones, _) {
        if (reseau.cities.isEmpty) {
          return const _Vide(
            icone: Icons.location_off,
            titre: 'Aucune ville',
            texte: 'Une ville se rattache à un marché ouvert. Elle porte les '
                'zones de livraison, qui portent les barèmes.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          itemCount: reseau.cities.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final ville = reseau.cities[index];
            final zonesDeLaVille =
                zones.zones.where((zone) => zone.cityId == ville.id).toList();
            final etablissements = reseau.restaurantsOf(ville.slug).length;

            return Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.location_city),
                    title: Text('${ville.name} — ${ville.countryIsoCode}'),
                    subtitle: Text(
                      '${zonesDeLaVille.length} zone(s) · $etablissements établissement(s)',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Switch(
                      value: ville.isActive,
                      onChanged: reseau.isLoading
                          ? null
                          : (actif) => reseau.setCityActive(ville.id, actif),
                    ),
                  ),
                  if (zonesDeLaVille.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              "Aucune zone : aucun établissement n'y est créable.",
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final creee = await ZoneCreationDialog.show(context, ville);
                              if (creee != null && context.mounted) {
                                await context.read<NetworkService>().refresh();
                              }
                            },
                            child: const Text('Ouvrir une zone'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _OngletEtablissements extends StatelessWidget {
  const _OngletEtablissements();

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkService>(
      builder: (context, reseau, _) {
        if (reseau.restaurants.isEmpty) {
          return const _Vide(
            icone: Icons.storefront_outlined,
            titre: 'Aucun établissement',
            texte: 'Un établissement se rattache à une zone de livraison, qui '
                'emporte sa ville, son marché, sa devise et son fuseau.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          itemCount: reseau.restaurants.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) =>
              _CarteEtablissement(etablissement: reseau.restaurants[index]),
        );
      },
    );
  }
}

class _CarteEtablissement extends StatelessWidget {
  const _CarteEtablissement({required this.etablissement});

  final eccore.ManagedRestaurant etablissement;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final manques = etablissement.configurationGaps.length;

    return Card(
      child: ListTile(
        leading: Icon(
          etablissement.status.isPublished ? Icons.storefront : Icons.construction,
          color: etablissement.status.isPublished ? scheme.primary : scheme.onSurfaceVariant,
        ),
        title: Text(etablissement.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${etablissement.cityName} (${etablissement.countryIsoCode}) · '
              '${etablissement.currency}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: [
                _Pastille(
                  texte: etablissement.status.label,
                  couleurFond: etablissement.status.isPublished
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHighest,
                  couleurTexte: etablissement.status.isPublished
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
                if (manques > 0)
                  _Pastille(
                    texte: '$manques à régler',
                    couleurFond: scheme.errorContainer,
                    couleurTexte: scheme.onErrorContainer,
                  ),
                if (etablissement.status.isPublished && !etablissement.acceptsOrders)
                  _Pastille(
                    texte: 'Commandes suspendues',
                    couleurFond: scheme.tertiaryContainer,
                    couleurTexte: scheme.onTertiaryContainer,
                  ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ProvisionnementScreen(slug: etablissement.slug),
          ),
        ),
      ),
    );
  }
}

class _Pastille extends StatelessWidget {
  const _Pastille({
    required this.texte,
    required this.couleurFond,
    required this.couleurTexte,
  });

  final String texte;
  final Color couleurFond;
  final Color couleurTexte;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: couleurFond,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        texte,
        style: TextStyle(fontSize: 11, color: couleurTexte, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Vide extends StatelessWidget {
  const _Vide({required this.icone, required this.titre, required this.texte});

  final IconData icone;
  final String titre;
  final String texte;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(titre, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              texte,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

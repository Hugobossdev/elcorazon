import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/presentation/messages_erreur.dart';
import 'package:admin/services/admin_auth_service.dart';
import 'package:admin/services/delivery_zone_service.dart';
import 'package:admin/services/network_service.dart';

/// La structure du réseau en chiffres — ce qu'on lit en ouvrant l'onglet.
///
/// Pur : se calcule depuis ce que le back-office a déjà chargé, sans appel.
/// « Fermée » compte les cuisines **en service** qu'un client ne peut pas
/// commander à cet instant — hors horaires, fermeture exceptionnelle, pause —,
/// d'après le verdict du serveur et non une composition locale.
@immutable
class ResumeReseau {
  const ResumeReseau({
    required this.pays,
    required this.villes,
    required this.zones,
    required this.cuisines,
    required this.enService,
    required this.commandables,
  });

  factory ResumeReseau.depuis({
    required List<eccore.ManagedCountry> pays,
    required List<eccore.ManagedCity> villes,
    required List<DeliveryZone> zones,
    required List<eccore.ManagedRestaurant> cuisines,
  }) {
    final enService = cuisines.where((c) => c.isActive).toList();
    return ResumeReseau(
      pays: pays.where((p) => p.isActive).length,
      villes: villes.where((v) => v.isActive).length,
      zones: zones.where((z) => z.isActive).length,
      cuisines: cuisines.length,
      enService: enService.length,
      commandables: enService.where((c) => c.canOrderNow).length,
    );
  }

  final int pays;
  final int villes;
  final int zones;
  final int cuisines;
  final int enService;
  final int commandables;

  /// En service, mais qu'aucun client ne peut commander maintenant.
  int get fermees => enService - commandables;
}

/// Les étages du rapport réseau, dans l'ordre de la hiérarchie.
enum EtageReseau {
  pays('country', 'Pays', 'Pays'),
  villes('city', 'Villes', 'Ville'),
  zones('zone', 'Zones', 'Zone'),
  cuisines('kitchen', 'Cuisines', 'Cuisine');

  const EtageReseau(this.code, this.libelle, this.singulier);

  final String code;
  final String libelle;
  final String singulier;
}

/// L'activité du réseau : structure, puis commandes et chiffre d'affaires par
/// pays, ville, zone ou cuisine — `GET /analytics/reports/network/`.
///
/// Les commandes sont rangées selon leur géographie **figée** : une cuisine
/// déplacée ne fait pas migrer son historique. Le chiffre d'affaires ne compte
/// que les commandes livrées ; « En cours » et « Annulées » disent le reste.
class OngletActiviteReseau extends StatefulWidget {
  const OngletActiviteReseau({this.depot, super.key});

  /// Injecté par les tests ; le dépôt réel sinon.
  final eccore.ReportingRepository? depot;

  @override
  State<OngletActiviteReseau> createState() => _OngletActiviteReseauState();
}

class _OngletActiviteReseauState extends State<OngletActiviteReseau> {
  late final eccore.ReportingRepository _depot =
      widget.depot ?? eccore.ReportingRepository(apiClient: AdminAuthService().apiClient);

  EtageReseau _etage = EtageReseau.cuisines;
  int _jours = 30;
  String? _paysIso;

  List<eccore.NetworkRow> _lignes = const [];
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    // Après la première image : `_charger` pose un état, ce que Flutter
    // refuse pendant `initState`.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_charger());
    });
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    final fin = DateTime.now();
    try {
      final lignes = await _depot.network(
        start: fin.subtract(Duration(days: _jours)),
        end: fin,
        level: _etage.code,
        countryIsoCode: _paysIso,
      );
      if (!mounted) return;
      setState(() => _lignes = lignes);
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _erreur = messageErreur(e));
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reseau = context.watch<NetworkService>();
    final zones = context.watch<DeliveryZoneService>();
    final resume = ResumeReseau.depuis(
      pays: reseau.countries,
      villes: reseau.cities,
      zones: zones.zones,
      cuisines: reseau.restaurants,
    );
    final scheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chiffre(libelle: 'Pays ouverts', valeur: '${resume.pays}', icone: Icons.public),
              _Chiffre(libelle: 'Villes', valeur: '${resume.villes}', icone: Icons.location_city),
              _Chiffre(libelle: 'Zones actives', valeur: '${resume.zones}', icone: Icons.map_outlined),
              _Chiffre(
                libelle: 'Cuisines en service',
                valeur: '${resume.enService} / ${resume.cuisines}',
                icone: Icons.soup_kitchen_outlined,
              ),
              _Chiffre(
                libelle: 'Commandables maintenant',
                valeur: '${resume.commandables}',
                icone: Icons.check_circle_outline,
              ),
              _Chiffre(
                libelle: 'Fermées ou en pause',
                valeur: '${resume.fermees}',
                icone: Icons.nightlight_outlined,
                alerte: resume.fermees > 0,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<EtageReseau>(
                segments: [
                  for (final etage in EtageReseau.values)
                    ButtonSegment(value: etage, label: Text(etage.libelle)),
                ],
                selected: {_etage},
                onSelectionChanged: (choix) {
                  setState(() => _etage = choix.single);
                  unawaited(_charger());
                },
              ),
              DropdownButton<int>(
                value: _jours,
                items: const [
                  DropdownMenuItem(value: 1, child: Text("Aujourd'hui")),
                  DropdownMenuItem(value: 7, child: Text('7 jours')),
                  DropdownMenuItem(value: 30, child: Text('30 jours')),
                  DropdownMenuItem(value: 90, child: Text('90 jours')),
                ],
                onChanged: (jours) {
                  if (jours == null) return;
                  setState(() => _jours = jours);
                  unawaited(_charger());
                },
              ),
              if (reseau.countries.length > 1)
                DropdownButton<String?>(
                  value: _paysIso,
                  items: [
                    const DropdownMenuItem<String?>(child: Text('Tous les pays')),
                    for (final pays in reseau.countries)
                      DropdownMenuItem(value: pays.isoCode, child: Text(pays.name)),
                  ],
                  onChanged: (iso) {
                    setState(() => _paysIso = iso);
                    unawaited(_charger());
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_chargement) const LinearProgressIndicator(minHeight: 2),
          if (_erreur != null)
            Card(
              color: scheme.errorContainer,
              child: ListTile(
                title: Text(_erreur!, style: TextStyle(color: scheme.onErrorContainer)),
                trailing: TextButton(onPressed: _charger, child: const Text('Réessayer')),
              ),
            )
          else if (!_chargement && _lignes.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Aucune commande sur cette période.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  DataColumn(label: Text(_etage.singulier)),
                  const DataColumn(label: Text('Commandes'), numeric: true),
                  const DataColumn(label: Text('En cours'), numeric: true),
                  const DataColumn(label: Text('Livrées'), numeric: true),
                  const DataColumn(label: Text('Annulées'), numeric: true),
                  const DataColumn(label: Text("Chiffre d'affaires"), numeric: true),
                ],
                rows: [
                  for (final ligne in _lignes)
                    DataRow(
                      cells: [
                        DataCell(
                          Text(
                            [
                              ligne.name,
                              if (ligne.cityName.isNotEmpty && _etage != EtageReseau.villes)
                                ligne.cityName,
                              if (ligne.countryIsoCode.isNotEmpty) ligne.countryIsoCode,
                            ].join(' · '),
                          ),
                        ),
                        DataCell(Text('${ligne.ordersCount}')),
                        DataCell(Text('${ligne.inProgressCount}')),
                        DataCell(Text('${ligne.deliveredCount}')),
                        DataCell(
                          Text(
                            '${ligne.cancelledCount}'
                            '${ligne.ordersCount == 0 ? '' : ' (${(ligne.cancellationRate * 100).round()} %)'}',
                          ),
                        ),
                        DataCell(
                          Text(
                            eccore.Money(amountMinor: ligne.revenueMinor, currency: ligne.currency)
                                .format(),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Chiffre extends StatelessWidget {
  const _Chiffre({
    required this.libelle,
    required this.valeur,
    required this.icone,
    this.alerte = false,
  });

  final String libelle;
  final String valeur;
  final IconData icone;
  final bool alerte;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 170,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icone, color: alerte ? scheme.error : scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      valeur,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(libelle, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

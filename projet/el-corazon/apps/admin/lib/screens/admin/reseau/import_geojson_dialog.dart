import 'dart:convert';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';

import 'package:admin/presentation/messages_erreur.dart';
import 'package:admin/services/admin_auth_service.dart';

/// « Importer une zone » — coller un GeoJSON, le faire valider, confirmer.
///
/// La validation est **entièrement serveur** : structure, coordonnées,
/// géométrie, cohérence avec la ville, chevauchements. L'écran ne fait que
/// lire le JSON collé pour l'envoyer ; un texte qui n'est pas du JSON est dit
/// tel quel, sans deviner.
///
/// La zone créée naît en **brouillon**, au barème nul : elle se tarife et se
/// relit avant d'être soumise.
class ImportGeoJsonDialog extends StatefulWidget {
  const ImportGeoJsonDialog({required this.villes, this.depot, super.key});

  /// Villes proposées, `{id: nom}`.
  final Map<String, String> villes;
  final eccore.ZoneImportRepository? depot;

  static Future<eccore.DeliveryZone?> show(BuildContext context, Map<String, String> villes) =>
      showDialog<eccore.DeliveryZone>(
        context: context,
        builder: (_) => ImportGeoJsonDialog(villes: villes),
      );

  @override
  State<ImportGeoJsonDialog> createState() => _ImportGeoJsonDialogState();
}

class _ImportGeoJsonDialogState extends State<ImportGeoJsonDialog> {
  late final eccore.ZoneImportRepository _depot =
      widget.depot ?? eccore.ZoneImportRepository(apiClient: AdminAuthService().apiClient);
  final _nom = TextEditingController();
  final _geojson = TextEditingController();
  String? _ville;
  eccore.ApercuImportZone? _apercu;
  String? _erreur;
  bool _enCours = false;

  Object? _lire() {
    try {
      return jsonDecode(_geojson.text);
    } on FormatException {
      setState(() => _erreur = 'Le texte collé n’est pas du JSON.');
      return null;
    }
  }

  Future<void> _previsualiser() async {
    final geojson = _lire();
    if (geojson == null || _ville == null) return;
    await _envoyer(() async {
      final apercu =
          await _depot.previsualiser(cityId: _ville!, nom: _nom.text.trim(), geojson: geojson);
      setState(() => _apercu = apercu);
    });
  }

  Future<void> _importer() async {
    final geojson = _lire();
    if (geojson == null || _ville == null) return;
    await _envoyer(() async {
      final zone = await _depot.importer(cityId: _ville!, nom: _nom.text.trim(), geojson: geojson);
      if (mounted) Navigator.pop(context, zone);
    });
  }

  Future<void> _envoyer(Future<void> Function() action) async {
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    try {
      await action();
    } on Object catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pret = _ville != null && _nom.text.trim().isNotEmpty && _geojson.text.trim().isNotEmpty;
    final apercu = _apercu;
    return AlertDialog(
      title: const Text('Importer une zone'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                key: const Key('ville-import'),
                initialValue: _ville,
                decoration: const InputDecoration(labelText: 'Ville'),
                items: [
                  for (final e in widget.villes.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setState(() {
                  _ville = v;
                  _apercu = null;
                }),
              ),
              TextField(
                key: const Key('nom-import'),
                controller: _nom,
                decoration: const InputDecoration(labelText: 'Nom de la zone'),
                onChanged: (_) => setState(() => _apercu = null),
              ),
              TextField(
                key: const Key('geojson-import'),
                controller: _geojson,
                minLines: 4,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: 'GeoJSON (Polygon, MultiPolygon, Feature ou FeatureCollection)',
                ),
                onChanged: (_) => setState(() => _apercu = null),
              ),
              if (_enCours) const LinearProgressIndicator(),
              if (_erreur != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child:
                      Text(_erreur!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              if (apercu != null)
                ListTile(
                  key: const Key('apercu-import'),
                  leading: const Icon(Icons.fact_check_outlined),
                  title: Text(
                    'Contour valide : ${apercu.polygones} morceau(x), ${apercu.trous} trou(s).',
                  ),
                  subtitle: Text(
                    apercu.chevauchements.isEmpty
                        ? 'Aucun chevauchement.'
                        : '⚠️ Recouvre : ${apercu.chevauchements.join(', ')}.',
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        OutlinedButton(
            onPressed: pret && !_enCours ? _previsualiser : null, child: const Text('Vérifier'),),
        FilledButton(
          onPressed: apercu != null && !_enCours ? _importer : null,
          child: const Text('Créer en brouillon'),
        ),
      ],
    );
  }
}

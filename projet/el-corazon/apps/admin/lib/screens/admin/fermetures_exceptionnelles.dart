import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';

import 'package:admin/presentation/messages_erreur.dart';
import 'package:admin/services/admin_auth_service.dart';

/// Les fermetures exceptionnelles d'une cuisine — sous ses horaires.
///
/// ## Pourquoi pas une plage en moins
///
/// Fermer le 25 décembre en retirant la plage du jeudi fermait **tous** les
/// jeudis, jusqu'à ce que quelqu'un pense à la remettre. Une fermeture est
/// datée, et se lève d'elle-même : la cuisine rouvre à l'heure dite, et le
/// client lit entre-temps « Fermé exceptionnellement — réouverture vendredi à
/// 11 h 00 ».
///
/// Les dates se saisissent à l'heure du poste et partent en UTC ; le serveur
/// compare dans le fuseau du pays. Un poste réglé sur un autre fuseau que la
/// cuisine voit donc ses heures décalées d'autant — le rappel est à l'écran.
class FermeturesExceptionnelles extends StatefulWidget {
  const FermeturesExceptionnelles({
    required this.restaurantId,
    required this.nomCuisine,
    this.depot,
    super.key,
  });

  final String restaurantId;
  final String nomCuisine;

  /// Injecté par les tests ; le dépôt réel sinon.
  final eccore.ManagedKitchenClosureRepository? depot;

  @override
  State<FermeturesExceptionnelles> createState() => _FermeturesExceptionnellesState();
}

class _FermeturesExceptionnellesState extends State<FermeturesExceptionnelles> {
  late final eccore.ManagedKitchenClosureRepository _depot =
      widget.depot ?? eccore.ManagedKitchenClosureRepository(apiClient: AdminAuthService().apiClient);

  List<eccore.KitchenClosure> _fermetures = const [];
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

  @override
  void didUpdateWidget(covariant FermeturesExceptionnelles ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.restaurantId != widget.restaurantId) unawaited(_charger());
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final fermetures = await _depot.list(restaurantId: widget.restaurantId);
      if (!mounted) return;
      setState(() => _fermetures = fermetures);
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _erreur = messageErreur(e));
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _ajouter() async {
    final saisie = await showDialog<_Saisie>(
      context: context,
      builder: (_) => _DialogueFermeture(nomCuisine: widget.nomCuisine),
    );
    if (saisie == null || !mounted) return;

    try {
      await _depot.create(
        restaurantId: widget.restaurantId,
        startsAt: saisie.debut,
        endsAt: saisie.fin,
        reason: saisie.motif,
      );
      if (!mounted) return;
      _annoncer('Fermeture enregistrée. Les clients la voient immédiatement.');
      await _charger();
    } on Exception catch (e) {
      if (mounted) _annoncer(messageErreur(e), erreur: true);
    }
  }

  Future<void> _annuler(eccore.KitchenClosure fermeture) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler cette fermeture ?'),
        content: Text(
          fermeture.isCurrent
              ? '${widget.nomCuisine} rouvre tout de suite, dans ses horaires habituels.'
              : '${widget.nomCuisine} restera ouverte à ces dates, selon ses horaires.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Garder')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Annuler la fermeture'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;
    try {
      await _depot.delete(fermeture.id);
      if (!mounted) return;
      _annoncer('Fermeture annulée.');
      await _charger();
    } on Exception catch (e) {
      if (mounted) _annoncer(messageErreur(e), erreur: true);
    }
  }

  void _annoncer(String message, {bool erreur = false}) {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: erreur ? scheme.error : scheme.inverseSurface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_busy_outlined),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Fermetures exceptionnelles',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                TextButton.icon(
                  onPressed: _chargement ? null : _ajouter,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Fermer'),
                ),
              ],
            ),
            Text(
              'Jour férié, travaux, coupure : la cuisine rouvre d’elle-même à la fin '
              'de la fermeture. Heures saisies à l’heure de ce poste.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (_chargement)
              const Center(child: CircularProgressIndicator())
            else if (_erreur != null)
              Row(
                children: [
                  Expanded(child: Text(_erreur!, style: TextStyle(color: scheme.error))),
                  TextButton(onPressed: _charger, child: const Text('Réessayer')),
                ],
              )
            else if (_fermetures.isEmpty)
              Text(
                'Aucune fermeture à venir.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              )
            else
              for (final fermeture in _fermetures)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    fermeture.isCurrent ? Icons.lock_clock : Icons.event_outlined,
                    color: fermeture.isCurrent ? scheme.error : scheme.onSurfaceVariant,
                  ),
                  title: Text(libellePeriode(fermeture.startsAt, fermeture.endsAt)),
                  subtitle: Text(
                    [
                      if (fermeture.isCurrent) 'En cours',
                      if (fermeture.reason.isNotEmpty) fermeture.reason,
                    ].join(' · '),
                  ),
                  trailing: IconButton(
                    tooltip: 'Annuler cette fermeture',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _annuler(fermeture),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// « 25/12 à 00:00 », à l'heure du poste.
String libelleInstant(DateTime instant) {
  String deux(int n) => n.toString().padLeft(2, '0');
  final l = instant.toLocal();
  return '${deux(l.day)}/${deux(l.month)} à ${deux(l.hour)}:${deux(l.minute)}';
}

/// « du 25/12 à 00:00 au 26/12 à 11:00 », à l'heure du poste.
String libellePeriode(DateTime debut, DateTime fin) =>
    'du ${libelleInstant(debut)} au ${libelleInstant(fin)}';

class _Saisie {
  const _Saisie({required this.debut, required this.fin, required this.motif});

  final DateTime debut;
  final DateTime fin;
  final String motif;
}

class _DialogueFermeture extends StatefulWidget {
  const _DialogueFermeture({required this.nomCuisine});

  final String nomCuisine;

  @override
  State<_DialogueFermeture> createState() => _DialogueFermetureState();
}

class _DialogueFermetureState extends State<_DialogueFermeture> {
  late DateTime _debut = DateTime.now();
  late DateTime _fin = DateTime.now().add(const Duration(hours: 2));
  final _motif = TextEditingController();

  @override
  void dispose() {
    _motif.dispose();
    super.dispose();
  }

  Future<DateTime?> _choisir(DateTime depart) async {
    final jour = await showDatePicker(
      context: context,
      initialDate: depart,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (jour == null || !mounted) return null;
    final heure = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(depart));
    if (heure == null) return null;
    return DateTime(jour.year, jour.month, jour.day, heure.hour, heure.minute);
  }

  @override
  Widget build(BuildContext context) {
    final valide = _fin.isAfter(_debut) && _fin.isAfter(DateTime.now());

    return AlertDialog(
      title: Text('Fermer ${widget.nomCuisine}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.play_arrow_outlined),
            title: const Text('Début'),
            subtitle: Text(libelleInstant(_debut)),
            onTap: () async {
              final choisi = await _choisir(_debut);
              if (choisi != null) setState(() => _debut = choisi);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.stop_outlined),
            title: const Text('Réouverture'),
            subtitle: Text(libelleInstant(_fin)),
            onTap: () async {
              final choisi = await _choisir(_fin);
              if (choisi != null) setState(() => _fin = choisi);
            },
          ),
          TextField(
            controller: _motif,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Motif montré aux clients (facultatif)',
              hintText: 'Jour férié, travaux…',
            ),
          ),
          if (!valide)
            Text(
              'La réouverture doit suivre le début, et ne pas être déjà passée.',
              style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        FilledButton(
          onPressed: valide
              ? () => Navigator.of(context).pop(_Saisie(debut: _debut, fin: _fin, motif: _motif.text))
              : null,
          child: const Text('Fermer la cuisine'),
        ),
      ],
    );
  }
}

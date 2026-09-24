import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';

import 'package:admin/presentation/barre_pagination.dart';
import 'package:admin/presentation/echec.dart';
import 'package:admin/presentation/retours.dart';
import 'package:admin/services/admin_auth_service.dart';
import 'package:admin/utils/price_formatter.dart';

/// L'historique d'un livreur : ses **courses**, et ce qu'il a gagné.
///
/// ## Ce qui a changé (22 septembre 2026)
///
/// * **Le « Revenu » n'était pas le sien.** L'écran additionnait le total des
///   commandes qu'il avait portées — ce que les clients ont payé — et non sa
///   rémunération (`courier_fee`). Il mêlait de surcroît les devises.
/// * **Les données venaient d'un croisement en mémoire** : toutes les courses
///   du livreur, croisées avec un an de commandes téléchargées par la
///   supervision, puis filtrées par période dans l'écran. Un livreur dont les
///   commandes sortaient de cette fenêtre paraissait n'avoir rien fait. Le
///   serveur borne, pagine et totalise.
/// * Les chiffres sont ceux de la **période choisie**, et la période part au
///   serveur.
class DriverHistoryScreen extends StatefulWidget {
  const DriverHistoryScreen({required this.driver, super.key});

  final eccore.CourierProfile driver;

  @override
  State<DriverHistoryScreen> createState() => _DriverHistoryScreenState();
}

/// Les périodes que l'écran propose — bornes envoyées au serveur.
enum PeriodeHistorique {
  semaine('7 jours', Duration(days: 7)),
  mois('30 jours', Duration(days: 30)),
  an('1 an', Duration(days: 365));

  const PeriodeHistorique(this.libelle, this.duree);

  final String libelle;
  final Duration duree;
}

class _DriverHistoryScreenState extends State<DriverHistoryScreen> {
  eccore.ManagedAssignmentRepository get _courses =>
      eccore.ManagedAssignmentRepository(apiClient: AdminAuthService().apiClient);

  PeriodeHistorique _periode = PeriodeHistorique.mois;
  eccore.Page<eccore.Assignment>? _page;
  eccore.CourierEarnings? _totaux;
  int _numeroDePage = 1;
  bool _enCours = false;
  Echec? _echec;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_charger());
    });
  }

  DateTime get _depuis => DateTime.now().subtract(_periode.duree);

  Future<void> _charger({int page = 1}) async {
    setState(() {
      _enCours = true;
      _echec = null;
      _numeroDePage = page;
    });
    try {
      final courses = await _courses.page(
        courierId: widget.driver.id,
        deliveredFrom: _depuis,
        page: page,
      );
      final totaux = await _courses.summary(
        courierId: widget.driver.id,
        deliveredFrom: _depuis,
      );
      if (!mounted) return;
      setState(() {
        _page = courses;
        _totaux = totaux;
      });
    } on eccore.ApiException catch (e) {
      if (mounted) setState(() => _echec = Echec.de(e));
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final courses = _page?.results ?? const <eccore.Assignment>[];
    final totaux = _totaux;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Historique', style: TextStyle(fontSize: 16)),
            Text(
              widget.driver.fullName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<PeriodeHistorique>(
              segments: [
                for (final periode in PeriodeHistorique.values)
                  ButtonSegment(value: periode, label: Text(periode.libelle)),
              ],
              selected: {_periode},
              onSelectionChanged: (choix) {
                setState(() => _periode = choix.first);
                unawaited(_charger());
              },
            ),
          ),
          if (_echec != null)
            BandeauEchec(echec: _echec!, onReessayer: () => unawaited(_charger())),
          if (totaux != null) _Totaux(totaux: totaux, periode: _periode),
          Expanded(
            child: _enCours && _page == null
                ? const Center(child: CircularProgressIndicator())
                : courses.isEmpty
                    ? Center(
                        child: Text(
                          'Aucune course livrée sur ${_periode.libelle.toLowerCase()}.',
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: courses.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) => _LigneCourse(course: courses[index]),
                      ),
          ),
          BarrePagination(
            numeroDePage: _numeroDePage,
            nombreDePages:
                _page == null || _page!.count == 0 ? 1 : ((_page!.count + 24) ~/ 25),
            total: _page?.count ?? 0,
            enCours: _enCours,
            onPrecedente: (_page?.hasPrevious ?? false)
                ? () => unawaited(_charger(page: _numeroDePage - 1))
                : null,
            onSuivante: (_page?.hasNext ?? false)
                ? () => unawaited(_charger(page: _numeroDePage + 1))
                : null,
          ),
        ],
      ),
    );
  }
}

class _Totaux extends StatelessWidget {
  const _Totaux({required this.totaux, required this.periode});

  final eccore.CourierEarnings totaux;
  final PeriodeHistorique periode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 24,
          runSpacing: 12,
          children: [
            _Chiffre(libelle: 'Courses (${periode.libelle})', valeur: '${totaux.assignments}'),
            _Chiffre(libelle: 'Livrées', valeur: '${totaux.compteDe('delivered')}'),
            _Chiffre(libelle: 'Refusées', valeur: '${totaux.compteDe('declined')}'),
            _Chiffre(libelle: 'Annulées', valeur: '${totaux.compteDe('cancelled')}'),
            if (totaux.earnings.isEmpty)
              const _Chiffre(libelle: 'Gains du livreur', valeur: 'Aucun'),
            // Les gains **du livreur**, par devise — jamais le chiffre
            // d'affaires des commandes qu'il a portées.
            for (final ligne in totaux.earnings)
              _Chiffre(
                libelle: 'Gains (${ligne.amount.currency})',
                valeur: formatMontant(ligne.amount),
                couleur: scheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}

class _Chiffre extends StatelessWidget {
  const _Chiffre({required this.libelle, required this.valeur, this.couleur});

  final String libelle;
  final String valeur;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          valeur,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: couleur ?? scheme.onSurface,
          ),
        ),
        Text(libelle, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
      ],
    );
  }
}

class _LigneCourse extends StatelessWidget {
  const _LigneCourse({required this.course});

  final eccore.Assignment course;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final livree = course.deliveredAt != null;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(
          livree ? Icons.check_circle : Icons.local_shipping_outlined,
          color: livree ? scheme.primary : scheme.outline,
        ),
        title: Text(course.orderReference),
        subtitle: Text(
          [
            course.restaurantName,
            if (course.courierFee != null) 'Gain : ${formatMontant(course.courierFee!)}',
            if (course.declineReason.isNotEmpty) 'Refus : ${course.declineReason}',
          ].join(' • '),
        ),
        trailing: Text(
          dateCourte(course.deliveredAt ?? course.offeredAt),
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

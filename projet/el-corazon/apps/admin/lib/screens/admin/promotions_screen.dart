import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/presentation/autorisations.dart';
import 'package:admin/presentation/dialogue_formulaire.dart';
import 'package:admin/presentation/echec.dart';
import 'package:admin/presentation/retours.dart';
import 'package:admin/services/admin_auth_service.dart';
import 'package:admin/services/promotion_service.dart';
import 'package:admin/services/restaurant_scope_service.dart';
import 'package:admin/utils/price_formatter.dart';

/// Codes promotionnels.
///
/// ## Ce qui a changé (22 septembre 2026)
///
/// * **Établissement.** Le formulaire n'en proposait pas : tout code naissait
///   national, que le serveur refuse à un compte rattaché (« renseignez un
///   établissement »). Un gérant ne pouvait créer aucun code. Le champ existe,
///   et l'option « national » n'est offerte qu'au siège.
/// * **Devise.** Les montants partaient dans la devise de l'établissement
///   *sélectionné dans le back-office*, et s'affichaient tous « FCFA ». Ils
///   partent dans la devise de l'établissement du code (ou celle que le siège
///   choisit pour un code national), et s'affichent avec leur code ISO.
/// * **Effacer une limite.** Vider « Remise maximale » ou « Quota » ne retirait
///   rien : la valeur nulle n'était pas envoyée. Elle l'est.
/// * **Quota par client**, que le serveur gère, est saisissable.
/// * Les gestes d'écriture suivent `promotions.write`.
class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({super.key});

  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<PromotionService>().initialize());
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<PromotionService>();
    final peutEcrire = context.peut('promotions.write');

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Promotions'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Toutes', icon: Icon(Icons.list)),
              Tab(text: 'Utilisables', icon: Icon(Icons.check_circle)),
              Tab(text: 'Hors service', icon: Icon(Icons.history)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Recharger',
              onPressed: service.isLoading ? null : () => unawaited(service.refresh()),
            ),
          ],
        ),
        floatingActionButton: peutEcrire
            ? FloatingActionButton.extended(
                onPressed: () => ouvrirFormulairePromotion(context),
                icon: const Icon(Icons.add),
                label: const Text('Nouveau code'),
              )
            : null,
        body: Column(
          children: [
            if (service.echec != null)
              BandeauEchec(echec: service.echec!, onReessayer: () => unawaited(service.refresh())),
            Expanded(
              child: service.isLoading && service.promotions.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      children: [
                        _Liste(codes: service.promotions, peutEcrire: peutEcrire),
                        _Liste(codes: service.activePromotions, peutEcrire: peutEcrire),
                        _Liste(codes: service.expiredPromotions, peutEcrire: peutEcrire),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Liste extends StatelessWidget {
  const _Liste({required this.codes, required this.peutEcrire});

  final List<eccore.Promotion> codes;
  final bool peutEcrire;

  @override
  Widget build(BuildContext context) {
    if (codes.isEmpty) return const Center(child: Text('Aucun code'));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: codes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _CarteDeCode(code: codes[index], peutEcrire: peutEcrire),
    );
  }
}

/// La valeur de la remise, telle qu'un client la lira.
String valeurDeRemise(eccore.Promotion code) => switch (code.kind) {
      eccore.DiscountKind.percentage => '−${code.percentage?.toStringAsFixed(code.percentage! % 1 == 0 ? 0 : 2)} %',
      eccore.DiscountKind.fixed => code.amount == null ? '—' : '−${formatMontant(code.amount!)}',
      _ => 'Livraison offerte',
    };

class _CarteDeCode extends StatelessWidget {
  const _CarteDeCode({required this.code, required this.peutEcrire});

  final eccore.Promotion code;
  final bool peutEcrire;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final perimetre = context.watch<RestaurantScopeService>();
    // Un code national ne se modifie qu'au siège ; un code nominatif (né d'un
    // échange de points) se consulte seulement.
    final modifiable = peutEcrire && !code.isPersonal && (!code.isNational || context.estSiege);
    final portee = code.isNational
        ? 'National — tous les établissements'
        : (perimetre.parSlug(code.restaurantSlug)?.name ?? code.restaurantSlug!);

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: code.isAvailable ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          child: Icon(Icons.local_offer, color: code.isAvailable ? scheme.primary : scheme.outline),
        ),
        title: Text(code.code, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (code.description.isNotEmpty) Text(code.description),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                Chip(label: Text(valeurDeRemise(code))),
                Chip(label: Text(portee)),
                Chip(label: Text('Du ${dateCourte(code.startsAt)} au ${dateCourte(code.endsAt)}')),
                if (code.minOrderAmount != null)
                  Chip(label: Text('Dès ${formatMontant(code.minOrderAmount!)}')),
                if (code.maxDiscount != null)
                  Chip(label: Text('Plafond ${formatMontant(code.maxDiscount!)}')),
                Chip(
                  label: Text(
                    code.usageLimit == null
                        ? '${code.usedCount} utilisation(s)'
                        : '${code.usedCount} / ${code.usageLimit} utilisation(s)',
                  ),
                ),
                if (code.usageLimitPerUser != null)
                  Chip(label: Text('${code.usageLimitPerUser} par client')),
                if (code.isPersonal) Chip(label: Text('Nominatif — ${code.ownerEmail}')),
                Chip(
                  label: Text(code.isAvailable ? 'Utilisable' : (code.isActive ? 'Hors période ou épuisé' : 'Suspendu')),
                ),
              ],
            ),
          ],
        ),
        trailing: modifiable
            ? PopupMenuButton<String>(
                onSelected: (choix) {
                  if (choix == 'modifier') unawaited(ouvrirFormulairePromotion(context, code: code));
                  if (choix == 'basculer') {
                    unawaited(basculerAvecRetour(context, () => context.read<PromotionService>().basculer(code)));
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'modifier', child: Text('Modifier')),
                  PopupMenuItem(value: 'basculer', child: Text(code.isActive ? 'Suspendre' : 'Réactiver')),
                ],
              )
            : null,
      ),
    );
  }
}

const String _national = '__national__';

/// Formulaire de création ou de modification d'un code.
Future<void> ouvrirFormulairePromotion(BuildContext context, {eccore.Promotion? code}) async {
  final service = context.read<PromotionService>();
  final perimetre = context.read<RestaurantScopeService>();
  final siege = context.read<AdminAuthService>().estSiege;

  String? saisieDe(eccore.Money? m) => m == null ? '' : montantEnSaisie(m.toMajorUnits());

  final codeSaisi = TextEditingController(text: code?.code);
  final description = TextEditingController(text: code?.description);
  final pourcentage = TextEditingController(
    text: code?.percentage == null || code!.percentage == 0 ? '' : montantEnSaisie(code.percentage!),
  );
  final montant = TextEditingController(text: saisieDe(code?.amount));
  final minimum = TextEditingController(text: saisieDe(code?.minOrderAmount));
  final plafond = TextEditingController(text: saisieDe(code?.maxDiscount));
  final quota = TextEditingController(text: code?.usageLimit?.toString() ?? '');
  final quotaClient = TextEditingController(text: code?.usageLimitPerUser?.toString() ?? '');
  var nature = code?.kind ?? eccore.DiscountKind.percentage;
  var actif = code?.isActive ?? true;
  final maintenant = DateTime.now();
  var debut = code?.startsAt.toLocal() ?? maintenant;
  var fin = code?.endsAt.toLocal() ?? maintenant.add(const Duration(days: 7));
  var porteur = code == null
      ? (perimetre.current?.slug ?? (siege ? _national : null))
      : (code.restaurantSlug ?? _national);
  var deviseNationale = code?.amount?.currency ??
      code?.minOrderAmount?.currency ??
      code?.maxDiscount?.currency ??
      (perimetre.devises.isEmpty ? 'XOF' : perimetre.devises.first);

  String devise() =>
      porteur == _national ? deviseNationale : (perimetre.parSlug(porteur)?.currency ?? deviseNationale);
  eccore.Money? versMoney(TextEditingController champ) {
    final valeur = lireMontant(champ.text);
    return valeur == null ? null : eccore.Money.fromMajorUnits(valeur, devise());
  }

  int? entierFacultatif(TextEditingController champ) => int.tryParse(champ.text.trim());

  Future<DateTime?> choisir(BuildContext context, DateTime initial) async {
    final jour = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(maintenant.year + 3),
    );
    if (jour == null || !context.mounted) return null;
    final heure = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (heure == null) return null;
    return DateTime(jour.year, jour.month, jour.day, heure.hour, heure.minute);
  }

  final enregistre = await DialogueDeFormulaire.ouvrir(
    context,
    titre: code == null ? 'Nouveau code' : 'Modifier ${code.code}',
    libelleAction: code == null ? 'Créer' : 'Enregistrer',
    enregistrer: () async {
      final pct = nature == eccore.DiscountKind.percentage ? lireMontant(pourcentage.text) : null;
      final fixe = nature == eccore.DiscountKind.fixed ? versMoney(montant) : null;
      final plafondEnvoye = nature == eccore.DiscountKind.percentage ? versMoney(plafond) : null;
      if (code == null) {
        await service.creer(
          code: codeSaisi.text.trim().toUpperCase(),
          description: description.text.trim(),
          kind: nature,
          percentage: pct,
          amount: fixe,
          minOrderAmount: versMoney(minimum),
          maxDiscount: plafondEnvoye,
          startsAt: debut,
          endsAt: fin,
          usageLimit: entierFacultatif(quota),
          usageLimitPerUser: entierFacultatif(quotaClient),
          restaurantSlug: porteur == _national ? null : porteur,
        );
      } else {
        await service.remplacer(
          id: code.id,
          description: description.text.trim(),
          kind: nature,
          percentage: pct,
          amount: fixe,
          minOrderAmount: versMoney(minimum),
          maxDiscount: plafondEnvoye,
          startsAt: debut,
          endsAt: fin,
          usageLimit: entierFacultatif(quota),
          usageLimitPerUser: entierFacultatif(quotaClient),
          isActive: actif,
        );
      }
    },
    corps: (context, echec) => StatefulBuilder(
      builder: (context, majEtat) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: codeSaisi,
            enabled: code == null,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Code *',
              helperText: code == null ? 'Ce que le client saisit.' : 'Le code ne change pas après sa création.',
              errorText: echec?.pourLeChamp('code'),
            ),
            validator: Valider.requis,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: description,
            decoration: const InputDecoration(labelText: 'Description'),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          if (code == null)
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: porteur,
              decoration: InputDecoration(
                labelText: 'Établissement *',
                helperText: siege ? null : 'Un code national relève du siège.',
                errorText: echec?.pourLeChamp('restaurant'),
              ),
              items: [
                if (siege) const DropdownMenuItem(value: _national, child: Text('National — tous les établissements')),
                for (final etablissement in perimetre.restaurants)
                  DropdownMenuItem(
                    value: etablissement.slug,
                    child: Text('${etablissement.name} (${etablissement.currency})'),
                  ),
              ],
              validator: (valeur) => valeur == null ? 'Choisissez un établissement' : null,
              onChanged: (valeur) => majEtat(() => porteur = valeur),
            )
          else
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Établissement'),
              child: Text(
                porteur == _national
                    ? 'National — tous les établissements'
                    : (perimetre.parSlug(porteur)?.name ?? porteur ?? ''),
              ),
            ),
          if (porteur == _national && perimetre.devises.length > 1 && code == null)
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: deviseNationale,
              decoration: const InputDecoration(
                labelText: 'Devise des montants *',
                helperText: 'Un code national libellé en XOF est refusé sur une commande en XAF.',
                helperMaxLines: 2,
              ),
              items: [for (final d in perimetre.devises) DropdownMenuItem(value: d, child: Text(d))],
              onChanged: (valeur) => majEtat(() => deviseNationale = valeur ?? deviseNationale),
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: nature,
            decoration: InputDecoration(labelText: 'Nature de la remise *', errorText: echec?.pourLeChamp('kind')),
            items: const [
              DropdownMenuItem(value: eccore.DiscountKind.percentage, child: Text('Pourcentage du sous-total')),
              DropdownMenuItem(value: eccore.DiscountKind.fixed, child: Text('Montant fixe')),
              DropdownMenuItem(value: eccore.DiscountKind.freeDelivery, child: Text('Livraison offerte')),
            ],
            onChanged: (valeur) => majEtat(() => nature = valeur ?? nature),
          ),
          const SizedBox(height: 12),
          if (nature == eccore.DiscountKind.percentage) ...[
            TextFormField(
              controller: pourcentage,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Pourcentage *', suffixText: '%', errorText: echec?.pourLeChamp('percentage')),
              validator: (v) {
                final valeur = lireMontant(v ?? '');
                if (valeur == null || valeur <= 0) return 'Un pourcentage strictement positif';
                if (valeur > 100) return 'Au plus 100 %';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: plafond,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Remise maximale (${devise()})',
                helperText: 'Vide : sans plafond.',
                errorText: echec?.pourLeChamp('max_discount'),
              ),
              validator: Valider.montantFacultatif,
            ),
          ],
          if (nature == eccore.DiscountKind.fixed)
            TextFormField(
              controller: montant,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Montant de la remise (${devise()}) *', errorText: echec?.pourLeChamp('amount')),
              validator: Valider.montant,
            ),
          const SizedBox(height: 12),
          TextFormField(
            controller: minimum,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Minimum de commande (${devise()})',
              helperText: 'Vide : sans minimum.',
              errorText: echec?.pourLeChamp('min_order_amount'),
            ),
            validator: Valider.montantFacultatif,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: quota,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Quota total',
                    helperText: 'Vide : illimité.',
                    errorText: echec?.pourLeChamp('usage_limit'),
                  ),
                  validator: Valider.entierFacultatif,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: quotaClient,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Quota par client',
                    helperText: 'Vide : illimité.',
                    errorText: echec?.pourLeChamp('usage_limit_per_user'),
                  ),
                  validator: Valider.entierFacultatif,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final choisie = await choisir(context, debut);
                    if (choisie != null) majEtat(() => debut = choisie);
                  },
                  child: Text('Début : ${dateCourte(debut)}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final choisie = await choisir(context, fin);
                    if (choisie != null) majEtat(() => fin = choisie);
                  },
                  child: Text('Fin : ${dateCourte(fin)}'),
                ),
              ),
            ],
          ),
          FormField<void>(
            validator: (_) => fin.isAfter(debut) ? null : 'La fin doit suivre le début.',
            builder: (etat) => Text(
              etat.errorText ?? echec?.pourLeChamp('ends_at') ?? '',
              style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
            ),
          ),
          if (code != null)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Actif'),
              value: actif,
              onChanged: (valeur) => majEtat(() => actif = valeur),
            ),
        ],
      ),
    ),
  );

  if (enregistre && context.mounted) {
    annoncer(context, code == null ? 'Code créé.' : 'Code enregistré.');
  }
}


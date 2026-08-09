import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/services/marketing_service.dart';
import 'package:admin/ui/ui.dart';
import 'package:admin/utils/dialog_helper.dart';

/// Campagnes de notifications — rédiger, estimer, envoyer une fois.
///
/// L'écran avait trois onglets ; il en garde un. « Analytics » affichait des
/// prévisions calculées dans le navigateur, avec un « niveau de confiance » qui
/// ne mesurait rien ; « Clients » un « risque d'attrition » obtenu de la même
/// façon, après avoir chargé l'historique de commandes de tous les clients sur
/// un poste de travail. Les chiffres réels de l'exploitation sont dans l'écran
/// Analytics, alimenté par `/analytics/reports/*`.
///
/// Ce qui reste est le geste métier : on écrit, on regarde combien de personnes
/// c'est, on envoie — et une campagne envoyée ne se retouche plus.
class MarketingScreen extends StatefulWidget {
  const MarketingScreen({super.key});

  @override
  State<MarketingScreen> createState() => _MarketingScreenState();
}

class _MarketingScreenState extends State<MarketingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<MarketingService>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Campagnes'),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<MarketingService>().refresh(),
            tooltip: 'Recharger',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _ouvrirFormulaire(null),
        icon: const Icon(Icons.add),
        label: const Text('Rédiger'),
      ),
      body: Consumer<MarketingService>(
        builder: (context, service, child) {
          if (service.isLoading && service.campaigns.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (service.error != null && service.campaigns.isEmpty) {
            return _Vide(
              icone: Icons.lock_outline,
              texte: service.error!,
              action: service.refresh,
            );
          }

          if (service.campaigns.isEmpty) {
            return _Vide(
              icone: Icons.campaign_outlined,
              texte: 'Aucune campagne pour le moment.',
              action: service.refresh,
            );
          }

          return Column(
            children: [
              _bandeauCompteurs(service),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: service.campaigns.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _carte(service, service.campaigns[index]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _bandeauCompteurs(MarketingService service) {
    final scheme = Theme.of(context).colorScheme;
    final sem = AdminColorTokens.semantic(scheme);
    final destinataires = service.sent.fold<int>(
      0,
      (somme, campagne) => somme + campagne.recipientCount,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      color: scheme.surfaceContainerHighest,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _compteur('Brouillons', '${service.drafts.length}', scheme.primary),
          _compteur('Envoyées', '${service.sent.length}', sem.success),
          // Notifications réellement écrites, hors comptes ayant refusé le
          // marketing : compter la taille des segments donnerait un chiffre
          // flatteur que personne n'a reçu.
          _compteur('Destinataires', '$destinataires', scheme.tertiary),
        ],
      ),
    );
  }

  Widget _compteur(String libelle, String valeur, Color couleur) {
    return Column(
      children: [
        Text(
          valeur,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: couleur,
          ),
        ),
        const SizedBox(height: 2),
        Text(libelle, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _carte(MarketingService service, eccore.Campaign campagne) {
    final scheme = Theme.of(context).colorScheme;
    final sem = AdminColorTokens.semantic(scheme);
    final estimation = service.knownAudience(campagne.id);

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
                    campagne.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Chip(
                  label: Text(campagne.isSent ? 'Envoyée' : 'Brouillon'),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: campagne.isSent
                      ? sem.success.withValues(alpha: 0.15)
                      : scheme.surfaceContainerHighest,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(campagne.body, maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(Icons.group_outlined, size: 16, color: scheme.outline),
                Text(campagne.audienceLabel),
                if (campagne.isSent)
                  Text(
                    '· ${campagne.recipientCount} destinataires · '
                    '${_date(campagne.sentAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                else if (estimation != null)
                  Text(
                    '· environ $estimation personnes',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            if (campagne.createdByEmail != null) ...[
              const SizedBox(height: 4),
              Text(
                'Rédigée par ${campagne.createdByEmail}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (campagne.isDraft) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _estimer(service, campagne),
                    icon: const Icon(Icons.people_outline),
                    label: const Text('Estimer'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _ouvrirFormulaire(campagne),
                    icon: const Icon(Icons.edit),
                    label: const Text('Modifier'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _envoyer(service, campagne),
                    icon: const Icon(Icons.send),
                    label: const Text('Envoyer'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- actions

  Future<void> _estimer(
    MarketingService service,
    eccore.Campaign campagne,
  ) async {
    final messager = ScaffoldMessenger.of(context);
    final compte = await service.estimateAudience(campagne.id);

    if (!mounted) return;
    messager.showSnackBar(
      SnackBar(
        content: Text(
          compte == null
              ? service.error ?? 'Estimation indisponible'
              // Majorant : le consentement au marketing ne se vérifie qu'à
              // l'écriture de chaque notification.
              : 'Cette campagne viserait au plus $compte personnes.',
        ),
      ),
    );
  }

  Future<void> _envoyer(
    MarketingService service,
    eccore.Campaign campagne,
  ) async {
    final compte = service.knownAudience(campagne.id);
    final confirme = await DialogHelper.showSafeDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Envoyer la campagne'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              campagne.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Segment : ${campagne.audienceLabel}'),
            if (compte != null) Text('Environ $compte personnes'),
            const SizedBox(height: 12),
            const Text(
              "L'envoi est définitif : le message ne pourra plus être "
              'corrigé, et une campagne ne part qu'
              'une fois.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );

    if (confirme != true || !mounted) return;

    final messager = ScaffoldMessenger.of(context);
    final ok = await service.sendCampaign(campagne.id);

    if (!mounted) return;
    messager.showSnackBar(
      SnackBar(
        content: Text(ok ? 'Campagne envoyée' : service.error ?? 'Envoi refusé'),
      ),
    );
  }

  Future<void> _ouvrirFormulaire(eccore.Campaign? campagne) async {
    final service = context.read<MarketingService>();
    final titre = TextEditingController(text: campagne?.title ?? '');
    final corps = TextEditingController(text: campagne?.body ?? '');
    final jours = TextEditingController(
      text: '${campagne?.segmentDays ?? 30}',
    );
    var segment = campagne?.audience ?? eccore.CampaignAudience.allCustomers;
    final formKey = GlobalKey<FormState>();

    final valide = await DialogHelper.showSafeDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            campagne == null ? 'Nouvelle campagne' : 'Modifier le brouillon',
          ),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: titre,
                      maxLength: 120,
                      decoration: const InputDecoration(labelText: 'Titre *'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Le titre est requis'
                          : null,
                    ),
                    TextFormField(
                      controller: corps,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Message *'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Le message est requis'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: segment,
                      decoration: const InputDecoration(labelText: 'Segment *'),
                      // Liste fermée, celle du serveur : un ciblage libre est
                      // une requête que personne n'a relue avant qu'elle ne
                      // parte à des milliers de gens.
                      items: [
                        for (final valeur in eccore.CampaignAudience.values)
                          DropdownMenuItem(
                            value: valeur,
                            child: Text(_libelleSegment(valeur)),
                          ),
                      ],
                      onChanged: (valeur) => setDialogState(() {
                        if (valeur != null) segment = valeur;
                      }),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: jours,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Fenêtre du segment (jours)',
                        helperText:
                            'Sert aux segments « récemment » et « sans commande '
                            'récente »',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(context).pop(true);
                }
              },
              child: Text(campagne == null ? 'Créer' : 'Enregistrer'),
            ),
          ],
        ),
      ),
    );

    if (valide != true || !mounted) return;

    final messager = ScaffoldMessenger.of(context);
    final fenetre = int.tryParse(jours.text) ?? 30;
    final ok = campagne == null
        ? await service.createCampaign(
                title: titre.text.trim(),
                body: corps.text.trim(),
                audience: segment,
                segmentDays: fenetre,
              ) !=
              null
        : await service.updateCampaign(
            id: campagne.id,
            title: titre.text.trim(),
            body: corps.text.trim(),
            audience: segment,
            segmentDays: fenetre,
          );

    titre.dispose();
    corps.dispose();
    jours.dispose();

    if (!mounted) return;
    messager.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (campagne == null
                    ? 'Brouillon créé — il ne part pas tant que vous ne '
                          "l'envoyez pas"
                    : 'Brouillon mis à jour')
              : service.error ?? 'Opération refusée',
        ),
      ),
    );
  }

  String _libelleSegment(String valeur) {
    switch (valeur) {
      case eccore.CampaignAudience.allCustomers:
        return 'Tous les clients';
      case eccore.CampaignAudience.couriers:
        return 'Tous les livreurs';
      case eccore.CampaignAudience.activeCustomers:
        return 'Clients ayant commandé récemment';
      case eccore.CampaignAudience.lapsedCustomers:
        return 'Clients sans commande récente';
      default:
        return valeur;
    }
  }

  String _date(DateTime? date) {
    if (date == null) return '—';
    final local = date.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }
}

class _Vide extends StatelessWidget {
  const _Vide({
    required this.icone,
    required this.texte,
    required this.action,
  });

  final IconData icone;
  final String texte;
  final VoidCallback action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 56, color: scheme.outline),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(texte, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: action, child: const Text('Recharger')),
        ],
      ),
    );
  }
}

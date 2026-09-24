import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/presentation/autorisations.dart';
import 'package:admin/presentation/barre_pagination.dart';
import 'package:admin/presentation/commande.dart';
import 'package:admin/presentation/couleur_statut.dart';
import 'package:admin/presentation/dialogue_formulaire.dart';
import 'package:admin/presentation/echec.dart';
import 'package:admin/presentation/notes_internes.dart';
import 'package:admin/presentation/retours.dart';
import 'package:admin/services/client_management_service.dart';
import 'package:admin/utils/dialog_helper.dart';
import 'package:admin/utils/price_formatter.dart';

/// Comptes clients.
///
/// ## Ce qui a changé (22 septembre 2026)
///
/// * **Réactiver un compte.** Le service savait le faire depuis toujours et
///   aucun bouton ne l'appelait : un client suspendu le restait, et le menu
///   proposait « Suspendre » sur un compte déjà suspendu. Le geste dépend
///   désormais de l'état du compte.
/// * **La recherche est celle du serveur.** L'écran téléchargeait tous les
///   comptes puis filtrait en mémoire ; « aucun résultat » voulait dire
///   « pas dans ce que j'ai chargé ».
/// * **Les compteurs de la ligne étaient faux.** « 3 commande(s) » et le total
///   dépensé venaient d'un rapprochement entre l'identifiant du *client* et
///   celui d'une *commande* (`o.id == client.id`) : la liste affichait donc
///   zéro partout. Ces chiffres sont ceux de la fiche, que le serveur agrège.
/// * Suspendre et réactiver suivent `customers.block`.
class ClientManagementScreen extends StatefulWidget {
  const ClientManagementScreen({super.key});

  @override
  State<ClientManagementScreen> createState() => _ClientManagementScreenState();
}

class _ClientManagementScreenState extends State<ClientManagementScreen> {
  final _recherche = TextEditingController();
  Timer? _frappe;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<ClientManagementService>().initialize());
    });
  }

  @override
  void dispose() {
    _frappe?.cancel();
    _recherche.dispose();
    super.dispose();
  }

  /// La recherche part au serveur après une pause de frappe : une requête par
  /// caractère saisi n'apprendrait rien de plus et ferait attendre.
  void _surFrappe(String valeur) {
    _frappe?.cancel();
    _frappe = Timer(const Duration(milliseconds: 350), () {
      if (mounted) unawaited(context.read<ClientManagementService>().chercher(recherche: valeur));
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ClientManagementService>();
    final peutBloquer = context.peut('customers.block');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recharger',
            onPressed: service.isLoading ? null : () => unawaited(service.refresh()),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _recherche,
                    onChanged: _surFrappe,
                    decoration: const InputDecoration(
                      labelText: 'Rechercher',
                      helperText: 'Nom, adresse électronique ou téléphone — cherché par le serveur.',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<EtatDuClient>(
                    isExpanded: true,
                    initialValue: service.etat,
                    decoration: const InputDecoration(
                      labelText: 'État',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (final etat in EtatDuClient.values)
                        DropdownMenuItem(value: etat, child: Text(etat.libelle)),
                    ],
                    onChanged: (etat) =>
                        etat == null ? null : unawaited(service.chercher(etat: etat)),
                  ),
                ),
              ],
            ),
          ),
          if (service.echec != null)
            BandeauEchec(echec: service.echec!, onReessayer: () => unawaited(service.refresh())),
          Expanded(
            child: service.isLoading && service.clients.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : service.clients.isEmpty
                    ? Center(
                        child: Text(
                          service.recherche.trim().isEmpty
                              ? 'Aucun compte client.'
                              : 'Aucun compte ne correspond à « ${service.recherche.trim()} ».',
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: service.clients.length,
                        itemBuilder: (context, index) => _LigneClient(
                          client: service.clients[index],
                          peutBloquer: peutBloquer,
                        ),
                      ),
          ),
          BarrePagination(
            numeroDePage: service.numeroDePage,
            nombreDePages: service.nombreDePages,
            total: service.total,
            enCours: service.isLoading,
            onPrecedente: service.aPagePrecedente ? () => unawaited(service.pagePrecedente()) : null,
            onSuivante: service.aPageSuivante ? () => unawaited(service.pageSuivante()) : null,
          ),
        ],
      ),
    );
  }
}

class _LigneClient extends StatelessWidget {
  const _LigneClient({required this.client, required this.peutBloquer});

  final eccore.Customer client;
  final bool peutBloquer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final suspendu = !client.isActive;
    final initiale = client.fullName.trim().isEmpty ? '?' : client.fullName.trim()[0].toUpperCase();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () => unawaited(ouvrirFicheClient(context, client)),
        leading: CircleAvatar(
          backgroundColor: suspendu ? scheme.surfaceContainerHighest : scheme.primary,
          child: Text(
            initiale,
            style: TextStyle(
              color: suspendu ? scheme.onSurfaceVariant : scheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(client.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(client.email),
            if ((client.phone ?? '').isNotEmpty) Text(client.phone!),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: [
                Chip(label: Text(suspendu ? 'Suspendu' : 'Actif')),
                if (client.emailVerifiedAt == null) const Chip(label: Text('Courriel non vérifié')),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (choix) {
            switch (choix) {
              case 'fiche':
                unawaited(ouvrirFicheClient(context, client));
              case 'commandes':
                unawaited(ouvrirCommandesDuClient(context, client));
              case 'suspendre':
                unawaited(suspendreClient(context, client));
              case 'reactiver':
                unawaited(reactiverClient(context, client));
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'fiche', child: Text('Fiche du client')),
            const PopupMenuItem(value: 'commandes', child: Text('Historique des commandes')),
            // Le geste dépend de l'état : proposer « Suspendre » sur un compte
            // déjà suspendu est ce que faisait l'écran, sans offrir l'inverse.
            if (peutBloquer && !suspendu)
              const PopupMenuItem(value: 'suspendre', child: Text('Suspendre le compte')),
            if (peutBloquer && suspendu)
              const PopupMenuItem(value: 'reactiver', child: Text('Réactiver le compte')),
          ],
        ),
      ),
    );
  }
}

/// La fiche d'un client : les chiffres que le serveur agrège, et les notes
/// internes de l'équipe.
Future<void> ouvrirFicheClient(BuildContext context, eccore.Customer client) async {
  final service = context.read<ClientManagementService>();
  eccore.CustomerStats fiche;
  try {
    fiche = await service.fiche(client.id);
  } on eccore.ApiException catch (e) {
    if (context.mounted) annoncerEchec(context, Echec.de(e));
    return;
  }
  if (!context.mounted) return;

  await DialogHelper.showSafeDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(client.fullName),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _Ligne('Adresse électronique', client.email),
              _Ligne('Téléphone', client.phone ?? '—'),
              _Ligne('Commandes', '${fiche.ordersCount}'),
              _Ligne('Livrées', '${fiche.ordersDelivered}'),
              _Ligne('Annulées', '${fiche.ordersCancelled}'),
              _Ligne('Total dépensé', formatMontant(fiche.totalSpent)),
              _Ligne('Panier moyen', formatMontant(fiche.averageBasket)),
              _Ligne('Points de fidélité', '${fiche.loyaltyBalance}'),
              _Ligne('Points gagnés à vie', '${fiche.loyaltyLifetimeEarned}'),
              _Ligne('Adresses enregistrées', '${fiche.addressesCount}'),
              _Ligne('Compte créé le', dateCourte(client.createdAt)),
              if (fiche.lastOrderAt != null)
                _Ligne('Dernière commande', dateCourte(fiche.lastOrderAt!)),
              const Divider(height: 24),
              SizedBox(
                width: 480,
                child: NotesInternes(
                  lire: () => service.notesOf(client.id),
                  ajouter: (contenu) => service.addNote(client.id, contenu),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fermer')),
      ],
    ),
  );
}

/// Les commandes d'un client — **une page**, demandée au serveur.
Future<void> ouvrirCommandesDuClient(BuildContext context, eccore.Customer client) async {
  final service = context.read<ClientManagementService>();
  eccore.Page<eccore.Order> page;
  try {
    page = await service.commandes(client.id);
  } on eccore.ApiException catch (e) {
    if (context.mounted) annoncerEchec(context, Echec.de(e));
    return;
  }
  if (!context.mounted) return;

  await DialogHelper.showSafeDialog<void>(
    context: context,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return AlertDialog(
        title: Text('Commandes de ${client.fullName}'),
        content: SizedBox(
          width: 560,
          height: 420,
          child: page.results.isEmpty
              ? const Center(child: Text('Aucune commande'))
              : Column(
                  children: [
                    if (page.count > page.results.length)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Les ${page.results.length} plus récentes sur ${page.count}.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: page.results.length,
                        itemBuilder: (context, index) {
                          final order = page.results[index];
                          return ListTile(
                            leading: Icon(
                              Icons.receipt_long,
                              color: couleurDeStatut(order.statut, scheme),
                            ),
                            title: Text(order.reference),
                            subtitle: Text(
                              '${formatMontant(order.total)} — ${order.statut.libelle}'
                              ' — ${order.restaurantName}',
                            ),
                            trailing: Text(dateCourte(order.placedAt)),
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fermer')),
        ],
      );
    },
  );
}

/// Suspend un compte — motif obligatoire (le serveur l'exige et le journalise).
Future<void> suspendreClient(BuildContext context, eccore.Customer client) async {
  final service = context.read<ClientManagementService>();
  final motif = TextEditingController();

  final fait = await DialogueDeFormulaire.ouvrir(
    context,
    titre: 'Suspendre ${client.fullName}',
    libelleAction: 'Suspendre',
    enregistrer: () => service.suspendre(client.id, motif: motif.text.trim()),
    corps: (context, echec) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Le compte est fermé et ses sessions révoquées : le client ne peut '
          'plus commander tant qu’il n’est pas réactivé.',
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: motif,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Motif *',
            helperText: 'Conservé au journal des décisions : c’est lui qu’on cherchera '
                'le jour où le client rappellera.',
            helperMaxLines: 2,
            errorText: echec?.pourLeChamp('reason'),
          ),
          validator: (valeur) =>
              (valeur ?? '').trim().length < 3 ? 'Dites pourquoi, en quelques mots' : null,
        ),
      ],
    ),
  );

  if (fait && context.mounted) annoncer(context, 'Compte suspendu.');
}

/// Rouvre un compte suspendu.
Future<void> reactiverClient(BuildContext context, eccore.Customer client) async {
  final service = context.read<ClientManagementService>();
  final confirme = await DialogHelper.showSafeDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Réactiver ${client.fullName} ?'),
      content: const Text(
        'Le compte pourra de nouveau commander. Le client devra se reconnecter : '
        'ses sessions ont été révoquées à la suspension.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Réactiver'),
        ),
      ],
    ),
  );
  if (confirme != true || !context.mounted) return;

  try {
    await service.reactiver(client.id);
    if (context.mounted) annoncer(context, 'Compte réactivé.');
  } on eccore.ApiException catch (e) {
    if (context.mounted) annoncerEchec(context, Echec.de(e));
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne(this.label, this.valeur);

  final String label;
  final String valeur;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text('$label :', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(valeur)),
        ],
      ),
    );
  }
}

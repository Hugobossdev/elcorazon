import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/screens/admin/versements/communs.dart';
import 'package:admin/services/admin_auth_service.dart';
import 'package:admin/services/support_client_service.dart';
import 'package:admin/ui/ui.dart';

/// Le service client : ce que les clients ont écrit, et ce qu'on leur répond.
///
/// ## Ce que l'écran comble
///
/// Les routes du support n'étaient ouvertes qu'aux clients. Un ticket, une
/// réclamation, une demande de retour arrivaient en base, et le back-office
/// n'avait aucun moyen de les lire — encore moins d'y répondre. Tout se
/// traitait dans l'administration Django, dont les réponses ne partaient vers
/// personne. Chaque geste d'ici parvient au client en notification.
class ServiceClientScreen extends StatefulWidget {
  const ServiceClientScreen({super.key});

  @override
  State<ServiceClientScreen> createState() => _ServiceClientScreenState();
}

class _ServiceClientScreenState extends State<ServiceClientScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<SupportClientService>().charger());
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<SupportClientService>();
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 3,
      child: Material(
        color: theme.colorScheme.surface,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('À traiter'),
                    selected: service.seulementATraiter,
                    onSelected: (_) => unawaited(service.charger(aTraiter: true)),
                  ),
                  ChoiceChip(
                    label: const Text('Tout l’historique'),
                    selected: !service.seulementATraiter,
                    onSelected: (_) => unawaited(service.charger(aTraiter: false)),
                  ),
                  IconButton(
                    tooltip: 'Recharger',
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: () => unawaited(service.charger()),
                  ),
                ],
              ),
            ),
            TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'Tickets (${service.tickets.length})'),
                Tab(text: 'Réclamations (${service.reclamations.length})'),
                Tab(text: 'Retours (${service.retours.length})'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _Onglet(
                    vide: service.tickets.isEmpty,
                    messageVide: 'Aucun ticket à traiter.',
                    enfants: [for (final t in service.tickets) _LigneTicket(ticket: t)],
                  ),
                  _Onglet(
                    vide: service.reclamations.isEmpty,
                    messageVide: 'Aucune réclamation à traiter.',
                    enfants: [
                      for (final r in service.reclamations) _CarteReclamation(reclamation: r),
                    ],
                  ),
                  _Onglet(
                    vide: service.retours.isEmpty,
                    messageVide: 'Aucune demande de retour à traiter.',
                    enfants: [for (final r in service.retours) _CarteRetour(retour: r)],
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

class _Onglet extends StatelessWidget {
  const _Onglet({required this.vide, required this.messageVide, required this.enfants});

  final bool vide;
  final String messageVide;
  final List<Widget> enfants;

  @override
  Widget build(BuildContext context) {
    final service = context.watch<SupportClientService>();
    return EtatDeListe(
      chargement: service.chargement,
      erreur: service.erreur,
      vide: vide,
      messageVide: service.seulementATraiter ? messageVide : 'Rien dans l’historique.',
      onReessayer: () => unawaited(service.charger()),
      liste: RefreshIndicator(
        onRefresh: service.charger,
        child: ListView(padding: const EdgeInsets.all(16), children: enfants),
      ),
    );
  }
}

class _Pastille extends StatelessWidget {
  const _Pastille(this.libelle, {required this.ouverte});

  final String libelle;

  /// Attend encore un geste : couleur d'alerte ; sinon, couleur apaisée.
  final bool ouverte;

  @override
  Widget build(BuildContext context) {
    final sem = AdminColorTokens.semantic(Theme.of(context).colorScheme);
    final couleur = ouverte ? sem.warning : sem.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        libelle,
        style: TextStyle(color: couleur, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

// --------------------------------------------------------------- tickets

class _LigneTicket extends StatelessWidget {
  const _LigneTicket({required this.ticket});

  final eccore.ManagedTicket ticket;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.forum_outlined),
        title: Text(ticket.subject),
        subtitle: Text(
          '${ticket.customerName} · ${eccore.StatutSupport.categorie(ticket.category)} · '
          '${dateCourte(ticket.createdAt)} · ${ticket.messagesCount} message(s)',
        ),
        trailing: _Pastille(
          eccore.StatutSupport.ticket(ticket.status),
          ouverte: ticket.enSouffrance,
        ),
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => DialogueTicket(ticketId: ticket.id, apercu: ticket),
        ),
      ),
    );
  }
}

/// Le fil d'un ticket, et la réponse.
class DialogueTicket extends StatefulWidget {
  const DialogueTicket({required this.ticketId, required this.apercu, super.key});

  final String ticketId;

  /// Ce que la liste savait déjà — affiché le temps que le fil arrive.
  final eccore.ManagedTicket apercu;

  @override
  State<DialogueTicket> createState() => _DialogueTicketState();
}

class _DialogueTicketState extends State<DialogueTicket> {
  final _reponse = TextEditingController();
  late eccore.ManagedTicket _ticket = widget.apercu;
  bool _filCharge = false;
  String? _refus;

  @override
  void initState() {
    super.initState();
    unawaited(_relire());
  }

  @override
  void dispose() {
    _reponse.dispose();
    super.dispose();
  }

  Future<void> _relire() async {
    final complet = await context.read<SupportClientService>().ouvrirTicket(widget.ticketId);
    if (!mounted) return;
    setState(() {
      if (complet != null) _ticket = complet;
      _filCharge = true;
    });
  }

  Future<void> _envoyer() async {
    final texte = _reponse.text.trim();
    if (texte.isEmpty) return;
    final refus = await context.read<SupportClientService>().repondre(widget.ticketId, texte);
    if (!mounted) return;
    setState(() => _refus = refus);
    if (refus == null) {
      _reponse.clear();
      await _relire();
    }
  }

  Future<void> _statut(String statut, {bool demanderResolution = false}) async {
    var resolution = '';
    if (demanderResolution) {
      final saisie = await demanderTexte(
        context,
        titre: 'Résoudre le ticket',
        explication: 'Le client lira cette phrase : dites-lui comment son problème a été réglé.',
        libelle: 'Résolution',
        action: 'Résoudre',
      );
      if (saisie == null || !mounted) return;
      resolution = saisie;
    }
    final service = context.read<SupportClientService>();
    final refus = await service.changerStatutTicket(widget.ticketId, statut, resolution: resolution);
    if (!mounted) return;
    setState(() {
      _refus = refus;
      if (refus == null) {
        _ticket = eccore.ManagedTicket(
          id: _ticket.id,
          customerId: _ticket.customerId,
          customerName: _ticket.customerName,
          customerEmail: _ticket.customerEmail,
          customerPhone: _ticket.customerPhone,
          category: _ticket.category,
          subject: _ticket.subject,
          description: _ticket.description,
          attachments: _ticket.attachments,
          status: statut,
          resolution: resolution.isEmpty ? _ticket.resolution : resolution,
          messagesCount: _ticket.messagesCount,
          messages: _ticket.messages,
          createdAt: _ticket.createdAt,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final peutEcrire = context.watch<AdminAuthService>().can('support.write');
    final occupe = context.watch<SupportClientService>().enCours(widget.ticketId);

    return AlertDialog(
      title: Text(_ticket.subject),
      content: SizedBox(
        width: 600,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _Pastille(eccore.StatutSupport.ticket(_ticket.status), ouverte: _ticket.enSouffrance),
                Text(_ticket.customerName, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(_ticket.customerEmail, style: TextStyle(color: theme.hintColor)),
                if (_ticket.customerPhone != null && _ticket.customerPhone!.isNotEmpty)
                  NumeroCopiable(numero: _ticket.customerPhone!),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  _Bulle(
                    auteur: _ticket.customerName,
                    texte: _ticket.description,
                    date: _ticket.createdAt,
                    duPersonnel: false,
                  ),
                  if (!_filCharge) const LinearProgressIndicator(),
                  for (final message in _ticket.messages)
                    _Bulle(
                      auteur: message.author.fullName,
                      texte: message.content,
                      date: message.createdAt,
                      duPersonnel: message.author.userType == 'staff',
                    ),
                  if (_ticket.resolution.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Résolution : ${_ticket.resolution}',
                        style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                      ),
                    ),
                ],
              ),
            ),
            if (_refus != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_refus!, style: TextStyle(color: theme.colorScheme.error)),
              ),
            if (peutEcrire) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _reponse,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Répondre au client…',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Envoyer — le client est prévenu',
                    onPressed: occupe ? null : () => unawaited(_envoyer()),
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (peutEcrire && _ticket.enSouffrance) ...[
          TextButton(
            onPressed: occupe ? null : () => unawaited(_statut('closed')),
            child: const Text('Fermer sans suite'),
          ),
          FilledButton.tonal(
            onPressed: occupe ? null : () => unawaited(_statut('resolved', demanderResolution: true)),
            child: const Text('Résoudre…'),
          ),
        ],
        if (peutEcrire && !_ticket.enSouffrance)
          TextButton(
            onPressed: occupe ? null : () => unawaited(_statut('open')),
            child: const Text('Rouvrir'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer la fenêtre'),
        ),
      ],
    );
  }
}

class _Bulle extends StatelessWidget {
  const _Bulle({
    required this.auteur,
    required this.texte,
    required this.date,
    required this.duPersonnel,
  });

  final String auteur;
  final String texte;
  final DateTime date;
  final bool duPersonnel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: duPersonnel ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: duPersonnel ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$auteur · ${dateCourte(date)}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 4),
            Text(texte),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------- réclamations

class _CarteReclamation extends StatelessWidget {
  const _CarteReclamation({required this.reclamation});

  final eccore.ManagedComplaint reclamation;

  Future<void> _statuer(BuildContext context, String statut) async {
    final service = context.read<SupportClientService>();
    final messager = ScaffoldMessenger.of(context);
    var resolution = '';
    if (statut != 'under_review') {
      final saisie = await demanderTexte(
        context,
        titre: statut == 'resolved' ? 'Résoudre la réclamation' : 'Rejeter la réclamation',
        explication: 'Le client lira cette réponse. Une réclamation close ne se rejuge plus.',
        libelle: 'Réponse au client',
        action: statut == 'resolved' ? 'Résoudre' : 'Rejeter',
        destructif: statut == 'rejected',
      );
      if (saisie == null) return;
      resolution = saisie;
    }
    final refus = await service.statuerReclamation(reclamation.id, statut, resolution: resolution);
    messager.showSnackBar(SnackBar(content: Text(refus ?? 'Réclamation mise à jour.')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final peutEcrire = context.watch<AdminAuthService>().can('support.write');
    final occupe = context.watch<SupportClientService>().enCours(reclamation.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    reclamation.subject,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                _Pastille(
                  eccore.StatutSupport.reclamation(reclamation.status),
                  ouverte: !reclamation.close,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 12,
              children: [
                Text('Commande ${reclamation.orderReference}'),
                Text(reclamation.customerName),
                if (reclamation.customerPhone != null && reclamation.customerPhone!.isNotEmpty)
                  NumeroCopiable(numero: reclamation.customerPhone!),
                Text(reclamation.restaurantName, style: TextStyle(color: theme.hintColor)),
                Text(dateCourte(reclamation.createdAt), style: TextStyle(color: theme.hintColor)),
              ],
            ),
            const SizedBox(height: 8),
            Text(reclamation.description),
            if (reclamation.resolution.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Réponse : ${reclamation.resolution}', style: theme.textTheme.bodySmall),
            ],
            if (peutEcrire && !reclamation.close) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  if (reclamation.status == 'pending')
                    OutlinedButton(
                      onPressed: occupe ? null : () => unawaited(_statuer(context, 'under_review')),
                      child: const Text('Prendre en examen'),
                    ),
                  FilledButton(
                    onPressed: occupe ? null : () => unawaited(_statuer(context, 'resolved')),
                    child: const Text('Résoudre…'),
                  ),
                  TextButton(
                    onPressed: occupe ? null : () => unawaited(_statuer(context, 'rejected')),
                    child: const Text('Rejeter…'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- retours

class _CarteRetour extends StatelessWidget {
  const _CarteRetour({required this.retour});

  final eccore.ManagedReturn retour;

  static const _libelleGeste = {
    'approved': 'Approuver',
    'rejected': 'Refuser…',
    'refunded': 'Marquer remboursé',
  };

  Future<void> _statuer(BuildContext context, String statut) async {
    final service = context.read<SupportClientService>();
    final messager = ScaffoldMessenger.of(context);
    var resolution = '';
    if (statut == 'rejected') {
      final saisie = await demanderTexte(
        context,
        titre: 'Refuser le retour',
        explication: 'Le client lira ce motif. Un retour refusé ne se rembourse plus ensuite.',
        libelle: 'Motif',
        action: 'Refuser',
        destructif: true,
      );
      if (saisie == null) return;
      resolution = saisie;
    }
    final refus = await service.statuerRetour(retour.id, statut, resolution: resolution);
    messager.showSnackBar(SnackBar(content: Text(refus ?? 'Retour mis à jour.')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final peutEcrire = context.watch<AdminAuthService>().can('support.write');
    final occupe = context.watch<SupportClientService>().enCours(retour.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${retour.refundAmount.format()} demandés sur ${retour.orderTotal.format()}',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                _Pastille(
                  eccore.StatutSupport.retour(retour.status),
                  ouverte: retour.decisionsPossibles.isNotEmpty,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 12,
              children: [
                Text('Commande ${retour.orderReference}'),
                Text(retour.customerName),
                Text(retour.restaurantName, style: TextStyle(color: theme.hintColor)),
                Text(dateCourte(retour.createdAt), style: TextStyle(color: theme.hintColor)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Articles : ${retour.items.join(', ')}'),
            Text('Motif : ${retour.reason}'),
            if (retour.resolution.isNotEmpty)
              Text('Réponse : ${retour.resolution}', style: theme.textTheme.bodySmall),
            if (retour.status == 'approved')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Approuvé : le remboursement se fait depuis la commande, puis se constate dans '
                  '« Remboursements ». « Marquer remboursé » ne verse rien.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                ),
              ),
            if (peutEcrire && retour.decisionsPossibles.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final decision in retour.decisionsPossibles)
                    decision == 'rejected'
                        ? TextButton(
                            onPressed: occupe ? null : () => unawaited(_statuer(context, decision)),
                            child: Text(_libelleGeste[decision] ?? decision),
                          )
                        : FilledButton.tonal(
                            onPressed: occupe ? null : () => unawaited(_statuer(context, decision)),
                            child: Text(_libelleGeste[decision] ?? decision),
                          ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

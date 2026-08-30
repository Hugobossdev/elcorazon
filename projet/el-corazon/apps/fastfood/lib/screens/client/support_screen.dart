import 'package:elcorazon_core/elcorazon_core.dart' show SupportTicket;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elcora_fast/services/support_service.dart';
import 'package:elcora_fast/services/design_enhancement_service.dart';
import 'package:elcora_fast/theme.dart';
import 'package:elcora_fast/utils/design_constants.dart';
import 'package:elcora_fast/widgets/design/design.dart';
import 'package:elcora_fast/widgets/loading_widget.dart' as etats;

/// Centre d'aide — sujets, FAQ, et demandes au support.
///
/// ## Ce que la maquette demande
///
/// `help_center` pose quatre tuiles de sujets, un bloc « Contact Us » et une
/// FAQ en accordéon. Les tuiles ne sont pas décoratives : chacune correspond à
/// une **catégorie de ticket** que le serveur accepte (`order`, `payment`,
/// `delivery`, `account`), et les toucher ouvre la demande déjà classée.
///
/// La FAQ est du contenu **statique configuré** — explicitement autorisé : ce
/// sont des réponses éditoriales, pas des données de compte.
///
/// « Chat with Support » ouvre un vrai ticket (`POST /support/tickets/`), pas
/// une messagerie fictive : le fil de messages existe côté serveur et le
/// personnel y répond.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // L'écran n'avait jamais déclenché de chargement : la liste des tickets
    // était donc vide en permanence, quel que soit le backend.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SupportService>().loadTickets();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Ouvre la feuille de demande, éventuellement déjà classée.
  void _ouvrirLaDemande({String categorie = 'other'}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DesignConstants.radiusXLarge),
        ),
      ),
      builder: (_) => _FeuilleDeDemande(
        categorieInitiale: categorie,
        service: context.read<SupportService>(),
        onEnvoye: () => _tabController.animateTo(1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: GlassAppBar(
        title: 'Aide',
        bottom: SegmentedTabs(
          controller: _tabController,
          labels: const ['Centre d’aide', 'Mes demandes'],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _CentreDAide(onSujet: _ouvrirLaDemande),
          _MesDemandes(onNouvelle: _ouvrirLaDemande),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ centre d'aide

/// Les quatre sujets de la maquette, chacun rattaché à une catégorie que le
/// serveur accepte — une valeur inventée serait refusée en 400.
const _sujets = <({String categorie, String titre, String texte, IconData icone})>[
  (
    categorie: 'order',
    titre: 'Ma commande',
    texte: 'Article manquant, erreur de préparation, annulation',
    icone: Icons.shopping_bag_outlined,
  ),
  (
    categorie: 'payment',
    titre: 'Paiement et remboursement',
    texte: 'Débit inattendu, paiement refusé, remboursement',
    icone: Icons.credit_card_outlined,
  ),
  (
    categorie: 'delivery',
    titre: 'Livraison',
    texte: 'Retard, adresse, livreur injoignable',
    icone: Icons.two_wheeler_rounded,
  ),
  (
    categorie: 'account',
    titre: 'Mon compte',
    texte: 'Connexion, coordonnées, suppression du compte',
    icone: Icons.manage_accounts_outlined,
  ),
];

/// Réponses éditoriales, sans donnée de compte.
const _faq = <({String question, String reponse})>[
  (
    question: 'Comment suivre ma commande ?',
    reponse: 'Ouvrez l’onglet « Commandes », puis votre commande en cours. '
        'La carte affiche la position du livreur dès qu’il a récupéré votre '
        'repas, et l’heure d’arrivée estimée se met à jour toute seule.',
  ),
  (
    question: 'Ma commande est incomplète ou incorrecte. Que faire ?',
    reponse: 'Ouvrez une demande dans la catégorie « Ma commande » en '
        'précisant le numéro de commande. Le service client revient vers vous '
        'dans le fil de la demande.',
  ),
  (
    question: 'Comment modifier mon adresse de livraison ?',
    reponse: 'Vos adresses se gèrent depuis le profil, section « Adresses ». '
        'Pour une commande déjà partie, ouvrez une demande « Livraison » : '
        'l’adresse ne peut plus être changée depuis l’application une fois le '
        'livreur en route.',
  ),
  (
    question: 'Quand mes points de fidélité sont-ils crédités ?',
    reponse: 'À la **livraison** de la commande, pas à sa création. Ils '
        'apparaissent alors dans le relevé de l’écran « Récompenses ».',
  ),
  (
    question: 'Puis-je annuler une commande ?',
    reponse: 'Tant que la cuisine ne l’a pas prise en charge. Passé ce stade, '
        'ouvrez une demande : l’annulation dépend de l’avancement de la '
        'préparation.',
  ),
];

class _CentreDAide extends StatelessWidget {
  const _CentreDAide({required this.onSujet});

  final void Function({String categorie}) onSujet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        DesignConstants.edgeMargin,
        DesignConstants.spacingM,
        DesignConstants.edgeMargin,
        DesignConstants.spacingXL,
      ),
      children: [
        const SectionHeader(title: 'Sur quoi porte votre demande ?'),
        const SizedBox(height: DesignConstants.spacingS),
        for (final sujet in _sujets) ...[
          SectionCard(
            margin: const EdgeInsets.only(bottom: DesignConstants.spacingS),
            onTap: () => onSujet(categorie: sujet.categorie),
            child: Row(
              children: [
                Container(
                  width: DesignConstants.avatarSizeMedium,
                  height: DesignConstants.avatarSizeMedium,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: DesignConstants.borderRadiusMedium,
                  ),
                  child: Icon(
                    sujet.icone,
                    color: theme.colorScheme.primary,
                    size: DesignConstants.iconSizeMedium,
                  ),
                ),
                const SizedBox(width: DesignConstants.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sujet.titre,
                        style: AppTypography.titleLg(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sujet.texte,
                        style: AppTypography.bodyMd(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: DesignConstants.spacingM),
        SectionCard(
          color: theme.colorScheme.primaryContainer,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Besoin de nous parler ?',
                style: AppTypography.titleLg(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: DesignConstants.spacingXS),
              Text(
                'Ouvrez une demande : elle est suivie par le service client, '
                'et vous recevez la réponse dans l’application.',
                style: AppTypography.bodyMd(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: DesignConstants.spacingM),
              ActionButton(
                label: 'Ouvrir une demande',
                icon: Icons.chat_bubble_outline_rounded,
                backgroundColor: theme.colorScheme.onPrimaryContainer,
                foregroundColor: theme.colorScheme.primaryContainer,
                onPressed: onSujet,
              ),
            ],
          ),
        ),
        const SizedBox(height: DesignConstants.spacingL),
        const SectionHeader(title: 'Questions fréquentes'),
        const SizedBox(height: DesignConstants.spacingS),
        SectionCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < _faq.length; i++)
                Theme(
                  // `ExpansionTile` dessine ses propres séparateurs : ils
                  // doublonneraient avec ceux de la carte.
                  data: theme.copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: DesignConstants.spacingM,
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(
                      DesignConstants.spacingM,
                      0,
                      DesignConstants.spacingM,
                      DesignConstants.spacingM,
                    ),
                    title: Text(
                      _faq[i].question,
                      style: AppTypography.titleLg(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _faq[i].reponse.replaceAll('**', ''),
                          style: AppTypography.bodyLg(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ mes demandes

class _MesDemandes extends StatelessWidget {
  const _MesDemandes({required this.onNouvelle});

  final void Function({String categorie}) onNouvelle;

  @override
  Widget build(BuildContext context) {
    return Consumer<SupportService>(
      builder: (context, service, child) {
        if (service.isLoading) {
          return const etats.PageLoadingWidget(
            message: 'Chargement de vos demandes…',
          );
        }

        final tickets = service.tickets;

        if (tickets.isEmpty) {
          // Une liste vide et un chargement en échec ne disent pas la même
          // chose au client — l'ancienne version confondait les deux.
          final erreur = service.error;
          if (erreur != null) {
            return etats.ErrorWidget(
              message: erreur,
              onRetry: service.loadTickets,
            );
          }
          return etats.EmptyStateWidget(
            title: 'Aucune demande',
            message: 'Vos échanges avec le service client apparaîtront ici.',
            icon: Icons.inbox_outlined,
            actionText: 'Ouvrir une demande',
            onAction: onNouvelle,
          );
        }

        return RefreshIndicator(
          onRefresh: service.loadTickets,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              DesignConstants.edgeMargin,
              DesignConstants.spacingM,
              DesignConstants.edgeMargin,
              DesignConstants.spacingXL,
            ),
            itemCount: tickets.length,
            itemBuilder: (context, index) => _carte(context, tickets[index]),
          ),
        );
      },
    );
  }

  Widget _carte(BuildContext context, SupportTicket ticket) {
    final theme = Theme.of(context);
    final etat = _EtatDeTicket.pour(ticket.status, theme);

    return SectionCard(
      margin: const EdgeInsets.only(bottom: DesignConstants.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: DesignConstants.avatarSizeMedium,
                height: DesignConstants.avatarSizeMedium,
                decoration: BoxDecoration(
                  color: etat.fond,
                  borderRadius: DesignConstants.borderRadiusMedium,
                ),
                child: Icon(
                  etat.icone,
                  color: etat.encre,
                  size: DesignConstants.iconSizeMedium,
                ),
              ),
              const SizedBox(width: DesignConstants.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.subject,
                      style: AppTypography.titleLg(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _categoryLabels[ticket.category] ?? ticket.category,
                      style: AppTypography.bodyMd(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignConstants.spacingM),
          Row(
            children: [
              // Le statut était affiché brut, en majuscules : « IN_PROGRESS »
              // au client. Il porte maintenant son mot.
              StatusChip(
                label: etat.libelle,
                background: etat.fond,
                foreground: etat.encre,
              ),
              const Spacer(),
              Text(
                _anciennete(ticket.createdAt),
                style: AppTypography.bodyMd(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// « il y a 3 jours » — et non « Il y a 0 jours » le jour même, ce que
  /// faisait la soustraction en jours entiers.
  String _anciennete(DateTime date) {
    final ecart = DateTime.now().difference(date);
    if (ecart.inMinutes < 60) return 'à l’instant';
    if (ecart.inHours < 24) return 'il y a ${ecart.inHours} h';
    if (ecart.inDays == 1) return 'hier';
    if (ecart.inDays < 30) return 'il y a ${ecart.inDays} jours';
    final j = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$j/$m/${date.year}';
  }
}

/// Libellés des valeurs de `TicketCategory` servies par l'API.
const Map<String, String> _categoryLabels = {
  'order': 'Commande',
  'payment': 'Paiement',
  'delivery': 'Livraison',
  'account': 'Compte',
  'other': 'Autre',
};

/// L'apparence d'un statut de ticket, prise aux rôles du thème.
class _EtatDeTicket {
  const _EtatDeTicket({
    required this.libelle,
    required this.icone,
    required this.fond,
    required this.encre,
  });

  final String libelle;
  final IconData icone;
  final Color fond;
  final Color encre;

  static _EtatDeTicket pour(String statut, ThemeData theme) {
    switch (statut) {
      case 'in_progress':
        return _EtatDeTicket(
          libelle: 'En cours de traitement',
          icone: Icons.hourglass_bottom_rounded,
          fond: theme.colorScheme.tertiaryContainer,
          encre: theme.colorScheme.onTertiaryContainer,
        );
      case 'resolved':
        return const _EtatDeTicket(
          libelle: 'Résolue',
          icone: Icons.task_alt_rounded,
          fond: AppColors.successLight,
          encre: AppColors.success,
        );
      case 'closed':
        return _EtatDeTicket(
          libelle: 'Close',
          icone: Icons.lock_outline_rounded,
          fond: theme.colorScheme.surfaceContainerHighest,
          encre: theme.colorScheme.onSurfaceVariant,
        );
      case 'open':
      default:
        return _EtatDeTicket(
          libelle: 'Ouverte',
          icone: Icons.mark_email_unread_outlined,
          fond: theme.colorScheme.secondaryContainer,
          encre: theme.colorScheme.onSecondaryContainer,
        );
    }
  }
}

// -------------------------------------------------------- feuille de demande

/// Le formulaire de demande, en feuille plutôt qu'en onglet.
///
/// L'onglet « Nouveau ticket » restait offert en permanence, à côté d'une
/// liste qu'on venait consulter. La feuille s'ouvre quand on a choisi un
/// sujet — et arrive alors **déjà classée**, ce qui retire une décision au
/// client au moment où il a un problème.
class _FeuilleDeDemande extends StatefulWidget {
  const _FeuilleDeDemande({
    required this.categorieInitiale,
    required this.service,
    required this.onEnvoye,
  });

  final String categorieInitiale;
  final SupportService service;
  final VoidCallback onEnvoye;

  @override
  State<_FeuilleDeDemande> createState() => _FeuilleDeDemandeState();
}

class _FeuilleDeDemandeState extends State<_FeuilleDeDemande> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  late String _categorie;
  bool _envoiEnCours = false;

  @override
  void initState() {
    super.initState();
    _categorie = _categoryLabels.containsKey(widget.categorieInitiale)
        ? widget.categorieInitiale
        : 'other';
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    if (!_formKey.currentState!.validate() || _envoiEnCours) return;

    setState(() => _envoiEnCours = true);

    // Plus de garde « connecté ? » ici : la requête part avec le jeton de
    // session, et c'est le serveur qui refuse (401) s'il n'y en a pas.
    final success = await widget.service.createTicket(
      category: _categorie,
      subject: _subjectController.text.trim(),
      description: _descriptionController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _envoiEnCours = false);

    if (success) {
      Navigator.of(context).pop();
      widget.onEnvoye();
      context.showSuccessMessage(
        'Demande envoyée. Le service client vous répond ici même.',
      );
    } else {
      context.showErrorMessage(
        widget.service.error ?? 'La demande n’a pas pu être envoyée.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: DesignConstants.edgeMargin,
        right: DesignConstants.edgeMargin,
        bottom: MediaQuery.viewInsetsOf(context).bottom +
            DesignConstants.spacingL,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Nouvelle demande',
                style: AppTypography.headlineSm(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: DesignConstants.spacingL),
              DropdownButtonFormField<String>(
                initialValue: _categorie,
                decoration: const InputDecoration(labelText: 'Catégorie'),
                // Valeurs de `TicketCategory` côté serveur, à la lettre : il
                // n'y a pas de catégorie « général », et une valeur inconnue
                // serait refusée en 400.
                items: [
                  for (final entree in _categoryLabels.entries)
                    DropdownMenuItem(
                      value: entree.key,
                      child: Text(entree.value),
                    ),
                ],
                onChanged: _envoiEnCours
                    ? null
                    : (value) => setState(() => _categorie = value ?? 'other'),
              ),
              const SizedBox(height: DesignConstants.spacingM),
              TextFormField(
                controller: _subjectController,
                enabled: !_envoiEnCours,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Sujet',
                  hintText: 'Résumez votre demande',
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Indiquez un sujet'
                    : null,
              ),
              const SizedBox(height: DesignConstants.spacingM),
              TextFormField(
                controller: _descriptionController,
                enabled: !_envoiEnCours,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Numéro de commande, date, ce qui s’est passé…',
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Décrivez votre demande'
                    : null,
              ),
              const SizedBox(height: DesignConstants.spacingL),
              ActionButton(
                label: 'Envoyer',
                emphasis: ActionEmphasis.gradient,
                icon: Icons.send_rounded,
                isLoading: _envoiEnCours,
                onPressed: _envoiEnCours ? null : _envoyer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

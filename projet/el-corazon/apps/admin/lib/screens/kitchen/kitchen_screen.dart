import 'dart:async';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/presentation/anciennete_commande.dart';
import 'package:admin/presentation/autorisations.dart';
import 'package:admin/presentation/messages_erreur.dart';
import 'package:admin/presentation/poste_de_cuisine.dart';
import 'package:admin/presentation/statut_commande.dart';
import 'package:admin/services/dashboard_realtime_service.dart';
import 'package:admin/services/menu_service.dart';
import 'package:admin/services/order_management_service.dart';

/// Le poste de cuisine — quatre colonnes, un seul écran.
///
/// ## Pourquoi cet écran existe
///
/// El Corazón est une cuisine en ligne, et la cuisine n'avait pas d'outil. Le
/// personnel faisait avancer les commandes depuis
/// `advanced_order_management_screen.dart` — mille sept cents lignes d'écran
/// d'administration, avec ses filtres, ses exports et ses statistiques. On y
/// pilote une flotte ; on n'y tient pas un coup de feu.
///
/// ## Ce qu'il n'ajoute pas
///
/// **Aucune route serveur.** Tout existait :
///
/// * `ws/restaurants/{id}/dashboard/` pour le temps réel, déjà consommé par
///   [DashboardRealtimeService], reconnexion comprise ;
/// * `POST /orders/manage/{id}/status/` pour faire avancer, déjà enveloppé par
///   [OrderManagementService] ;
/// * `Order.allowedTransitions`, que le serveur calcule — la machine à états
///   n'est pas rejouée ici ;
/// * `ancienneteCommande()` pour la durée d'attente, déjà extraite et testée.
///
/// Ce qui manquait était la **disposition** : voir les quatre files côte à
/// côte, et avancer sans quitter l'écran.
///
/// ## Le temps réel, et son filet
///
/// Le WebSocket porte les arrivées et les changements de statut. Il peut
/// tomber — un réseau de cuisine n'est pas un réseau de bureau — et
/// [DashboardRealtimeService] se reconnecte seul. À chaque reconnexion, l'écran
/// **relit** la liste : les événements manqués pendant la coupure ne se
/// rattrapent pas, et un poste qui afficherait un état figé sans le dire est
/// pire qu'un poste vide.
///
/// Un rafraîchissement périodique double le tout. Il est lent — la minute —
/// parce qu'il n'est pas le chemin nominal : c'est le filet du filet.
class KitchenScreen extends StatefulWidget {
  const KitchenScreen({required this.restaurant, super.key});

  /// L'établissement dont on tient le poste. Le KDS est mono-établissement :
  /// un cuisinier est dans **une** cuisine, et mêler deux cartes ferait
  /// préparer un plat pour l'autre bout de la ville.
  final eccore.ManagedRestaurant restaurant;

  @override
  State<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends State<KitchenScreen> {
  static const _cadenceDeSecours = Duration(minutes: 1);

  final List<StreamSubscription<void>> _abonnements = [];
  Timer? _filet;
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    unawaited(_demarrer());
  }

  @override
  void dispose() {
    for (final abonnement in _abonnements) {
      unawaited(abonnement.cancel());
    }
    _filet?.cancel();
    super.dispose();
  }

  Future<void> _demarrer() async {
    final temsReel = context.read<DashboardRealtimeService>();

    // Trois signaux, trois raisons de relire. Aucun ne porte la commande
    // complète : la charge d'un événement ne dit que ce qui a changé (ADR-008),
    // et l'écran a besoin des lignes et des options pour les afficher.
    _abonnements
      ..add(temsReel.arrivees.listen((_) => unawaited(_relire())))
      ..add(temsReel.changements.listen((_) => unawaited(_relire())))
      ..add(temsReel.reconnexions.listen((_) => unawaited(_relire())));

    _filet = Timer.periodic(_cadenceDeSecours, (_) => unawaited(_relire()));

    await temsReel.connect();
    await _relire();
  }

  /// Relit **la file de cette cuisine**, et elle seule.
  ///
  /// ## Ce que cela remplace
  ///
  /// `refresh()` rechargeait la fenêtre agrégée de la supervision : un an de
  /// commandes, toutes cuisines confondues, page après page — à chaque
  /// événement du service. Un coup de feu à dix commandes déclenchait dix
  /// téléchargements d'historique, pour n'en afficher qu'une de plus.
  ///
  /// L'erreur remonte désormais du service, qui garde la file précédente à
  /// l'écran : en plein service, un poste qui se vide sur une coupure de trois
  /// secondes est pire qu'un poste périmé qui le dit.
  Future<void> _relire() async {
    if (!mounted) return;
    final service = context.read<OrderManagementService>();
    await service.chargerLePoste(widget.restaurant.slug);
    if (mounted) {
      setState(() {
        _erreur = service.erreurPoste;
        _chargement = false;
      });
    }
  }

  Future<void> _avancer(CommandeEnCuisine commande, StatutCommande cible) async {
    final service = context.read<OrderManagementService>();
    final messager = ScaffoldMessenger.of(context);

    final couleurErreur = Theme.of(context).colorScheme.error;
    try {
      await service.updateOrderStatus(commande.commande.id, cible);
    } catch (erreur) {
      if (!mounted) return;
      // **Le motif du serveur**, et non « n'a pas pu passer en Prête » : un 403
      // sans `orders.update_status`, un 409 « cette commande est déjà partie »
      // et une coupure réseau n'appellent pas le même geste, et l'écran les
      // rendait sous une seule phrase qui n'en indiquait aucun.
      messager.showSnackBar(
        SnackBar(
          content: Text('${commande.reference} : ${messageErreur(erreur)}'),
          backgroundColor: couleurErreur,
          duration: const Duration(seconds: 5),
        ),
      );
    }
    if (!mounted) return;
    await _relire();
  }

  /// La rupture, depuis la cuisine.
  ///
  /// C'est elle qui sait qu'il n'y a plus de poulet, et elle le sait avant tout
  /// le monde. L'obliger à passer par l'écran de gestion du menu — ses
  /// catégories, ses prix, ses photos — pour décocher une case fait qu'elle ne
  /// le fait pas, et que le client commande un plat qui n'existe plus.
  Future<void> _ouvrirLesRuptures() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FeuilleDesRuptures(restaurantSlug: widget.restaurant.slug),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = context.watch<OrderManagementService>();
    final temsReel = context.watch<DashboardRealtimeService>();

    final poste = composerLePoste(
      service.poste,
      minutesDePreparation: widget.restaurant.defaultPreparationMinutes,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Cuisine — ${widget.restaurant.name}'),
        actions: [
          _VoyantDeLiaison(etat: temsReel.etat),
          IconButton(
            tooltip: 'Ruptures — retirer un article de la carte',
            onPressed: () => unawaited(_ouvrirLesRuptures()),
            icon: const Icon(Icons.remove_shopping_cart_outlined),
          ),
          IconButton(
            tooltip: 'Actualiser',
            onPressed: () => unawaited(_relire()),
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_erreur != null)
                  MaterialBanner(
                    backgroundColor: theme.colorScheme.errorContainer,
                    content: Text('Liste non rafraîchie : ${_erreur!}'),
                    actions: [
                      TextButton(
                        onPressed: () => unawaited(_relire()),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, contraintes) {
                      // Sous 900 px, quatre colonnes donnent des cartes
                      // illisibles. Le poste défile alors horizontalement, à
                      // largeur de colonne fixe : un cuisinier balaie du doigt,
                      // il ne pince pas pour zoomer.
                      final etroit = contraintes.maxWidth < 900;
                      final colonnes = [
                        for (final colonne in ColonneCuisine.values)
                          _Colonne(
                            colonne: colonne,
                            commandes: poste[colonne] ?? const [],
                            onAvancer: _avancer,
                          ),
                      ];

                      if (!etroit) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [for (final c in colonnes) Expanded(child: c)],
                        );
                      }
                      return ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final c in colonnes) SizedBox(width: 320, child: c),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

/// L'état de la liaison temps réel, en un point de couleur.
///
/// Un poste qui a perdu le fil doit le dire. Sans ce voyant, une coupure se
/// traduit par un écran qui ne bouge plus — indiscernable d'un service calme.
class _VoyantDeLiaison extends StatelessWidget {
  const _VoyantDeLiaison({required this.etat});

  final EtatTempsReel etat;

  @override
  Widget build(BuildContext context) {
    final (couleur, texte) = switch (etat) {
      EtatTempsReel.connecte => (Colors.green, 'En direct'),
      EtatTempsReel.connexion => (Colors.orange, 'Connexion…'),
      // Refusé : la permission `orders.read` manque, ou l'établissement est
      // hors périmètre. Réessayer n'y changera rien — le poste continue de
      // fonctionner par le rafraîchissement, et le dit.
      EtatTempsReel.refuse => (Colors.red, 'Accès refusé'),
      EtatTempsReel.ferme => (Colors.grey, 'Hors ligne'),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(Icons.circle, size: 10, color: couleur),
          const SizedBox(width: 6),
          Text(texte, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _Colonne extends StatelessWidget {
  const _Colonne({
    required this.colonne,
    required this.commandes,
    required this.onAvancer,
  });

  final ColonneCuisine colonne;
  final List<CommandeEnCuisine> commandes;
  final Future<void> Function(CommandeEnCuisine, StatutCommande) onAvancer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enRetard = commandes.where((c) => c.enRetard).length;

    return Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(colonne.icone, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    colonne.titre,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                _Pastille(nombre: commandes.length),
                if (enRetard > 0) ...[
                  const SizedBox(width: 6),
                  _Pastille(nombre: enRetard, alerte: true),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: commandes.isEmpty
                ? Center(
                    child: Text(
                      'Rien ici',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: commandes.length,
                    itemBuilder: (context, i) => _CarteCommande(
                      commande: commandes[i],
                      onAvancer: onAvancer,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Pastille extends StatelessWidget {
  const _Pastille({required this.nombre, this.alerte = false});

  final int nombre;
  final bool alerte;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fond = alerte ? theme.colorScheme.error : theme.colorScheme.secondaryContainer;
    final encre = alerte ? theme.colorScheme.onError : theme.colorScheme.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: fond, borderRadius: BorderRadius.circular(10)),
      child: Text(
        '$nombre',
        style: theme.textTheme.labelSmall?.copyWith(color: encre, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// Une commande, telle qu'un cuisinier a besoin de la lire.
///
/// L'ordre des informations suit celui du geste : la référence pour l'appeler,
/// l'attente pour savoir si elle presse, les articles pour la préparer, les
/// consignes pour ne pas se tromper, l'action pour la faire avancer.
class _CarteCommande extends StatelessWidget {
  const _CarteCommande({required this.commande, required this.onAvancer});

  final CommandeEnCuisine commande;
  final Future<void> Function(CommandeEnCuisine, StatutCommande) onAvancer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Le poste s'ouvre avec `orders.read` ; faire avancer une commande exige
    // `orders.update_status`, comme dans l'écran des commandes. Sans ce droit,
    // le bouton partait et revenait en 403 au milieu du coup de feu : la carte
    // se lit, elle ne s'avance pas.
    final suivante = context.peut('orders.update_status') ? commande.etapeSuivante : null;
    final commandeSocle = commande.commande;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: commande.enRetard ? theme.colorScheme.errorContainer.withValues(alpha: 0.35) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: commande.enRetard
            ? BorderSide(color: theme.colorScheme.error, width: 1.5)
            : BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    commande.reference,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (commande.enRetard)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: theme.colorScheme.error,
                    ),
                  ),
                Text(
                  // Deux durées, deux questions : « depuis combien de temps
                  // elle attend » et « à quel moment du service elle est
                  // tombée ». Un cuisinier qui reprend un poste a besoin de la
                  // seconde.
                  '${ancienneteCommande(commandeSocle.placedAt)} · '
                  '${heureCommande(commandeSocle.placedAt)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: commande.enRetard ? theme.colorScheme.error : theme.hintColor,
                    fontWeight: commande.enRetard ? FontWeight.bold : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Les plats, leurs options et les remarques du client. La forme de
            // cuisine les porte toujours ; le repli sur « 3 article(s) » n'a
            // plus lieu d'être — c'était tout ce que le poste savait dire.
            for (final ligne in commandeSocle.lines) _Ligne(ligne: ligne),
            if (commandeSocle.lines.isEmpty)
              Text(
                '${commandeSocle.itemsCount} article(s)',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
              ),

            if (commandeSocle.deliveryInstructions.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.sticky_note_2_outlined, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      commandeSocle.deliveryInstructions,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ],

            if (suivante != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => unawaited(onAvancer(commande, suivante)),
                  child: Text(suivante.libelle),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({required this.ligne});

  final eccore.KitchenLine ligne;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // La quantité d'abord, en gras : c'est le nombre qu'on lit en
              // premier quand on assemble un sac.
              Text(
                '${ligne.quantity}×',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 6),
              Expanded(child: Text(ligne.itemName, style: theme.textTheme.bodyMedium)),
            ],
          ),
          // Les options décident du contenu de l'assiette : les taire ferait
          // préparer le mauvais plat.
          if (ligne.options.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: Text(
                ligne.options.join(' · '),
                style: theme.textTheme.labelSmall?.copyWith(color: theme.hintColor),
              ),
            ),
          if (ligne.notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: Text(
                ligne.notes,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.tertiary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}


/// La carte, réduite à ce qu'un cuisinier en fait : disponible, ou non.
///
/// Ni prix, ni photo, ni description — l'écran de gestion du menu s'en charge.
/// Ce qui est ici est le seul geste qui se décide **pendant** le service.
class _FeuilleDesRuptures extends StatefulWidget {
  const _FeuilleDesRuptures({required this.restaurantSlug});

  final String restaurantSlug;

  @override
  State<_FeuilleDesRuptures> createState() => _FeuilleDesRupturesState();
}

class _FeuilleDesRupturesState extends State<_FeuilleDesRuptures> {
  List<eccore.ManagedMenuItem>? _articles;
  String? _erreur;
  final Set<String> _enCours = {};

  @override
  void initState() {
    super.initState();
    unawaited(_charger());
  }

  Future<void> _charger() async {
    try {
      // `null` : toutes les catégories. Un cuisinier cherche un plat, pas une
      // arborescence.
      final articles = await context.read<MenuService>().getMenuItems(null, notify: false);
      if (mounted) setState(() => _articles = articles);
    } catch (erreur) {
      if (mounted) setState(() => _erreur = '$erreur');
    }
  }

  Future<void> _basculer(eccore.ManagedMenuItem article, bool disponible) async {
    setState(() => _enCours.add(article.id));
    final ok = await context.read<MenuService>().basculerDisponibilite(
      menuItemId: article.id,
      disponible: disponible,
    );
    if (!mounted) return;
    setState(() => _enCours.remove(article.id));

    if (ok) {
      // Relu plutôt que supposé : c'est le serveur qui décide, et un
      // interrupteur qui bouge tout seul sur un refus ferait croire à une
      // rupture déclarée.
      await _charger();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La carte n’a pas pu être modifiée.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final articles = _articles;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.remove_shopping_cart_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Ruptures', style: theme.textTheme.titleMedium),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: switch ((articles, _erreur)) {
                (_, final String erreur) => Center(child: Text('Carte illisible : $erreur')),
                (null, _) => const Center(child: CircularProgressIndicator()),
                (final List<eccore.ManagedMenuItem> liste, _) when liste.isEmpty =>
                  const Center(child: Text('Aucun article à la carte.')),
                (final List<eccore.ManagedMenuItem> liste, _) => ListView.builder(
                  itemCount: liste.length,
                  itemBuilder: (context, i) {
                    final article = liste[i];
                    return SwitchListTile(
                      title: Text(article.name),
                      subtitle: Text(article.isAvailable ? 'À la carte' : 'En rupture'),
                      value: article.isAvailable,
                      onChanged: _enCours.contains(article.id)
                          ? null
                          : (valeur) => unawaited(_basculer(article, valeur)),
                    );
                  },
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}


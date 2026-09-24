import 'package:flutter/material.dart';

import 'package:admin/presentation/commande.dart';
import 'package:admin/presentation/echec.dart';
import 'package:admin/presentation/statut_livreur.dart';
import 'package:admin/services/driver_management_service.dart';
import 'package:admin/services/order_management_service.dart';
import 'package:admin/utils/dialog_helper.dart';
import 'package:admin/utils/price_formatter.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

/// Le choix d'un livreur pour une commande.
///
/// Pourquoi ce fichier existe
/// --------------------------
///
/// Ces 520 lignes vivaient dans `advanced_order_management_screen.dart`, tenues
/// par un `StatefulBuilder` imbriqué à sept niveaux du `build` de l'écran. Un
/// dialogue est une vue à part entière : il a son propre état — le livreur
/// mis en évidence — et sa propre fin. Le sortir le rend nommable, donc
/// racontable.
///
/// Il existait un **second** dialogue d'assignation, dans
/// `active_deliveries_screen.dart` ; les deux écrans appellent celui-ci. La
/// divergence qui les séparait est tranchée, et pas en faveur de ce fichier :
/// `picked_up` appartient au livreur, et l'écrire ici rendait la commande
/// inannulable pendant que le repas était encore en cuisine (voir `_assigner`).
///
/// Ce que l'éligibilité n'est plus (23 septembre 2026)
/// --------------------------------------------------
///
/// Le dialogue lisait la flotte déjà chargée par `DriverManagementService` et
/// la filtrait ici : en ligne, dossier validé, pas déjà engagé. Trois termes
/// sur cinq. Il manquait le **périmètre de zone** — un livreur restreint aux
/// zones de Kara était proposé pour une commande de Lomé — et la **cuisine** :
/// la liste chargée est celle du périmètre du compte, pas celle de la commande,
/// si bien qu'un siège se voyait proposer Douala pour une commande de Lomé.
/// Le serveur refusait ensuite en 409, après le geste.
///
/// `GET /delivery/couriers/available/{commande}/` applique les cinq termes
/// (`CourierService.available_for`) et **trie par distance à la cuisine**, que
/// le back-office ne pouvait pas calculer : la position du livreur n'est pas
/// dans la liste de flotte, et la distance PostGIS encore moins. Le dialogue
/// demande cette liste, et n'en filtre rien.
Future<void> afficherAssignationLivreur({
  required BuildContext context,
  required eccore.Order order,
  required OrderManagementService orderService,
  required DriverManagementService driverService,
}) {
  return DialogHelper.showSafeDialog(
    context: context,
    builder: (context) => _ChoixDuLivreur(
      order: order,
      orderService: orderService,
      driverService: driverService,
    ),
  );
}

/// L'en-tête du dialogue : une icône, un titre, une croix.
class _EnTete extends StatelessWidget {
  const _EnTete({required this.titre, required this.fermable});

  final String titre;

  /// Faux pendant l'envoi : fermer ne rappellerait pas la proposition partie.
  final bool fermable;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(Icons.local_shipping, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              titre,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: IconButton(
              icon: const Icon(Icons.close),
              onPressed: fermable ? () => Navigator.of(context).pop() : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoixDuLivreur extends StatefulWidget {
  const _ChoixDuLivreur({
    required this.order,
    required this.orderService,
    required this.driverService,
  });

  final eccore.Order order;
  final OrderManagementService orderService;
  final DriverManagementService driverService;

  @override
  State<_ChoixDuLivreur> createState() => _ChoixDuLivreurState();
}

class _ChoixDuLivreurState extends State<_ChoixDuLivreur> {
  List<eccore.CourierProfile>? _eligibles;
  eccore.CourierProfile? _choisi;
  Echec? _echec;
  bool _chargement = true;
  bool _envoiEnCours = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  /// Relit les éligibles.
  ///
  /// [conserverEchec] est vrai après un refus d'affectation : la relecture
  /// réussit, mais le motif du refus doit rester à l'écran — c'est lui qui dit
  /// au superviseur pourquoi la liste vient de changer sous ses yeux.
  Future<void> _charger({bool conserverEchec = false}) async {
    setState(() {
      _chargement = true;
      if (!conserverEchec) _echec = null;
    });
    try {
      final eligibles = await widget.driverService.availableForOrder(widget.order.id);
      if (!mounted) return;
      setState(() {
        _eligibles = eligibles;
        // Le livreur mis en évidence peut avoir disparu de la liste entre deux
        // lectures — quelqu'un d'autre a pu lui confier une course.
        _choisi = eligibles.any((livreur) => livreur.id == _choisi?.id) ? _choisi : null;
      });
    } on eccore.ApiException catch (e) {
      // Un refus n'est pas une flotte vide : un 403 affichait « Aucun livreur
      // disponible », et le superviseur attendait un livreur qu'il n'aurait
      // jamais vu arriver.
      if (mounted) setState(() => _echec = Echec.de(e));
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ecran = MediaQuery.of(context).size;
    final echec = _echec;

    return PopScope(
      // Pendant l'envoi, la proposition est partie : la fermer laisserait
      // croire au superviseur qu'elle ne l'est pas.
      canPop: !_envoiEnCours,
      child: Dialog(
        child: SizedBox(
          width: (ecran.width * 0.9).clamp(500.0, 800.0),
          height: (ecran.height * 0.7).clamp(500.0, 800.0),
          child: Column(
            children: [
              _EnTete(titre: 'Assigner un livreur', fermable: !_envoiEnCours),
              const Divider(height: 1),
              if (echec != null)
                BandeauEchec(echec: echec, onReessayer: _chargement ? null : _charger),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RappelCommande(order: widget.order),
                      const SizedBox(height: 16),
                      Expanded(child: _corps()),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              _PiedDeDialogue(
                envoiEnCours: _envoiEnCours,
                onAssigner: _choisi == null || _envoiEnCours ? null : _assigner,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _corps() {
    final eligibles = _eligibles;
    if (_chargement) return const Center(child: CircularProgressIndicator());
    // Rien à lister quand la lecture a échoué : le bandeau dit déjà pourquoi,
    // et une liste vide ajouterait un second message, faux.
    if (eligibles == null) return const SizedBox.shrink();
    if (eligibles.isEmpty) return const _AucunEligible();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eligibles.length == 1
              ? 'Un livreur éligible, du plus proche de la cuisine :'
              : '${eligibles.length} livreurs éligibles, du plus proche de la cuisine :',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: eligibles.length,
            itemBuilder: (context, index) {
              final livreur = eligibles[index];
              return _CarteLivreur(
                livreur: livreur,
                estChoisi: _choisi?.id == livreur.id,
                onTap: _envoiEnCours ? null : () => setState(() => _choisi = livreur),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _assigner() async {
    final livreur = _choisi!;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() {
      _envoiEnCours = true;
      _echec = null;
    });

    try {
      await widget.orderService.assignDriver(widget.order.id, livreur.id);
    } on eccore.ApiException catch (e) {
      // Le dialogue **reste ouvert**. Il se fermait avant la réponse, et le
      // refus s'affichait dans un bandeau sur l'écran d'en dessous : le
      // superviseur avait perdu sa liste, et devait tout rouvrir pour choisir
      // quelqu'un d'autre. Un 409 — « ce livreur porte déjà une course » — est
      // précisément le cas où il faut en choisir un autre, tout de suite.
      if (!mounted) return;
      setState(() {
        _envoiEnCours = false;
        _echec = Echec.de(e);
      });
      // La liste date d'avant le refus ; la relire évite de reproposer
      // quelqu'un que le serveur vient d'écarter.
      if (e.status == 409) await _charger(conserverEchec: true);
      return;
    }

    // La commande n'est **pas** marquée « récupérée » ici.
    //
    // Elle l'était, et c'était faux : le livreur vient d'être choisi, il n'a
    // rien pris — souvent il n'est même pas encore au restaurant. Trois choses
    // en découlaient, toutes visibles par le client :
    //
    //   * le suivi affichait « récupérée » à l'heure du geste du superviseur,
    //     et la notification correspondante partait ;
    //   * `ORDER_TRANSITIONS[picked_up]` ne mène qu'à `on_the_way` : la commande
    //     devenait **inannulable** alors que le repas était encore en cuisine ;
    //   * quand le livreur marquait le vrai enlèvement, la projection constatait
    //     que la commande y était déjà et **retournait en silence** — l'étape
    //     réelle ne produisait plus aucun événement.
    //
    // `picked_up` appartient au livreur, et à lui seul :
    // `POST /delivery/assignments/{id}/status/`.
    navigator.pop();
    // « Proposée » et non « assignée » : le livreur accepte ou refuse, et
    // l'annonce ne doit pas laisser croire que la course est partie.
    messenger.showSnackBar(
      SnackBar(content: Text('Course proposée à ${livreur.fullName}')),
    );
  }
}

/// Ce que le serveur exige d'un livreur pour cette commande — affiché quand il
/// n'en trouve aucun.
///
/// L'ancien texte conseillait « d'assigner un livreur manuellement depuis la
/// liste des livreurs » : il n'existe aucun écran qui le permette, et aucune
/// route non plus. Un superviseur qui lit une liste vide a besoin de savoir
/// **quel terme** manque, parce que trois des cinq se corrigent depuis le
/// back-office.
class _AucunEligible extends StatelessWidget {
  const _AucunEligible();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_search_outlined, color: scheme.tertiary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Aucun livreur éligible pour cette commande',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Le serveur retient les livreurs qui remplissent les cinq conditions '
            'suivantes. Il en manque au moins une :',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          for (final critere in const [
            ('Rattaché à la cuisine de la commande', null),
            ('En ligne', 'le livreur bascule lui-même sa disponibilité depuis son application'),
            ('Dossier validé', 'écran Livreurs → Vérification'),
            (
              'Desservant la zone de livraison',
              'écran Livreurs → Zones ; un livreur sans zone roule partout où sa cuisine livre',
            ),
            (
              'Pas déjà en course',
              'une course acceptée ou en route occupe le livreur jusqu’à sa livraison',
            ),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: critere.$1,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          if (critere.$2 != null)
                            TextSpan(
                              text: ' — ${critere.$2}',
                              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RappelCommande extends StatelessWidget {
  const _RappelCommande({required this.order});

  final eccore.Order order;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final secondaire = TextStyle(fontSize: 12, color: scheme.onSurfaceVariant);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Commande ${order.reference}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text('Total : ${formatMontant(order.total)}', style: secondaire),
          const SizedBox(height: 4),
          Text(
            'Adresse : ${order.adresseComplete}',
            style: secondaire,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _CarteLivreur extends StatelessWidget {
  const _CarteLivreur({
    required this.livreur,
    required this.estChoisi,
    required this.onTap,
  });

  final eccore.CourierProfile livreur;
  final bool estChoisi;

  /// `null` pendant l'envoi : changer d'avis n'annulerait pas la proposition.
  final VoidCallback? onTap;

  /// « à 1,2 km » ou « à 350 m » de la cuisine.
  ///
  /// La distance n'est portée que par la route des éligibles, et reste nulle
  /// pour un livreur dont aucune position n'est connue — celui qui vient
  /// d'ouvrir son application. Afficher zéro le placerait en tête de liste, sur
  /// le pas de la porte.
  String? get _distance {
    final metres = livreur.distanceM;
    if (metres == null) return null;
    if (metres < 1000) return 'à $metres m';
    return 'à ${(metres / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final secondaire = TextStyle(fontSize: 12, color: scheme.onSurfaceVariant);
    final distance = _distance;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: estChoisi ? scheme.primaryContainer.withValues(alpha: 0.35) : null,
      elevation: estChoisi ? 4 : 1,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(minHeight: 60),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: livreur.statut.couleur,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            livreur.fullName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: estChoisi ? scheme.onPrimaryContainer : null,
                            ),
                          ),
                        ),
                        if (estChoisi)
                          Icon(Icons.check_circle, color: scheme.primary, size: 20),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // La distance d'abord : c'est sur elle que le serveur
                        // trie, et la seule information qui départage deux
                        // livreurs également éligibles.
                        _Detail(
                          icone: distance == null
                              ? Icons.location_off_outlined
                              : Icons.near_me_outlined,
                          texte: distance ?? 'Position inconnue',
                          style: secondaire,
                          couleurIcone: distance == null ? scheme.outline : scheme.primary,
                        ),
                        // Une moyenne sur zéro note vaut 0,0 : l'afficher
                        // rendait un livreur qui débute indigne de confiance.
                        _Detail(
                          icone: Icons.star,
                          texte: livreur.ratingCount == 0
                              ? 'Pas encore noté'
                              : '${livreur.ratingAverage.toStringAsFixed(1)} '
                                  '(${livreur.ratingCount})',
                          style: secondaire,
                          couleurIcone: scheme.tertiary,
                        ),
                        _Detail(
                          icone: Icons.delivery_dining,
                          texte: '${livreur.deliveriesCompleted} livraisons',
                          style: secondaire,
                          couleurIcone: scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Véhicule : ${livreur.vehicleType}',
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
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

class _Detail extends StatelessWidget {
  const _Detail({
    required this.icone,
    required this.texte,
    required this.style,
    required this.couleurIcone,
  });

  final IconData icone;
  final String texte;
  final TextStyle style;
  final Color couleurIcone;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: 14, color: couleurIcone),
        const SizedBox(width: 4),
        Text(texte, style: style),
      ],
    );
  }
}

class _PiedDeDialogue extends StatelessWidget {
  const _PiedDeDialogue({required this.onAssigner, required this.envoiEnCours});

  /// `null` tant qu'aucun livreur n'est choisi, ou pendant l'envoi.
  final VoidCallback? onAssigner;
  final bool envoiEnCours;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 48),
            child: TextButton(
              onPressed: envoiEnCours ? null : () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            constraints: const BoxConstraints(minHeight: 48),
            child: ElevatedButton.icon(
              onPressed: onAssigner,
              icon: envoiEnCours
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.local_shipping),
              // « Proposer » : le serveur crée une offre que le livreur accepte
              // ou refuse. Le bouton disait « Assigner », et le superviseur
              // fermait la commande en croyant la course partie.
              label: Text(envoiEnCours ? 'Envoi…' : 'Proposer la course'),
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

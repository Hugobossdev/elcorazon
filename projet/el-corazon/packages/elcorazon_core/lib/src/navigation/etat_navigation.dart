/// Où en est la navigation du livreur.
///
/// ## Pourquoi un état, et pas trois booléens
///
/// L'écran de suivi portait `_isLoading`, `_isCalculatingRoute` et
/// `_cameraSuitLeLivreur`, et devinait le reste. Rien n'y distinguait « je
/// calcule le premier itinéraire » de « je recalcule parce que le livreur a
/// tourné trop tôt », ni « le GPS n'a pas encore fixé » de « la permission est
/// refusée ». Les combinaisons impossibles étaient représentables, et
/// certaines apparaissaient : un écran qui suit la position d'un livreur dont
/// le flux est coupé, par exemple.
///
/// ## Ce que cet état ne décide pas
///
/// **L'avancement de la course.** [arriveAuRestaurant] et
/// [arriveChezLeClient] disent que le téléphone est à l'endroit voulu, rien de
/// plus. Marquer une commande récupérée ou livrée reste un geste du livreur,
/// validé par le serveur (`allowed_transitions`) : un relevé GPS ne prouve ni
/// qu'un sac a changé de mains, ni qu'un client a été payé, et il se falsifie.
/// Voir `EtapeCourse` et `Course.prochaineEtape`.
enum EtatNavigation {
  /// `IDLE` — rien en cours. Aucune destination, aucun tracé, aucune voix.
  inactif,

  /// `PREPARING` — la destination est connue, l'itinéraire pas encore.
  preparation,

  /// `NAVIGATING_TO_RESTAURANT` — guidage vers le point de retrait.
  versLeRestaurant,

  /// `ARRIVED_AT_RESTAURANT` — le livreur est dans le rayon d'arrivée du
  /// restaurant. C'est au livreur, ensuite, de déclarer la commande récupérée.
  arriveAuRestaurant,

  /// `NAVIGATING_TO_CUSTOMER` — guidage vers l'adresse de livraison.
  versLeClient,

  /// `ARRIVED_AT_CUSTOMER` — le livreur est dans le rayon d'arrivée du client.
  /// La confirmation de livraison reste un geste, et reste validée par le
  /// serveur.
  arriveChezLeClient,

  /// `COMPLETED` — la course est close, il n'y a plus rien à guider.
  terminee,

  /// `OFF_ROUTE` — le livreur s'est écarté du tracé au-delà du seuil, et un
  /// nouvel itinéraire est en cours de calcul. État **transitoire** : il
  /// revient à [versLeRestaurant] ou [versLeClient] dès que le tracé est
  /// remplacé.
  horsItineraire,

  /// `GPS_UNAVAILABLE` — plus de position. Le guidage se tait plutôt que de
  /// continuer à annoncer des virages sur une position vieille de deux
  /// minutes.
  positionIndisponible,

  /// `ERROR` — l'itinéraire n'a pas pu être calculé (réseau, quota, refus de
  /// la clé). Le message est porté à part, dans `MoteurDeNavigation.erreur`.
  erreur;

  /// Le guidage tourne-t-il ? Vrai pendant un recalcul : le livreur roule
  /// toujours, et la carte doit continuer de le suivre.
  bool get guide =>
      this == EtatNavigation.versLeRestaurant ||
      this == EtatNavigation.versLeClient ||
      this == EtatNavigation.horsItineraire;

  /// Le livreur est-il arrivé quelque part ?
  bool get estUneArrivee =>
      this == EtatNavigation.arriveAuRestaurant ||
      this == EtatNavigation.arriveChezLeClient;
}

/// Vers lequel des deux points la navigation guide.
///
/// Une livraison est un trajet en deux temps, et l'un ne se déduit pas de
/// l'autre : le livreur va d'abord au restaurant, puis chez le client. Cette
/// étape-ci est **dérivée de la course** (`Course.repasRecupere`), jamais
/// choisie à la main — demander à un livreur de sélectionner sa destination
/// alors que la commande la porte, c'est lui faire saisir ce qu'on sait déjà,
/// et lui laisser l'occasion de se tromper.
enum EtapeNavigation {
  restaurant,
  client;

  /// L'étape suivante, ou `null` après la dernière.
  EtapeNavigation? get suivante =>
      this == EtapeNavigation.restaurant ? EtapeNavigation.client : null;

  /// L'état de guidage correspondant.
  EtatNavigation get etatEnRoute => switch (this) {
        EtapeNavigation.restaurant => EtatNavigation.versLeRestaurant,
        EtapeNavigation.client => EtatNavigation.versLeClient,
      };

  /// L'état d'arrivée correspondant.
  EtatNavigation get etatArrive => switch (this) {
        EtapeNavigation.restaurant => EtatNavigation.arriveAuRestaurant,
        EtapeNavigation.client => EtatNavigation.arriveChezLeClient,
      };
}

/// Aperçu ou navigation.
///
/// ## Pourquoi les deux ne se confondent pas
///
/// En [apercu], le livreur regarde où il va : la carte cadre l'itinéraire
/// entier, la voix se tait, et rien ne le suit. C'est ce qu'il consulte avant
/// d'accepter, ou à l'arrêt.
///
/// En [navigation], la carte le suit dans son sens de marche, les instructions
/// sont prononcées, et l'itinéraire se recalcule s'il s'en écarte. C'est un
/// mode qu'on démarre expressément, parce qu'il fait parler le téléphone et
/// qu'il n'a de sens qu'une fois en route.
enum ModeNavigation { apercu, navigation }

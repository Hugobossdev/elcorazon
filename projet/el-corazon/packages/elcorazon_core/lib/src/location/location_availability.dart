/// Ce qui empêche — ou non — de relever la position de l'appareil.
///
/// ## Pourquoi ce type vit dans le socle
///
/// Les deux applications qui relèvent une position portaient chacune leur
/// `LocationService`, et toutes deux répondaient à la question par un `bool`.
/// Un `false` y recouvrait quatre situations qui n'appellent pas le même
/// geste : le GPS éteint se rallume, une permission refusée se redemande, un
/// refus **définitif** ne se redemande plus et impose les réglages du système,
/// et une panne de capteur ne s'agit pas du tout. Ramenées à un booléen, les
/// quatre produisaient le même écran muet — « impossible d'obtenir votre
/// position » — devant lequel l'utilisateur n'a rien à faire.
///
/// Le type est **sans dépendance de plateforme** : `geolocator` n'entre pas
/// dans le socle, dont les dépendances servent l'API du serveur, la session et
/// le temps réel — et que l'application d'administration embarque sans jamais
/// relever la moindre position. Chaque application traduit l'énumération du
/// greffon vers celle-ci à la frontière, c'est un `switch` de six lignes ; en
/// échange, le message montré au livreur et celui montré au client sortent du
/// même endroit.
enum LocationAvailability {
  /// Le relevé est possible.
  disponible,

  /// La localisation est coupée sur l'appareil — rien à voir avec
  /// l'application. Se règle dans les réglages du **système**, et une demande
  /// de permission n'y changerait rien.
  serviceDesactive,

  /// Refusée pour cette fois. Se redemande.
  permissionRefusee,

  /// Refusée définitivement (« ne plus demander », ou restriction parentale).
  /// Le système ne réaffichera plus la demande : seul un passage par la fiche
  /// de l'application la rouvre.
  permissionRefuseeDefinitivement,

  /// Le capteur n'a rien rendu — pas de fixation satellite, ou une erreur du
  /// greffon. Transitoire : c'est le seul cas où attendre est la bonne
  /// réponse.
  positionIndisponible;

  bool get estDisponible => this == LocationAvailability.disponible;

  /// Titre court, tel qu'un bandeau ou une boîte de dialogue l'affiche.
  String get titre => switch (this) {
        LocationAvailability.disponible => 'Position active',
        LocationAvailability.serviceDesactive => 'GPS désactivé',
        LocationAvailability.permissionRefusee => 'Permission refusée',
        LocationAvailability.permissionRefuseeDefinitivement =>
          'Permission refusée',
        LocationAvailability.positionIndisponible => 'Position indisponible',
      };

  /// Ce que l'utilisateur doit faire, en une phrase.
  ///
  /// Jamais l'exception d'origine : un message de greffon (« PERMISSION_DENIED,
  /// LocationPermission.deniedForever ») ne dit rien à qui attend son repas.
  /// L'erreur technique part au journal, cette phrase-ci à l'écran.
  String get consigne => switch (this) {
        LocationAvailability.disponible => '',
        LocationAvailability.serviceDesactive =>
          'Activez votre localisation pour continuer.',
        LocationAvailability.permissionRefusee =>
          'Autorisez la localisation pour continuer.',
        LocationAvailability.permissionRefuseeDefinitivement =>
          'Autorisez la localisation dans les paramètres.',
        LocationAvailability.positionIndisponible =>
          'Recherche de votre position…',
      };

  /// Le geste qui débloque la situation — c'est lui qui décide du bouton à
  /// afficher, et il n'y en a jamais qu'un.
  LocationRemede get remede => switch (this) {
        LocationAvailability.disponible => LocationRemede.aucun,
        LocationAvailability.serviceDesactive =>
          LocationRemede.ouvrirReglagesDeLocalisation,
        LocationAvailability.permissionRefusee =>
          LocationRemede.redemanderLaPermission,
        LocationAvailability.permissionRefuseeDefinitivement =>
          LocationRemede.ouvrirLaFicheDeLApplication,
        LocationAvailability.positionIndisponible => LocationRemede.patienter,
      };
}

/// Le geste attendu de l'utilisateur face à un [LocationAvailability].
enum LocationRemede {
  aucun,

  /// Réglages système de la localisation — `Geolocator.openLocationSettings`.
  ouvrirReglagesDeLocalisation,

  /// Une nouvelle demande a encore une chance d'aboutir.
  redemanderLaPermission,

  /// Fiche de l'application — `Geolocator.openAppSettings`. Le système ne
  /// réaffiche plus la demande, insister ne sert à rien.
  ouvrirLaFicheDeLApplication,

  /// Rien à faire, la fixation finira par arriver.
  patienter;

  /// Libellé du bouton, ou vide quand il n'y a pas de bouton à montrer.
  String get libelle => switch (this) {
        LocationRemede.aucun => '',
        LocationRemede.ouvrirReglagesDeLocalisation => 'Activer le GPS',
        LocationRemede.redemanderLaPermission => 'Autoriser',
        LocationRemede.ouvrirLaFicheDeLApplication => 'Ouvrir les réglages',
        LocationRemede.patienter => '',
      };
}

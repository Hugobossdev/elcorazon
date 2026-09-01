import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

/// Vocabulaire d'affichage des statuts de commande, côté back-office.
///
/// Pourquoi ce fichier existe
/// --------------------------
///
/// Le socle décrit le statut d'une commande en **chaîne brute**
/// (`eccore.Order.status`), et c'est délibéré : la valeur voyage telle quelle
/// dans le JSON, et un enum imposerait une correspondance à tenir à jour des
/// deux côtés — celle-là même qui finit par ne plus correspondre. `dely` a
/// suivi la même route avec `libelles_course.dart`.
///
/// Ce que ce fichier ajoute n'est pas du domaine mais de la présentation : un
/// libellé, une pastille, et les trois questions que l'écran pose d'un statut.
///
/// Il vient de `models/order.dart`, qui déclarait **dix** statuts là où le
/// serveur n'en connaît que huit. Les deux de trop — `refunded` et `failed` —
/// n'ont jamais existé côté serveur : `DjangoOrderMapper` ne pouvait pas les
/// produire, et les renvoyait tous deux en `cancelled`. Le remboursement est
/// un mouvement de paiement, pas un état de commande ; ce qui n'aboutit pas
/// est annulé avec un motif.
enum StatutCommande {
  enAttente('pending', 'En attente'),
  confirmee('confirmed', 'Confirmée'),
  enPreparation('preparing', 'En préparation'),
  prete('ready', 'Prête'),
  recuperee('picked_up', 'Récupérée'),
  enRoute('on_the_way', 'En route'),
  livree('delivered', 'Livrée'),
  annulee('cancelled', 'Annulée');

  const StatutCommande(this.versServeur, this.libelle);

  /// La valeur que le serveur attend et rend.
  final String versServeur;

  final String libelle;

  /// L'illustration de l'étape, prise dans le pack partagé du socle.
  ///
  /// ## Pourquoi elle vient du socle
  ///
  /// Les trois applications décrivaient les mêmes huit étapes avec leurs
  /// propres emojis Unicode, tenus séparément. Rien ne garantissait qu'ils
  /// restent d'accord : le back-office pouvait montrer un statut que le client
  /// ne reconnaissait pas. Le pack vit maintenant dans `elcorazon_core`, et
  /// **une étape a la même illustration partout**.
  ///
  /// Deux des emojis remplacés (`'👨‍🍳'`, `'🏃‍♂️'`) étaient des séquences
  /// ZWJ, que les Android anciens décomposent en glyphes séparés.
  eccore.AppEmojiToken get illustration => switch (this) {
        StatutCommande.enAttente => eccore.AppEmojis.newOrder,
        StatutCommande.confirmee => eccore.AppEmojis.orderConfirmed,
        StatutCommande.enPreparation => eccore.AppEmojis.preparing,
        StatutCommande.prete => eccore.AppEmojis.orderReady,
        StatutCommande.recuperee => eccore.AppEmojis.courier,
        StatutCommande.enRoute => eccore.AppEmojis.delivery,
        StatutCommande.livree => eccore.AppEmojis.delivered,
        StatutCommande.annulee => eccore.AppEmojis.error,
      };

  /// Depuis la valeur rendue par le serveur.
  ///
  /// Une valeur inconnue retombe sur [enAttente] : c'est le comportement que
  /// `DjangoOrderMapper` avait déjà, et le seul qui ne fasse pas disparaître
  /// une commande d'un écran de supervision.
  static StatutCommande depuisServeur(String valeur) {
    for (final statut in values) {
      if (statut.versServeur == valeur) return statut;
    }
    return enAttente;
  }

  /// La commande est-elle encore en cours de traitement ?
  bool get estEnCours => this != livree && this != annulee;

  /// La commande a-t-elle atteint sa fin, quelle qu'elle soit ?
  bool get estTerminee => !estEnCours;

  /// Le personnel peut-il encore la modifier ?
  ///
  /// Trois états seulement : passé la préparation, la cuisine a engagé des
  /// denrées et le livreur peut être en route.
  bool get peutEtreModifiee =>
      this == enAttente || this == confirmee || this == enPreparation;

  /// Le rang de l'étape dans le cycle de vie.
  ///
  /// [annulee] n'en a pas : une annulation n'est pas une étape de plus mais
  /// une sortie. L'ancienne énumération la classait après [livree], ce qui
  /// faisait passer une commande annulée pour une commande partie en
  /// livraison.
  int? get rang => this == annulee ? null : index;
}

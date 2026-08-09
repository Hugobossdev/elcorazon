import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

/// Vocabulaire d'affichage des notifications.
///
/// Pourquoi ce fichier existe
/// --------------------------
///
/// Le socle garde `kind` en chaîne brute, comme partout ailleurs : la valeur
/// voyage telle quelle dans le JSON, et un enum imposerait une correspondance
/// à tenir des deux côtés.
///
/// Il remplace `models/notification_model.dart`, qui déclarait **sept** genres
/// et **quatre** priorités. Le serveur en connaît cinq et n'a pas de priorité :
/// `NotificationPriority` n'a jamais été rempli qu'avec `normal`, écrit en dur
/// dans l'écran.
enum GenreNotification {
  commande('order_status', 'Commandes'),
  livraison('delivery_offer', 'Livraisons'),
  paiement('payment', 'Paiements'),
  compte('account', 'Compte'),
  promotion('marketing', 'Promotions');

  const GenreNotification(this.versServeur, this.libelle);

  /// La valeur que le serveur rend dans `kind`.
  final String versServeur;

  final String libelle;

  /// Depuis la valeur rendue par le serveur.
  ///
  /// Une valeur inconnue devient [compte] plutôt que de faire disparaître la
  /// notification d'une liste que l'utilisateur consulte justement pour ne
  /// rien manquer.
  static GenreNotification depuisServeur(String kind) {
    for (final genre in values) {
      if (genre.versServeur == kind) return genre;
    }
    return compte;
  }
}

extension NotificationAffichee on eccore.AppNotification {
  /// Le genre, dans le vocabulaire de l'écran.
  GenreNotification get genre => GenreNotification.depuisServeur(kind);

  /// La commande que la notification désigne, si elle en désigne une.
  ///
  /// La clé est `order` — c'est ce que `notifications/receivers.py` écrit.
  /// L'écran cherchait `orderId`, qui n'a jamais existé : la navigation depuis
  /// une notification de commande ne pouvait pas aboutir.
  ///
  /// La charge utile est **minimale** par contrat : de quoi ouvrir le bon
  /// écran, pas une copie de l'objet métier, qui aura changé d'ici la lecture.
  String? get commandeVisee {
    final valeur = data['order'];
    return valeur is String && valeur.isNotEmpty ? valeur : null;
  }
}

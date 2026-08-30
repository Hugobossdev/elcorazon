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

/// Les notifications à afficher : filtrées, puis rangées de la plus récente à
/// la plus ancienne.
///
/// Pourquoi cette fonction existe
/// ------------------------------
///
/// L'écran filtrait et triait dans son `build`, et le tri se faisait **en
/// place**. Or `NotificationDatabaseService.notifications` rend une
/// `List.unmodifiable` : trier cette liste-là levait
/// `Unsupported operation: sort`, et l'écran affichait le bandeau rouge à la
/// place de ses notifications.
///
/// Le défaut ne se produisait que dans un cas sur quatre — onglet « Toutes »,
/// filtre « Tous », bascule éteinte — c'est-à-dire exactement à l'ouverture de
/// l'écran. Dès qu'un filtre s'appliquait, le `.where(…).toList()` produisait
/// une copie, et le tri passait. C'est ce qui l'a si longtemps masqué.
///
/// Ici, le filtrage rend **toujours** une liste neuve, y compris sans critère :
/// la faute n'est plus seulement corrigée, elle est devenue impossible.
List<eccore.AppNotification> notificationsAAfficher(
  List<eccore.AppNotification> notifications, {
  GenreNotification? genre,
  bool nonLuesSeulement = false,
}) {
  final retenues = notifications.where((notification) {
    if (genre != null && notification.genre != genre) return false;
    if (nonLuesSeulement && notification.isRead) return false;
    return true;
  }).toList();

  retenues.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return retenues;
}


/// Un paquet de notifications d'une même journée, avec son intitulé.
class JourneeDeNotifications {
  const JourneeDeNotifications({required this.libelle, required this.notifications});

  /// « Aujourd'hui », « Hier », ou la date.
  final String libelle;

  final List<eccore.AppNotification> notifications;
}

/// Regroupe [notifications] par journée, de la plus récente à la plus ancienne.
///
/// Pourquoi cette fonction existe
/// ------------------------------
///
/// La maquette `notifications` sépare « Today » et « Yesterday » : sans ces
/// intertitres, une liste de trente alertes n'a plus de repère temporel, et
/// « il y a 3 h » se confond avec « il y a 3 jours » dès qu'on fait défiler.
///
/// Le regroupement se fait sur la **journée civile**, pas sur un écart de
/// 24 heures : à 1 h du matin, une notification de 23 h la veille appartient à
/// « Hier », même si elle date de deux heures. C'est ainsi qu'on lit un
/// journal.
///
/// [maintenant] est injectable pour que le test ne dépende pas de l'heure à
/// laquelle il tourne.
List<JourneeDeNotifications> grouperParJour(
  List<eccore.AppNotification> notifications, {
  DateTime? maintenant,
}) {
  if (notifications.isEmpty) return const [];

  final reference = maintenant ?? DateTime.now();
  final aujourdhui = DateTime(reference.year, reference.month, reference.day);

  final paquets = <DateTime, List<eccore.AppNotification>>{};
  for (final notification in notifications) {
    final creee = notification.createdAt;
    final jour = DateTime(creee.year, creee.month, creee.day);
    paquets.putIfAbsent(jour, () => []).add(notification);
  }

  final jours = paquets.keys.toList()..sort((a, b) => b.compareTo(a));

  return [
    for (final jour in jours)
      JourneeDeNotifications(
        libelle: _libelleDuJour(jour, aujourdhui),
        notifications: paquets[jour]!,
      ),
  ];
}

String _libelleDuJour(DateTime jour, DateTime aujourdhui) {
  final ecart = aujourdhui.difference(jour).inDays;
  if (ecart <= 0) return 'Aujourd’hui';
  if (ecart == 1) return 'Hier';

  final j = jour.day.toString().padLeft(2, '0');
  final m = jour.month.toString().padLeft(2, '0');
  return ecart < 365 ? '$j/$m' : '$j/$m/${jour.year}';
}

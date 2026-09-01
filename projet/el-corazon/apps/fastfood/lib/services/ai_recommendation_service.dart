import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:elcora_fast/presentation/catalogue.dart';
import 'package:flutter/foundation.dart';

import 'package:elcora_fast/services/app_service.dart';
import 'package:elcora_fast/repositories/django_menu_repository.dart';
import 'package:elcorazon_core/elcorazon_core.dart' show Journal;

/// Les suggestions de l'accueil, tirées de ce que le client a réellement
/// commandé.
///
/// ## Ce que ce service faisait
///
/// Il fabriquait ses propres données. `_loadUserPreferences` écrivait, pour
/// **tout** compte, les mêmes goûts inventés — « burgers, pizzas, drinks »,
/// régime végétarien, gamme de prix moyenne — et `_loadUserOrderHistory`
/// fabriquait deux commandes qui n'avaient jamais eu lieu : un « El Corazón
/// Burger » à 12,99 et une « Margherita Pizza » à 15,99, livrées au « 123 Main
/// St ». Le classement qui en découlait était ensuite bousculé par
/// `Random().nextBool()` pour la météo et `Random().nextDouble()` dans le
/// score.
///
/// Trois conséquences, dont deux invisibles :
///
///  * les catégories cherchées étaient anglaises (`breakfast`, `sandwich`,
///    `drink`, `soup`, `coffee`) et le catalogue est français : « Boissons »
///    ne contient pas `drink`, « Poulet & Grillades » ne contient rien du
///    tout. La moitié des règles ne pouvait rien apparier ;
///  * les seuils de prix — 10 et 20 — étaient en dollars, sur des articles
///    facturés entre 1 500 et 6 000 F CFA : *tous* les articles tombaient
///    au-dessus de 20, donc dans une gamme que la préférence inventée
///    n'accordait jamais. Ce terme du score valait zéro pour tout le monde ;
///  * `_getPopularRecommendations` cherchait « special », « deluxe » ou
///    « premium » dans les noms, alors que le serveur **publie** `is_popular`
///    sur chaque article.
///
/// ## Ce qu'il fait
///
/// Il n'existe pas de route de recommandation côté serveur, et une vraie
/// recommandation est un travail de modèle. Ce service se limite donc à ce
/// qu'on peut établir honnêtement, à partir de trois signaux qui existent pour
/// de bon :
///
///  1. **l'historique réel du client** (`/orders/`, déjà chargé par
///     `AppService`), qui donne ses catégories par fréquence ;
///  2. **`is_popular`**, que l'exploitation pose sur l'article ;
///  3. **la note moyenne** et son nombre d'avis, que le serveur entretient.
///
/// Aucun tirage aléatoire : deux ouvertures de l'accueil à une seconde
/// d'intervalle proposent la même chose, ce qui est le minimum attendu d'une
/// suggestion.
class AIRecommendationService extends ChangeNotifier {
  static final AIRecommendationService _instance =
      AIRecommendationService._internal();
  factory AIRecommendationService() => _instance;
  AIRecommendationService._internal();

  final Map<String, List<eccore.MenuItem>> _recommendations = {};
  bool _isInitialized = false;

  Map<String, List<eccore.MenuItem>> get recommendations =>
      Map.unmodifiable(_recommendations);
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    _isInitialized = true;
    notifyListeners();
  }

  /// Calcule les suggestions du compte.
  ///
  /// Appelé une fois à l'ouverture de session, par `ServiceInitializer`, après
  /// que `AppService` a chargé le catalogue et l'historique — les deux dont ce
  /// calcul dépend. Une commande passée en cours de session n'est donc prise
  /// en compte qu'au prochain démarrage : c'est un décalage assumé, la liste
  /// n'ayant pas à bouger sous les doigts entre deux visites de l'accueil.
  Future<void> initializeUser(String userId) async {
    final articles = await _articlesDisponibles();
    if (articles.isEmpty) {
      _recommendations[userId] = const [];
      _isInitialized = true;
      notifyListeners();
      return;
    }

    final affinites = _affinitesParCategorie();

    // Ce que le client a déjà commandé sort de la liste : l'accueil a déjà une
    // reprise de commande et une section de favoris pour cela. Une
    // « suggestion » qui propose ce qu'on a mangé la semaine dernière n'en est
    // pas une.
    final dejaCommandes = _articlesDejaCommandes();

    final candidats = articles
        .where((article) => article.isAvailable)
        .where((article) => !dejaCommandes.contains(article.id))
        .toList();

    candidats.sort((a, b) {
      final ecart = _score(b, affinites).compareTo(_score(a, affinites));
      // Départage par nom, et non par ordre d'arrivée : à score égal, la liste
      // doit être la même d'une ouverture à l'autre.
      return ecart != 0 ? ecart : a.name.compareTo(b.name);
    });

    _recommendations[userId] = candidats.take(10).toList();
    _isInitialized = true;
    notifyListeners();
  }

  List<eccore.MenuItem> getRecommendationsForUser(String userId) {
    return _recommendations[userId] ?? const [];
  }

  /// Part de chaque catégorie dans les commandes passées du client, entre 0
  /// et 1.
  ///
  /// La catégorie ne se lit pas sur la ligne de commande : `OrderLine` porte le
  /// nom de l'article et son prix, pas sa catégorie — `DjangoOrderRepository`
  /// laisse d'ailleurs `category` vide, faute d'avoir la donnée. Elle se
  /// retrouve par l'identifiant d'article, sur le catalogue. C'est ce
  /// rapprochement qui manquait : l'ancienne version comptait des chaînes
  /// vides, et n'appariait donc jamais rien.
  Map<String, double> _affinitesParCategorie() {
    final catalogue = {
      for (final article in AppService().menuItems) article.id: article,
    };

    final comptes = <String, int>{};
    var total = 0;

    for (final commande in AppService().orders) {
      for (final ligne in commande.items) {
        final article = catalogue[ligne.menuItemId];
        if (article == null || article.categorySlug.isEmpty) continue;
        comptes[article.categorySlug] =
            (comptes[article.categorySlug] ?? 0) + ligne.quantity;
        total += ligne.quantity;
      }
    }

    if (total == 0) return const {};
    return {
      for (final entree in comptes.entries) entree.key: entree.value / total,
    };
  }

  Set<String> _articlesDejaCommandes() {
    return {
      for (final commande in AppService().orders)
        for (final ligne in commande.items) ligne.menuItemId,
    };
  }

  /// Trois termes, tous adossés à une donnée du serveur.
  ///
  /// L'affinité pèse le plus : c'est le seul signal propre à **ce** client.
  /// Les deux autres le remplacent quand il n'y a pas encore d'historique — un
  /// compte neuf reçoit alors les articles mis en avant et les mieux notés, ce
  /// qui est exactement ce qu'on lui montrerait à défaut de le connaître.
  double _score(eccore.MenuItem article, Map<String, double> affinites) {
    var score = (affinites[article.categorySlug] ?? 0) * 0.5;

    if (article.isPopular) score += 0.25;

    // La note n'entre en compte que si quelqu'un a noté. Une moyenne de 0,00
    // sur zéro avis — ce que porte tout catalogue neuf — ne dit rien du plat,
    // et la traiter comme une mauvaise note enterrerait toute la carte.
    if (article.ratingCount > 0) {
      score += (article.ratingAverage / 5) * 0.25;
    }

    return score;
  }

  /// Le catalogue, depuis la mémoire de `AppService` si elle est chaude, du
  /// serveur sinon.
  Future<List<eccore.MenuItem>> _articlesDisponibles() async {
    try {
      final enMemoire = AppService().menuItems;
      if (enMemoire.isNotEmpty) return enMemoire;

      final articles = (await DjangoMenuRepository().getMenuItems())
          .where((article) => article.estCommandable)
          .toList();

      if (articles.isEmpty) {
        Journal.trace(
          'AIRecommendationService: aucun article disponible au catalogue',
        );
      }
      return articles;
    } catch (e) {
      Journal.trace('AIRecommendationService: catalogue indisponible - $e');
      return const [];
    }
  }
}

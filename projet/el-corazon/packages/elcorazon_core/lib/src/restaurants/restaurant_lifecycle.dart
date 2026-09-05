/// Cycle de vie d'un établissement — miroir de `RestaurantStatus`
/// (`backend/apps/restaurants/states.py`).
///
///     brouillon → en configuration → prêt → en service ⇄ suspendu
///
/// C'est ce qui manquait pour provisionner un restaurant sans le publier :
/// `is_active` valait `true` par défaut, si bien qu'une fiche créée depuis le
/// back-office apparaissait immédiatement dans l'application cliente — sans
/// carte, sans horaires, sans livreur.
///
/// L'énumération est fermée et porte son code serveur : une valeur inconnue
/// rendue par une version plus récente de l'API ne se devine pas, elle est
/// signalée. Un `switch` silencieux sur une chaîne aurait affiché « brouillon »
/// pour un état qu'on n'aurait pas su lire.
enum RestaurantLifecycle {
  draft('draft', 'Brouillon'),
  configuring('configuring', 'En configuration'),
  ready('ready', 'Prêt à ouvrir'),
  active('active', 'En service'),
  inactive('inactive', 'Suspendu');

  const RestaurantLifecycle(this.code, this.label);

  /// Valeur transmise au serveur, et telle qu'il la rend.
  final String code;

  /// Intitulé affiché au back-office.
  final String label;

  static RestaurantLifecycle fromCode(String code) {
    return RestaurantLifecycle.values.firstWhere(
      (etat) => etat.code == code,
      orElse: () => throw ArgumentError(
        'État d\'établissement inconnu : "$code". '
        'Le contrat serveur a-t-il changé sans que le client suive ?',
      ),
    );
  }

  /// L'établissement est-il visible des applications clientes ?
  ///
  /// Un seul état le rend public, et c'est délibéré : « prêt » veut dire que la
  /// configuration est complète, pas que l'exploitation a décidé d'ouvrir.
  bool get isPublished => this == RestaurantLifecycle.active;

  /// Reste-t-il à configurer avant de pouvoir ouvrir ?
  bool get isProvisioning =>
      this == RestaurantLifecycle.draft || this == RestaurantLifecycle.configuring;

  /// États atteignables depuis celui-ci — miroir de `RESTAURANT_TRANSITIONS`.
  ///
  /// Recopié côté client pour n'afficher que les boutons qui aboutiront. Ce
  /// n'est **pas** un contrôle : le serveur refait la vérification, et c'est
  /// lui qui décide. Une liste qui divergerait ferait au pire proposer une
  /// action refusée en 409, jamais autoriser ce qui ne l'est pas.
  Set<RestaurantLifecycle> get nextStates => switch (this) {
        RestaurantLifecycle.draft => {RestaurantLifecycle.configuring},
        RestaurantLifecycle.configuring => {
            RestaurantLifecycle.draft,
            RestaurantLifecycle.ready,
          },
        RestaurantLifecycle.ready => {
            RestaurantLifecycle.configuring,
            RestaurantLifecycle.active,
          },
        RestaurantLifecycle.active => {RestaurantLifecycle.inactive},
        RestaurantLifecycle.inactive => {
            RestaurantLifecycle.active,
            RestaurantLifecycle.configuring,
          },
      };
}

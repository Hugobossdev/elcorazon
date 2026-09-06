/// Préférences d'un client — `/api/v1/profiles/preferences/`.
///
/// ## Ce que le serveur en fait, et ce qu'il n'en fait pas
///
/// Un réglage affiché est une promesse. Les champs portés ici n'ont pas tous
/// la même valeur, et l'écran qui les montre doit le savoir :
///
/// * [marketingPushEnabled] est **appliqué**. `apps/notifications/services.py`
///   le relit avant chaque envoi de campagne (`_accepts_marketing`), et une
///   campagne n'atteint pas un client qui l'a coupé. Les notifications
///   transactionnelles — « votre livreur arrive » — ne passent pas par là et
///   ne se coupent pas : ce n'est pas du marketing, et les taire laisserait un
///   client devant sa porte sans savoir que son repas est arrivé.
/// * [marketingEmailEnabled] est **enregistré**, et rien ne l'a encore lu :
///   aucun envoi de courriel commercial n'existe à ce jour. C'est un
///   consentement recueilli avant l'usage, ce qui est le bon ordre — le refus
///   est déjà honoré, puisque rien ne part.
///
/// Le serveur porte aussi des régimes alimentaires et des allergènes. Ils ne
/// sont **pas** exposés ici : aucun chemin ne les fait parvenir à la cuisine,
/// et un écran qui les proposerait laisserait croire à un client allergique
/// qu'il a prévenu le restaurant. Tant que la commande ne les transporte pas,
/// ne pas les demander est la seule réponse honnête.
class CustomerPreferences {
  const CustomerPreferences({
    required this.marketingPushEnabled,
    required this.marketingEmailEnabled,
  });

  factory CustomerPreferences.fromJson(Map<String, dynamic> json) {
    return CustomerPreferences(
      // Défaut à vrai, comme le modèle : un champ absent d'une réponse ancienne
      // ne doit pas se lire comme un refus, ce qui ferait taire une
      // communication que le client n'a jamais refusée.
      marketingPushEnabled: json['marketing_push_enabled'] as bool? ?? true,
      marketingEmailEnabled: json['marketing_email_enabled'] as bool? ?? true,
    );
  }

  /// Recevoir les offres et nouveautés en notification.
  final bool marketingPushEnabled;

  /// Recevoir les offres et nouveautés par courriel.
  final bool marketingEmailEnabled;

  CustomerPreferences copyWith({
    bool? marketingPushEnabled,
    bool? marketingEmailEnabled,
  }) {
    return CustomerPreferences(
      marketingPushEnabled: marketingPushEnabled ?? this.marketingPushEnabled,
      marketingEmailEnabled: marketingEmailEnabled ?? this.marketingEmailEnabled,
    );
  }

  /// Corps d'écriture — **partiel**, et c'est voulu.
  ///
  /// La route accepte un `PATCH` partiel. N'envoyer que ce qui change évite
  /// d'écraser un champ que cette version de l'application ne connaît pas
  /// encore : les régimes et les allergènes vivent dans la même ressource, et
  /// un corps complet les remettrait à leur valeur par défaut — c'est-à-dire
  /// les effacerait.
  Map<String, dynamic> toJson() {
    return {
      'marketing_push_enabled': marketingPushEnabled,
      'marketing_email_enabled': marketingEmailEnabled,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is CustomerPreferences &&
        other.marketingPushEnabled == marketingPushEnabled &&
        other.marketingEmailEnabled == marketingEmailEnabled;
  }

  @override
  int get hashCode => Object.hash(marketingPushEnabled, marketingEmailEnabled);
}

import 'package:elcorazon_core/src/models/money.dart';

/// Ce qu'une période a rapporté au livreur — miroir de
/// `PeriodEarningsSerializer` (`backend/apps/delivery/serializers.py`).
class PeriodEarnings {
  const PeriodEarnings({required this.earned, required this.deliveries});

  factory PeriodEarnings.fromJson(Map<String, dynamic> json) {
    return PeriodEarnings(
      earned: Money.fromJson(json['earned'] as Map<String, dynamic>),
      deliveries: json['deliveries'] as int,
    );
  }

  /// Somme des rémunérations figées à l'acceptation des courses livrées.
  final Money earned;

  /// Combien de courses ont produit ce montant.
  final int deliveries;
}

/// Gains du livreur, agrégés **par le serveur** — `GET /delivery/me/earnings/`.
///
/// ## Pourquoi ce contrat existe
///
/// L'écran des gains additionnait les courses que l'application avait en
/// mémoire, c'est-à-dire au plus soixante : `recentlyDelivered` suit trois
/// pages de vingt, à dessein — l'historique d'un livreur en poste depuis un an
/// croît sans limite.
///
/// Il en tirait pourtant « aujourd'hui », « cette semaine » et **« ce mois »**.
/// Un livreur à dix courses par jour n'avait donc, dans son onglet mensuel, que
/// ses six derniers jours : un total plus petit que la réalité, affiché sans la
/// moindre mention de troncature. C'est le genre de chiffre qu'on ne met pas en
/// doute, puisqu'on compte sa paie dessus.
///
/// Une somme se demande au serveur, qui les a toutes. Les bornes de période
/// suivent le fuseau de l'établissement et non UTC : une course livrée à
/// 23 h 30 appartient à cette journée-là pour celui qui l'a faite.
class Earnings {
  const Earnings({
    required this.today,
    required this.week,
    required this.month,
    required this.lifetime,
  });

  factory Earnings.fromJson(Map<String, dynamic> json) {
    PeriodEarnings periode(String cle) =>
        PeriodEarnings.fromJson(json[cle] as Map<String, dynamic>);

    return Earnings(
      today: periode('today'),
      week: periode('week'),
      month: periode('month'),
      lifetime: periode('lifetime'),
    );
  }

  final PeriodEarnings today;
  final PeriodEarnings week;

  /// Le mois **civil** en cours, du premier au jour dit — et non les trente
  /// derniers jours.
  final PeriodEarnings month;

  /// Le cumul de carrière, lu sur le dossier plutôt que recalculé : c'est le
  /// compteur que le serveur tient à chaque livraison, et le solde sur lequel
  /// une demande de retrait s'apprécie. En faire une seconde somme les ferait
  /// diverger, et un retrait accordé par l'une serait refusé par l'autre.
  final PeriodEarnings lifetime;
}

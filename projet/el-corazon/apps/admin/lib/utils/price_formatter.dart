import 'package:elcorazon_core/elcorazon_core.dart' as socle;

/// Affichage des montants du back-office — **toujours avec leur devise**.
///
/// ## Pourquoi il n'y a plus de `formatPrice(double)`
///
/// Ce fichier exposait `PriceFormatter.format(double)` et `formatPrice(double)`,
/// qui formataient n'importe quel nombre en francs CFA d'Afrique de l'Ouest —
/// « la seule devise que ces écrans affichent », disait son commentaire. C'était
/// faux dès l'ouverture de Douala et Yaoundé : une commande camerounaise
/// (XAF) s'affichait comme une somme togolaise, et « Total encaissé »
/// additionnait les deux. Un nombre sans devise ne se formate pas juste ; les
/// deux fonctions ont donc disparu, et le compilateur a désigné chaque appel.
///
/// Le code ISO est écrit (« 12 500 XOF », « 12 500 XAF ») là où le socle écrit
/// « CFA » pour les deux : le back-office supervise plusieurs marchés, et doit
/// dire lequel il montre.

/// Un montant, tel qu'il arrive du serveur.
String formatMontant(socle.Money montant) => montant.formatIso();

/// Un montant déjà en unité **majeure**, dont on connaît la devise.
String formatMajeur(double montantMajeur, String devise) =>
    socle.formatPrice(montantMajeur, currency: devise, codeIso: true);

/// Un montant en unité majeure, tel qu'on le pré-remplit dans un champ :
/// « 1500 » en francs CFA, « 12.50 » en euros — autant de décimales que la
/// devise, jamais plus. Un `toStringAsFixed(0)` écrit en dur tronquait un prix
/// en euros à l'ouverture du formulaire, et l'enregistrement le repassait
/// arrondi.
String montantPourSaisie(double montantMajeur, String devise) =>
    montantMajeur.toStringAsFixed(socle.Money.exponentOf(devise));

/// Refuse une saisie plus précise que la devise — `null` si elle est juste.
///
/// Le serveur la refuserait de toute façon (`Money.from_major`) ; le dire au
/// champ évite un aller-retour et nomme la cause. Remplace un
/// `currency == 'XOF'` qui ignorait le XAF et le GNF, sans décimale eux non
/// plus.
String? erreurDePrecision(double montantMajeur, String devise) {
  final arrondi = socle.Money.fromMajorUnits(montantMajeur, devise).toMajorUnits();
  if ((arrondi - montantMajeur).abs() < 1e-9) return null;
  final decimales = socle.Money.exponentOf(devise);
  return decimales == 0
      ? 'Le $devise n’a pas de subdivision : montant entier attendu'
      : 'Le $devise s’écrit avec $decimales décimales au plus';
}

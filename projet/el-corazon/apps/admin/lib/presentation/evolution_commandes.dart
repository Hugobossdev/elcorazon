import 'package:elcorazon_core/elcorazon_core.dart' as eccore;

/// Le nombre de commandes par jour, sur les [jours] derniers jours de la série
/// du serveur — jours sans commande compris, à zéro.
///
/// La série venait d'un comptage **local** sur la fenêtre d'un an
/// téléchargée, jour découpé à l'horloge du poste. Elle vient désormais de
/// `GET /orders/manage/statistics/` (`per_day`), découpée dans le fuseau des
/// cuisines ; il reste ici à combler les jours vides, que le serveur n'émet
/// pas, pour que le graphe montre sept colonnes et non les seuls jours actifs.
///
/// Les clés sont des dates `AAAA-MM-JJ` complétées par des zéros : l'ordre
/// alphabétique est l'ordre chronologique.
Map<String, int> serieQuotidienne(
  eccore.OrderStatistics stats, {
  int jours = 7,
  DateTime? aujourdhui,
}) {
  final parJourServeur = {
    for (final ligne in stats.perDay) _cle(ligne.day): ligne.ordersCount,
  };
  final dernier = aujourdhui ?? DateTime.now();
  final fin = DateTime(dernier.year, dernier.month, dernier.day);
  return {
    for (var i = jours - 1; i >= 0; i--)
      _cle(fin.subtract(Duration(days: i))):
          parJourServeur[_cle(fin.subtract(Duration(days: i)))] ?? 0,
  };
}

String _cle(DateTime date) {
  final mois = date.month.toString().padLeft(2, '0');
  final jour = date.day.toString().padLeft(2, '0');
  return '${date.year}-$mois-$jour';
}

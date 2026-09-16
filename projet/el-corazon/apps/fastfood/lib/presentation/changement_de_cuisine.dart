import 'package:flutter/material.dart';

/// Messager de l'application, posé sur `MaterialApp.scaffoldMessengerKey`.
///
/// Un service — le panier — doit pouvoir prévenir le client sans tenir de
/// `BuildContext` : le changement de cuisine arrive d'un carnet d'adresses,
/// hors de tout écran.
final GlobalKey<ScaffoldMessengerState> messagerDeLApplication =
    GlobalKey<ScaffoldMessengerState>();

/// Ce qu'on dit au client quand sa cuisine change et que son panier ne suit pas.
///
/// ## Pourquoi le panier ne suit pas
///
/// Chaque cuisine a sa carte et ses prix : porter des lignes d'une cuisine sur
/// une autre les ferait refuser une par une par le serveur, ou correspondre par
/// hasard à un plat homonyme au mauvais prix. Le panier de l'ancienne cuisine
/// reste enregistré sous sa clé et se retrouve intact si l'on y revient.
///
/// ## Pourquoi il faut le dire
///
/// Sans message, un client qui corrige son adresse voyait son panier se vider
/// sous ses yeux — et concluait à une perte, ce qui n'en est pas une.
abstract final class ChangementDeCuisine {
  /// La question posée **avant** un changement choisi, panier non vide.
  static String confirmation({
    required String ancienne,
    required String nouvelle,
    required int articles,
  }) =>
      'Votre panier contient $articles article${articles > 1 ? 's' : ''} de $ancienne. '
      'La carte et les prix de $nouvelle sont différents : vous commencerez un '
      'nouveau panier. Celui de $ancienne reste enregistré si vous y revenez.';

  /// L'avis **après** un changement imposé par l'adresse, panier non vide.
  static String avis({
    required String ancienne,
    required String nouvelle,
    required int articles,
  }) =>
      'Votre adresse est livrée par $nouvelle. Votre panier de $ancienne '
      '($articles article${articles > 1 ? 's' : ''}) reste enregistré si vous y revenez.';

  /// Demande confirmation. Rend `true` si le client accepte de changer.
  static Future<bool> confirmer(
    BuildContext context, {
    required String ancienne,
    required String nouvelle,
    required int articles,
  }) async {
    final accepte = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.shopping_basket_outlined),
        title: Text('Passer à $nouvelle ?'),
        content: Text(confirmation(ancienne: ancienne, nouvelle: nouvelle, articles: articles)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Rester sur $ancienne'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Changer de cuisine'),
          ),
        ],
      ),
    );
    return accepte ?? false;
  }
}

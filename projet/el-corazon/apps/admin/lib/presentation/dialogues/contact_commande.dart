import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:admin/presentation/commande.dart';
import 'package:admin/utils/dialog_helper.dart';

/// Joindre le destinataire d'une commande, et la situer sur une carte.
///
/// Pourquoi ce fichier existe
/// --------------------------
///
/// Ces deux gestes n'existaient que dans `order_management_screen`, l'écran de
/// supervision **secondaire** — celui qu'aucune entrée de menu n'ouvrait. Ils
/// sont exactement ce dont on a besoin quand une livraison coince, et ils
/// étaient hors d'atteinte depuis l'écran que l'exploitation utilise.
///
/// Les extraire plutôt que les recopier dans l'écran unifié : c'est la
/// condition pour supprimer l'ancien sans rien perdre.
///
/// Le destinataire est celui de la **commande**, pas le titulaire du compte :
/// on commande pour un collègue, pour ses parents. Appeler le titulaire dans ce
/// cas fait tomber sur quelqu'un qui n'attend rien.
Future<void> contacterLeDestinataire(
  BuildContext context,
  eccore.Order order,
) async {
  final telephone = order.recipientPhone.trim();
  final nom = order.recipientName.isEmpty ? 'le client' : order.recipientName;

  if (telephone.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Aucun numéro sur cette commande : $nom n’a pas laissé de téléphone.',
        ),
      ),
    );
    return;
  }

  final action = await DialogHelper.showSafeDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Contacter $nom'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: const Icon(Icons.phone),
            title: const Text('Appeler'),
            subtitle: Text(telephone),
            onTap: () => Navigator.of(context).pop('tel'),
          ),
          ListTile(
            leading: const Icon(Icons.sms),
            title: const Text('Envoyer un SMS'),
            subtitle: Text(telephone),
            onTap: () => Navigator.of(context).pop('sms'),
          ),
          // L'adresse électronique n'est pas sur la commande, et ce n'est pas
          // un oubli : écrire au titulaire d'un compte à propos d'une
          // livraison faite pour un tiers n'a pas de destinataire évident.
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
      ],
    ),
  );

  if (action == null || !context.mounted) return;

  await _ouvrir(
    context,
    Uri.parse('$action:$telephone'),
    action == 'tel'
        ? 'Impossible d’ouvrir l’application téléphone.'
        : 'Impossible d’ouvrir l’application de messages.',
  );
}

/// Ouvre l'adresse de livraison dans une carte.
///
/// Par recherche d'adresse et non par coordonnées : la commande porte bien un
/// point (`delivery_location`), mais l'opérateur qui ouvre une carte cherche
/// à lire un nom de rue et à le dicter à un livreur — une épingle sans libellé
/// ne lui sert à rien.
Future<void> situerLaCommande(BuildContext context, eccore.Order order) async {
  final adresse = Uri.encodeComponent(order.adresseComplete);
  await _ouvrir(
    context,
    Uri.parse('https://www.google.com/maps/search/?api=1&query=$adresse'),
    'Impossible d’ouvrir la carte.',
    externe: true,
  );
}

Future<void> _ouvrir(
  BuildContext context,
  Uri uri,
  String echec, {
  bool externe = false,
}) async {
  // `canLaunchUrl` avant `launchUrl` : sur bureau, un `tel:` sans application
  // associée lève, et l'exception remonterait jusqu'à la console sans que
  // l'opérateur comprenne pourquoi rien ne s'est passé.
  final possible = await canLaunchUrl(uri);
  if (!context.mounted) return;

  if (!possible) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(echec)));
    return;
  }

  await launchUrl(
    uri,
    mode: externe ? LaunchMode.externalApplication : LaunchMode.platformDefault,
  );
}

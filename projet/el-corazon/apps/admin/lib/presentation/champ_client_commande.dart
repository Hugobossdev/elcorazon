import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/services/client_management_service.dart';

/// Les clients qu'une saisie désigne : nom, adresse électronique ou téléphone.
///
/// Sans accent ni casse — « eloise » doit trouver « Éloïse ». Plafonné : la
/// liste suggérée tient sous le champ, et au-delà de huit noms on précise sa
/// saisie plutôt qu'on ne fait défiler.
List<eccore.Customer> clientsCorrespondants(
  Iterable<eccore.Customer> clients,
  String saisie, {
  int plafond = 8,
}) {
  final cle = _normaliser(saisie.trim());
  if (cle.isEmpty) return const [];
  return clients
      .where(
        (client) =>
            _normaliser(client.fullName).contains(cle) ||
            _normaliser(client.email).contains(cle) ||
            (client.phone ?? '').replaceAll(' ', '').contains(cle.replaceAll(' ', '')),
      )
      .take(plafond)
      .toList(growable: false);
}

String _normaliser(String texte) {
  const accents = {
    'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a',
    'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
    'î': 'i', 'ï': 'i', 'í': 'i',
    'ô': 'o', 'ö': 'o', 'ó': 'o',
    'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u',
    'ç': 'c', 'ñ': 'n',
  };
  final bas = texte.toLowerCase();
  final sortie = StringBuffer();
  for (final lettre in bas.split('')) {
    sortie.write(accents[lettre] ?? lettre);
  }
  return sortie.toString();
}

/// Choisit le client dont on veut voir les commandes, ou montre celui qui est
/// retenu.
///
/// La recherche porte sur la liste que `ClientManagementService` tient déjà :
/// elle se charge à l'ouverture du back-office, et une requête par frappe
/// ferait, pour le même résultat, un aller-retour par lettre.
class ChampClientDeCommande extends StatefulWidget {
  const ChampClientDeCommande({
    required this.clientId,
    required this.clientNom,
    required this.onChoisi,
    super.key,
  });

  final String? clientId;
  final String? clientNom;

  /// `null` retire le filtre.
  final ValueChanged<eccore.Customer?> onChoisi;

  @override
  State<ChampClientDeCommande> createState() => _ChampClientDeCommandeState();
}

class _ChampClientDeCommandeState extends State<ChampClientDeCommande> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ClientManagementService>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.clientId != null) {
      return InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Client',
          border: OutlineInputBorder(),
        ),
        child: Wrap(
          children: [
            InputChip(
              avatar: const Icon(Icons.person_rounded, size: 18),
              label: Text(widget.clientNom ?? 'Client retenu'),
              onDeleted: () => widget.onChoisi(null),
              deleteButtonTooltipMessage: 'Toute la clientèle',
            ),
          ],
        ),
      );
    }

    final clients = context.watch<ClientManagementService>().clients;
    return Autocomplete<eccore.Customer>(
      optionsBuilder: (saisie) => clientsCorrespondants(clients, saisie.text),
      displayStringForOption: (client) => client.fullName,
      onSelected: widget.onChoisi,
      fieldViewBuilder: (context, controleur, focus, valider) => TextField(
        controller: controleur,
        focusNode: focus,
        decoration: const InputDecoration(
          labelText: 'Client',
          hintText: 'Nom, e-mail ou téléphone',
          prefixIcon: Icon(Icons.person_search_rounded),
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => valider(),
      ),
      optionsViewBuilder: (context, choisir, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280, maxWidth: 420),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                for (final client in options)
                  ListTile(
                    dense: true,
                    title: Text(client.fullName),
                    subtitle: Text(
                      [client.email, if (client.phone != null) client.phone!].join(' · '),
                    ),
                    onTap: () => choisir(client),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

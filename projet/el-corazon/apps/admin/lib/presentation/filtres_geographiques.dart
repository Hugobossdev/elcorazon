import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/material.dart';

import 'package:admin/presentation/filtres_supervision.dart';
import 'package:admin/services/delivery_zone_service.dart';

/// Une option de filtre géographique : la valeur envoyée, le libellé affiché.
typedef OptionGeographique = ({String valeur, String libelle});

/// Ce que chaque étage du filtre propose, **dérivé de ce que le compte voit**.
///
/// Pur, sans widget : c'est la règle qui décide qu'on ne propose pas « Abidjan »
/// sous « Togo », et elle se vérifie sans monter un écran.
abstract final class OptionsGeographiques {
  /// Les pays des cuisines du périmètre, sans doublon, triés.
  static List<OptionGeographique> pays(List<eccore.ManagedRestaurant> cuisines) {
    final vus = <String>{};
    return [
      for (final cuisine in cuisines)
        if (cuisine.countryIsoCode.isNotEmpty && vus.add(cuisine.countryIsoCode))
          (valeur: cuisine.countryIsoCode, libelle: cuisine.countryIsoCode),
    ]..sort((a, b) => a.libelle.compareTo(b.libelle));
  }

  /// Les villes des cuisines du périmètre, restreintes au pays retenu.
  static List<OptionGeographique> villes(
    List<eccore.ManagedRestaurant> cuisines, {
    String? paysIso,
  }) {
    final vues = <String>{};
    return [
      for (final cuisine in cuisines)
        if (cuisine.citySlug.isNotEmpty &&
            (paysIso == null || cuisine.countryIsoCode == paysIso) &&
            vues.add(cuisine.citySlug))
          (valeur: cuisine.citySlug, libelle: cuisine.cityName),
    ]..sort((a, b) => a.libelle.compareTo(b.libelle));
  }

  /// Les zones de la ville retenue — rien tant qu'aucune ville ne l'est.
  ///
  /// Proposer toutes les zones du réseau sans ville mêlerait trois « Centre »
  /// de trois villes, qu'aucun libellé ne permettrait de distinguer.
  static List<OptionGeographique> zones(
    List<DeliveryZone> zones,
    String Function(String cityId) nomDeVille, {
    String? nomVille,
  }) {
    if (nomVille == null) return const [];
    return [
      for (final zone in zones)
        if (nomDeVille(zone.cityId) == nomVille) (valeur: zone.id, libelle: zone.name),
    ]..sort((a, b) => a.libelle.compareTo(b.libelle));
  }
}

/// Pays → ville → zone, dans la boîte de filtres de la supervision.
///
/// Chaque étage ne propose que ce que l'étage du dessus contient, et changer un
/// étage efface ceux d'en dessous (`FiltresCommandes.copyWith`). Les menus sont
/// reconstruits sur leur valeur — sans quoi un menu garde affichée une ville
/// que le changement de pays vient d'effacer.
class FiltresGeographiques extends StatelessWidget {
  const FiltresGeographiques({
    required this.filtres,
    required this.etablissements,
    required this.zones,
    required this.onChange,
    super.key,
  });

  final FiltresCommandes filtres;
  final List<eccore.ManagedRestaurant> etablissements;
  final DeliveryZoneService zones;
  final ValueChanged<FiltresCommandes> onChange;

  @override
  Widget build(BuildContext context) {
    final pays = OptionsGeographiques.pays(etablissements);
    final villes = OptionsGeographiques.villes(etablissements, paysIso: filtres.paysIso);
    final villeRetenue = villes.where((v) => v.valeur == filtres.villeSlug).firstOrNull;
    final zonesDeLaVille = OptionsGeographiques.zones(
      zones.zones,
      zones.cityName,
      nomVille: villeRetenue?.libelle,
    );

    // Un réseau d'un seul pays et d'une seule ville n'a rien à filtrer ici.
    if (pays.length <= 1 && villes.length <= 1 && zonesDeLaVille.isEmpty && filtres.villeSlug == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pays.length > 1) ...[
          _Menu(
            cle: 'pays-${filtres.paysIso}',
            libelle: 'Pays',
            tous: 'Tous les pays',
            valeur: filtres.paysIso,
            options: pays,
            onChange: (iso) => onChange(filtres.copyWith(paysIso: iso, effacerPays: iso == null)),
          ),
          const SizedBox(height: 16),
        ],
        _Menu(
          cle: 'ville-${filtres.paysIso}-${filtres.villeSlug}',
          libelle: 'Ville',
          tous: 'Toutes les villes',
          valeur: filtres.villeSlug,
          options: villes,
          onChange: (slug) =>
              onChange(filtres.copyWith(villeSlug: slug, effacerVille: slug == null)),
        ),
        const SizedBox(height: 16),
        if (villeRetenue != null) ...[
          _Menu(
            cle: 'zone-${filtres.villeSlug}-${filtres.zoneId}',
            libelle: 'Zone de livraison',
            tous: 'Toutes les zones de ${villeRetenue.libelle}',
            valeur: filtres.zoneId,
            options: zonesDeLaVille,
            onChange: (id) => onChange(filtres.copyWith(zoneId: id, effacerZone: id == null)),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu({
    required this.cle,
    required this.libelle,
    required this.tous,
    required this.valeur,
    required this.options,
    required this.onChange,
  });

  final String cle;
  final String libelle;
  final String tous;
  final String? valeur;
  final List<OptionGeographique> options;
  final ValueChanged<String?> onChange;

  @override
  Widget build(BuildContext context) {
    // Une valeur qui n'est plus proposée — une zone désactivée depuis — ferait
    // lever le menu : elle s'affiche alors comme « tous ».
    final connue = options.any((o) => o.valeur == valeur) ? valeur : null;
    return DropdownButtonFormField<String?>(
      key: ValueKey(cle),
      initialValue: connue,
      isExpanded: true,
      decoration: InputDecoration(labelText: libelle, border: const OutlineInputBorder()),
      items: [
        DropdownMenuItem<String?>(child: Text(tous)),
        for (final option in options)
          DropdownMenuItem(value: option.valeur, child: Text(option.libelle)),
      ],
      onChanged: onChange,
    );
  }
}

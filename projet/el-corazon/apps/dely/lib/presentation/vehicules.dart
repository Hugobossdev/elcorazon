import 'package:flutter/material.dart';

/// Les véhicules qu'un livreur peut déclarer — `VehicleType` côté serveur.
///
/// ## Pourquoi cette table est ici, et pas dans un écran
///
/// Elle vivait en dur dans le formulaire d'inscription, et l'écran de profil
/// n'en avait aucune : il affichait la **valeur brute du contrat** dans un
/// champ intitulé « Véhicule ». Un livreur y lisait donc `motorcycle`, quand le
/// formulaire qu'il avait rempli la veille lui proposait « Moto ». Deux écrans,
/// deux vocabulaires pour la même donnée.
///
/// ## Ce que ces valeurs sont
///
/// [code] est un **identifiant d'API**, pas un libellé : c'est ce que le
/// serveur accepte, et le traduire à l'envoi ferait refuser la requête. Le
/// français ne sort jamais d'ici.
enum Vehicule {
  moto(code: 'motorcycle', libelle: 'Moto', icone: Icons.two_wheeler),
  scooter(code: 'scooter', libelle: 'Scooter', icone: Icons.electric_scooter),
  velo(code: 'bicycle', libelle: 'Vélo', icone: Icons.pedal_bike),
  voiture(code: 'car', libelle: 'Voiture', icone: Icons.directions_car);

  const Vehicule({required this.code, required this.libelle, required this.icone});

  /// La valeur transmise au serveur (`VehicleType`).
  final String code;

  final String libelle;
  final IconData icone;

  /// Le véhicule correspondant à ce que le serveur a rendu, ou `null`.
  ///
  /// `null` plutôt qu'un repli sur « Moto » : une valeur que cette version de
  /// l'application ne connaît pas — un type ajouté au serveur depuis — doit
  /// s'afficher telle quelle plutôt que d'être remplacée par une autre. Un
  /// livreur ne doit jamais lire « Moto » sur un dossier qui dit autre chose.
  static Vehicule? depuisServeur(String? code) {
    for (final vehicule in Vehicule.values) {
      if (vehicule.code == code) return vehicule;
    }
    return null;
  }

  /// Ce qu'on affiche pour [code], même inconnu de cette version.
  static String libelleDe(String? code) =>
      depuisServeur(code)?.libelle ?? (code == null || code.isEmpty ? '—' : code);
}

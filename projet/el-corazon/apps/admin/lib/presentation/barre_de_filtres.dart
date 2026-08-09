import 'package:flutter/material.dart';

import 'package:admin/presentation/filtres_commandes.dart';

/// La barre de recherche et les deux listes déroulantes de
/// `order_management_screen.dart`.
///
/// Pourquoi ce fichier existe
/// --------------------------
///
/// 247 lignes de décoration pour trois contrôles. La barre ne décide de rien :
/// elle rend ce qu'on lui donne et signale ce que l'opérateur touche. Ce que
/// les trois valeurs filtrent est dans `filtres_commandes.dart`, et testé.
class BarreDeFiltres extends StatelessWidget {
  const BarreDeFiltres({
    required this.recherche,
    required this.fenetre,
    required this.zone,
    required this.surRecherche,
    required this.surFenetre,
    required this.surZone,
    super.key,
  });

  final TextEditingController recherche;
  final FenetreCommandes fenetre;
  final ZoneCommandes zone;

  /// Appelé à chaque frappe : la liste se refiltre au fil de la saisie.
  final VoidCallback surRecherche;

  final ValueChanged<FenetreCommandes> surFenetre;
  final ValueChanged<ZoneCommandes> surZone;

  @override
    Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        scheme.tertiary,
                        scheme.tertiary.withValues(alpha: 0.70),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    color: scheme.onTertiary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Filtres de recherche',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: scheme.onSurface,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Search bar
            TextField(
              controller: recherche,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                labelText: 'Rechercher une commande',
                hintText: 'ID, adresse...',
                labelStyle: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
                hintStyle: TextStyle(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: scheme.tertiary,
                ),
                filled: true,
                fillColor: scheme.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: scheme.outline.withValues(alpha: 0.30),
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: scheme.tertiary,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
              ),
              onChanged: (value) {
                surRecherche();
                // Charger les noms de clients manquants si nécessaire
              },
            ),
            const SizedBox(height: 20),

            // Filters row
            Row(
              children: [
                // Time range filter
                Expanded(
                  child: DropdownButtonFormField<FenetreCommandes>(
                    initialValue: fenetre,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Période',
                      labelStyle: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                      filled: true,
                      fillColor: scheme.surfaceContainerHigh,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: scheme.outline.withValues(alpha: 0.30),
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: scheme.tertiary,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    items: [
                      for (final choix in FenetreCommandes.values)
                        DropdownMenuItem(
                          value: choix,
                          child: Text(choix.libelle),
                        ),
                    ],
                    dropdownColor: scheme.surfaceContainerHigh,
                    onChanged: (choix) {
                      if (choix == null) return;
                      surFenetre(choix);
                    },
                  ),
                ),
                const SizedBox(width: 16),

                // Zone filter
                Expanded(
                  child: DropdownButtonFormField<ZoneCommandes>(
                    initialValue: zone,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Zone',
                      labelStyle: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                      filled: true,
                      fillColor: scheme.surfaceContainerHigh,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: scheme.outline.withValues(alpha: 0.30),
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: scheme.tertiary,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    items: [
                      for (final choix in ZoneCommandes.values)
                        DropdownMenuItem(
                          value: choix,
                          child: Text(choix.libelle),
                        ),
                    ],
                    dropdownColor: scheme.surfaceContainerHigh,
                    onChanged: (choix) {
                      if (choix == null) return;
                      surZone(choix);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


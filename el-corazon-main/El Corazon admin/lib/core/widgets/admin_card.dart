import 'package:flutter/material.dart';
import '../constants/admin_constants.dart';

/// Widget Card professionnel et réutilisable pour l'application admin
///
/// Ce widget garantit que tous les widgets interactifs ont une taille définie
/// avant d'être rendus, évitant ainsi l'erreur "Cannot hit test a render box
/// that has never been laid out".
class AdminCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final double? elevation;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final bool showShadow;
  final Gradient? gradient;

  const AdminCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.elevation,
    this.borderRadius,
    this.onTap,
    this.showShadow = true,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    // Définition du contenu de la carte avec padding et décoration
    // Le Container garantit que le widget a des contraintes de taille
    final cardContent = Container(
      // Le padding garantit un espace interne minimal, créant une taille minimale
      padding: padding ?? const EdgeInsets.all(AdminConstants.cardPadding),
      // La décoration avec BoxDecoration garantit que le widget a une forme définie
      decoration: BoxDecoration(
        // Utilisation de la couleur de fond si pas de gradient, sinon transparent
        color: gradient == null ? (color ?? Theme.of(context).cardColor) : null,
        // Gradient optionnel pour un style personnalisé
        gradient: gradient,
        // BorderRadius pour arrondir les coins
        borderRadius: borderRadius ??
            BorderRadius.circular(AdminConstants.borderRadiusMD),
        // Ombre portée optionnelle pour donner de la profondeur
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      // L'enfant est placé dans le Container qui a maintenant des contraintes
      child: child,
    );

    // Si onTap est fourni, on utilise un widget interactif (InkWell)
    if (onTap != null) {
      // IMPORTANT: Material est nécessaire pour InkWell pour le hit testing
      // Material garantit que le widget a une taille et peut être hit testé
      return Material(
        // Couleur transparente pour que le gradient/décoration soit visible
        color: Colors.transparent,
        // BorderRadius pour correspondre à la décoration
        borderRadius: borderRadius ??
            BorderRadius.circular(AdminConstants.borderRadiusMD),
        child: InkWell(
          // Callback appelé après que le widget soit complètement rendu
          onTap: onTap,
          // BorderRadius pour l'effet de splash
          borderRadius: borderRadius ??
              BorderRadius.circular(AdminConstants.borderRadiusMD),
          // Le cardContent a maintenant des contraintes de taille définies
          // grâce au Container, donc InkWell peut le hit tester correctement
          child: cardContent,
        ),
      );
    }

    // Si pas de onTap, on utilise un Card standard
    return Card(
      elevation: elevation ?? AdminConstants.cardElevation,
      margin: margin ?? EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius ??
            BorderRadius.circular(AdminConstants.borderRadiusMD),
      ),
      // Si gradient est fourni, on rend le Card transparent et on utilise cardContent
      // Sinon, on utilise cardContent qui a déjà la couleur par défaut
      color: gradient != null ? Colors.transparent : null,
      // Toujours utiliser cardContent qui garantit une taille définie
      child: cardContent,
    );
  }
}

/// Widget Card avec header et footer optionnels
///
/// Ce widget garantit que tous les enfants ont une taille définie
/// grâce à l'utilisation de Container et Padding qui fournissent des contraintes.
class AdminCardWithHeader extends StatelessWidget {
  final Widget? header;
  final Widget child;
  final Widget? footer;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  const AdminCardWithHeader({
    super.key,
    this.header,
    required this.child,
    this.footer,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Utilisation d'AdminCard qui garantit déjà une taille définie
    return AdminCard(
      // Padding zéro car on gère le padding dans les sections individuelles
      padding: EdgeInsets.zero,
      margin: margin,
      color: backgroundColor,
      onTap: onTap,
      // Container avec width garantit une taille définie
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(
          minHeight: 50,
        ),
        // Column avec mainAxisSize.min pour prendre seulement l'espace nécessaire
        child: Column(
          // Stretch pour que tous les enfants prennent toute la largeur disponible
          crossAxisAlignment: CrossAxisAlignment.stretch,
          // min pour que la Column prenne seulement la hauteur nécessaire
          mainAxisSize: MainAxisSize.min,
        children: [
          // Header optionnel avec séparateur en bas
          if (header != null) ...[
            // Container garantit une taille définie pour le header
            Container(
              padding:
                  padding ?? const EdgeInsets.all(AdminConstants.cardPadding),
              // Décoration avec bordure inférieure pour séparer le header
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color:
                        Theme.of(context).dividerColor.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
              ),
              // Le header a maintenant des contraintes de taille grâce au Container
              child: header!,
            ),
          ],
          // Contenu principal avec padding
          Padding(
            padding:
                padding ?? const EdgeInsets.all(AdminConstants.cardPadding),
            // Padding garantit un espacement et des contraintes de taille
            child: child,
          ),
          // Footer optionnel avec séparateur en haut
          if (footer != null) ...[
            // Container garantit une taille définie pour le footer
            Container(
              padding:
                  padding ?? const EdgeInsets.all(AdminConstants.cardPadding),
              // Décoration avec bordure supérieure pour séparer le footer
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color:
                        Theme.of(context).dividerColor.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
              ),
              // Le footer a maintenant des contraintes de taille grâce au Container
              child: footer!,
            ),
          ],
        ],
      ),
      ),
    );
  }
}

/// Widget Card de statistique pour le dashboard
///
/// Ce widget garantit que tous les éléments ont une taille définie
/// grâce à l'utilisation de Container pour les éléments interactifs.
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final String? trend;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.trend,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Utilisation d'AdminCard qui garantit déjà une taille définie
    return AdminCard(
      // Callback onTap géré par AdminCard qui utilise Material + InkWell
      // Cela garantit que le hit testing se fait après le layout
      onTap: onTap,
      // IMPORTANT: Container avec width et constraints garantit une taille définie
      // Cela évite l'erreur "Cannot hit test a render box with no size"
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(
          minHeight: 100,
        ),
        child: Column(
          // Alignement à gauche pour le contenu
          crossAxisAlignment: CrossAxisAlignment.start,
          // Centrage vertical du contenu
          mainAxisAlignment: MainAxisAlignment.center,
          // min pour que la Column prenne seulement la hauteur nécessaire
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row pour l'icône et le trend (côte à côte)
            Row(
              // Espacement entre les éléments
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Container pour l'icône avec padding et décoration
                // Container garantit une taille définie pour l'icône
                Container(
                  padding: const EdgeInsets.all(AdminConstants.spacingSM),
                  // Décoration avec couleur de fond et coins arrondis
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius:
                        BorderRadius.circular(AdminConstants.borderRadiusSM),
                  ),
                  // L'icône a maintenant des contraintes de taille grâce au Container
                  child:
                      Icon(icon, color: color, size: AdminConstants.iconSizeMD),
                ),
                // Trend optionnel affiché à droite
                if (trend != null)
                  // Container garantit une taille définie pour le trend
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AdminConstants.spacingSM,
                      vertical: 4,
                    ),
                    // Décoration avec couleur verte pour le trend
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(AdminConstants.borderRadiusSM),
                    ),
                    // Le Text a maintenant des contraintes de taille grâce au Container
                    child: Text(
                      trend!,
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            // Espacement vertical entre l'icône/trend et la valeur
            const SizedBox(height: AdminConstants.spacingMD),
            // Valeur principale (grande taille)
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
            // Espacement vertical entre la valeur et le titre
            const SizedBox(height: AdminConstants.spacingXS),
            // Titre de la statistique
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
            // Sous-titre optionnel
            if (subtitle != null) ...[
              // Espacement vertical entre le titre et le sous-titre
              const SizedBox(height: AdminConstants.spacingXS),
              // Sous-titre avec style plus petit et plus transparent
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// EXEMPLE COMMENTÉ : Gestion correcte du curseur et des clics après le layout
// ============================================================================
//
// Si vous devez utiliser findRenderObject() ou localToGlobal() dans votre code,
// voici la bonne méthode pour éviter l'erreur "Cannot hit test a render box":
//
// Exemple 1: Utiliser WidgetsBinding.instance.addPostFrameCallback
// ```dart
// class MyWidget extends StatefulWidget {
//   @override
//   State<MyWidget> createState() => _MyWidgetState();
// }
//
// class _MyWidgetState extends State<MyWidget> {
//   final GlobalKey _key = GlobalKey();
//
//   @override
//   void initState() {
//     super.initState();
//     // NE JAMAIS appeler findRenderObject() directement dans initState()
//     // Attendre que le widget soit complètement rendu
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       // Maintenant le widget est complètement rendu et a une taille
//       final RenderBox? renderBox = _key.currentContext?.findRenderObject() as RenderBox?;
//       if (renderBox != null && renderBox.hasSize) {
//         // Vous pouvez maintenant utiliser renderBox en toute sécurité
//         final size = renderBox.size;
//         final position = renderBox.localToGlobal(Offset.zero);
//         print('Widget size: $size, position: $position');
//       }
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       key: _key, // Clé pour accéder au RenderBox
//       width: 200,
//       height: 100,
//       color: Colors.blue,
//       child: GestureDetector(
//         // GestureDetector fonctionne car le Container a une taille définie
//         onTap: () {
//           // Accéder au RenderBox après un événement utilisateur est sûr
//           final RenderBox? renderBox = _key.currentContext?.findRenderObject() as RenderBox?;
//           if (renderBox != null && renderBox.hasSize) {
//             // Faire quelque chose avec renderBox
//           }
//         },
//         child: Text('Click me'),
//       ),
//     );
//   }
// }
// ```
//
// Exemple 2: Utiliser Material + InkWell pour les cartes cliquables
// ```dart
// Material(
//   color: Colors.transparent,
//   child: InkWell(
//     onTap: () {
//       // Le callback est appelé après le layout complet
//       print('Card tapped');
//     },
//     borderRadius: BorderRadius.circular(8),
//     child: Container(
//       // Container garantit une taille définie
//       padding: EdgeInsets.all(16),
//       child: Text('Clickable card'),
//     ),
//   ),
// )
// ```
//
// Exemple 3: Utiliser MouseRegion pour détecter le curseur
// ```dart
// MouseRegion(
//   onEnter: (_) {
//     // Appelé après le layout, donc le widget a une taille
//     print('Mouse entered');
//   },
//   child: Container(
//     // Container garantit une taille définie pour le hit testing
//     width: 200,
//     height: 100,
//     color: Colors.blue,
//     child: Text('Hover me'),
//   ),
// )
// ```
//
// Points importants à retenir:
// 1. Toujours utiliser Container, SizedBox, ou Expanded pour définir une taille
// 2. Ne jamais appeler findRenderObject() dans initState() directement
// 3. Utiliser WidgetsBinding.instance.addPostFrameCallback() pour accéder au RenderBox
// 4. Material est nécessaire pour InkWell pour le hit testing correct
// 5. Les widgets interactifs (GestureDetector, MouseRegion, InkWell) doivent avoir des contraintes de taille
// ============================================================================

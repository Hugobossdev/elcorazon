import 'package:flutter/material.dart';

import 'package:admin/models/order.dart';
import 'package:admin/presentation/anciennete_commande.dart';
import 'package:admin/presentation/chronologie_commande.dart';
import 'package:admin/utils/price_formatter.dart';

/// Ce que montre une commande dépliée dans `order_management_screen.dart`.
///
/// Pourquoi ce fichier existe
/// --------------------------
///
/// Cinq méthodes de l'écran, 400 lignes, dessinaient les trois panneaux qui
/// s'ouvrent sous une commande. Aucune ne lisait l'état de l'écran.
///
/// Les couleurs sont **écrites en dur** — `0xFF2C2C2C`, `Colors.white`,
/// l'orange `0xFFFF6A00`. Cet écran est peint sombre quel que soit le thème.
/// Elles sont reprises telles quelles : les brancher sur `ColorScheme`
/// changerait ce que voient les utilisateurs, et cela ne se décide pas dans un
/// refactoring.
class _Palette {
  static const fond = Color(0xFF2C2C2C);
  static const fondArticle = Color(0xFF1E1E1E);
  static const accent = Color(0xFFFF6A00);
  static const accentClair = Color(0xFFFF8A50);
  static const franchi = Color(0xFF4CAF50);
  static const eteint = Color(0xFF666666);
}

/// Un panneau sombre à coins arrondis, coiffé de son titre.
class _Panneau extends StatelessWidget {
  const _Panneau({required this.titre, required this.enfants});

  final String titre;
  final List<Widget> enfants;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _Palette.fond,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              titre,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),
            ...enfants,
          ],
        ),
      ),
    );
  }
}

class DetailsCommande extends StatelessWidget {
  const DetailsCommande({required this.order, super.key});

  final Order order;

  /// Le destinataire, ou la référence à défaut.
  ///
  /// La ligne « Client: » affichait `order.id` — la référence de la commande
  /// sous une étiquette qui annonce une personne. `recipientName` est ce que
  /// l'étiquette promet ; le repli sur la référence garde le comportement
  /// d'avant quand le nom manque.
  String get _client =>
      order.recipientName.isNotEmpty ? order.recipientName : order.id;

  @override
  Widget build(BuildContext context) {
    return _Panneau(
      titre: 'Détails de la commande',
      enfants: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  LigneDeDetail('Client:', _client, Icons.person),
                  const SizedBox(height: 12),
                  LigneDeDetail(
                    'Adresse:',
                    order.deliveryAddress,
                    Icons.location_on,
                  ),
                  const SizedBox(height: 12),
                  LigneDeDetail(
                    'Paiement:',
                    order.paymentMethod.displayName,
                    Icons.payment,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  LigneDeDetail(
                    'Sous-total:',
                    PriceFormatter.format(order.subtotal),
                    Icons.receipt,
                  ),
                  const SizedBox(height: 12),
                  LigneDeDetail(
                    'Livraison:',
                    PriceFormatter.format(order.deliveryFee),
                    Icons.local_shipping,
                  ),
                  const SizedBox(height: 12),
                  LigneDeDetail(
                    'Total:',
                    PriceFormatter.format(order.total),
                    Icons.monetization_on,
                    enGras: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Une icône orange, une étiquette pâle, une valeur.
///
/// Publique parce que la fenêtre de détail de
/// `order_management_screen.dart` s'en sert aussi.
class LigneDeDetail extends StatelessWidget {
  const LigneDeDetail(
    this.label,
    this.valeur,
    this.icone, {
    this.enGras = false,
    super.key,
  });

  final String label;
  final String valeur;
  final IconData icone;
  final bool enGras;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icone, size: 18, color: _Palette.accent),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              children: [
                TextSpan(
                  text: '$label ',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                ),
                TextSpan(
                  text: valeur,
                  style: TextStyle(
                    fontWeight: enGras ? FontWeight.w700 : FontWeight.w600,
                    color: enGras ? _Palette.accent : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ArticlesCommande extends StatelessWidget {
  const ArticlesCommande({required this.order, super.key});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return _Panneau(
      titre: 'Articles commandés',
      enfants: [
        for (final item in order.items) _CarteArticle(item: item),
      ],
    );
  }
}

class _CarteArticle extends StatelessWidget {
  const _CarteArticle({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    final personnalisations = item.getFormattedCustomizations();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Palette.fondArticle.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Palette.accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_Palette.accent, _Palette.accentClair],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${item.quantity}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${PriceFormatter.format(item.unitPrice)} × '
                      '${item.quantity}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  PriceFormatter.format(item.totalPrice),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: _Palette.accent,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          if (personnalisations.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Personnalisations(choix: personnalisations),
          ],
          if (item.notes != null && item.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _NoteArticle(note: item.notes!),
          ],
        ],
      ),
    );
  }
}

class _Personnalisations extends StatelessWidget {
  const _Personnalisations({required this.choix});

  final List<String> choix;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tune,
                size: 16,
                color: _Palette.accent.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 6),
              Text(
                'Personnalisations',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final custom in choix)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.only(top: 6, right: 8),
                    decoration: const BoxDecoration(
                      color: _Palette.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      custom,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _NoteArticle extends StatelessWidget {
  const _NoteArticle({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.note, size: 16, color: Colors.blue.withValues(alpha: 0.8)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              note,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.8),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// L'historique d'une commande — dont les heures sont fabriquées.
///
/// Voir [chronologieDe] : ce panneau affiche des instants qui ne
/// correspondent à rien de mesuré.
class ChronologieCommande extends StatelessWidget {
  const ChronologieCommande({required this.order, super.key});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return _Panneau(
      titre: 'Historique de la commande',
      enfants: [
        for (final etape in chronologieDe(order)) _LigneChronologie(etape: etape),
      ],
    );
  }
}

class _LigneChronologie extends StatelessWidget {
  const _LigneChronologie({required this.etape});

  final EtapeCommande etape;

  @override
  Widget build(BuildContext context) {
    final franchie = etape.franchie;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: franchie ? _Palette.franchi : Colors.transparent,
              border: Border.all(
                color: franchie ? _Palette.franchi : _Palette.eteint,
                width: 2,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                franchie ? Icons.check : null,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              etape.libelle,
              style: TextStyle(
                color: franchie
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.5),
                fontWeight: franchie ? FontWeight.w700 : FontWeight.w500,
                fontSize: 15,
                letterSpacing: 0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: franchie
                    ? _Palette.franchi.withValues(alpha: 0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                ancienneteCommande(etape.quand),
                style: TextStyle(
                  color: franchie ? _Palette.franchi : _Palette.eteint,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

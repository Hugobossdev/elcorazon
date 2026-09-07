import 'package:elcora_fast/presentation/cle_de_tentative.dart';
import 'package:flutter_test/flutter_test.dart';

/// La clé d'idempotence doit survivre au réessai — et à lui seul.
///
/// ## Le défaut, et pourquoi il était bien caché
///
/// `POST /orders/` exige un en-tête `Idempotency-Key`, et le serveur s'en sert
/// pour rendre la commande déjà créée au lieu d'en créer une seconde
/// (`backend/apps/orders/idempotency.py`). Le socle partagé respecte le
/// contrat : sa méthode prend la clé en paramètre, et son en-tête dit « à
/// générer une fois par tentative côté appelant, **jamais par cette méthode
/// elle-même** ».
///
/// `DjangoOrderRepository` la tirait pourtant lui-même, à chaque appel. Chaque
/// réessai partait donc avec une clé neuve, ce qui vide la garantie de sa
/// substance exactement le jour où elle sert : la requête part, le serveur crée
/// la commande, la réponse se perd, l'écran de caisse invite à réessayer — et
/// une seconde commande est créée et facturée.
///
/// Aucune suite ne pouvait le voir. Le test du socle passe sa propre clé et
/// vérifie qu'elle arrive bien dans l'en-tête : c'est vrai, et cela ne dit rien
/// de qui la fabrique.
void main() {
  group('Une tentative de commande', () {
    test('garde la même clé d’un réessai à l’autre', () {
      final tentative = CleDeTentative();
      final premierEnvoi = tentative.valeur;

      // Le réseau coupe, l'écran invite à réessayer, le client réessaie. Rien
      // n'est signalé à la clé : ce n'est pas une nouvelle intention.
      expect(
        tentative.valeur,
        premierEnvoi,
        reason: 'Une clé neuve au réessai laisse le serveur créer une seconde '
            'commande pour la même intention.',
      );
    });

    test('la garde aussi après un refus métier', () {
      // Panier devenu incommandable, adresse hors zone, code promotionnel
      // expiré : le serveur n'a rien écrit et libère la clé. Le client corrige
      // et réessaie — c'est la même tentative.
      final tentative = CleDeTentative();
      final avant = tentative.valeur;

      expect(tentative.valeur, avant);
    });

    test('la renouvelle une fois la commande créée', () {
      final tentative = CleDeTentative();
      final premiere = tentative.valeur;

      tentative.commandeCreee();

      expect(
        tentative.valeur,
        isNot(premiere),
        reason: 'Sans renouvellement, un client qui recommande depuis cet écran '
            'se verrait rendre sa commande précédente.',
      );
    });

    test('deux tentatives ne partagent jamais la leur', () {
      expect(CleDeTentative().valeur, isNot(CleDeTentative().valeur));
    });

    test('tient dans l’en-tête que le serveur accepte', () {
      // `IdempotencyKey.key` est un `CharField(max_length=255)`. Un UUID v4 y
      // tient très largement ; l'épingler évite qu'une clé composée — panier,
      // horodatage, adresse — s'y glisse un jour et se fasse tronquer.
      final valeur = CleDeTentative().valeur;

      expect(valeur, hasLength(36));
      expect(valeur.length, lessThanOrEqualTo(255));
    });
  });
}

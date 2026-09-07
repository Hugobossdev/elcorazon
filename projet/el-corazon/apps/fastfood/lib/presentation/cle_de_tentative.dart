import 'package:uuid/uuid.dart';

/// La clé d'idempotence d'une **tentative** de commande.
///
/// ## Pourquoi cette chose porte un nom
///
/// `POST /orders/` exige un en-tête `Idempotency-Key`, et le serveur s'en sert
/// pour rendre la commande déjà créée au lieu d'en créer une seconde
/// (`backend/apps/orders/idempotency.py`). La garantie tient à une propriété et
/// une seule : **la clé ne change pas entre l'envoi perdu et le réessai**.
///
/// C'est cette propriété qui manquait. `DjangoOrderRepository` tirait un
/// `Uuid().v4()` à chaque appel, ce que le contrat du socle interdit en toutes
/// lettres — « à générer une fois par tentative côté appelant, *jamais par
/// cette méthode elle-même* ». Chaque réessai partait donc avec une clé neuve,
/// et la garantie était vide précisément le jour où elle sert : la requête part,
/// le serveur crée la commande, la réponse se perd. L'écran de caisse affiche
/// alors « Connexion perdue : votre commande n'a pas été envoyée. Réessayez une
/// fois le réseau revenu » — il **invite** au geste qui produit le doublon.
///
/// Un `String` dans l'état de l'écran suffirait à corriger. Il ne suffit pas à
/// empêcher la rechute : rien n'y dirait quand le renouveler, et « une clé
/// d'idempotence » se renomme, se recopie et se régénère au premier
/// refactoring. Ce type-ci a une seule façon d'être remis à neuf, et elle
/// s'appelle [commandeCreee].
///
/// ## Ce qui borne une tentative
///
/// Elle commence à l'ouverture de la caisse et ne s'achève qu'à une commande
/// **réellement créée**. Un refus métier n'y met pas fin : panier devenu
/// incommandable, adresse hors zone, code promotionnel expiré — le serveur
/// n'a rien écrit (il libère la clé, `release()`), le client corrige, et c'est
/// la même intention de commande qui repart.
class CleDeTentative {
  CleDeTentative() : _valeur = const Uuid().v4();

  /// Pour les tests, qui ont besoin d'une valeur qu'ils reconnaissent.
  CleDeTentative.avec(this._valeur);

  String _valeur;

  /// La valeur à porter dans l'en-tête, tant que la tentative dure.
  String get valeur => _valeur;

  /// La commande est passée : la tentative est close.
  ///
  /// À appeler **après** un succès, et nulle part ailleurs. Sans cela, un client
  /// qui revient en arrière et recommande se verrait rendre sa commande
  /// précédente au lieu d'en passer une nouvelle — le défaut symétrique de
  /// celui qu'on corrige, et tout aussi silencieux.
  void commandeCreee() => _valeur = const Uuid().v4();
}

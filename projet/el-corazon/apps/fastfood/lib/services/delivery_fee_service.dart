import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';

import 'package:elcora_fast/main.dart' show apiClient;
import 'package:elcora_fast/presentation/frais_de_livraison.dart';
import 'package:elcora_fast/services/restaurant_context_service.dart';

/// Frais de livraison — **demandés au serveur**, jamais calculés ici.
///
/// Ce service calculait autrefois lui-même : distance à vol d'oiseau depuis
/// des coordonnées de restaurant écrites en dur, forfait de 500 F, 200 F du
/// kilomètre, franco à 10 000 F, plafond à 5 000 F, le tout doublé d'un cache.
/// Aucune de ces valeurs n'existait côté serveur, qui facture depuis le barème
/// de la zone couvrant le point d'arrivée : l'écran annonçait un prix, la
/// commande en retenait un autre, et c'est le second que le client payait.
///
/// Deux questions, deux routes :
///
/// * [breakdownForPoint] — « livrez-vous ici, par qui, à quel prix, en combien
///   de temps ? », posée par la carte pendant qu'on déplace le repère, avant
///   qu'un panier existe. Elle passe par `delivery-check`, **la même règle de
///   résolution que celle qui facturera** ;
/// * [quoteOrder] / [breakdownForAddress] — « combien coûte cette commande ? »,
///   posée au moment de commander. Même chemin de calcul que la création :
///   franco, minimum de commande et code promotionnel compris.
///
/// Aucune valeur de repli : quand le serveur ne répond pas, l'appelant reçoit
/// l'exception. Un montant inventé en secours est précisément ce qui produisait
/// l'écart entre l'écran et la facture.
class DeliveryFeeService extends ChangeNotifier {
  static final DeliveryFeeService _instance = DeliveryFeeService._internal();
  factory DeliveryFeeService() => _instance;
  DeliveryFeeService._internal();

  /// Construits au premier devis — même raison que dans `CartService` :
  /// `apiClient` lit le conteneur Riverpod monté par `main()`, et l'évaluer
  /// dans l'initialiseur de champ rendait ce service, et tout service qui le
  /// tient, inconstructible hors de l'application lancée.
  late final eccore.OrderRepository _orders =
      eccore.OrderRepository(apiClient: apiClient);
  late final eccore.GeographyRepository _geography =
      eccore.GeographyRepository(apiClient: apiClient);
  late final eccore.DeliveryCheckRepository _livrabilite =
      eccore.DeliveryCheckRepository(apiClient: apiClient);

  eccore.OrderQuote? _lastQuote;
  FraisDeLivraison? _lastBreakdown;

  /// Dernier devis rendu par le serveur, ou `null` tant qu'aucun n'a abouti.
  eccore.OrderQuote? get lastQuote => _lastQuote;
  FraisDeLivraison? get lastBreakdown => _lastBreakdown;

  /// Frais du dernier devis, en unité majeure — pour l'affichage seulement.
  double? get lastCalculatedFee => _lastBreakdown?.totalFee;

  /// Ce point est-il desservi, et par quelle zone ?
  Future<eccore.ZoneResolution> resolveZone({
    required double latitude,
    required double longitude,
  }) {
    return _geography.resolveZone(lat: latitude, lon: longitude);
  }

  /// Livrabilité d'un point de la carte — **par le référentiel unique**.
  ///
  /// ## Ce que ce passage change
  ///
  /// La méthode interrogeait `zones/resolve/`, qui rend **la zone seule**.
  /// L'écran savait donc « oui, une zone couvre ce point » et rien de plus : ni
  /// quel établissement dessert, ni à quelle distance, ni combien de temps au
  /// total, ni — quand la réponse était non — pourquoi. Il affichait « hors
  /// zone » dans les quatre cas de refus, dont trois n'ont rien à voir avec la
  /// zone.
  ///
  /// `delivery-check` répond à la question entière, et c'est la **même** règle
  /// de résolution que celle qui facturera la commande. C'était le défaut le
  /// plus coûteux du couple précédent : l'écran et la facture choisissaient
  /// leur zone par deux critères différents.
  ///
  /// ## Pourquoi l'établissement courant est transmis
  ///
  /// Un panier est ouvert **sur un établissement** : en changer changerait le
  /// catalogue et les prix. On demande donc « cet établissement me livre-t-il
  /// ici ? » et non « quelqu'un me livre-t-il ici ? », dont la réponse pourrait
  /// désigner une autre cuisine et rendre un tarif qui ne sera pas appliqué.
  ///
  /// Tant que rien n'est résolu, le slug est nul et le serveur choisit le plus
  /// proche : c'est le bon comportement au tout premier écran, avant qu'une
  /// cuisine ait été retenue.
  Future<FraisDeLivraison> breakdownForPoint({
    required double latitude,
    required double longitude,
  }) async {
    final reponse = await _livrabilite.check(
      latitude: latitude,
      longitude: longitude,
      restaurantSlug: RestaurantContextService().slug,
    );

    final breakdown = FraisDeLivraison.depuisLivrabilite(reponse);
    _lastBreakdown = breakdown;
    notifyListeners();
    return breakdown;
  }

  /// Devis complet de la commande en cours — sous-total, frais, remise, total.
  ///
  /// Le panier n'est pas transmis : le serveur le relit depuis l'établissement
  /// (invariants C1/C2). [addressId] omis, les frais sont ceux de la zone de
  /// l'établissement, c'est-à-dire un ordre de grandeur tant qu'aucune adresse
  /// n'est choisie.
  Future<eccore.OrderQuote> quoteOrder({String? addressId, String promoCode = ''}) async {
    final quote = await _orders.preview(
      restaurantSlug: await RestaurantContextService().exigerSlug(),
      addressId: addressId,
      promoCode: promoCode,
    );

    _lastQuote = quote;
    notifyListeners();
    return quote;
  }

  /// Devis pour une adresse enregistrée, présenté du point de vue livraison.
  ///
  /// La zone est résolue en plus du devis, pour le nom du secteur et le délai
  /// annoncé : le devis rend des montants, pas le contexte qui les explique.
  Future<FraisDeLivraison> breakdownForAddress({
    required eccore.Address address,
    String promoCode = '',
  }) async {
    final quote = await quoteOrder(addressId: address.id, promoCode: promoCode);

    eccore.DeliveryZone? zone;
    try {
      final reponse = await _livrabilite.check(
        latitude: address.latitude,
        longitude: address.longitude,
        restaurantSlug: RestaurantContextService().slug,
      );
      if (!reponse.isAvailable) {
        // Le refus est relayé **avec sa raison** : « trop loin » et « hors
        // zone » appellent deux gestes différents, et l'écran ne peut plus les
        // confondre.
        final breakdown = FraisDeLivraison.horsZone(raison: reponse.reason);
        _lastBreakdown = breakdown;
        notifyListeners();
        return breakdown;
      }
      zone = reponse.zone;
    } catch (e) {
      // Le devis, lui, a abouti : c'est lui qui fait foi. L'absence de nom
      // de zone n'est pas une raison de renoncer au montant exact.
      eccore.Journal.trace('DeliveryFeeService: livrabilité non résolue — $e');
    }

    final breakdown = FraisDeLivraison.depuisDevis(quote, zone: zone);
    _lastBreakdown = breakdown;
    notifyListeners();
    return breakdown;
  }

  /// Oublie le dernier devis — au vidage du panier, ou à la déconnexion.
  void reset() {
    _lastQuote = null;
    _lastBreakdown = null;
    notifyListeners();
  }
}

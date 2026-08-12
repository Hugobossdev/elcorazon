import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter/foundation.dart';

import 'package:elcora_fast/config/app_constants.dart';
import 'package:elcora_fast/main.dart' show apiClient;
import 'package:elcora_fast/presentation/frais_de_livraison.dart';

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
/// * [resolveZone] / [breakdownForPoint] — « livrez-vous ici ? », posée par la
///   carte pendant qu'on déplace le repère, avant qu'un panier existe ;
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

  final eccore.OrderRepository _orders = eccore.OrderRepository(apiClient: apiClient);
  final eccore.GeographyRepository _geography =
      eccore.GeographyRepository(apiClient: apiClient);

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

  /// Barème applicable à un point de la carte.
  ///
  /// Le montant rendu est le **forfait de base** de la zone : la part liée à
  /// la distance et l'effet du panier ne sont connus que du devis. L'écran de
  /// choix d'adresse n'a pas besoin de plus — il répond « on livre ici, à peu
  /// près à ce prix, en tant de minutes ».
  Future<FraisDeLivraison> breakdownForPoint({
    required double latitude,
    required double longitude,
  }) async {
    final resolution = await resolveZone(latitude: latitude, longitude: longitude);

    final breakdown = resolution.zone == null
        ? FraisDeLivraison.horsZone()
        : FraisDeLivraison.depuisZone(resolution.zone!);

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
      restaurantSlug: AppConstants.restaurantSlug,
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
      final resolution = await resolveZone(
        latitude: address.latitude,
        longitude: address.longitude,
      );
      if (!resolution.isCovered) {
        final breakdown = FraisDeLivraison.horsZone();
        _lastBreakdown = breakdown;
        notifyListeners();
        return breakdown;
      }
      zone = resolution.zone;
    } catch (e) {
      // Le devis, lui, a abouti : c'est lui qui fait foi. L'absence de nom
      // de zone n'est pas une raison de renoncer au montant exact.
      eccore.Journal.trace('DeliveryFeeService: zone non résolue — $e');
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

import 'package:elcora_fast/models/delivery_fee_breakdown.dart';
import 'package:elcorazon_core/elcorazon_core.dart' as eccore;
import 'package:flutter_test/flutter_test.dart';

/// Frais de livraison — ce que l'écran a le droit d'affirmer.
///
/// L'application les calculait elle-même : 500 F de base, 200 F du kilomètre à
/// vol d'oiseau depuis des coordonnées de restaurant écrites en dur, franco à
/// 10 000 F, plafond à 5 000 F. Aucune de ces valeurs n'existait côté serveur,
/// qui facture depuis le barème de la zone couvrant l'adresse de livraison.
/// Ces tests fixent l'unique règle qui reste : **tout montant affiché vient du
/// serveur**, et rien n'est fabriqué quand il n'a pas répondu.
void main() {
  eccore.Money xof(int montant) => eccore.Money(amountMinor: montant, currency: 'XOF');

  eccore.DeliveryZone zone({
    eccore.Money? franco,
    eccore.Money? minimum,
  }) {
    return eccore.DeliveryZone(
      id: 'zone-centre',
      cityId: 'city-lome',
      name: 'Centre-ville',
      baseFee: xof(600),
      feePerKm: xof(150),
      freeDeliveryThreshold: franco,
      minOrderAmount: minimum,
      maxDistanceKm: 12,
      estimatedDeliveryMinutes: 35,
      isActive: true,
    );
  }

  eccore.OrderQuote devis({int frais = 700, int remise = 0}) {
    return eccore.OrderQuote(
      subtotal: xof(5000),
      deliveryFee: xof(frais),
      discount: xof(remise),
      total: xof(5000 + frais - remise),
      isOrderable: true,
    );
  }

  group('Devis de commande', () {
    test('les frais affichés sont ceux du devis, sans recalcul', () {
      final detail = DeliveryFeeBreakdown.fromQuote(devis(frais: 875), zone: zone());

      expect(detail.totalFee, 875);
      expect(detail.isInServiceableZone, isTrue);
      expect(detail.isFreeDelivery, isFalse);
    });

    test('des frais nuls sont une livraison offerte, pas une absence de frais', () {
      final detail = DeliveryFeeBreakdown.fromQuote(devis(frais: 0));

      expect(detail.isFreeDelivery, isTrue);
      expect(detail.freeDeliveryReason, isNotNull);
    });

    test('la zone n’apporte que le contexte : nom, délai et seuils', () {
      final detail = DeliveryFeeBreakdown.fromQuote(
        devis(frais: 900),
        zone: zone(franco: xof(12000), minimum: xof(2000)),
      );

      expect(detail.zoneName, 'Centre-ville');
      expect(detail.estimatedDeliveryTime, 35);
      expect(detail.freeDeliveryThreshold, 12000);
      expect(detail.minOrderAmount, 2000);
      // Le montant reste celui du devis : le forfait de la zone (600) ne s'y
      // substitue pas, il ne décrit pas cette course-ci.
      expect(detail.totalFee, 900);
    });

    test('un devis sans zone reste exploitable', () {
      final detail = DeliveryFeeBreakdown.fromQuote(devis(frais: 900));

      expect(detail.totalFee, 900);
      expect(detail.zoneName, isNull);
      expect(detail.estimatedDeliveryTime, isNull);
    });
  });

  group('Barème d’une zone, sans commande', () {
    test('la carte annonce le forfait de base, pas un prix ferme', () {
      final detail = DeliveryFeeBreakdown.fromZone(zone());

      expect(detail.totalFee, 600);
      expect(detail.estimatedDeliveryTime, 35);
      expect(detail.isInServiceableZone, isTrue);
    });

    test('hors zone : aucun montant, et ce n’est pas une erreur', () {
      final detail = DeliveryFeeBreakdown.notServiceable();

      expect(detail.isInServiceableZone, isFalse);
      expect(detail.totalFee, 0);
      expect(detail.isFreeDelivery, isFalse);
    });
  });

  group('Devises autres que le franc CFA', () {
    test('les centimes ne sont pas perdus en route', () {
      const quote = eccore.OrderQuote(
        subtotal: eccore.Money(amountMinor: 2500, currency: 'EUR'),
        deliveryFee: eccore.Money(amountMinor: 349, currency: 'EUR'),
        discount: eccore.Money(amountMinor: 0, currency: 'EUR'),
        total: eccore.Money(amountMinor: 2849, currency: 'EUR'),
        isOrderable: true,
      );

      expect(DeliveryFeeBreakdown.fromQuote(quote).totalFee, 3.49);
    });
  });
}

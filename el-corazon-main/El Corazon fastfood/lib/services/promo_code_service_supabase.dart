import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PromoCodeService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Valider un code promo
  Future<Map<String, dynamic>?> validatePromoCode(String code, double orderAmount) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _supabase
          .from('promo_codes')
          .select()
          .eq('code', code.toUpperCase())
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) {
        _error = 'Code promo invalide';
        return null;
      }

      // Vérifier la date d'expiration
      if (response['expiry_date'] != null) {
        final expiryDate = DateTime.parse(response['expiry_date']);
        if (DateTime.now().isAfter(expiryDate)) {
          _error = 'Code promo expiré';
          return null;
        }
      }

      // Vérifier le montant minimum
      final minAmount = (response['min_order_amount'] as num?)?.toDouble() ?? 0.0;
      if (orderAmount < minAmount) {
        _error = 'Montant minimum requis: $minAmount';
        return null;
      }

      // Vérifier la limite d'utilisation
      final usageLimit = response['usage_limit'] as int?;
      final usageCount = response['usage_count'] as int? ?? 0;
      if (usageLimit != null && usageCount >= usageLimit) {
        _error = 'Limite d\'utilisation atteinte';
        return null;
      }

      return response;
    } catch (e) {
      _error = 'Erreur lors de la validation du code promo';
      debugPrint('Error validating promo code: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Appliquer un code promo (incrémenter le compteur)
  Future<bool> applyPromoCode(String code) async {
    try {
      final response = await _supabase.rpc('increment_promo_usage', params: {'promo_code': code});
      return response == true;
    } catch (e) {
      debugPrint('Error applying promo code: $e');
      return false;
    }
  }
}


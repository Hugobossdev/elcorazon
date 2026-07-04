import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DriverRatingService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Soumettre une évaluation pour un livreur
  Future<bool> submitRating({
    required String driverId,
    required String orderId,
    required String customerId,
    required int rating,
    String? comment,
  }) async {
    try {
      await _supabase.from('driver_ratings').insert({
        'driver_id': driverId,
        'order_id': orderId,
        'customer_id': customerId,
        'rating': rating,
        'comment': comment,
      });
      return true;
    } catch (e) {
      debugPrint('Error submitting driver rating: $e');
      return false;
    }
  }

  /// Vérifier si une commande a déjà été évaluée
  Future<bool> hasRatedOrder(String orderId) async {
    try {
      final response = await _supabase
          .from('driver_ratings')
          .select('id')
          .eq('order_id', orderId)
          .maybeSingle();
      return response != null;
    } catch (e) {
      debugPrint('Error checking if order is rated: $e');
      return false;
    }
  }

  /// Récupérer la note moyenne d'un livreur
  Future<double?> getDriverAverageRating(String driverId) async {
    try {
      final response = await _supabase
          .from('driver_ratings')
          .select('rating')
          .eq('driver_id', driverId);

      if (response.isEmpty) {
        return null; // Aucune évaluation
      }

      final ratings = response.map((r) => r['rating'] as int).toList();
      final average = ratings.reduce((a, b) => a + b) / ratings.length;

      return average;
    } catch (e) {
      debugPrint('Error fetching driver average rating: $e');
      return null;
    }
  }

  /// Récupérer le nombre total d'évaluations d'un livreur
  Future<int> getDriverRatingCount(String driverId) async {
    try {
      final response = await _supabase
          .from('driver_ratings')
          .select('id')
          .eq('driver_id', driverId);

      return response.length;
    } catch (e) {
      debugPrint('Error fetching driver rating count: $e');
      return 0;
    }
  }
}

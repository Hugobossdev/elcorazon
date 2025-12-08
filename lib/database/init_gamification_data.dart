import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:elcora_fast/services/database_service.dart';

/// Script d'initialisation des données de gamification
Future<void> initializeGamificationData() async {
  try {
    debugPrint('🎮 Initialisation des données de gamification...');

    final databaseService = DatabaseService();
    final supabase = databaseService.supabase;

    // Vérifier si les données existent déjà
    final achievementsResponse =
        await supabase.from('achievements').select('id').limit(1);

    if (achievementsResponse.isNotEmpty) {
      debugPrint('✅ Les données de gamification sont déjà initialisées');
      return;
    }

    // Insérer les achievements
    debugPrint('📊 Insertion des achievements...');
    try {
      await supabase.from('achievements').insert(
        [
          {
            'title': 'Premier Pas',
            'description': 'Faire votre première commande',
            'icon': '🎯',
            'points': 10,
            'target': 1,
            'is_active': true,
          },
          {
            'title': 'Habitué',
            'description': 'Faire 5 commandes',
            'icon': '🏆',
            'points': 25,
            'target': 5,
            'is_active': true,
          },
          {
            'title': 'Explorateur',
            'description': 'Essayer 10 plats différents',
            'icon': '🗺️',
            'points': 50,
            'target': 10,
            'is_active': true,
          },
          {
            'title': 'Série de Victoires',
            'description': 'Commander 7 jours consécutifs',
            'icon': '🔥',
            'points': 75,
            'target': 7,
            'is_active': true,
          },
          {
            'title': 'Critique Culinaire',
            'description': 'Laisser 20 avis',
            'icon': '⭐',
            'points': 100,
            'target': 20,
            'is_active': true,
          },
          {
            'title': 'Champion El Corazón',
            'description': 'Atteindre le niveau 5',
            'icon': '👑',
            'points': 200,
            'target': 5,
            'is_active': true,
          },
        ],
      );
      debugPrint('✅ Achievements insérés avec succès');
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'insertion des achievements: $e');
      rethrow;
    }

    // Insérer les challenges
    debugPrint('🎯 Insertion des challenges...');
    try {
      await supabase.from('challenges').insert(
        [
          {
            'title': 'Défi Weekend',
            'description': 'Commandez 3 fois ce weekend',
            'challenge_type': 'weekly',
            'target_value': 3,
            'reward_points': 50,
            'start_date': DateTime.now().toIso8601String(),
            'end_date':
                DateTime.now().add(const Duration(days: 2)).toIso8601String(),
            'is_active': true,
          },
          {
            'title': 'Découverte Culinaire',
            'description': 'Essayez 2 nouveaux plats cette semaine',
            'challenge_type': 'weekly',
            'target_value': 2,
            'reward_points': 30,
            'start_date': DateTime.now().toIso8601String(),
            'end_date':
                DateTime.now().add(const Duration(days: 5)).toIso8601String(),
            'is_active': true,
          },
        ],
      );
      debugPrint('✅ Challenges insérés avec succès');
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'insertion des challenges: $e');
      rethrow;
    }

    // Insérer les rewards
    debugPrint('🎁 Insertion des rewards...');
    try {
      await supabase.from('loyalty_rewards').insert(
        [
          {
            'id': 'loyalty_free_drink',
            'title': 'Boisson Gratuite',
            'description': 'Une boisson de votre choix offerte',
            'cost': 50,
            'reward_type': 'free_item',
            'value': null,
            'is_active': true,
          },
          {
            'id': 'loyalty_free_fries',
            'title': 'Frites Gratuites',
            'description': 'Portion de frites offerte',
            'cost': 75,
            'reward_type': 'free_item',
            'value': null,
            'is_active': true,
          },
          {
            'id': 'loyalty_discount_10',
            'title': '10% de Réduction',
            'description': 'Sur votre prochaine commande',
            'cost': 100,
            'reward_type': 'discount',
            'value': 10,
            'is_active': true,
          },
          {
            'id': 'loyalty_free_burger',
            'title': 'Burger Gratuit',
            'description': 'Un burger de votre choix offert',
            'cost': 150,
            'reward_type': 'free_item',
            'value': null,
            'is_active': true,
          },
          {
            'id': 'loyalty_discount_20',
            'title': '20% de Réduction',
            'description': 'Sur votre prochaine commande',
            'cost': 200,
            'reward_type': 'discount',
            'value': 20,
            'is_active': true,
          },
          {
            'id': 'loyalty_free_menu',
            'title': 'Menu Complet Gratuit',
            'description': 'Un menu complet offert',
            'cost': 300,
            'reward_type': 'free_item',
            'value': null,
            'is_active': true,
          },
        ],
      );
      debugPrint('✅ Rewards insérés avec succès');
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'insertion des rewards: $e');
      rethrow;
    }

    // Insérer les badges
    debugPrint('🏆 Insertion des badges...');
    try {
      await supabase.from('badges').insert(
        [
          {
            'title': 'Premier Pas',
            'description': 'Votre première commande',
            'icon': '🎯',
            'points_required': 0,
            'is_active': true,
          },
          {
            'title': 'Habitué',
            'description': '5 commandes effectuées',
            'icon': '🏆',
            'points_required': 25,
            'is_active': true,
          },
          {
            'title': 'Explorateur',
            'description': '10 plats différents essayés',
            'icon': '🗺️',
            'points_required': 50,
            'is_active': true,
          },
          {
            'title': 'Série de Victoires',
            'description': '7 jours consécutifs de commandes',
            'icon': '🔥',
            'points_required': 75,
            'is_active': true,
          },
          {
            'title': 'Champion El Corazón',
            'description': 'Niveau 5 atteint',
            'icon': '👑',
            'points_required': 200,
            'is_active': true,
          },
        ],
      );
      debugPrint('✅ Badges insérés avec succès');
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'insertion des badges: $e');
      rethrow;
    }

    debugPrint('🎉 Données de gamification initialisées avec succès!');
  } catch (e) {
    debugPrint(
        '❌ Erreur lors de l\'initialisation des données de gamification: $e',);
    rethrow;
  }
}

/// Fonction pour initialiser les données depuis l'application
/// Utilise la configuration existante de l'application
Future<void> initializeGamificationDataFromApp() async {
  try {
    debugPrint(
        '🎮 Initialisation des données de gamification depuis l\'application...',);
    await initializeGamificationData();
  } catch (e) {
    debugPrint('❌ Erreur lors de l\'initialisation depuis l\'application: $e');
    rethrow;
  }
}

/// Fonction principale pour exécuter le script en standalone
/// Remplacez les URL et clés par vos vraies valeurs Supabase
Future<void> main() async {
  // Remplacez par vos vraies valeurs Supabase
  const supabaseUrl = 'YOUR_SUPABASE_URL';
  const supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

  if (supabaseUrl == 'YOUR_SUPABASE_URL' ||
      supabaseAnonKey == 'YOUR_SUPABASE_ANON_KEY') {
    debugPrint(
        '❌ Veuillez configurer vos URL et clés Supabase dans le fichier',);
    debugPrint(
        '💡 Ou utilisez initializeGamificationDataFromApp() depuis votre application',);
    return;
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  await initializeGamificationData();
}

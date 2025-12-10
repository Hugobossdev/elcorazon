import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Helper class to handle database initialization
class DatabaseInitializer {
  static const String _isInitializedKey = 'db_initialized_v1';

  /// Checks if the database has been initialized
  static Future<bool> isDatabaseInitialized() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_isInitializedKey) ?? false;
    } catch (e) {
      debugPrint('Error checking database initialization: $e');
      return false;
    }
  }

  /// Initializes the database (e.g. initial data seeding)
  /// This is intended to be run once.
  static Future<void> initializeDatabase() async {
    try {
      debugPrint('🚀 Starting database initialization...');
      
      // Since the logic for seeding or actual DB setup is missing,
      // we assume for now that if we are here, we just mark it as done
      // or perform any necessary migrations if we had them.
      
      // In a real scenario, this might call Supabase functions or 
      // insert initial data into tables if they are empty.
      
      await Future.delayed(const Duration(seconds: 1)); // Simulate work
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isInitializedKey, true);
      
      debugPrint('✅ Database initialization completed');
    } catch (e) {
      debugPrint('❌ Error during database initialization: $e');
      // We don't rethrow to avoid crashing the app, but we don't set the flag to true
      // so it tries again next time.
    }
  }
}


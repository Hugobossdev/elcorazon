import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  static Future<void> initialize() async {
    // Éviter les ré-initialisations inutiles
    if (_isInitialized) return;

    // Vérification des clés
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      debugPrint('⚠️ Warning: Supabase credentials not found in .env file.');
      return;
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: kDebugMode,
    );

    _isInitialized = true;
  }

  static SupabaseClient get client => Supabase.instance.client;
}

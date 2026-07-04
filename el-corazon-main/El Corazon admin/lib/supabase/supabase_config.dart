import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  static Future<void> initialize() async {
    // Logs de debug pour vérifier les valeurs réellement lues
    if (kDebugMode) {
      debugPrint('[SupabaseConfig] SUPABASE_URL: $supabaseUrl');
      final key = supabaseAnonKey;
      final maskedKey = key.length > 12
          ? '${key.substring(0, 6)}...${key.substring(key.length - 6)}'
          : key;
      debugPrint('[SupabaseConfig] SUPABASE_ANON_KEY: $maskedKey');
    }

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
  }

  static SupabaseClient get client => Supabase.instance.client;
}

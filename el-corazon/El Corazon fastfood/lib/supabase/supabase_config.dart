import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:elcora_fast/config/api_config.dart';

class SupabaseConfig {
  static Future<void> initialize() async {
    try {
      if (!ApiConfig.isEssentialConfigured) {
        debugPrint('⚠️ Supabase credentials missing in ApiConfig');
        return;
      }

      await Supabase.initialize(
        url: ApiConfig.supabaseUrl,
        anonKey: ApiConfig.supabaseAnonKey,
        debug: kDebugMode,
      );
      debugPrint('✅ Supabase initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize Supabase: $e');
    }
  }

  static SupabaseClient get client {
    try {
      return Supabase.instance.client;
    } catch (e) {
      debugPrint('⚠️ Supabase client accessed before initialization');
      throw Exception('Supabase not initialized');
    }
  }
}


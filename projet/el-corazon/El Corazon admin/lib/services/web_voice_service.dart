import 'package:flutter/foundation.dart';

class VoiceService extends ChangeNotifier {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  bool _isInitialized = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  String _lastRecognizedText = '';

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  String get lastRecognizedText => _lastRecognizedText;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Web-compatible voice service initialization
      _isInitialized = true;
      notifyListeners();
      debugPrint('Web: Voice service initialized');
    } catch (e) {
      debugPrint('Error initializing Voice Service: $e');
    }
  }

  Future<bool> startListening() async {
    if (!_isInitialized) return false;

    try {
      _isListening = true;
      notifyListeners();
      debugPrint('Web: Voice recognition started (simulated)');

      // Simulate voice recognition
      await Future.delayed(const Duration(seconds: 2));
      _lastRecognizedText = 'Commande simulée pour le web';
      _isListening = false;
      notifyListeners();

      return true;
    } catch (e) {
      debugPrint('Error starting voice recognition: $e');
      _isListening = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> stopListening() async {
    _isListening = false;
    notifyListeners();
    debugPrint('Web: Voice recognition stopped');
  }

  Future<void> speak(String text) async {
    if (!_isInitialized) return;

    try {
      _isSpeaking = true;
      notifyListeners();
      debugPrint('Web: Speaking: $text');

      // Simulate speech
      await Future.delayed(Duration(milliseconds: text.length * 50));

      _isSpeaking = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error speaking: $e');
      _isSpeaking = false;
      notifyListeners();
    }
  }

  Future<bool> isAvailable() async {
    // Web has limited voice capabilities
    return false;
  }

  Future<List<String>> getSupportedLanguages() async {
    return ['fr-FR', 'en-US'];
  }
}

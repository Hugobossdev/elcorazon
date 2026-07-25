import 'package:flutter/foundation.dart';

class VoiceService extends ChangeNotifier {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  bool _isListening = false;
  bool _isAvailable = false;
  String _currentRecognition = '';
  final List<String> _recognitionHistory = [];

  bool get isListening => _isListening;
  bool get isAvailable => _isAvailable;
  String get currentRecognition => _currentRecognition;
  List<String> get recognitionHistory => List.unmodifiable(_recognitionHistory);

  Future<void> initialize() async {
    try {
      // Simulate voice recognition availability
      _isAvailable = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing Voice Service: $e');
      _isAvailable = false;
    }
  }

  Future<void> startListening() async {
    if (!_isAvailable || _isListening) return;

    try {
      _isListening = true;
      _currentRecognition = '';
      notifyListeners();

      // Simulate voice recognition
      await Future.delayed(const Duration(seconds: 2));

      // Mock voice recognition results
      List<String> mockRecognitions = [
        'Je voudrais un burger poulet sans oignon',
        'Commande un pizza margherita avec coca',
        'Ajoute des frites et une boisson',
        'Je veux le même que la dernière fois',
        'Recommande-moi quelque chose de bon',
      ];

      _currentRecognition = mockRecognitions[
          DateTime.now().millisecond % mockRecognitions.length];
      _recognitionHistory.add(_currentRecognition);

      _isListening = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error during voice recognition: $e');
      _isListening = false;
      notifyListeners();
    }
  }

  Future<void> stopListening() async {
    if (!_isListening) return;

    _isListening = false;
    notifyListeners();
  }

  void clearRecognition() {
    _currentRecognition = '';
    notifyListeners();
  }

  void clearHistory() {
    _recognitionHistory.clear();
    notifyListeners();
  }

  // Text-to-Speech simulation
  Future<void> speak(String text) async {
    try {
      // Simulate TTS
      debugPrint('TTS: $text');
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      debugPrint('Error in TTS: $e');
    }
  }

  // Voice command patterns for fast food
  Map<String, dynamic> parseVoiceCommand(String command) {
    command = command.toLowerCase();

    Map<String, dynamic> result = {
      'action': 'unknown',
      'items': <Map<String, dynamic>>[],
      'modifications': <String>[],
      'confidence': 0.0,
    };

    // Detect action type
    if (command.contains('commande') ||
        command.contains('veux') ||
        command.contains('voudrais')) {
      result['action'] = 'order';
      result['confidence'] += 0.3;
    } else if (command.contains('recommande') || command.contains('suggère')) {
      result['action'] = 'recommend';
      result['confidence'] += 0.3;
    } else if (command.contains('répète') ||
        command.contains('même') ||
        command.contains('encore')) {
      result['action'] = 'repeat_last';
      result['confidence'] += 0.4;
    }

    // Extract menu items
    Map<String, String> menuKeywords = {
      'burger': 'Burger Classic',
      'pizza': 'Pizza Margherita',
      'frites': 'Frites Croustillantes',
      'coca': 'Coca-Cola',
      'wrap': 'Wrap Végétarien',
      'salade': 'Salade César',
      'sandwich': 'Sandwich Poulet',
      'nuggets': 'Nuggets de Poulet',
    };

    for (String keyword in menuKeywords.keys) {
      if (command.contains(keyword)) {
        result['items'].add({
          'name': menuKeywords[keyword],
          'quantity': _extractQuantity(command, keyword),
        });
        result['confidence'] += 0.2;
      }
    }

    // Extract modifications
    if (command.contains('sans')) {
      List<String> modifications = _extractModifications(command);
      result['modifications'].addAll(modifications);
      result['confidence'] += 0.1;
    }

    return result;
  }

  int _extractQuantity(String command, String item) {
    // Simple quantity extraction
    List<String> numbers = ['un', 'deux', 'trois', 'quatre', 'cinq'];
    for (int i = 0; i < numbers.length; i++) {
      if (command.contains('${numbers[i]} $item')) {
        return i + 1;
      }
    }
    return 1; // Default quantity
  }

  List<String> _extractModifications(String command) {
    List<String> modifications = [];

    // Common modifications
    if (command.contains('sans oignon')) modifications.add('Sans oignon');
    if (command.contains('sans tomate')) modifications.add('Sans tomate');
    if (command.contains('sans sauce')) modifications.add('Sans sauce');
    if (command.contains('extra fromage')) modifications.add('Extra fromage');
    if (command.contains('bien cuit')) modifications.add('Bien cuit');
    if (command.contains('peu cuit')) modifications.add('Peu cuit');

    return modifications;
  }

  // Get voice command suggestions
  List<String> getVoiceCommandSuggestions() {
    return [
      'Je voudrais un burger classic avec des frites',
      'Commande-moi une pizza margherita sans oignon',
      'Ajoute un coca au panier',
      'Recommande-moi quelque chose de végétarien',
      'Je veux le même que la dernière fois',
      'Supprime les frites de ma commande',
      'Combien coûte le menu burger ?',
    ];
  }
}

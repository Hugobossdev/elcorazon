import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';

class VoiceCommandService extends ChangeNotifier {
  static final VoiceCommandService _instance = VoiceCommandService._internal();
  factory VoiceCommandService() => _instance;
  VoiceCommandService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isAvailable = false;
  String _lastWords = '';

  // Commandes vocales supportées
  final Map<String, VoiceCommand> _supportedCommands = {};
  final StreamController<VoiceCommandResult> _commandController =
      StreamController<VoiceCommandResult>.broadcast();

  Stream<VoiceCommandResult> get commandStream => _commandController.stream;
  bool get isListening => _isListening;
  bool get isAvailable => _isAvailable;
  String get lastWords => _lastWords;

  /// Initialise le service de reconnaissance vocale
  Future<void> initialize() async {
    _isAvailable = await _speech.initialize(
      onStatus: _onStatus,
      onError: _onError,
    );

    if (_isAvailable) {
      _initializeSupportedCommands();
      debugPrint('VoiceCommandService: Service initialisé avec succès');
    } else {
      debugPrint('VoiceCommandService: Service non disponible');
    }

    notifyListeners();
  }

  /// Initialise les commandes vocales supportées
  void _initializeSupportedCommands() {
    _supportedCommands.addAll({
      'commander': VoiceCommand(
        keywords: ['commander', 'je veux', 'je voudrais', 'donne moi'],
        action: VoiceAction.order,
        description: 'Passer une commande',
      ),
      'ajouter': VoiceCommand(
        keywords: ['ajouter', 'ajoute', 'mettre dans le panier'],
        action: VoiceAction.addToCart,
        description: 'Ajouter un item au panier',
      ),
      'burger': VoiceCommand(
        keywords: ['burger', 'hamburger', 'sandwich'],
        action: VoiceAction.searchCategory,
        category: 'burgers',
        description: 'Rechercher des burgers',
      ),
      'pizza': VoiceCommand(
        keywords: ['pizza', 'pizzas'],
        action: VoiceAction.searchCategory,
        category: 'pizzas',
        description: 'Rechercher des pizzas',
      ),
      'boisson': VoiceCommand(
        keywords: ['boisson', 'boissons', 'drink', 'drinks'],
        action: VoiceAction.searchCategory,
        category: 'drinks',
        description: 'Rechercher des boissons',
      ),
      'dessert': VoiceCommand(
        keywords: ['dessert', 'desserts', 'sucré'],
        action: VoiceAction.searchCategory,
        category: 'desserts',
        description: 'Rechercher des desserts',
      ),
      'panier': VoiceCommand(
        keywords: ['panier', 'mon panier', 'voir panier'],
        action: VoiceAction.viewCart,
        description: 'Voir le panier',
      ),
      'commande': VoiceCommand(
        keywords: ['commande', 'mes commandes', 'historique'],
        action: VoiceAction.viewOrders,
        description: 'Voir les commandes',
      ),
      'profil': VoiceCommand(
        keywords: ['profil', 'mon profil', 'compte'],
        action: VoiceAction.viewProfile,
        description: 'Voir le profil',
      ),
      'aide': VoiceCommand(
        keywords: ['aide', 'help', 'assistance'],
        action: VoiceAction.help,
        description: 'Obtenir de l\'aide',
      ),
    });
  }

  /// Démarre l'écoute des commandes vocales
  Future<void> startListening() async {
    if (!_isAvailable) {
      await initialize();
    }

    if (_isAvailable && !_isListening) {
      await _speech.listen(
        onResult: _onResult,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        localeId: 'fr_FR',
        onSoundLevelChange: _onSoundLevelChange,
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: stt.ListenMode.confirmation,
        ),
      );
    }
  }

  /// Arrête l'écoute
  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
    }
  }

  /// Gère les résultats de reconnaissance vocale
  void _onResult(SpeechRecognitionResult result) {
    setState(() {
      _lastWords = result.recognizedWords;
    });

    if (result.finalResult) {
      _processVoiceCommand(_lastWords);
    }
  }

  /// Traite la commande vocale
  void _processVoiceCommand(String words) {
    final lowercaseWords = words.toLowerCase();
    VoiceCommand? matchedCommand;
    Map<String, dynamic>? parameters;

    // Chercher une correspondance avec les commandes supportées
    for (final entry in _supportedCommands.entries) {
      final command = entry.value;
      for (final keyword in command.keywords) {
        if (lowercaseWords.contains(keyword.toLowerCase())) {
          matchedCommand = command;
          parameters = _extractParameters(words, command);
          break;
        }
      }
      if (matchedCommand != null) break;
    }

    if (matchedCommand != null) {
      final result = VoiceCommandResult(
        command: matchedCommand,
        originalText: words,
        parameters: parameters ?? {},
        confidence: 0.9, // Simulation de confiance
      );

      _commandController.add(result);
      debugPrint(
          'VoiceCommandService: Commande détectée - ${matchedCommand.action}');
    } else {
      // Commande non reconnue
      final result = VoiceCommandResult(
        command: null,
        originalText: words,
        parameters: {},
        confidence: 0.0,
        error: 'Commande non reconnue',
      );

      _commandController.add(result);
      debugPrint('VoiceCommandService: Commande non reconnue - $words');
    }
  }

  /// Extrait les paramètres de la commande vocale
  Map<String, dynamic> _extractParameters(String words, VoiceCommand command) {
    final parameters = <String, dynamic>{};

    switch (command.action) {
      case VoiceAction.addToCart:
        // Extraire le nom de l'item
        final itemName = _extractItemName(words);
        if (itemName != null) {
          parameters['itemName'] = itemName;
        }
        break;
      case VoiceAction.searchCategory:
        parameters['category'] = command.category;
        break;
      case VoiceAction.order:
        // Extraire les détails de la commande
        final orderDetails = _extractOrderDetails(words);
        parameters.addAll(orderDetails);
        break;
      default:
        break;
    }

    return parameters;
  }

  /// Extrait le nom d'un item depuis le texte
  String? _extractItemName(String words) {
    // Liste des items populaires pour la correspondance
    final popularItems = [
      'burger',
      'hamburger',
      'cheeseburger',
      'big mac',
      'whopper',
      'pizza',
      'margherita',
      'pepperoni',
      'quatre fromages',
      'coca',
      'coca cola',
      'pepsi',
      'fanta',
      'sprite',
      'frites',
      'chicken nuggets',
      'salade',
      'dessert',
    ];

    final lowercaseWords = words.toLowerCase();
    for (final item in popularItems) {
      if (lowercaseWords.contains(item)) {
        return item;
      }
    }

    return null;
  }

  /// Extrait les détails d'une commande depuis le texte
  Map<String, dynamic> _extractOrderDetails(String words) {
    final details = <String, dynamic>{};
    final lowercaseWords = words.toLowerCase();

    // Extraire la quantité
    final quantityMatch =
        RegExp(r'(\d+)\s*(fois|fois|unité|unités)').firstMatch(lowercaseWords);
    if (quantityMatch != null) {
      details['quantity'] = int.tryParse(quantityMatch.group(1) ?? '1') ?? 1;
    }

    // Extraire la taille
    if (lowercaseWords.contains('grand') || lowercaseWords.contains('large')) {
      details['size'] = 'large';
    } else if (lowercaseWords.contains('petit') ||
        lowercaseWords.contains('small')) {
      details['size'] = 'small';
    } else {
      details['size'] = 'medium';
    }

    return details;
  }

  /// Gère les changements de statut
  void _onStatus(String status) {
    setState(() {
      _isListening = status == 'listening';
    });
    debugPrint('VoiceCommandService: Statut - $status');
  }

  /// Gère les erreurs
  void _onError(dynamic error) {
    debugPrint('VoiceCommandService: Erreur - $error');

    final result = VoiceCommandResult(
      command: null,
      originalText: '',
      parameters: {},
      confidence: 0.0,
      error: error.toString(),
    );

    _commandController.add(result);
  }

  /// Gère les changements de niveau sonore
  void _onSoundLevelChange(double level) {
    // Peut être utilisé pour afficher un indicateur visuel
  }

  /// Met à jour l'état
  void setState(VoidCallback fn) {
    fn();
    notifyListeners();
  }

  /// Ajoute une commande vocale personnalisée
  void addCustomCommand(String name, VoiceCommand command) {
    _supportedCommands[name] = command;
    debugPrint('VoiceCommandService: Commande personnalisée ajoutée - $name');
  }

  /// Supprime une commande vocale
  void removeCustomCommand(String name) {
    _supportedCommands.remove(name);
    debugPrint('VoiceCommandService: Commande supprimée - $name');
  }

  /// Obtient la liste des commandes supportées
  Map<String, VoiceCommand> getSupportedCommands() {
    return Map.unmodifiable(_supportedCommands);
  }

  /// Simule une commande vocale (pour les tests)
  void simulateVoiceCommand(String text) {
    _processVoiceCommand(text);
  }

  /// Obtient les suggestions de commandes vocales
  List<String> getVoiceCommandSuggestions() {
    return _supportedCommands.values
        .map((command) => command.keywords.first)
        .toList();
  }

  /// Vérifie si une commande est supportée
  bool isCommandSupported(String text) {
    final lowercaseText = text.toLowerCase();
    return _supportedCommands.values.any((command) => command.keywords
        .any((keyword) => lowercaseText.contains(keyword.toLowerCase())));
  }

  @override
  void dispose() {
    _speech.stop();
    _commandController.close();
    super.dispose();
  }
}

class VoiceCommand {
  final List<String> keywords;
  final VoiceAction action;
  final String? category;
  final String description;
  final Map<String, dynamic>? parameters;

  VoiceCommand({
    required this.keywords,
    required this.action,
    this.category,
    required this.description,
    this.parameters,
  });
}

class VoiceCommandResult {
  final VoiceCommand? command;
  final String originalText;
  final Map<String, dynamic> parameters;
  final double confidence;
  final String? error;

  VoiceCommandResult({
    this.command,
    required this.originalText,
    required this.parameters,
    required this.confidence,
    this.error,
  });

  bool get isSuccess => command != null && error == null;
  bool get hasError => error != null;
}

enum VoiceAction {
  order,
  addToCart,
  searchCategory,
  viewCart,
  viewOrders,
  viewProfile,
  help,
  navigate,
  cancel,
}

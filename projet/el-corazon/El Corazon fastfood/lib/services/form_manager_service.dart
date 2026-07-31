import 'package:flutter/foundation.dart';
import 'package:elcora_fast/services/form_validation_service.dart';

/// Service de gestion des formulaires avec sauvegarde automatique.
///
/// La sauvegarde est purement en mémoire : les brouillons ne survivent pas au
/// redémarrage de l'app. La persistance passera par le backend Django quand le
/// domaine correspondant sera migré (Phase 6, §3.3).
class FormManagerService extends ChangeNotifier {
  static final FormManagerService _instance = FormManagerService._internal();
  factory FormManagerService() => _instance;
  FormManagerService._internal();

  final FormValidationService _validationService = FormValidationService();

  // Cache des formulaires en cours
  final Map<String, Map<String, dynamic>> _formData = {};

  // Cache des formulaires sauvegardés
  final Map<String, Map<String, dynamic>> _savedForms = {};

  // Historique des modifications
  final List<Map<String, dynamic>> _modificationHistory = [];

  // Timers pour la sauvegarde automatique
  final Map<String, DateTime> _lastModified = {};

  /// Initialiser le service
  Future<void> initialize() async {
    try {
      await _validationService.initialize();
      debugPrint('FormManagerService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing FormManagerService: $e');
    }
  }

  /// Sauvegarder automatiquement un formulaire
  Future<void> autoSaveForm(
    String formName,
    Map<String, dynamic> formData,
  ) async {
    try {
      _formData[formName] = Map.from(formData);
      _lastModified[formName] = DateTime.now();

      // Ajouter à l'historique
      _modificationHistory.add({
        'formName': formName,
        'timestamp': DateTime.now().toIso8601String(),
        'action': 'auto_save',
        'data': Map.from(formData),
      });

      notifyListeners();
    } catch (e) {
      debugPrint('Error auto-saving form $formName: $e');
    }
  }

  /// Sauvegarder manuellement un formulaire
  Future<bool> saveForm(String formName, Map<String, dynamic> formData) async {
    try {
      // Valider le formulaire
      final validationResult =
          await _validationService.validateForm(formName, formData);
      if (!validationResult.isValid) {
        debugPrint('Form validation failed: ${validationResult.fieldErrors}');
        return false;
      }

      _formData[formName] = Map.from(formData);
      _savedForms[formName] = Map.from(formData);
      _lastModified[formName] = DateTime.now();

      // Ajouter à l'historique
      _modificationHistory.add({
        'formName': formName,
        'timestamp': DateTime.now().toIso8601String(),
        'action': 'manual_save',
        'data': Map.from(formData),
      });

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error saving form $formName: $e');
      return false;
    }
  }

  /// Charger un formulaire sauvegardé
  Map<String, dynamic>? loadForm(String formName) {
    return _savedForms[formName];
  }

  /// Charger les données d'un formulaire en cours
  Map<String, dynamic>? getFormData(String formName) {
    return _formData[formName];
  }

  /// Mettre à jour les données d'un formulaire
  void updateFormData(String formName, Map<String, dynamic> formData) {
    _formData[formName] = Map.from(formData);
    _lastModified[formName] = DateTime.now();

    // Ajouter à l'historique
    _modificationHistory.add({
      'formName': formName,
      'timestamp': DateTime.now().toIso8601String(),
      'action': 'update',
      'data': Map.from(formData),
    });

    notifyListeners();
  }

  /// Supprimer un formulaire
  Future<void> deleteForm(String formName) async {
    try {
      _formData.remove(formName);
      _savedForms.remove(formName);
      _lastModified.remove(formName);

      // Ajouter à l'historique
      _modificationHistory.add({
        'formName': formName,
        'timestamp': DateTime.now().toIso8601String(),
        'action': 'delete',
        'data': null,
      });

      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting form $formName: $e');
    }
  }

  /// Restaurer un formulaire depuis l'historique
  Future<bool> restoreForm(String formName, DateTime timestamp) async {
    try {
      // Trouver la modification dans l'historique
      final modification = _modificationHistory.firstWhere(
        (mod) =>
            mod['formName'] == formName &&
            DateTime.parse(mod['timestamp']).isAtSameMomentAs(timestamp),
        orElse: () => throw Exception('Modification not found'),
      );

      if (modification['data'] != null) {
        _formData[formName] = Map<String, dynamic>.from(modification['data']);
        _lastModified[formName] = DateTime.now();

        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error restoring form $formName: $e');
      return false;
    }
  }

  /// Obtenir l'historique des modifications d'un formulaire
  List<Map<String, dynamic>> getFormHistory(String formName) {
    return _modificationHistory
        .where((mod) => mod['formName'] == formName)
        .toList()
      ..sort(
        (a, b) => DateTime.parse(b['timestamp'])
            .compareTo(DateTime.parse(a['timestamp'])),
      );
  }

  /// Obtenir tous les formulaires sauvegardés
  Map<String, Map<String, dynamic>> getAllSavedForms() {
    return Map.from(_savedForms);
  }

  /// Obtenir tous les formulaires en cours
  Map<String, Map<String, dynamic>> getAllFormData() {
    return Map.from(_formData);
  }

  /// Vérifier si un formulaire a des modifications non sauvegardées
  bool hasUnsavedChanges(String formName) {
    final formData = _formData[formName];
    final savedForm = _savedForms[formName];

    if (formData == null && savedForm == null) return false;
    if (formData == null || savedForm == null) return true;

    return formData.toString() != savedForm.toString();
  }

  /// Obtenir la date de dernière modification
  DateTime? getLastModified(String formName) {
    return _lastModified[formName];
  }

  /// Effacer toutes les données des formulaires
  void clearAllForms() {
    _formData.clear();
    _savedForms.clear();
    _lastModified.clear();
    _modificationHistory.clear();
    notifyListeners();
  }

  /// Exporter un formulaire
  Map<String, dynamic> exportForm(String formName) {
    final formData = _formData[formName];
    final savedForm = _savedForms[formName];

    return {
      'formName': formName,
      'currentData': formData,
      'savedData': savedForm,
      'lastModified': _lastModified[formName]?.toIso8601String(),
      'hasUnsavedChanges': hasUnsavedChanges(formName),
      'exportTimestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Importer un formulaire
  bool importForm(Map<String, dynamic> exportData) {
    try {
      final formName = exportData['formName'] as String;
      final currentData = exportData['currentData'] as Map<String, dynamic>?;
      final savedData = exportData['savedData'] as Map<String, dynamic>?;

      if (currentData != null) {
        _formData[formName] = Map.from(currentData);
      }

      if (savedData != null) {
        _savedForms[formName] = Map.from(savedData);
      }

      if (exportData['lastModified'] != null) {
        _lastModified[formName] = DateTime.parse(exportData['lastModified']);
      }

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error importing form: $e');
      return false;
    }
  }

  /// Obtenir les statistiques des formulaires
  Map<String, dynamic> getFormStatistics() {
    return {
      'totalForms': _formData.length,
      'savedForms': _savedForms.length,
      'formsWithUnsavedChanges':
          _formData.keys.where((name) => hasUnsavedChanges(name)).length,
      'totalModifications': _modificationHistory.length,
      'lastSync': DateTime.now().toIso8601String(),
    };
  }
}

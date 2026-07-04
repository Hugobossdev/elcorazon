import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase/supabase_config.dart';

// Import conditionnel pour File (mobile) vs web
import 'dart:io' if (dart.library.html) 'dart:html' as io;

/// Service de gestion des uploads vers Supabase Storage
class StorageService extends ChangeNotifier {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SupabaseClient get _supabase {
    if (!SupabaseConfig.isInitialized) {
      throw Exception(
          'Supabase not initialized. Please call SupabaseConfig.initialize() first.');
    }
    return SupabaseConfig.client;
  }

  // Limites de taille (en bytes)
  static const int maxImageSize = 10 * 1024 * 1024; // 10 MB
  static const int maxDocumentSize = 5 * 1024 * 1024; // 5 MB

  // Types de fichiers autorisés
  static const List<String> allowedImageTypes = [
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/webp',
  ];

  static const List<String> allowedDocumentTypes = [
    'image/jpeg',
    'image/jpg',
    'image/png',
    'application/pdf',
  ];

  /// Upload un fichier vers Supabase Storage
  /// 
  /// [file] : Le fichier à uploader
  /// [bucketName] : Le nom du bucket Supabase Storage
  /// [fileName] : Le nom du fichier (sera généré si non fourni)
  /// [folder] : Le dossier dans le bucket (optionnel)
  /// [onProgress] : Callback pour suivre la progression (0.0 à 1.0)
  /// 
  /// Retourne l'URL publique du fichier uploadé
  Future<String> uploadFile({
    required io.File file,
    required String bucketName,
    String? fileName,
    String? folder,
    Function(double)? onProgress,
  }) async {
    try {
      // Lire les bytes du fichier
      Uint8List fileBytes;
      String finalFileName;
      
      if (kIsWeb) {
        // Pour le web, utiliser html.File
        // dart:html.File a readAsBytes() qui retourne directement Future<Uint8List>
        final htmlFile = file as dynamic;
        fileBytes = await htmlFile.readAsBytes();
        final fileNameFromFile = htmlFile.name ?? htmlFile.fileName ?? 'file';
        finalFileName = fileName ?? 
            '${DateTime.now().millisecondsSinceEpoch}_$fileNameFromFile';
      } else {
        // Pour mobile, utiliser io.File (dart:io.File uniquement)
        // On doit utiliser un cast dynamique pour éviter les erreurs de type
        if (kIsWeb) {
          throw UnsupportedError('uploadFile with File object not supported on web. Use uploadFileBytes instead.');
        }
        // Sur mobile, file est garanti d'être dart:io.File
        final ioFile = file;
        // Utiliser des méthodes dynamiques pour éviter les erreurs de type
        final dynamic fileObj = ioFile;
        if (!await fileObj.exists()) {
          throw Exception('Le fichier n\'existe pas');
        }
        fileBytes = await fileObj.readAsBytes();
        final filePath = fileObj.path as String;
        finalFileName = fileName ?? 
            '${DateTime.now().millisecondsSinceEpoch}_${filePath.split('/').last}';
      }

      // Valider le fichier
      await _validateFile(fileBytes, fileType: 'image');

      // Upload via uploadFileBytes
      final contentType = kIsWeb 
          ? _getContentTypeFromName(finalFileName)
          : _getContentType((file as dynamic).path as String);
      
      return await uploadFileBytes(
        fileBytes: fileBytes,
        bucketName: bucketName,
        fileName: finalFileName,
        folder: folder,
        contentType: contentType,
        onProgress: onProgress,
      );
    } catch (e) {
      debugPrint('❌ StorageService: Erreur upload fichier - $e');
      rethrow;
    }
  }

  /// Upload des bytes vers Supabase Storage
  /// 
  /// [fileBytes] : Les bytes du fichier
  /// [bucketName] : Le nom du bucket Supabase Storage
  /// [fileName] : Le nom du fichier
  /// [folder] : Le dossier dans le bucket (optionnel)
  /// [contentType] : Le type MIME du fichier
  /// [onProgress] : Callback pour suivre la progression (0.0 à 1.0)
  /// 
  /// Retourne l'URL publique du fichier uploadé
  Future<String> uploadFileBytes({
    required Uint8List fileBytes,
    required String bucketName,
    required String fileName,
    String? folder,
    String contentType = 'image/jpeg',
    Function(double)? onProgress,
  }) async {
    try {
      // Valider le fichier
      await _validateFile(fileBytes, fileType: contentType.startsWith('image/') ? 'image' : 'document');

      // Construire le chemin
      final path = folder != null ? '$folder/$fileName' : fileName;

      // Simuler la progression (Supabase ne fournit pas de callback de progression natif)
      if (onProgress != null) {
        onProgress(0.1); // Début
      }

      // Upload vers Supabase Storage
      await _supabase.storage.from(bucketName).uploadBinary(
        path,
        fileBytes,
        fileOptions: FileOptions(
          upsert: true,
          contentType: contentType,
          cacheControl: '3600',
        ),
      );

      if (onProgress != null) {
        onProgress(0.9); // Presque terminé
      }

      // Obtenir l'URL publique
      final publicUrl = _supabase.storage.from(bucketName).getPublicUrl(path);

      if (onProgress != null) {
        onProgress(1.0); // Terminé
      }

      debugPrint('✅ StorageService: Fichier uploadé avec succès - $path');
      debugPrint('✅ StorageService: URL publique - $publicUrl');

      return publicUrl;
    } catch (e) {
      debugPrint('❌ StorageService: Erreur upload bytes - $e');
      
      // Gérer les erreurs spécifiques de Supabase
      if (e.toString().contains('Bucket not found')) {
        throw Exception('Le bucket "$bucketName" n\'existe pas. Veuillez le créer dans Supabase Storage.');
      } else if (e.toString().contains('duplicate')) {
        throw Exception('Un fichier avec ce nom existe déjà');
      } else if (e.toString().contains('permission')) {
        throw Exception('Permission refusée. Vérifiez les politiques du bucket.');
      } else if (e.toString().contains('size')) {
        throw Exception('Le fichier est trop volumineux');
      }
      
      throw Exception('Erreur lors de l\'upload: ${e.toString()}');
    }
  }

  /// Upload multiple fichiers
  /// 
  /// Retourne une Map avec les noms de fichiers comme clés et les URLs comme valeurs
  /// Note: Sur web, utilisez uploadFileBytes avec Uint8List au lieu de File
  Future<Map<String, String>> uploadMultipleFiles({
    required List<io.File> files,
    required String bucketName,
    String? folder,
    Function(String fileName, double progress)? onFileProgress,
  }) async {
    final results = <String, String>{};
    
    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      final fileName = kIsWeb 
          ? 'file_${i}_${DateTime.now().millisecondsSinceEpoch}'
          : (file as dynamic).path.split('/').last as String;
      
      try {
        final url = await uploadFile(
          file: file,
          bucketName: bucketName,
          folder: folder,
          onProgress: (progress) {
            if (onFileProgress != null) {
              onFileProgress(fileName, progress);
            }
          },
        );
        
        results[fileName] = url;
      } catch (e) {
        debugPrint('❌ StorageService: Erreur upload $fileName - $e');
        // Continuer avec les autres fichiers même si un échoue
      }
    }
    
    return results;
  }

  /// Supprime un fichier de Supabase Storage
  Future<void> deleteFile({
    required String bucketName,
    required String fileName,
    String? folder,
  }) async {
    try {
      final path = folder != null ? '$folder/$fileName' : fileName;
      
      await _supabase.storage.from(bucketName).remove([path]);
      
      debugPrint('✅ StorageService: Fichier supprimé - $path');
    } catch (e) {
      debugPrint('❌ StorageService: Erreur suppression fichier - $e');
      throw Exception('Erreur lors de la suppression: ${e.toString()}');
    }
  }

  /// Obtient l'URL publique d'un fichier
  String getPublicUrl({
    required String bucketName,
    required String fileName,
    String? folder,
  }) {
    final path = folder != null ? '$folder/$fileName' : fileName;
    return _supabase.storage.from(bucketName).getPublicUrl(path);
  }

  /// Vérifie si un fichier existe
  Future<bool> fileExists({
    required String bucketName,
    required String fileName,
    String? folder,
  }) async {
    try {
      final files = await _supabase.storage.from(bucketName).list(
        path: folder ?? '',
      );
      
      return files.any((file) => file.name == fileName);
    } catch (e) {
      debugPrint('❌ StorageService: Erreur vérification existence - $e');
      return false;
    }
  }

  /// Valide un fichier (taille, type)
  Future<void> _validateFile(
    Uint8List fileBytes, {
    required String fileType,
  }) async {
    // Vérifier la taille
    final maxSize = fileType == 'image' ? maxImageSize : maxDocumentSize;
    if (fileBytes.length > maxSize) {
      final sizeMB = (fileBytes.length / (1024 * 1024)).toStringAsFixed(2);
      final maxMB = (maxSize / (1024 * 1024)).toStringAsFixed(0);
      throw Exception(
          'Le fichier est trop volumineux ($sizeMB MB). Taille maximum: $maxMB MB');
    }

    // Vérifier que le fichier n'est pas vide
    if (fileBytes.isEmpty) {
      throw Exception('Le fichier est vide');
    }

    // Vérifier le type de fichier (magic bytes)
    if (fileType == 'image') {
      if (!_isValidImage(fileBytes)) {
        throw Exception('Le fichier n\'est pas une image valide');
      }
    }
  }

  /// Vérifie si les bytes représentent une image valide
  bool _isValidImage(Uint8List bytes) {
    if (bytes.length < 4) return false;

    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return true;
    }

    // PNG: 89 50 4E 47
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return true;
    }

    // WebP: RIFF ... WEBP
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return true;
    }

    return false;
  }

  /// Détermine le type MIME à partir de l'extension du fichier (pour mobile)
  String _getContentType(String filePath) {
    final extension = filePath.split('.').last.toLowerCase();
    return _getContentTypeFromExtension(extension);
  }

  /// Obtient le type MIME d'un fichier à partir de son nom (pour web)
  String _getContentTypeFromName(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    return _getContentTypeFromExtension(extension);
  }

  /// Obtient le type MIME à partir de l'extension
  String _getContentTypeFromExtension(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'image/jpeg'; // Par défaut
    }
  }

  /// Génère un nom de fichier unique basé sur l'ID utilisateur et le type
  String generateFileName({
    required String userId,
    required String documentType,
    String extension = 'jpg',
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${userId}_${documentType}_$timestamp.$extension';
  }

  /// Upload un document de livreur
  /// Méthode helper spécifique pour les documents de livreur
  Future<String> uploadDriverDocument({
    required String userId,
    required Uint8List fileBytes,
    required String documentType, // 'profile', 'license', 'idcard', 'vehicle'
    String? customFileName,
    Function(double)? onProgress,
  }) async {
    final fileName = customFileName ?? 
        generateFileName(
          userId: userId,
          documentType: documentType,
        );

    // Déterminer le dossier selon le type de document
    String folder;
    switch (documentType) {
      case 'profile':
        folder = 'profiles';
        break;
      case 'license':
        folder = 'licenses';
        break;
      case 'idcard':
        folder = 'id-cards';
        break;
      case 'vehicle':
        folder = 'vehicles';
        break;
      default:
        folder = 'documents';
    }

    return await uploadFileBytes(
      fileBytes: fileBytes,
      bucketName: 'driver-documents',
      fileName: fileName,
      folder: folder,
      contentType: 'image/jpeg',
      onProgress: onProgress,
    );
  }
}


import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:elcora_dely/l10n/app_localizations.dart';
import '../../../services/app_service.dart';
import '../../../widgets/custom_button.dart';
import '../../../widgets/custom_text_field.dart';
import '../../../widgets/loading_widget.dart';
import '../../../utils/validators.dart';
// Conditional import for File support (not available on web)
import 'dart:io' if (dart.library.html) 'dart:html' as io;

class DriverRegistrationScreen extends StatefulWidget {
  const DriverRegistrationScreen({super.key});

  @override
  State<DriverRegistrationScreen> createState() =>
      _DriverRegistrationScreenState();
}

class _DriverRegistrationScreenState extends State<DriverRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _vehicleTypeController = TextEditingController();
  final _vehicleNumberController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();

  // On mobile, these are dart:io.File. On web, they should never be set.
  io.File? _profilePhoto;
  io.File? _licensePhoto;
  io.File? _idCardPhoto;
  io.File? _vehiclePhoto;

  /// Helper to create a File on mobile only
  /// This ensures we use dart:io.File, not dart:html.File
  io.File _createFileFromPath(String path) {
    if (kIsWeb) {
      throw UnsupportedError('File creation not supported on web');
    }
    // On mobile, io.File is dart:io.File
    // Use a cast to work around conditional import type checking
    return (io.File as dynamic)(path);
  }

  // For web compatibility
  Uint8List? _profilePhotoBytes;
  Uint8List? _licensePhotoBytes;
  Uint8List? _idCardPhotoBytes;
  Uint8List? _vehiclePhotoBytes;

  bool _isLoading = false;
  bool _acceptTerms = false;

  final List<String> _vehicleTypes = ['Moto', 'Vélo', 'Voiture', 'Scooter'];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _licenseNumberController.dispose();
    _idNumberController.dispose();
    _vehicleTypeController.dispose();
    _vehicleNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source, String type) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          if (kIsWeb) {
            // For web, read bytes
            image.readAsBytes().then((bytes) {
              setState(() {
                switch (type) {
                  case 'profile':
                    _profilePhotoBytes = bytes;
                    break;
                  case 'license':
                    _licensePhotoBytes = bytes;
                    break;
                  case 'id':
                    _idCardPhotoBytes = bytes;
                    break;
                  case 'vehicle':
                    _vehiclePhotoBytes = bytes;
                    break;
                }
              });
            });
          } else {
            // For mobile, use File (dart:io.File only, not dart:html.File)
            if (!kIsWeb) {
              final filePath = image.path;
              switch (type) {
                case 'profile':
                  _profilePhoto = _createFileFromPath(filePath);
                  break;
                case 'license':
                  _licensePhoto = _createFileFromPath(filePath);
                  break;
                case 'id':
                  _idCardPhoto = _createFileFromPath(filePath);
                  break;
                case 'vehicle':
                  _vehiclePhoto = _createFileFromPath(filePath);
                  break;
              }
            }
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la sélection de l\'image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showImagePicker(String type) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(l10n?.takePhoto ?? 'Prendre une photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera, type);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(l10n?.chooseFromGallery ?? 'Choisir depuis la galerie'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery, type);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez accepter les conditions d\'utilisation'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if all photos are provided (either File for mobile or bytes for web)
    final hasAllPhotos = kIsWeb
        ? (_profilePhotoBytes != null &&
            _licensePhotoBytes != null &&
            _idCardPhotoBytes != null &&
            _vehiclePhotoBytes != null)
        : (_profilePhoto != null &&
            _licensePhoto != null &&
            _idCardPhoto != null &&
            _vehiclePhoto != null);

    if (!hasAllPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez télécharger toutes les photos requises'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final appService = Provider.of<AppService>(context, listen: false);

      if (kIsWeb) {
        // On web, use bytes for upload
        if (_profilePhotoBytes == null ||
            _licensePhotoBytes == null ||
            _idCardPhotoBytes == null ||
            _vehiclePhotoBytes == null) {
          throw Exception('Toutes les photos sont requises');
        }

        // Create temporary files from bytes for web
        // Note: We'll need to update AppService to handle bytes directly
        // For now, we'll create a workaround
        await appService.registerDriverWithDocumentsBytes(
          name: _nameController.text,
          email: _emailController.text,
          phone: _phoneController.text,
          licenseNumber: _licenseNumberController.text,
          idNumber: _idNumberController.text,
          vehicleType: _vehicleTypeController.text,
          vehicleNumber: _vehicleNumberController.text,
          profilePhotoBytes: _profilePhotoBytes!,
          licensePhotoBytes: _licensePhotoBytes!,
          idCardPhotoBytes: _idCardPhotoBytes!,
          vehiclePhotoBytes: _vehiclePhotoBytes!,
          password: _passwordController.text,
        );
      } else {
        // On mobile, use File objects
        if (_profilePhoto == null ||
            _licensePhoto == null ||
            _idCardPhoto == null ||
            _vehiclePhoto == null) {
          throw Exception('Toutes les photos sont requises');
        }

        await appService.registerDriverWithDocuments(
          name: _nameController.text,
          email: _emailController.text,
          phone: _phoneController.text,
          licenseNumber: _licenseNumberController.text,
          idNumber: _idNumberController.text,
          vehicleType: _vehicleTypeController.text,
          vehicleNumber: _vehicleNumberController.text,
          profilePhoto: _profilePhoto!,
          licensePhoto: _licensePhoto!,
          idCardPhoto: _idCardPhoto!,
          vehiclePhoto: _vehiclePhoto!,
          password: _passwordController.text,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Inscription soumise avec succès! Votre compte sera activé après vérification.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        // Extraire le message d'erreur proprement
        String errorMessage = _extractErrorMessage(e);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Extrait le message d'erreur proprement, en évitant les duplications
  String _extractErrorMessage(dynamic error) {
    String errorString = error.toString();
    
    // Si c'est une Exception, essayer d'extraire le message directement
    if (error is Exception) {
      // Pour certaines exceptions, on peut accéder à la propriété message
      try {
        final message = (error as dynamic).message;
        if (message != null && message.toString().isNotEmpty) {
          errorString = message.toString();
        }
      } catch (_) {
        // Si on ne peut pas accéder à message, utiliser toString()
        errorString = error.toString();
      }
    }
    
    // Supprimer tous les préfixes "Exception: " répétés (même plusieurs niveaux)
    // Utiliser une regex pour supprimer tous les "Exception: " même s'ils sont imbriqués
    errorString = errorString.replaceAll(RegExp(r'Exception:\s*'), '');
    
    // Supprimer les préfixes "Erreur d'inscription: " ou "Erreur lors de l'inscription: "
    final prefixesToRemove = [
      'Erreur d\'inscription: ',
      'Erreur lors de l\'inscription: ',
      'Erreur lors de la création du profil: ',
      'Erreur lors de la récupération du profil: ',
    ];
    
    for (final prefix in prefixesToRemove) {
      while (errorString.startsWith(prefix)) {
        errorString = errorString.substring(prefix.length);
      }
    }
    
    // Nettoyer les espaces en début et fin
    errorString = errorString.trim();
    
    // Si le message est vide ou ne contient que "Exception", retourner un message par défaut
    if (errorString.isEmpty || errorString == 'Exception' || errorString == 'null') {
      return 'Une erreur est survenue lors de l\'inscription. Veuillez réessayer.';
    }
    
    return errorString;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Fallback if l10n is null
    if (l10n == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.completeRegistration),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const LoadingWidget(message: 'Soumission de votre inscription...')
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle(l10n.personalInfo),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: l10n.fullName,
                      controller: _nameController,
                      prefixIcon: Icons.person,
                      validator: Validators.validateName,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: l10n.email,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.email,
                      validator: Validators.validateEmail,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: l10n.password,
                      controller: _passwordController,
                      isPassword: true,
                      prefixIcon: Icons.lock,
                      validator: Validators.validatePassword,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: l10n.phone,
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      prefixIcon: Icons.phone,
                      validator: Validators.validatePhone,
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle(l10n.officialDocs),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: l10n.licenseNumber,
                      controller: _licenseNumberController,
                      prefixIcon: Icons.card_membership,
                      validator: (value) => Validators.validateRequired(value, 'votre numéro de permis'),
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: l10n.idNumber,
                      controller: _idNumberController,
                      prefixIcon: Icons.badge,
                      validator: (value) => Validators.validateRequired(value, 'votre numéro de carte d\'identité'),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle(l10n.vehicle),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _vehicleTypeController.text.isEmpty
                          ? null
                          : _vehicleTypeController.text,
                      decoration: InputDecoration(
                        labelText: l10n.vehicleType,
                        prefixIcon: const Icon(Icons.two_wheeler),
                        border: const OutlineInputBorder(),
                      ),
                      items: _vehicleTypes
                          .map((type) => DropdownMenuItem<String>(
                                value: type,
                                child: Text(type),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _vehicleTypeController.text = value ?? '';
                        });
                      },
                      validator: (value) => Validators.validateRequired(value, 'un type de véhicule'),
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: l10n.vehicleNumber,
                      controller: _vehicleNumberController,
                      prefixIcon: Icons.directions_car,
                      validator: (value) => Validators.validateRequired(value, 'le numéro de votre véhicule'),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle(l10n.requiredPhotos),
                    const SizedBox(height: 16),
                    _buildPhotoSection(
                        l10n.profilePhoto, _profilePhoto, 'profile', l10n),
                    const SizedBox(height: 16),
                    _buildPhotoSection(
                        l10n.licensePhoto, _licensePhoto, 'license', l10n),
                    const SizedBox(height: 16),
                    _buildPhotoSection(l10n.idPhoto, _idCardPhoto, 'id', l10n),
                    const SizedBox(height: 16),
                    _buildPhotoSection(
                        l10n.vehiclePhoto, _vehiclePhoto, 'vehicle', l10n),
                    const SizedBox(height: 24),
                    _buildTermsSection(l10n),
                    const SizedBox(height: 24),
                    CustomButton(
                      text: l10n.submit,
                      onPressed: _submitRegistration,
                      icon: Icons.send,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }

  Widget _buildPhotoSection(String title, io.File? photo, String type, AppLocalizations l10n) {
    // Get the appropriate photo data (File for mobile, bytes for web)
    final hasPhoto = kIsWeb
        ? (type == 'profile'
            ? _profilePhotoBytes != null
            : type == 'license'
                ? _licensePhotoBytes != null
                : type == 'id'
                    ? _idCardPhotoBytes != null
                    : _vehiclePhotoBytes != null)
        : photo != null;

    Uint8List? photoBytes;
    if (kIsWeb) {
      switch (type) {
        case 'profile':
          photoBytes = _profilePhotoBytes;
          break;
        case 'license':
          photoBytes = _licensePhotoBytes;
          break;
        case 'id':
          photoBytes = _idCardPhotoBytes;
          break;
        case 'vehicle':
          photoBytes = _vehiclePhotoBytes;
          break;
      }
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            if (hasPhoto)
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: kIsWeb
                      ? Image.memory(
                          photoBytes!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(child: Icon(Icons.error)),
                        )
                      : (photo != null && !kIsWeb)
                          ? Image.file(
                              photo as dynamic,
                              fit: BoxFit.cover,
                            )
                          : const SizedBox(),
                ),
              )
            else
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_a_photo, size: 32, color: Colors.grey),
                      const SizedBox(height: 8),
                      Text(l10n.noPhotoSelected),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _showImagePicker(type),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.camera_alt),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        hasPhoto ? l10n.changePhoto : l10n.addPhoto,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsSection(AppLocalizations l10n) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Checkbox(
                    value: _acceptTerms,
                    onChanged: (value) {
                      setState(() {
                        _acceptTerms = value ?? false;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: Text(
                    l10n.acceptTerms,
                    style: Theme.of(context).textTheme.bodyMedium,
                    softWrap: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '• Votre compte sera vérifié dans les 24-48h\n'
              '• Vous recevrez une notification une fois approuvé\n'
              '• Tous vos documents sont sécurisés et confidentiels',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

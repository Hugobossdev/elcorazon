# 🛡️ Guide de Validation et Sécurité des Formulaires

> ⚠️ **Document antérieur à la migration Django (1er août 2026).**
> Les exemples ci-dessous montrent des dépôts Supabase qui n'existent plus.
> L'accès aux données passe désormais par `packages/elcorazon_core`, dont les
> dépôts parlent à l'API Django `/api/v1/*`. Le **patron** décrit ici reste
> valable — c'est son implémentation qui a changé.
>
> Référence : [`docs/architecture/04-migration-flutter.md`](../../../docs/architecture/04-migration-flutter.md).

## Vue d'ensemble

Ce système de validation protège contre :
- **Injection SQL** : Détection et blocage des tentatives d'injection SQL
- **Attaques XSS** : Détection et blocage des scripts malveillants
- **Caractères dangereux** : Sanitization automatique des entrées utilisateur
- **Validation de format** : Email, téléphone, mot de passe, etc.

## Utilisation

### 1. Utiliser `SecureTextField` (Recommandé)

Le widget `SecureTextField` intègre automatiquement toutes les protections :

```dart
import 'package:elcora_fast/widgets/secure_text_field.dart';

SecureTextField(
  label: 'Nom complet',
  fieldName: 'Nom',
  required: true,
  prefixIcon: Icon(Icons.person),
  controller: _nameController,
  strictValidation: true, // Mode strict activé
)
```

### 2. Utiliser `InputSanitizer` directement

Pour valider manuellement une valeur :

```dart
import 'package:elcora_fast/utils/input_sanitizer.dart';

final result = InputSanitizer.validateAndSanitize(
  userInput,
  fieldName: 'Email',
  strict: true,
);

if (!result.isValid) {
  // Afficher l'erreur
  showError(result.errorMessage);
} else {
  // Utiliser la valeur sanitizée
  final safeValue = result.sanitizedValue!;
}
```

### 3. Utiliser `FormValidationService`

Pour valider un formulaire complet :

```dart
import 'package:elcora_fast/services/form_validation_service.dart';

final validationService = FormValidationService();
final result = await validationService.validateForm('auth', {
  'name': _nameController.text,
  'email': _emailController.text,
  'phone': _phoneController.text,
  'password': _passwordController.text,
});

if (!result.isValid) {
  // Afficher les erreurs
  result.fieldErrors.forEach((field, error) {
    print('$field: $error');
  });
}
```

### 4. Sanitizer les données avant insertion en base

```dart
import 'package:elcora_fast/utils/security_helper.dart';

// Avant insertion
final sanitizedData = SecurityHelper.sanitizeData(
  {
    'name': userInput,
    'email': emailInput,
    'description': descriptionInput,
  },
  excludeFields: ['password'], // Exclure certains champs
  strict: true,
);

await apiClient.post('/domaine/ressource/', data: sanitizedData);
```

## Messages d'erreur clairs

Tous les messages d'erreur sont conçus pour être :
- **Compréhensibles** : Langage clair pour l'utilisateur
- **Informatifs** : Indiquent ce qui est attendu
- **Sécurisés** : N'exposent pas d'informations techniques sensibles

### Exemples de messages :

- ✅ "⚠️ Le champ 'Nom' contient des caractères non autorisés. Veuillez utiliser uniquement des lettres, chiffres et caractères de ponctuation standards."
- ✅ "⚠️ L'email contient du contenu non autorisé. Les balises HTML et scripts ne sont pas autorisés."
- ✅ "Le nom doit contenir au moins 2 caractères"
- ✅ "Veuillez entrer un email valide"

## Protection contre les injections SQL

Le système détecte automatiquement :
- Mots-clés SQL dangereux : `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `DROP`, etc.
- Patterns SQL : `OR 1=1`, `AND 1=1`, `UNION SELECT`, etc.
- Commentaires SQL : `--`, `/* */`
- Caractères spéciaux : `'`, `"`, `;`, etc.

## Protection contre les attaques XSS

Le système détecte automatiquement :
- Balises HTML : `<script>`, `<iframe>`, `<img>`, etc.
- Événements JavaScript : `onclick=`, `onload=`, etc.
- URLs JavaScript : `javascript:`
- Contenu malveillant dans les attributs

## Configuration

### Ajouter une validation personnalisée

```dart
FormValidationService().addValidationConfig('myForm', FormValidationConfig(
  formName: 'myForm',
  fields: [
    FieldValidationConfig(
      fieldName: 'customField',
      label: 'Champ personnalisé',
      rules: [
        ValidationRule(
          type: ValidationType.required,
          message: 'Ce champ est requis',
        ),
        ValidationRule(
          type: ValidationType.sqlInjection,
          message: '⚠️ Caractères non autorisés détectés',
        ),
        ValidationRule(
          type: ValidationType.minLength,
          value: 5,
          message: 'Minimum 5 caractères',
        ),
      ],
    ),
  ],
));
```

## Bonnes pratiques

1. **Toujours utiliser la sanitization** avant insertion en base
2. **Valider côté client ET serveur** (défense en profondeur)
3. **Utiliser des messages d'erreur clairs** pour guider l'utilisateur
4. **Ne jamais faire confiance aux données utilisateur**
5. **Logger les tentatives d'injection** pour monitoring

## Exemple complet

```dart
class MyFormScreen extends StatefulWidget {
  @override
  State<MyFormScreen> createState() => _MyFormScreenState();
}

class _MyFormScreenState extends State<MyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      // Sanitizer les données
      final sanitizedData = SecurityHelper.sanitizeData({
        'name': _nameController.text,
        'email': _emailController.text,
      });

      // Insérer en base
      await apiClient.post('/domaine/ressource/', data: sanitizedData);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Formulaire soumis avec succès')),
      );
    } on SecurityException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            SecureTextField(
              label: 'Nom',
              fieldName: 'Nom',
              controller: _nameController,
              required: true,
            ),
            SecureTextField(
              label: 'Email',
              fieldName: 'Email',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              required: true,
            ),
            ElevatedButton(
              onPressed: _submitForm,
              child: Text('Soumettre'),
            ),
          ],
        ),
      ),
    );
  }
}
```












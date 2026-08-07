import 'package:elcorazon_core/elcorazon_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Catégorie vue de l'exploitation.
///
/// Ce qui se teste ici est le champ qui manquait : le dépôt d'exploitation
/// rendait des `Category`, modelées sur le sérialiseur **public**, où
/// `is_active` n'existe pas. Le champ arrivait bien du serveur et se perdait au
/// parsing — le back-office affichait donc toute catégorie comme active, et sa
/// prochaine modification la réactivait en silence.
Map<String, dynamic> _json({bool? isActive}) {
  return {
    'id': 'cat-1',
    'restaurant': 'el-corazon-lome',
    'name': 'Burgers',
    'slug': 'burgers',
    'emoji': '🍔',
    'description': 'Les classiques',
    'sort_order': 3,
    if (isActive != null) 'is_active': isActive,
    'created_at': '2026-07-31T10:00:00Z',
    'updated_at': '2026-08-07T09:00:00Z',
  };
}

void main() {
  group('Lecture', () {
    test('le champ « active » du serveur est retenu', () {
      expect(ManagedCategory.fromJson(_json(isActive: false)).isActive, isFalse);
      expect(ManagedCategory.fromJson(_json(isActive: true)).isActive, isTrue);
    });

    test('tous les champs du contrat sont lus', () {
      final categorie = ManagedCategory.fromJson(_json());

      expect(categorie.id, 'cat-1');
      expect(categorie.restaurantSlug, 'el-corazon-lome');
      expect(categorie.name, 'Burgers');
      expect(categorie.slug, 'burgers');
      expect(categorie.emoji, '🍔');
      expect(categorie.description, 'Les classiques');
      expect(categorie.sortOrder, 3);
      expect(categorie.createdAt, DateTime.parse('2026-07-31T10:00:00Z'));
      expect(categorie.updatedAt, DateTime.parse('2026-08-07T09:00:00Z'));
    });

    test('une réponse sans le champ décrit une catégorie active', () {
      // C'est le cas de la route publique, qui ne rend que les actives : en
      // voir une signifie qu'elle l'est.
      expect(ManagedCategory.fromJson(_json()).isActive, isTrue);
    });

    test('les libellés optionnels tolèrent l’absence', () {
      final maigre = _json()
        ..remove('emoji')
        ..remove('description');
      final categorie = ManagedCategory.fromJson(maigre);

      expect(categorie.emoji, isEmpty);
      expect(categorie.description, isEmpty);
    });
  });

  group('Modification locale', () {
    test('bascule l’activation sans toucher au reste', () {
      final avant = ManagedCategory.fromJson(_json(isActive: true));
      final apres = avant.copyWith(isActive: false);

      expect(apres.isActive, isFalse);
      expect(apres.id, avant.id);
      expect(apres.slug, avant.slug);
      expect(apres.name, avant.name);
      expect(apres.sortOrder, avant.sortOrder);
      expect(apres.restaurantSlug, avant.restaurantSlug);
    });

    test('renommer ne réactive pas une catégorie désactivée', () {
      // C'est la régression que ce modèle corrige : l'écran renvoyait
      // `isActive` avec chaque enregistrement, et il valait toujours `true`.
      final desactivee = ManagedCategory.fromJson(_json(isActive: false));
      expect(desactivee.copyWith(name: 'Burgers & Co').isActive, isFalse);
    });
  });
}

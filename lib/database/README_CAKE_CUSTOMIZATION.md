# Initialisation des Gâteaux Personnalisés

Ce dossier contient les scripts SQL nécessaires pour initialiser les tables et données pour la personnalisation des gâteaux.

## 📋 Scripts disponibles

### 1. `init_custom_cake_item.sql`
Crée l'item "Gâteau personnalisé" dans la table `menu_items` s'il n'existe pas encore.

### 2. `seed_cake_customization_options.sql`
Insère toutes les options de personnalisation des gâteaux dans les tables :
- `customization_options` : Les options disponibles (formes, tailles, saveurs, etc.)
- `menu_item_customizations` : Les liaisons entre l'item "Gâteau personnalisé" et ses options

## 🚀 Comment utiliser

### Option 1 : Via Supabase Dashboard

1. Connectez-vous à votre dashboard Supabase
2. Allez dans l'éditeur SQL
3. Exécutez d'abord `init_custom_cake_item.sql`
4. Puis exécutez `seed_cake_customization_options.sql`

### Option 2 : Via ligne de commande

```bash
# Si vous avez psql installé
psql -h [your-host] -U [your-user] -d [your-database] -f init_custom_cake_item.sql
psql -h [your-host] -U [your-user] -d [your-database] -f seed_cake_customization_options.sql
```

### Option 3 : Via l'application Dart

Les scripts peuvent être exécutés via l'application si vous créez une fonction d'initialisation.

## 📊 Options de personnalisation créées

Le script crée les options suivantes :

### Formes (shape)
- Rond (par défaut) - 0 FCFA
- Carré - +2000 FCFA
- Cœur - +3500 FCFA
- Rectangle - +2500 FCFA

### Tailles (size)
- Petit (6 personnes) - 0 FCFA
- Moyen (10 personnes) - +6000 FCFA
- Grand (16 personnes) - +11000 FCFA

### Saveurs (flavor)
- Vanille (par défaut) - 0 FCFA
- Chocolat - +2000 FCFA
- Fraise - +2500 FCFA
- Vanille & Chocolat - +3000 FCFA

### Étages (tiers)
- 1 étage (par défaut) - 0 FCFA
- 2 étages - +7000 FCFA
- 3 étages - +12000 FCFA

### Glaçages (icing)
- Crème au beurre vanille (par défaut) - 0 FCFA
- Cream cheese citron - +2500 FCFA
- Ganache chocolat noir - +3000 FCFA

### Régimes / Allergies (dietary)
- Classique (par défaut) - 0 FCFA
- Sans fruits à coque - +1500 FCFA
- Sans gluten - +3500 FCFA
- Sans lactose - +3000 FCFA

### Garnitures (filling) - Multi-sélection (max 2)
- Crème fouettée - +1500 FCFA
- Ganache chocolat - +2000 FCFA
- Compotée de fruits rouges - +2500 FCFA

### Décorations (decoration) - Multi-sélection (max 3)
- Fruits frais - +2000 FCFA
- Copeaux de chocolat - +1500 FCFA
- Macarons assortis - +3000 FCFA
- Photo comestible - +4000 FCFA
- Message en sucre - +1000 FCFA

## ✅ Vérification

Après avoir exécuté les scripts, vérifiez que :

1. L'item "Gâteau personnalisé" existe dans `menu_items`
2. Les options sont présentes dans `customization_options`
3. Les liaisons sont créées dans `menu_item_customizations`

Vous pouvez vérifier avec ces requêtes SQL :

```sql
-- Vérifier l'item
SELECT * FROM menu_items WHERE name ILIKE '%gâteau personnalisé%';

-- Vérifier les options
SELECT COUNT(*) FROM customization_options WHERE category IN ('shape', 'size', 'flavor', 'tiers', 'icing', 'dietary', 'filling', 'decoration');

-- Vérifier les liaisons
SELECT mic.*, co.name, co.category 
FROM menu_item_customizations mic
JOIN customization_options co ON co.id = mic.customization_option_id
WHERE mic.menu_item_id = (SELECT id FROM menu_items WHERE name ILIKE '%gâteau personnalisé%' LIMIT 1)
ORDER BY mic.sort_order;
```

## 🔄 Mise à jour

Les scripts utilisent `ON CONFLICT DO UPDATE`, donc vous pouvez les exécuter plusieurs fois sans créer de doublons. Les données existantes seront mises à jour si nécessaire.

## 📝 Notes

- Les scripts sont idempotents : vous pouvez les exécuter plusieurs fois sans problème
- Les options sont triées par `sort_order` pour un affichage cohérent
- Les options par défaut sont marquées avec `is_default = TRUE`
- Les options multi-sélection ont un `max_quantity` > 1


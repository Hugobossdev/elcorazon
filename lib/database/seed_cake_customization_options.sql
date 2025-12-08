-- =============================================================
-- Script de création des options de personnalisation pour les gâteaux
-- =============================================================

-- Insertion des options de personnalisation pour les gâteaux dans customization_options

-- FORMES (shape)
INSERT INTO customization_options (id, name, category, price_modifier, is_default, max_quantity, description, is_active)
VALUES
  ('cake-shape-round', 'Rond', 'shape', 0.0, TRUE, 1, 'Forme ronde classique', TRUE),
  ('cake-shape-square', 'Carré', 'shape', 2000.0, FALSE, 1, 'Forme carrée moderne', TRUE),
  ('cake-shape-heart', 'Cœur', 'shape', 3500.0, FALSE, 1, 'Forme cœur romantique', TRUE),
  ('cake-shape-rectangle', 'Rectangle', 'shape', 2500.0, FALSE, 1, 'Forme rectangulaire élégante', TRUE)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  category = EXCLUDED.category,
  price_modifier = EXCLUDED.price_modifier,
  is_default = EXCLUDED.is_default,
  description = EXCLUDED.description;

-- TAILLES (size)
INSERT INTO customization_options (id, name, category, price_modifier, is_default, max_quantity, description, is_active)
VALUES
  ('cake-size-small', 'Petit (6 personnes)', 'size', 0.0, TRUE, 1, 'Pour 6 personnes', TRUE),
  ('cake-size-medium', 'Moyen (10 personnes)', 'size', 6000.0, FALSE, 1, 'Pour 10 personnes', TRUE),
  ('cake-size-large', 'Grand (16 personnes)', 'size', 11000.0, FALSE, 1, 'Pour 16 personnes', TRUE)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  category = EXCLUDED.category,
  price_modifier = EXCLUDED.price_modifier,
  is_default = EXCLUDED.is_default,
  description = EXCLUDED.description;

-- SAVEURS (flavor)
INSERT INTO customization_options (id, name, category, price_modifier, is_default, max_quantity, description, is_active)
VALUES
  ('cake-flavor-vanilla', 'Vanille', 'flavor', 0.0, TRUE, 1, 'Saveur vanille classique', TRUE),
  ('cake-flavor-chocolate', 'Chocolat', 'flavor', 2000.0, FALSE, 1, 'Chocolat intense', TRUE),
  ('cake-flavor-strawberry', 'Fraise', 'flavor', 2500.0, FALSE, 1, 'Fraîcheur des fruits rouges', TRUE),
  ('cake-flavor-mix', 'Vanille & Chocolat', 'flavor', 3000.0, FALSE, 1, 'Mélange vanille et chocolat', TRUE)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  category = EXCLUDED.category,
  price_modifier = EXCLUDED.price_modifier,
  is_default = EXCLUDED.is_default,
  description = EXCLUDED.description;

-- ÉTAGES (tiers)
INSERT INTO customization_options (id, name, category, price_modifier, is_default, max_quantity, description, is_active)
VALUES
  ('cake-tier-1', '1 étage (standard)', 'tiers', 0.0, TRUE, 1, 'Un étage pour vos occasions', TRUE),
  ('cake-tier-2', '2 étages (+12 parts)', 'tiers', 7000.0, FALSE, 1, 'Deux étages pour plus de convives', TRUE),
  ('cake-tier-3', '3 étages (+20 parts)', 'tiers', 12000.0, FALSE, 1, 'Trois étages pour les grandes occasions', TRUE)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  category = EXCLUDED.category,
  price_modifier = EXCLUDED.price_modifier,
  is_default = EXCLUDED.is_default,
  description = EXCLUDED.description;

-- GLAÇAGES (icing)
INSERT INTO customization_options (id, name, category, price_modifier, is_default, max_quantity, description, is_active)
VALUES
  ('cake-icing-buttercream', 'Crème au beurre vanille', 'icing', 0.0, TRUE, 1, 'Glaçage classique à la crème au beurre', TRUE),
  ('cake-icing-creamcheese', 'Cream cheese citron', 'icing', 2500.0, FALSE, 1, 'Glaçage crémeux au citron', TRUE),
  ('cake-icing-ganache', 'Ganache chocolat noir', 'icing', 3000.0, FALSE, 1, 'Glaçage chocolat intense', TRUE)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  category = EXCLUDED.category,
  price_modifier = EXCLUDED.price_modifier,
  is_default = EXCLUDED.is_default,
  description = EXCLUDED.description;

-- RÉGIME / ALLERGIES (dietary)
INSERT INTO customization_options (id, name, category, price_modifier, is_default, max_quantity, description, allergens, is_active)
VALUES
  ('cake-diet-standard', 'Classique', 'dietary', 0.0, TRUE, 1, 'Recette traditionnelle', ARRAY[]::TEXT[], TRUE),
  ('cake-diet-no-nuts', 'Sans fruits à coque', 'dietary', 1500.0, FALSE, 1, 'Sans noix, noisettes, amandes', ARRAY[]::TEXT[], TRUE),
  ('cake-diet-gluten-free', 'Sans gluten', 'dietary', 3500.0, FALSE, 1, 'Préparation sans gluten', ARRAY[]::TEXT[], TRUE),
  ('cake-diet-lactose-free', 'Sans lactose', 'dietary', 3000.0, FALSE, 1, 'Préparation sans lactose', ARRAY[]::TEXT[], TRUE)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  category = EXCLUDED.category,
  price_modifier = EXCLUDED.price_modifier,
  is_default = EXCLUDED.is_default,
  description = EXCLUDED.description,
  allergens = EXCLUDED.allergens;

-- GARNITURES (filling) - Multi-sélection (max 2)
INSERT INTO customization_options (id, name, category, price_modifier, is_default, max_quantity, description, is_active)
VALUES
  ('cake-filling-cream', 'Crème fouettée', 'filling', 1500.0, FALSE, 2, 'Crème fouettée légère', TRUE),
  ('cake-filling-ganache', 'Ganache chocolat', 'filling', 2000.0, FALSE, 2, 'Ganache au chocolat', TRUE),
  ('cake-filling-fruits', 'Compotée de fruits rouges', 'filling', 2500.0, FALSE, 2, 'Fruits rouges frais', TRUE)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  category = EXCLUDED.category,
  price_modifier = EXCLUDED.price_modifier,
  max_quantity = EXCLUDED.max_quantity,
  description = EXCLUDED.description;

-- DÉCORATIONS (decoration) - Multi-sélection (max 3)
INSERT INTO customization_options (id, name, category, price_modifier, is_default, max_quantity, description, is_active)
VALUES
  ('cake-deco-fruits', 'Fruits frais', 'decoration', 2000.0, FALSE, 3, 'Décoration avec fruits frais', TRUE),
  ('cake-deco-chocolate', 'Copeaux de chocolat', 'decoration', 1500.0, FALSE, 3, 'Copeaux de chocolat artisanal', TRUE),
  ('cake-deco-macarons', 'Macarons assortis', 'decoration', 3000.0, FALSE, 3, 'Macarons colorés', TRUE),
  ('cake-deco-photo', 'Photo comestible', 'decoration', 4000.0, FALSE, 1, 'Impression photo comestible', TRUE),
  ('cake-deco-message', 'Message en sucre', 'decoration', 1000.0, FALSE, 1, 'Message personnalisé en sucre', TRUE)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  category = EXCLUDED.category,
  price_modifier = EXCLUDED.price_modifier,
  max_quantity = EXCLUDED.max_quantity,
  description = EXCLUDED.description;

-- =============================================================
-- Liaison des options au menu item "Gâteau personnalisé"
-- =============================================================

-- Liaison des FORMES (sort_order: 1)
INSERT INTO menu_item_customizations (menu_item_id, customization_option_id, is_required, sort_order)
SELECT 
  mi.id,
  co.id,
  CASE WHEN co.id = 'cake-shape-round' THEN TRUE ELSE FALSE END,
  1
FROM menu_items mi, customization_options co
WHERE (mi.name ILIKE '%gâteau personnalisé%' OR mi.name ILIKE '%gateau personnalise%')
  AND co.category = 'shape'
ON CONFLICT (menu_item_id, customization_option_id) DO UPDATE SET
  is_required = EXCLUDED.is_required,
  sort_order = EXCLUDED.sort_order;

-- Liaison des TAILLES (sort_order: 2)
INSERT INTO menu_item_customizations (menu_item_id, customization_option_id, is_required, sort_order)
SELECT 
  mi.id,
  co.id,
  CASE WHEN co.id = 'cake-size-small' THEN TRUE ELSE FALSE END,
  2
FROM menu_items mi, customization_options co
WHERE (mi.name ILIKE '%gâteau personnalisé%' OR mi.name ILIKE '%gateau personnalise%')
  AND co.category = 'size'
ON CONFLICT (menu_item_id, customization_option_id) DO UPDATE SET
  is_required = EXCLUDED.is_required,
  sort_order = EXCLUDED.sort_order;

-- Liaison des SAVEURS (sort_order: 3)
INSERT INTO menu_item_customizations (menu_item_id, customization_option_id, is_required, sort_order)
SELECT 
  mi.id,
  co.id,
  CASE WHEN co.id = 'cake-flavor-vanilla' THEN TRUE ELSE FALSE END,
  3
FROM menu_items mi, customization_options co
WHERE (mi.name ILIKE '%gâteau personnalisé%' OR mi.name ILIKE '%gateau personnalise%')
  AND co.category = 'flavor'
ON CONFLICT (menu_item_id, customization_option_id) DO UPDATE SET
  is_required = EXCLUDED.is_required,
  sort_order = EXCLUDED.sort_order;

-- Liaison des ÉTAGES (sort_order: 4)
INSERT INTO menu_item_customizations (menu_item_id, customization_option_id, is_required, sort_order)
SELECT 
  mi.id,
  co.id,
  CASE WHEN co.id = 'cake-tier-1' THEN TRUE ELSE FALSE END,
  4
FROM menu_items mi, customization_options co
WHERE (mi.name ILIKE '%gâteau personnalisé%' OR mi.name ILIKE '%gateau personnalise%')
  AND co.category = 'tiers'
ON CONFLICT (menu_item_id, customization_option_id) DO UPDATE SET
  is_required = EXCLUDED.is_required,
  sort_order = EXCLUDED.sort_order;

-- Liaison des GLAÇAGES (sort_order: 5)
INSERT INTO menu_item_customizations (menu_item_id, customization_option_id, is_required, sort_order)
SELECT 
  mi.id,
  co.id,
  CASE WHEN co.id = 'cake-icing-buttercream' THEN TRUE ELSE FALSE END,
  5
FROM menu_items mi, customization_options co
WHERE (mi.name ILIKE '%gâteau personnalisé%' OR mi.name ILIKE '%gateau personnalise%')
  AND co.category = 'icing'
ON CONFLICT (menu_item_id, customization_option_id) DO UPDATE SET
  is_required = EXCLUDED.is_required,
  sort_order = EXCLUDED.sort_order;

-- Liaison des RÉGIMES (sort_order: 6)
INSERT INTO menu_item_customizations (menu_item_id, customization_option_id, is_required, sort_order)
SELECT 
  mi.id,
  co.id,
  CASE WHEN co.id = 'cake-diet-standard' THEN TRUE ELSE FALSE END,
  6
FROM menu_items mi, customization_options co
WHERE (mi.name ILIKE '%gâteau personnalisé%' OR mi.name ILIKE '%gateau personnalise%')
  AND co.category = 'dietary'
ON CONFLICT (menu_item_id, customization_option_id) DO UPDATE SET
  is_required = EXCLUDED.is_required,
  sort_order = EXCLUDED.sort_order;

-- Liaison des GARNITURES (sort_order: 7)
INSERT INTO menu_item_customizations (menu_item_id, customization_option_id, is_required, sort_order)
SELECT 
  mi.id,
  co.id,
  FALSE,
  7
FROM menu_items mi, customization_options co
WHERE (mi.name ILIKE '%gâteau personnalisé%' OR mi.name ILIKE '%gateau personnalise%')
  AND co.category = 'filling'
ON CONFLICT (menu_item_id, customization_option_id) DO UPDATE SET
  sort_order = EXCLUDED.sort_order;

-- Liaison des DÉCORATIONS (sort_order: 8)
INSERT INTO menu_item_customizations (menu_item_id, customization_option_id, is_required, sort_order)
SELECT 
  mi.id,
  co.id,
  FALSE,
  8
FROM menu_items mi, customization_options co
WHERE (mi.name ILIKE '%gâteau personnalisé%' OR mi.name ILIKE '%gateau personnalise%')
  AND co.category = 'decoration'
ON CONFLICT (menu_item_id, customization_option_id) DO UPDATE SET
  sort_order = EXCLUDED.sort_order;

-- =============================================================
-- Fin du script
-- =============================================================


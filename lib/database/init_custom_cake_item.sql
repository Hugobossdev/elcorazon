-- =============================================================
-- Script d'initialisation de l'item "Gâteau personnalisé"
-- =============================================================

-- S'assurer que la catégorie "desserts" existe
INSERT INTO menu_categories (name, display_name, emoji, description, sort_order)
SELECT 'desserts', 'Desserts', '🍰', 'Desserts gourmands et sucrés', 4
WHERE NOT EXISTS (
  SELECT 1 FROM menu_categories WHERE name = 'desserts'
);

-- Créer l'item "Gâteau personnalisé" s'il n'existe pas
INSERT INTO menu_items (
  name,
  description,
  price,
  category_id,
  image_url,
  is_popular,
  is_available,
  preparation_time,
  sort_order,
  is_vegetarian,
  is_vegan
)
SELECT
  'Gâteau personnalisé',
  'Composez votre gâteau idéal : forme, taille, saveur et décor. Créez une pièce unique sur-mesure pour toutes vos occasions spéciales.',
  20000.0,
  (SELECT id FROM menu_categories WHERE name = 'desserts' LIMIT 1),
  'https://images.unsplash.com/photo-1542281286-9e0a16bb7366?auto=format&fit=crop&w=600&q=80',
  TRUE,
  TRUE,
  90,
  999,
  FALSE,
  FALSE
WHERE NOT EXISTS (
  SELECT 1 FROM menu_items 
  WHERE name ILIKE '%gâteau personnalisé%' OR name ILIKE '%gateau personnalise%'
)
AND EXISTS (
  SELECT 1 FROM menu_categories WHERE name = 'desserts'
);



-- Nettoyage
-- TRUNCATE TABLE menu_items, menu_categories RESTART IDENTITY CASCADE;

-- 1. CRÉATION DES CATÉGORIES
-- Ajout d'une catégorie "rice" pour les plats de riz
INSERT INTO menu_categories (id, name, display_name, emoji, description, sort_order, is_active) 
VALUES 
('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'burgers', 'Nos Burgers', '🍔', 'Burgers gourmands avec pain brioché maison.', 1, true),
('b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'pizzas', 'Pizzas', '🍕', 'Pâte fine et croustillante, cuite au feu de bois.', 2, true),
('c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33', 'sushi', 'Sushis & Japonais', '🍣', 'Fraîcheur garantie, préparés à la commande.', 3, true),
('e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a55', 'rice', 'Spécialités de Riz', '🍚', 'Voyagez avec nos recettes de riz du monde.', 4, true),
('d0eebc99-9c0b-4ef8-bb6d-6bb9bd380a44', 'desserts', 'Desserts', '🍰', 'La touche sucrée pour finir en beauté.', 5, true)
ON CONFLICT (id) DO UPDATE SET 
    display_name = EXCLUDED.display_name,
    emoji = EXCLUDED.emoji,
    description = EXCLUDED.description,
    sort_order = EXCLUDED.sort_order;

-- 2. INSERTION DES PLATS

-- BURGERS (Prix en CFA)
INSERT INTO menu_items (name, description, price, category_id, image_url, is_popular, is_vegetarian, ingredients, calories, preparation_time) VALUES
('Le Boss', 'Double steak 150g, double cheddar, bacon fumé, œuf au plat et sauce secrète.', 6500, 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&w=800&q=80', true, false, '{Double Steak,Cheddar,Bacon,Oeuf,Sauce Maison}', 1100, 20),
('Cheese Bomb', 'Pour les amateurs de fromage : Steak, raclette fondue, oignons caramélisés.', 5500, 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'https://images.unsplash.com/photo-1586190848861-99c8a3da726c?auto=format&fit=crop&w=800&q=80', true, false, '{Steak,Raclette,Oignons Caramélisés,Salade}', 950, 15),
('Spicy Chicken', 'Filet de poulet mariné aux épices, panure croustillante, piments jalapeños.', 4500, 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'https://images.unsplash.com/photo-1615557960916-5f4791effe9d?auto=format&fit=crop&w=800&q=80', false, false, '{Poulet Pané,Piment,Cheddar,Salade}', 800, 15),
('Le Végé', 'Galette de quinoa et légumes, avocat, sauce yaourt menthe.', 5000, 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'https://images.unsplash.com/photo-1550547660-d9450f859349?auto=format&fit=crop&w=800&q=80', false, true, '{Galette Quinoa,Avocat,Menthe,Tomate}', 600, 15),
('BBQ King', 'Steak grillé, onion rings, sauce barbecue, cheddar affiné.', 5000, 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', 'https://images.unsplash.com/photo-1594212699903-ec8a3eca50f5?auto=format&fit=crop&w=800&q=80', true, false, '{Steak,Onion Rings,Sauce BBQ,Cheddar}', 900, 15);

-- PIZZAS
INSERT INTO menu_items (name, description, price, category_id, image_url, is_popular, is_vegetarian, ingredients, calories, preparation_time) VALUES
('Carnivore', 'Sauce tomate, mozzarella, boeuf haché, poulet, merguez.', 7000, 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'https://images.unsplash.com/photo-1628840042765-356cda07504e?auto=format&fit=crop&w=800&q=80', true, false, '{Boeuf,Poulet,Merguez,Mozzarella}', 1000, 20),
('Chèvre Miel', 'Crème fraîche, fromage de chèvre, miel d''acacia, noix, roquette.', 6500, 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&w=800&q=80', true, true, '{Chèvre,Miel,Noix,Crème}', 850, 15),
('Reine Blanche', 'Crème, mozzarella, jambon supérieur, champignons frais.', 6000, 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'https://images.unsplash.com/photo-1595854341625-f33ee10432fa?auto=format&fit=crop&w=800&q=80', false, false, '{Jambon,Champignons,Crème,Mozzarella}', 800, 15),
('Végétarienne Grillée', 'Tomate, mozzarella, aubergines et poivrons grillés, pesto.', 5500, 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?auto=format&fit=crop&w=800&q=80', false, true, '{Aubergine,Poivron,Pesto,Tomate}', 700, 15),
('Saumon', 'Crème aneth, saumon fumé, citron, mozzarella.', 7500, 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22', 'https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&w=800&q=80', false, false, '{Saumon fumé,Crème,Aneth,Citron}', 850, 15);

-- SUSHIS (Catégorie Asian/Sushi)
INSERT INTO menu_items (name, description, price, category_id, image_url, is_popular, is_vegetarian, ingredients, calories, preparation_time) VALUES
('Plateau Découverte', '18 pièces variées : 6 California, 6 Maki, 6 Sushi.', 12000, 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33', 'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?auto=format&fit=crop&w=800&q=80', true, false, '{Saumon,Thon,Avocat,Riz}', 600, 20),
('California Tempura', 'Crevette tempura croustillante, avocat, concombre, sésame.', 4500, 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33', 'https://images.unsplash.com/photo-1617196019294-dc44dfac01d5?auto=format&fit=crop&w=800&q=80', true, false, '{Crevette Tempura,Avocat,Concombre}', 350, 10),
('Maki Saumon Cheese', 'Saumon frais et fromage frais onctueux.', 3500, 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33', 'https://images.unsplash.com/photo-1553621042-f6e147245754?auto=format&fit=crop&w=800&q=80', false, false, '{Saumon,Fromage Frais,Riz,Algue}', 300, 10),
('Spring Roll Veggie', 'Feuille de riz, avocat, menthe, coriandre, carotte.', 3000, 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33', 'https://images.unsplash.com/photo-1534483509719-3feaee7c30da?auto=format&fit=crop&w=800&q=80', false, true, '{Avocat,Menthe,Carotte,Salade}', 200, 10),
('Sashimi Mix', '12 tranches fines de poisson frais (Saumon, Thon, Daurade).', 9000, 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33', 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=800&q=80', false, false, '{Saumon,Thon,Daurade}', 250, 15);

-- RIZ (Nouvelle catégorie 'rice')
INSERT INTO menu_items (name, description, price, category_id, image_url, is_popular, is_vegetarian, ingredients, calories, preparation_time) VALUES
('Riz Cantonais Royal', 'Riz sauté aux petits pois, dés de jambon, omelette et crevettes.', 4500, 'e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a55', 'https://images.unsplash.com/photo-1512058564366-18510be2db19?auto=format&fit=crop&w=800&q=80', true, false, '{Riz,Jambon,Oeuf,Petits pois,Crevettes}', 600, 15),
('Thieboudienne Rouge', 'Plat national sénégalais : Riz cuit dans une sauce tomate avec poisson (Thiof) et légumes.', 6000, 'e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a55', 'https://images.unsplash.com/photo-1627308595229-7830a5c91f9f?auto=format&fit=crop&w=800&q=80', true, false, '{Riz,Poisson,Chou,Carotte,Manioc}', 900, 45),
('Riz Jollof Poulet', 'Riz "Jollof" épicé servi avec une cuisse de poulet braisée et bananes plantains.', 5500, 'e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a55', 'https://images.unsplash.com/photo-1604329760661-e71dc70844f9?auto=format&fit=crop&w=800&q=80', true, false, '{Riz,Tomate,Poulet Braisé,Alloco}', 850, 40),
('Curry Vert Crevettes', 'Curry thaï au lait de coco, bambou et basilic, servi avec riz jasmin.', 7000, 'e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a55', 'https://images.unsplash.com/photo-1565557623262-b51c2513a641?auto=format&fit=crop&w=800&q=80', false, false, '{Lait de coco,Pâte Curry Vert,Crevettes,Riz}', 700, 20),
('Riz Sauté Boeuf Lok-Lak', 'Dés de boeuf tendre sautés à la tomate, servis avec riz à la tomate.', 6500, 'e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a55', 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&w=800&q=80', false, false, '{Boeuf,Tomate,Riz,Oignon}', 750, 15);

-- DESSERTS (Toujours sympa d'en avoir)
INSERT INTO menu_items (name, description, price, category_id, image_url, is_popular, is_vegetarian, ingredients, calories, preparation_time) VALUES
('Fondant Chocolat', 'Coeur coulant, servi avec une boule vanille.', 3500, 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a44', 'https://images.unsplash.com/photo-1606313564200-e75d5e30476d?auto=format&fit=crop&w=800&q=80', true, true, '{Chocolat,Beurre,Oeuf,Glace}', 500, 10),
('Tiramisu', 'La recette italienne authentique.', 3000, 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a44', 'https://images.unsplash.com/photo-1571877227200-a0d98ea607e9?auto=format&fit=crop&w=800&q=80', false, true, '{Mascarpone,Café,Biscuit}', 450, 0);

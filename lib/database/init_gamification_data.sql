-- =====================================================
-- INITIALISATION DES DONNÉES DE GAMIFICATION
-- =====================================================

-- Insérer les achievements par défaut
INSERT INTO achievements (title, description, icon, points, target, is_active) VALUES
('Premier Pas', 'Faire votre première commande', '🎯', 10, 1, true),
('Habitué', 'Faire 5 commandes', '🏆', 25, 5, true),
('Explorateur', 'Essayer 10 plats différents', '🗺️', 50, 10, true),
('Série de Victoires', 'Commander 7 jours consécutifs', '🔥', 75, 7, true),
('Critique Culinaire', 'Laisser 20 avis', '⭐', 100, 20, true),
('Champion El Corazón', 'Atteindre le niveau 5', '👑', 200, 5, true),
('Gourmet Expert', 'Commander 50 fois', '🍽️', 300, 50, true),
('Légende Culinaire', 'Atteindre le niveau 10', '🌟', 500, 10, true);

-- Insérer les challenges par défaut
INSERT INTO challenges (title, description, challenge_type, target_value, reward_points, start_date, end_date, is_active) VALUES
('Défi Weekend', 'Commandez 3 fois ce weekend', 'weekly', 3, 50, NOW(), NOW() + INTERVAL '2 days', true),
('Découverte Culinaire', 'Essayez 2 nouveaux plats cette semaine', 'weekly', 2, 30, NOW(), NOW() + INTERVAL '5 days', true),
('Partageur', 'Partagez l''app avec 3 amis', 'monthly', 3, 100, NOW(), NOW() + INTERVAL '7 days', true),
('Gourmet du Mois', 'Commander 15 fois ce mois', 'monthly', 15, 200, NOW(), NOW() + INTERVAL '30 days', true);

-- Insérer les rewards par défaut
INSERT INTO loyalty_rewards (id, title, description, cost, reward_type, value, is_active) VALUES
('loyalty_free_drink', 'Boisson Gratuite', 'Une boisson de votre choix offerte', 50, 'free_item', NULL, true),
('loyalty_free_fries', 'Frites Gratuites', 'Portion de frites offerte', 75, 'free_item', NULL, true),
('loyalty_discount_10', '10% de Réduction', 'Sur votre prochaine commande', 100, 'discount', 10, true),
('loyalty_free_burger', 'Un burger de votre choix offert', 150, 'free_item', NULL, true),
('loyalty_discount_20', '20% de Réduction', 'Sur votre prochaine commande', 200, 'discount', 20, true),
('loyalty_free_menu', 'Menu Complet Gratuit', 'Un menu complet offert', 300, 'free_item', NULL, true),
('loyalty_discount_30', '30% de Réduction', 'Réduction exceptionnelle sur votre prochain panier', 400, 'discount', 30, true),
('loyalty_free_meal', 'Repas Gratuit', 'Un repas complet offert', 500, 'free_item', NULL, true);

-- Insérer les badges par défaut
INSERT INTO badges (title, description, icon, points_required, is_active) VALUES
('Premier Pas', 'Votre première commande', '🎯', 0, true),
('Habitué', '5 commandes effectuées', '🏆', 25, true),
('Explorateur', '10 plats différents essayés', '🗺️', 50, true),
('Série de Victoires', '7 jours consécutifs de commandes', '🔥', 75, true),
('Critique Culinaire', '20 avis laissés', '⭐', 100, true),
('Champion El Corazón', 'Niveau 5 atteint', '👑', 200, true),
('Gourmet Expert', '50 commandes effectuées', '🍽️', 300, true),
('Légende Culinaire', 'Niveau 10 atteint', '🌟', 500, true);


-- =====================================================
-- FICHIER SQL POUR CRÉER LA TABLE PRODUCT_REVIEWS
-- =====================================================
-- Ce fichier crée la table product_reviews pour stocker
-- les avis et notes des utilisateurs sur les produits (menu items)
-- 
-- Instructions :
-- 1. Exécuter ce fichier dans l'éditeur SQL de Supabase
-- 2. Vérifier que la table a été créée correctement
-- =====================================================

-- =====================================================
-- 1. CRÉATION DE LA TABLE PRODUCT_REVIEWS
-- =====================================================

CREATE TABLE IF NOT EXISTS product_reviews (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    menu_item_id UUID NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    user_name TEXT NOT NULL,
    rating DECIMAL(3,2) NOT NULL CHECK (rating >= 1 AND rating <= 5),
    title TEXT,
    comment TEXT NOT NULL,
    photos TEXT[] DEFAULT '{}',
    is_verified_purchase BOOLEAN DEFAULT FALSE,
    helpful_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    -- Empêcher les doublons : un utilisateur ne peut pas reviewer le même produit plusieurs fois
    UNIQUE(menu_item_id, user_id)
);

-- =====================================================
-- 2. INDEX POUR LES PERFORMANCES
-- =====================================================

-- Index pour les requêtes par menu_item_id
CREATE INDEX IF NOT EXISTS idx_product_reviews_menu_item_id ON product_reviews(menu_item_id);

-- Index pour les requêtes par user_id
CREATE INDEX IF NOT EXISTS idx_product_reviews_user_id ON product_reviews(user_id);

-- Index pour les requêtes par rating
CREATE INDEX IF NOT EXISTS idx_product_reviews_rating ON product_reviews(rating);

-- Index pour les requêtes par created_at (pour trier par date)
CREATE INDEX IF NOT EXISTS idx_product_reviews_created_at ON product_reviews(created_at DESC);

-- Index composite pour les requêtes fréquentes
CREATE INDEX IF NOT EXISTS idx_product_reviews_menu_item_rating ON product_reviews(menu_item_id, rating);

-- =====================================================
-- 3. TRIGGER POUR MISE À JOUR AUTOMATIQUE
-- =====================================================

-- Trigger pour mettre à jour updated_at automatiquement
CREATE TRIGGER update_product_reviews_updated_at BEFORE UPDATE ON product_reviews
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- 4. ROW LEVEL SECURITY (RLS)
-- =====================================================

-- Activer RLS sur la table
ALTER TABLE product_reviews ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- 5. POLITIQUES RLS
-- =====================================================

-- Politique pour permettre à tous les utilisateurs de voir les reviews
CREATE POLICY "Anyone can view product reviews" ON product_reviews
    FOR SELECT USING (true);

-- Politique pour permettre aux utilisateurs de créer leurs propres reviews
CREATE POLICY "Users can create their own reviews" ON product_reviews
    FOR INSERT WITH CHECK (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    );

-- Politique pour permettre aux utilisateurs de mettre à jour leurs propres reviews
CREATE POLICY "Users can update their own reviews" ON product_reviews
    FOR UPDATE USING (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    ) WITH CHECK (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    );

-- Politique pour permettre aux utilisateurs de supprimer leurs propres reviews
CREATE POLICY "Users can delete their own reviews" ON product_reviews
    FOR DELETE USING (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    );

-- Politique pour permettre aux admins de gérer toutes les reviews
CREATE POLICY "Admins can manage all reviews" ON product_reviews
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE auth_user_id = auth.uid() 
            AND role = 'admin'
        )
    );

-- =====================================================
-- 6. FONCTION POUR CALCULER LA MOYENNE DES RATINGS
-- =====================================================

-- Fonction pour calculer la moyenne des ratings d'un menu item
CREATE OR REPLACE FUNCTION calculate_menu_item_rating(p_menu_item_id UUID)
RETURNS TABLE (
    average_rating DECIMAL(3,2),
    total_reviews INTEGER,
    rating_distribution JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(AVG(pr.rating), 0::DECIMAL(3,2))::DECIMAL(3,2) as average_rating,
        COUNT(*)::INTEGER as total_reviews,
        jsonb_build_object(
            '1', COUNT(*) FILTER (WHERE pr.rating >= 1 AND pr.rating < 2),
            '2', COUNT(*) FILTER (WHERE pr.rating >= 2 AND pr.rating < 3),
            '3', COUNT(*) FILTER (WHERE pr.rating >= 3 AND pr.rating < 4),
            '4', COUNT(*) FILTER (WHERE pr.rating >= 4 AND pr.rating < 5),
            '5', COUNT(*) FILTER (WHERE pr.rating = 5)
        ) as rating_distribution
    FROM product_reviews pr
    WHERE pr.menu_item_id = p_menu_item_id;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 7. TRIGGER POUR METTRE À JOUR LE RATING DU MENU ITEM
-- =====================================================

-- Fonction pour mettre à jour le rating du menu item après insertion/modification/suppression d'une review
CREATE OR REPLACE FUNCTION update_menu_item_rating()
RETURNS TRIGGER AS $$
DECLARE
    avg_rating DECIMAL(3,2);
    total_count INTEGER;
BEGIN
    -- Calculer la nouvelle moyenne
    SELECT 
        COALESCE(AVG(rating), 0)::DECIMAL(3,2),
        COUNT(*)::INTEGER
    INTO avg_rating, total_count
    FROM product_reviews
    WHERE menu_item_id = COALESCE(NEW.menu_item_id, OLD.menu_item_id);
    
    -- Mettre à jour le menu item
    UPDATE menu_items
    SET 
        rating = avg_rating,
        review_count = total_count,
        updated_at = NOW()
    WHERE id = COALESCE(NEW.menu_item_id, OLD.menu_item_id);
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Trigger pour mettre à jour le rating après insertion
CREATE TRIGGER trigger_update_menu_item_rating_after_insert
    AFTER INSERT ON product_reviews
    FOR EACH ROW
    EXECUTE FUNCTION update_menu_item_rating();

-- Trigger pour mettre à jour le rating après modification
CREATE TRIGGER trigger_update_menu_item_rating_after_update
    AFTER UPDATE ON product_reviews
    FOR EACH ROW
    WHEN (OLD.rating IS DISTINCT FROM NEW.rating)
    EXECUTE FUNCTION update_menu_item_rating();

-- Trigger pour mettre à jour le rating après suppression
CREATE TRIGGER trigger_update_menu_item_rating_after_delete
    AFTER DELETE ON product_reviews
    FOR EACH ROW
    EXECUTE FUNCTION update_menu_item_rating();

-- =====================================================
-- 8. COMMENTAIRES
-- =====================================================

COMMENT ON TABLE product_reviews IS 'Table pour stocker les avis et notes des utilisateurs sur les produits (menu items)';
COMMENT ON COLUMN product_reviews.rating IS 'Note de 1 à 5';
COMMENT ON COLUMN product_reviews.is_verified_purchase IS 'Indique si l''utilisateur a réellement commandé ce produit';
COMMENT ON COLUMN product_reviews.helpful_count IS 'Nombre d''utilisateurs qui ont trouvé cette review utile';

-- =====================================================
-- FIN DU FICHIER
-- =====================================================



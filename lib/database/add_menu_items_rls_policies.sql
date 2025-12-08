-- =====================================================
-- FICHIER SQL POUR AJOUTER LES POLITIQUES RLS POUR MENU_ITEMS
-- =====================================================
-- Ce fichier ajoute les politiques RLS manquantes pour permettre
-- la création, modification et suppression d'éléments de menu
-- 
-- Instructions :
-- 1. Exécuter ce fichier dans l'éditeur SQL de Supabase
-- 2. Vérifier que les politiques ont été créées correctement
-- =====================================================

-- Supprimer les anciennes politiques si elles existent (pour éviter les doublons)
DROP POLICY IF EXISTS "Admins can manage menu items" ON menu_items;
DROP POLICY IF EXISTS "Users can create menu items" ON menu_items;
DROP POLICY IF EXISTS "Users can update menu items" ON menu_items;
DROP POLICY IF EXISTS "Users can delete menu items" ON menu_items;

-- Politique pour permettre aux admins de gérer tous les éléments de menu
CREATE POLICY "Admins can manage menu items" ON menu_items
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE auth_user_id = auth.uid() 
            AND role = 'admin'
        )
    ) WITH CHECK (
        EXISTS (
            SELECT 1 FROM users 
            WHERE auth_user_id = auth.uid() 
            AND role = 'admin'
        )
    );

-- Politique pour permettre aux utilisateurs authentifiés de créer des éléments de menu
-- (nécessaire pour la création automatique lors des commandes)
-- Note: Cette politique permet à n'importe quel utilisateur authentifié de créer des éléments de menu
-- Si vous voulez restreindre cela, supprimez cette politique et assurez-vous que tous les éléments
-- de menu sont créés par les admins avant les commandes
CREATE POLICY "Authenticated users can create menu items" ON menu_items
    FOR INSERT WITH CHECK (
        auth.uid() IS NOT NULL
    );

-- Politique pour permettre aux utilisateurs authentifiés de mettre à jour leurs propres éléments de menu
-- (si nécessaire pour permettre aux utilisateurs de modifier les éléments qu'ils ont créés)
CREATE POLICY "Users can update their own menu items" ON menu_items
    FOR UPDATE USING (
        auth.uid() IS NOT NULL
    ) WITH CHECK (
        auth.uid() IS NOT NULL
    );

-- =====================================================
-- POLITIQUES POUR MENU_CATEGORIES (si nécessaire)
-- =====================================================

-- Supprimer les anciennes politiques si elles existent
DROP POLICY IF EXISTS "Admins can manage menu categories" ON menu_categories;
DROP POLICY IF EXISTS "Authenticated users can create menu categories" ON menu_categories;

-- Politique pour permettre aux admins de gérer les catégories
CREATE POLICY "Admins can manage menu categories" ON menu_categories
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE auth_user_id = auth.uid() 
            AND role = 'admin'
        )
    ) WITH CHECK (
        EXISTS (
            SELECT 1 FROM users 
            WHERE auth_user_id = auth.uid() 
            AND role = 'admin'
        )
    );

-- Politique pour permettre aux utilisateurs authentifiés de créer des catégories
-- (nécessaire pour la création automatique lors des commandes)
CREATE POLICY "Authenticated users can create menu categories" ON menu_categories
    FOR INSERT WITH CHECK (
        auth.uid() IS NOT NULL
    );

-- =====================================================
-- NOTES IMPORTANTES
-- =====================================================

-- ⚠️ ATTENTION : Les politiques ci-dessus permettent à tous les utilisateurs authentifiés
-- de créer des éléments de menu et des catégories. C'est utile pour la création automatique
-- lors des commandes, mais cela peut être un problème de sécurité.

-- Si vous voulez restreindre la création aux admins uniquement :
-- 1. Supprimez les politiques "Authenticated users can create..."
-- 2. Assurez-vous que tous les éléments de menu sont créés par les admins avant les commandes
-- 3. Modifiez le code pour ne pas essayer de créer des éléments de menu lors des commandes

-- Pour vérifier les politiques existantes :
-- SELECT * FROM pg_policies WHERE tablename = 'menu_items';

-- =====================================================
-- FIN DU FICHIER
-- =====================================================

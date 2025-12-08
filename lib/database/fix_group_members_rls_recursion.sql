-- =====================================================
-- FICHIER SQL POUR CORRIGER LA RÉCURSION INFINIE DANS GROUP_MEMBERS
-- =====================================================
-- Ce fichier corrige la politique RLS pour group_members qui cause
-- une récursion infinie en vérifiant l'appartenance au groupe
-- 
-- Instructions :
-- 1. Exécuter ce fichier dans l'éditeur SQL de Supabase
-- 2. Vérifier que les politiques ont été corrigées correctement
-- =====================================================

-- Supprimer les anciennes politiques qui causent la récursion
DROP POLICY IF EXISTS "Users can view group members" ON group_members;
DROP POLICY IF EXISTS "Users can manage their membership" ON group_members;

-- =====================================================
-- NOUVELLES POLITIQUES SANS RÉCURSION
-- =====================================================

-- Politique 1 : Les utilisateurs peuvent voir leurs propres membreships
CREATE POLICY "Users can view their own memberships" ON group_members
    FOR SELECT USING (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    );

-- Politique 2 : Les utilisateurs peuvent voir les membres des groupes publics
-- (sans vérifier l'appartenance pour éviter la récursion)
CREATE POLICY "Users can view public group members" ON group_members
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM social_groups sg
            WHERE sg.id = group_members.group_id
            AND sg.is_private = false
        )
    );

-- Politique 3 : Les créateurs de groupes peuvent voir tous les membres de leurs groupes
CREATE POLICY "Group creators can view their group members" ON group_members
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM social_groups sg
            JOIN users u ON u.id = sg.creator_id
            WHERE sg.id = group_members.group_id
            AND u.auth_user_id::text = auth.uid()::text
        )
    );

-- Politique 4 : Les utilisateurs peuvent gérer leurs propres membreships
CREATE POLICY "Users can manage their own memberships" ON group_members
    FOR ALL USING (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    ) WITH CHECK (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    );

-- Politique 5 : Les créateurs de groupes peuvent ajouter des membres à leurs groupes
CREATE POLICY "Group creators can add members" ON group_members
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM social_groups sg
            JOIN users u ON u.id = sg.creator_id
            WHERE sg.id = group_members.group_id
            AND u.auth_user_id::text = auth.uid()::text
        )
    );

-- Politique 6 : Les créateurs de groupes peuvent supprimer des membres de leurs groupes
CREATE POLICY "Group creators can remove members" ON group_members
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM social_groups sg
            JOIN users u ON u.id = sg.creator_id
            WHERE sg.id = group_members.group_id
            AND u.auth_user_id::text = auth.uid()::text
        )
    );

-- =====================================================
-- NOTES IMPORTANTES
-- =====================================================

-- ⚠️ ATTENTION : Les nouvelles politiques évitent la récursion en :
-- 1. Ne vérifiant pas l'appartenance au groupe dans la politique de lecture
-- 2. Utilisant directement les informations du groupe (is_private, creator_id)
-- 3. Séparant les permissions en plusieurs politiques spécifiques

-- Pour vérifier les politiques existantes :
-- SELECT * FROM pg_policies WHERE tablename = 'group_members';

-- Pour tester les politiques :
-- 1. Vérifier que les utilisateurs peuvent voir leurs propres membreships
-- 2. Vérifier que les utilisateurs peuvent voir les membres des groupes publics
-- 3. Vérifier que les créateurs peuvent voir tous les membres de leurs groupes

-- =====================================================
-- CORRECTION POUR SOCIAL_POSTS (qui utilise aussi group_members)
-- =====================================================

-- Vérifier si la politique pour social_posts utilise group_members
-- Si oui, elle pourrait aussi causer une récursion
-- La politique actuelle pour social_posts utilise :
-- EXISTS (SELECT 1 FROM group_members WHERE group_id = social_posts.group_id ...)
-- Ce qui pourrait causer une récursion si group_members vérifie l'appartenance

-- Solution : Simplifier la politique pour social_posts
DROP POLICY IF EXISTS "Users can view public posts and posts from their groups" ON social_posts;

-- Nouvelle politique simplifiée pour social_posts
CREATE POLICY "Users can view public posts" ON social_posts
    FOR SELECT USING (
        is_public = true
    );

-- Politique pour voir les posts des groupes publics
CREATE POLICY "Users can view public group posts" ON social_posts
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM social_groups sg
            WHERE sg.id = social_posts.group_id
            AND sg.is_private = false
        )
    );

-- Politique pour voir les posts des groupes dont l'utilisateur est créateur
CREATE POLICY "Group creators can view their group posts" ON social_posts
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM social_groups sg
            JOIN users u ON u.id = sg.creator_id
            WHERE sg.id = social_posts.group_id
            AND u.auth_user_id::text = auth.uid()::text
        )
    );

-- Politique pour voir ses propres posts
CREATE POLICY "Users can view their own posts" ON social_posts
    FOR SELECT USING (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    );

-- =====================================================
-- FIN DU FICHIER
-- =====================================================


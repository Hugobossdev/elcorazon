-- =====================================================
-- FICHIER SQL POUR CORRIGER LA RÉCURSION INFINIE DANS SOCIAL_GROUPS
-- =====================================================
-- Ce fichier corrige la politique RLS pour social_groups qui cause
-- une récursion infinie en vérifiant l'appartenance au groupe via group_members
-- 
-- Instructions :
-- 1. Exécuter ce fichier dans l'éditeur SQL de Supabase
-- 2. Vérifier que les politiques ont été corrigées correctement
-- =====================================================

-- Supprimer les anciennes politiques qui causent la récursion
DROP POLICY IF EXISTS "Users can view public groups and their own groups" ON social_groups;
DROP POLICY IF EXISTS "Users can create groups" ON social_groups;
DROP POLICY IF EXISTS "Users can update their groups" ON social_groups;
DROP POLICY IF EXISTS "Users can delete their groups" ON social_groups;

-- =====================================================
-- NOUVELLES POLITIQUES SANS RÉCURSION
-- =====================================================

-- Politique 1 : Les utilisateurs peuvent voir les groupes publics
CREATE POLICY "Users can view public groups" ON social_groups
    FOR SELECT USING (
        is_private = false
    );

-- Politique 2 : Les utilisateurs peuvent voir les groupes dont ils sont créateurs
CREATE POLICY "Users can view their created groups" ON social_groups
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users u
            WHERE u.id = social_groups.creator_id
            AND u.auth_user_id::text = auth.uid()::text
        )
    );

-- Politique 3 : Les utilisateurs peuvent créer des groupes
CREATE POLICY "Users can create groups" ON social_groups
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM users u
            WHERE u.id = creator_id
            AND u.auth_user_id::text = auth.uid()::text
        )
    );

-- Politique 4 : Les créateurs peuvent mettre à jour leurs groupes
CREATE POLICY "Group creators can update their groups" ON social_groups
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM users u
            WHERE u.id = creator_id
            AND u.auth_user_id::text = auth.uid()::text
        )
    ) WITH CHECK (
        EXISTS (
            SELECT 1 FROM users u
            WHERE u.id = creator_id
            AND u.auth_user_id::text = auth.uid()::text
        )
    );

-- Politique 5 : Les créateurs peuvent supprimer leurs groupes
CREATE POLICY "Group creators can delete their groups" ON social_groups
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM users u
            WHERE u.id = creator_id
            AND u.auth_user_id::text = auth.uid()::text
        )
    );

-- =====================================================
-- NOTES IMPORTANTES
-- =====================================================

-- ⚠️ ATTENTION : Les nouvelles politiques évitent la récursion en :
-- 1. Ne vérifiant pas l'appartenance au groupe via group_members
-- 2. Utilisant directement les informations du groupe (is_private, creator_id)
-- 3. Séparant les permissions en plusieurs politiques spécifiques

-- ⚠️ LIMITATION : Avec ces politiques, les utilisateurs ne peuvent voir que :
-- - Les groupes publics (is_private = false)
-- - Les groupes dont ils sont créateurs
-- 
-- Pour voir les groupes privés dont ils sont membres (mais pas créateurs),
-- il faudrait utiliser une fonction SQL ou une vue qui évite la récursion,
-- ou modifier l'approche pour stocker l'appartenance différemment.

-- Pour vérifier les politiques existantes :
-- SELECT * FROM pg_policies WHERE tablename = 'social_groups';

-- Pour tester les politiques :
-- 1. Vérifier que les utilisateurs peuvent voir les groupes publics
-- 2. Vérifier que les créateurs peuvent voir leurs groupes
-- 3. Vérifier que les créateurs peuvent créer/mettre à jour/supprimer leurs groupes

-- =====================================================
-- SOLUTION ALTERNATIVE : Fonction SQL pour vérifier l'appartenance
-- =====================================================

-- Si vous avez besoin que les utilisateurs voient les groupes privés dont ils sont membres,
-- vous pouvez créer une fonction SQL qui évite la récursion :

CREATE OR REPLACE FUNCTION is_group_member(p_group_id UUID, p_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM group_members gm
        JOIN users u ON u.id = gm.user_id
        WHERE gm.group_id = p_group_id
        AND u.id = p_user_id
        AND gm.is_active = true
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Puis utiliser cette fonction dans une politique (mais attention, cela peut encore causer des problèmes)
-- CREATE POLICY "Users can view groups they are members of" ON social_groups
--     FOR SELECT USING (
--         is_private = false
--         OR EXISTS (SELECT 1 FROM users WHERE id = creator_id AND auth_user_id = auth.uid())
--         OR is_group_member(id, (SELECT id FROM users WHERE auth_user_id = auth.uid()))
--     );

-- =====================================================
-- FIN DU FICHIER
-- =====================================================



-- =====================================================
-- FICHIER SQL POUR AJOUTER LES POLITIQUES RLS MANQUANTES
-- =====================================================
-- Ce fichier ajoute les politiques RLS manquantes pour :
-- - analytics_events : Permettre aux utilisateurs d'insérer des événements
-- - loyalty_transactions : Permettre aux utilisateurs d'insérer leurs transactions
-- 
-- Instructions :
-- 1. Exécuter ce fichier dans l'éditeur SQL de Supabase
-- 2. Vérifier que les politiques ont été créées correctement
-- =====================================================

-- =====================================================
-- 1. POLITIQUES POUR ANALYTICS_EVENTS
-- =====================================================

-- Supprimer l'ancienne politique si elle existe (pour éviter les doublons)
DROP POLICY IF EXISTS "Users can insert analytics events" ON analytics_events;

-- Politique pour permettre aux utilisateurs authentifiés d'insérer des événements analytics
CREATE POLICY "Users can insert analytics events" ON analytics_events
    FOR INSERT WITH CHECK (
        auth.uid() IS NOT NULL
        AND (
            user_id IS NULL 
            OR user_id = (
                SELECT id FROM users WHERE auth_user_id = auth.uid()
            )
        )
    );

-- Politique pour permettre aux utilisateurs de voir leurs propres événements analytics
DROP POLICY IF EXISTS "Users can view their own analytics events" ON analytics_events;
CREATE POLICY "Users can view their own analytics events" ON analytics_events
    FOR SELECT USING (
        user_id IS NULL
        OR user_id = (
            SELECT id FROM users WHERE auth_user_id = auth.uid()
        )
    );

-- =====================================================
-- 2. POLITIQUES POUR LOYALTY_TRANSACTIONS
-- =====================================================

-- Supprimer les anciennes politiques si elles existent
DROP POLICY IF EXISTS "Users can create their loyalty transactions" ON loyalty_transactions;

-- Politique pour permettre aux utilisateurs d'insérer leurs propres transactions de fidélité
CREATE POLICY "Users can create their loyalty transactions" ON loyalty_transactions
    FOR INSERT WITH CHECK (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    );

-- =====================================================
-- 3. NOTES IMPORTANTES
-- =====================================================

-- ⚠️ ATTENTION : Les politiques ci-dessus permettent aux utilisateurs authentifiés
-- d'insérer des événements analytics et des transactions de fidélité.
-- C'est nécessaire pour le fonctionnement normal de l'application.

-- Pour vérifier les politiques existantes :
-- SELECT * FROM pg_policies WHERE tablename = 'analytics_events';
-- SELECT * FROM pg_policies WHERE tablename = 'loyalty_transactions';

-- =====================================================
-- FIN DU FICHIER
-- =====================================================


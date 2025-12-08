-- =====================================================
-- FICHIER SQL POUR LES TABLES D'ABONNEMENTS
-- =====================================================
-- Ce fichier contient les tables, index, triggers et politiques RLS
-- pour le système d'abonnements (VIP et repas)
-- 
-- Instructions :
-- 1. Exécuter ce fichier dans l'éditeur SQL de Supabase
-- 2. Vérifier que les tables ont été créées correctement
-- 3. Tester les politiques RLS si nécessaire
-- =====================================================

-- =====================================================
-- 1. TABLES D'ABONNEMENTS
-- =====================================================

-- Table des abonnements (VIP et repas)
CREATE TABLE IF NOT EXISTS subscriptions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    subscription_type TEXT NOT NULL CHECK (subscription_type IN ('weekly', 'monthly', 'vip')),
    plan_name TEXT,
    meals_per_week INTEGER DEFAULT 0,
    price_per_meal DECIMAL(10,2) DEFAULT 0.0,
    monthly_price DECIMAL(10,2) NOT NULL,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'paused', 'cancelled', 'expired')),
    current_period_start TIMESTAMP WITH TIME ZONE NOT NULL,
    current_period_end TIMESTAMP WITH TIME ZONE NOT NULL,
    meals_used_this_period INTEGER DEFAULT 0,
    auto_renew BOOLEAN DEFAULT TRUE,
    cancelled_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table des commandes d'abonnement
CREATE TABLE IF NOT EXISTS subscription_orders (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    meal_count INTEGER DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(subscription_id, order_id)
);

-- =====================================================
-- 2. INDEX POUR LES PERFORMANCES
-- =====================================================

-- Index pour la table subscriptions
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_type ON subscriptions(subscription_type);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_subscriptions_period_end ON subscriptions(current_period_end);

-- Index pour la table subscription_orders
CREATE INDEX IF NOT EXISTS idx_subscription_orders_subscription_id ON subscription_orders(subscription_id);
CREATE INDEX IF NOT EXISTS idx_subscription_orders_order_id ON subscription_orders(order_id);
CREATE INDEX IF NOT EXISTS idx_subscription_orders_created_at ON subscription_orders(created_at);

-- =====================================================
-- 3. TRIGGERS POUR MISE À JOUR AUTOMATIQUE
-- =====================================================

-- Trigger pour mettre à jour updated_at automatiquement
CREATE TRIGGER update_subscriptions_updated_at BEFORE UPDATE ON subscriptions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Note: La fonction update_updated_at_column() doit déjà exister dans votre base de données
-- Si elle n'existe pas, exécutez d'abord :
-- CREATE OR REPLACE FUNCTION update_updated_at_column()
-- RETURNS TRIGGER AS $$
-- BEGIN
--     NEW.updated_at = NOW();
--     RETURN NEW;
-- END;
-- $$ language 'plpgsql';

-- =====================================================
-- 4. ROW LEVEL SECURITY (RLS)
-- =====================================================

-- Activer RLS sur les tables
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_orders ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- 5. POLITIQUES RLS POUR LES ABONNEMENTS
-- =====================================================

-- Politique pour permettre aux utilisateurs de voir leurs propres abonnements
CREATE POLICY "Users can view their own subscriptions" ON subscriptions
    FOR SELECT USING (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    );

-- Politique pour permettre aux utilisateurs de créer leurs propres abonnements
CREATE POLICY "Users can create their own subscriptions" ON subscriptions
    FOR INSERT WITH CHECK (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    );

-- Politique pour permettre aux utilisateurs de mettre à jour leurs propres abonnements
CREATE POLICY "Users can update their own subscriptions" ON subscriptions
    FOR UPDATE USING (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    ) WITH CHECK (
        auth.uid()::text = (
            SELECT auth_user_id::text FROM users WHERE id = user_id
        )
    );

-- Politique pour permettre aux admins de voir tous les abonnements
CREATE POLICY "Admins can view all subscriptions" ON subscriptions
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE auth_user_id = auth.uid() 
            AND role = 'admin'
        )
    );

-- Politique pour permettre aux admins de gérer tous les abonnements
CREATE POLICY "Admins can manage all subscriptions" ON subscriptions
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE auth_user_id = auth.uid() 
            AND role = 'admin'
        )
    );

-- =====================================================
-- 6. POLITIQUES RLS POUR LES COMMANDES D'ABONNEMENT
-- =====================================================

-- Politique pour permettre aux utilisateurs de voir leurs commandes d'abonnement
CREATE POLICY "Users can view their subscription orders" ON subscription_orders
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM subscriptions s
            JOIN users u ON u.id = s.user_id
            WHERE s.id = subscription_orders.subscription_id
            AND u.auth_user_id::text = auth.uid()::text
        )
    );

-- Politique pour permettre aux utilisateurs de créer des commandes d'abonnement
CREATE POLICY "Users can create subscription orders" ON subscription_orders
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM subscriptions s
            JOIN users u ON u.id = s.user_id
            WHERE s.id = subscription_orders.subscription_id
            AND u.auth_user_id::text = auth.uid()::text
        )
    );

-- Politique pour permettre aux admins de voir toutes les commandes d'abonnement
CREATE POLICY "Admins can view all subscription orders" ON subscription_orders
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE auth_user_id = auth.uid() 
            AND role = 'admin'
        )
    );

-- =====================================================
-- 7. COMMENTAIRES ET NOTES
-- =====================================================

-- Types d'abonnements supportés :
-- - 'weekly' : Abonnement hebdomadaire pour repas
-- - 'monthly' : Abonnement mensuel pour repas
-- - 'vip' : Abonnement VIP avec avantages exclusifs

-- Statuts possibles :
-- - 'active' : Abonnement actif
-- - 'paused' : Abonnement en pause
-- - 'cancelled' : Abonnement annulé
-- - 'expired' : Abonnement expiré

-- Notes importantes :
-- 1. La table subscriptions est liée à la table users via user_id
-- 2. La table subscription_orders lie les abonnements aux commandes
-- 3. Les politiques RLS garantissent que les utilisateurs ne peuvent voir que leurs propres abonnements
-- 4. Les admins ont accès à tous les abonnements pour la gestion
-- 5. Le trigger met à jour automatiquement updated_at lors des modifications

-- =====================================================
-- FIN DU FICHIER
-- =====================================================


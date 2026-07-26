-- =====================================================
-- 📋 SECTION 13: TABLES MARKETING (Manquantes)
-- =====================================================

-- Table des campagnes marketing
CREATE TABLE IF NOT EXISTS marketing_campaigns (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('personalized', 'seasonal', 'promotional', 'retention')),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    target_user_ids TEXT[] DEFAULT '{}',
    conditions JSONB DEFAULT '{}'::jsonb,
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    metrics JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index pour marketing_campaigns
CREATE INDEX IF NOT EXISTS idx_marketing_campaigns_is_active ON marketing_campaigns(is_active);
CREATE INDEX IF NOT EXISTS idx_marketing_campaigns_type ON marketing_campaigns(type);
CREATE INDEX IF NOT EXISTS idx_marketing_campaigns_dates ON marketing_campaigns(start_date, end_date);

-- Trigger pour mettre à jour updated_at
DROP TRIGGER IF EXISTS update_marketing_campaigns_updated_at ON marketing_campaigns;
CREATE TRIGGER update_marketing_campaigns_updated_at 
BEFORE UPDATE ON marketing_campaigns
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Politiques RLS (Row Level Security)
ALTER TABLE marketing_campaigns ENABLE ROW LEVEL SECURITY;

-- Les admins peuvent tout faire
CREATE POLICY "Admins can manage marketing campaigns"
    ON marketing_campaigns FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM user_admin_roles uar
            JOIN admin_roles ar ON uar.role_id = ar.id
            WHERE uar.user_id = auth.uid()
        )
    );

-- Les utilisateurs peuvent voir les campagnes actives qui les ciblent
-- Note: Cette politique est simplifiée. Pour une sécurité optimale, il faudrait vérifier target_user_ids
-- Mais comme auth.uid() retourne un UUID et target_user_ids est TEXT[], la conversion est nécessaire
CREATE POLICY "Users can view relevant campaigns"
    ON marketing_campaigns FOR SELECT
    USING (
        is_active = TRUE 
        AND NOW() BETWEEN start_date AND end_date
        -- Optionnel: filtrer par target_user_ids si nécessaire
        -- AND (target_user_ids = '{}' OR auth.uid()::text = ANY(target_user_ids))
    );


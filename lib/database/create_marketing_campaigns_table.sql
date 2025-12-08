-- =====================================================
-- TABLE MARKETING_CAMPAIGNS
-- Table pour stocker les campagnes marketing avec métriques
-- =====================================================

CREATE TABLE IF NOT EXISTS marketing_campaigns (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('personalized', 'seasonal', 'promotional', 'retention')),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    target_user_ids TEXT[] DEFAULT '{}',
    conditions JSONB DEFAULT '{}',
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    metrics JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index pour améliorer les performances des requêtes
CREATE INDEX IF NOT EXISTS idx_marketing_campaigns_type ON marketing_campaigns(type);
CREATE INDEX IF NOT EXISTS idx_marketing_campaigns_is_active ON marketing_campaigns(is_active);
CREATE INDEX IF NOT EXISTS idx_marketing_campaigns_dates ON marketing_campaigns(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_marketing_campaigns_created_at ON marketing_campaigns(created_at DESC);

-- Fonction pour mettre à jour automatiquement updated_at
CREATE OR REPLACE FUNCTION update_marketing_campaigns_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger pour mettre à jour updated_at automatiquement
DROP TRIGGER IF EXISTS trigger_update_marketing_campaigns_updated_at ON marketing_campaigns;
CREATE TRIGGER trigger_update_marketing_campaigns_updated_at
    BEFORE UPDATE ON marketing_campaigns
    FOR EACH ROW
    EXECUTE FUNCTION update_marketing_campaigns_updated_at();

-- RLS (Row Level Security) Policies
ALTER TABLE marketing_campaigns ENABLE ROW LEVEL SECURITY;

-- Policy: Les admins peuvent tout faire
CREATE POLICY "Admins can manage all marketing campaigns"
    ON marketing_campaigns
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE users.auth_user_id = auth.uid()
            AND users.role = 'admin'
        )
    );

-- Policy: Les utilisateurs peuvent voir les campagnes actives qui les ciblent
CREATE POLICY "Users can view active campaigns targeting them"
    ON marketing_campaigns
    FOR SELECT
    USING (
        is_active = TRUE
        AND NOW() >= start_date
        AND NOW() <= end_date
        AND (
            array_length(target_user_ids, 1) IS NULL
            OR auth.uid()::TEXT = ANY(target_user_ids)
        )
    );

-- Commentaires pour la documentation
COMMENT ON TABLE marketing_campaigns IS 'Table pour stocker les campagnes marketing avec leurs métriques';
COMMENT ON COLUMN marketing_campaigns.type IS 'Type de campagne: personalized, seasonal, promotional, retention';
COMMENT ON COLUMN marketing_campaigns.target_user_ids IS 'Liste des IDs utilisateurs ciblés (vide = tous les utilisateurs)';
COMMENT ON COLUMN marketing_campaigns.conditions IS 'Conditions JSON pour le ciblage (ex: dayOfWeek, loyaltyPoints, etc.)';
COMMENT ON COLUMN marketing_campaigns.metrics IS 'Métriques JSON (views, clicks, conversions, sent, etc.)';


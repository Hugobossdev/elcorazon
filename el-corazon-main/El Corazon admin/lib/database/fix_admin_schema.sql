-- =====================================================
-- 🛠️ FIX ADMIN SCHEMA: FONCTIONNALITÉS LIVREURS AVANCÉES
-- =====================================================
-- Ce script ajoute toutes les tables manquantes pour :
-- 1. La gestion des documents (validation, historique)
-- 2. La notation détaillée (service, temps, etc.)
-- 3. La gamification (badges)

-- =====================================================
-- 1. GESTION DES DOCUMENTS
-- =====================================================

CREATE TABLE IF NOT EXISTS public.driver_documents (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    driver_id UUID NOT NULL REFERENCES public.drivers(id) ON DELETE CASCADE,
    document_type TEXT NOT NULL,
    document_url TEXT NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'expired')),
    rejection_reason TEXT,
    expiry_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_driver_documents_driver_id ON public.driver_documents(driver_id);

CREATE TABLE IF NOT EXISTS public.driver_document_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    document_id UUID REFERENCES public.driver_documents(id) ON DELETE SET NULL,
    driver_id UUID REFERENCES public.drivers(id) ON DELETE CASCADE,
    previous_status TEXT,
    new_status TEXT NOT NULL,
    changed_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    change_reason TEXT,
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 2. NOTATION DÉTAILLÉE (Feedback)
-- =====================================================

CREATE TABLE IF NOT EXISTS public.driver_ratings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    driver_id UUID NOT NULL REFERENCES public.drivers(id) ON DELETE CASCADE,
    client_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    order_id UUID REFERENCES public.orders(id) ON DELETE SET NULL,
    rating_delivery_time INTEGER CHECK (rating_delivery_time BETWEEN 1 AND 5),
    rating_service INTEGER CHECK (rating_service BETWEEN 1 AND 5),
    rating_condition INTEGER CHECK (rating_condition BETWEEN 1 AND 5),
    rating_average DECIMAL(3,2),
    comment TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_driver_ratings_driver_id ON public.driver_ratings(driver_id);

-- Vue pour les stats détaillées
CREATE OR REPLACE VIEW public.driver_detailed_stats_view AS
SELECT 
    driver_id,
    COUNT(*) as total_reviews,
    ROUND(AVG(rating_average), 2) as avg_global_rating,
    ROUND(AVG(rating_delivery_time), 2) as avg_time_rating,
    ROUND(AVG(rating_service), 2) as avg_service_rating,
    ROUND(AVG(rating_condition), 2) as avg_condition_rating
FROM public.driver_ratings
GROUP BY driver_id;

-- =====================================================
-- 3. GAMIFICATION (Badges)
-- =====================================================

CREATE TABLE IF NOT EXISTS public.driver_badges (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE, -- ex: 'Speedy', 'Reliable', 'Veteran'
    display_name TEXT NOT NULL,
    icon_url TEXT,
    description TEXT,
    criteria TEXT, -- JSON ou texte descriptif
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.driver_earned_badges (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    driver_id UUID NOT NULL REFERENCES public.drivers(id) ON DELETE CASCADE,
    badge_id UUID NOT NULL REFERENCES public.driver_badges(id) ON DELETE CASCADE,
    earned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(driver_id, badge_id)
);

-- Données initiales pour les badges
INSERT INTO public.driver_badges (name, display_name, description) VALUES
('fast_delivery', 'Livreur Express', 'A effectué 50 livraisons en moins de 30 min'),
('top_rated', '5 Étoiles', 'A maintenu une note de 5.0 pendant un mois'),
('veteran', 'Vétéran', 'Plus de 1000 livraisons effectuées'),
('early_bird', 'Lève-tôt', 'Disponible régulièrement le matin')
ON CONFLICT (name) DO NOTHING;

-- =====================================================
-- 4. SECURITE (RLS)
-- =====================================================

ALTER TABLE public.driver_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_document_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_badges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_earned_badges ENABLE ROW LEVEL SECURITY;

-- Politiques Admins (accès complet)
CREATE POLICY "Admins full access documents" ON public.driver_documents FOR ALL USING (EXISTS (SELECT 1 FROM public.user_admin_roles WHERE user_id = auth.uid()));
CREATE POLICY "Admins full access history" ON public.driver_document_history FOR ALL USING (EXISTS (SELECT 1 FROM public.user_admin_roles WHERE user_id = auth.uid()));
CREATE POLICY "Admins full access ratings" ON public.driver_ratings FOR ALL USING (EXISTS (SELECT 1 FROM public.user_admin_roles WHERE user_id = auth.uid()));
CREATE POLICY "Admins full access badges" ON public.driver_badges FOR ALL USING (EXISTS (SELECT 1 FROM public.user_admin_roles WHERE user_id = auth.uid()));
CREATE POLICY "Admins full access earned badges" ON public.driver_earned_badges FOR ALL USING (EXISTS (SELECT 1 FROM public.user_admin_roles WHERE user_id = auth.uid()));

-- Politiques Drivers (lecture propre données)
-- Note: Simplified for brevity, assumes driver_id mapping handles ownership
CREATE POLICY "Drivers view own documents" ON public.driver_documents FOR SELECT USING (driver_id IN (SELECT id FROM public.drivers WHERE user_id = auth.uid()::uuid)); -- Cast if auth.uid() is not uuid in your setup (usually is)
CREATE POLICY "Drivers insert own documents" ON public.driver_documents FOR INSERT WITH CHECK (driver_id IN (SELECT id FROM public.drivers WHERE user_id = auth.uid()::uuid));


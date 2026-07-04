-- =====================================================
-- 🛠️ FIX ADMIN SCHEMA V3: FORCE RESET WITH CASCADE
-- =====================================================
-- Ce script nettoie d'abord les tables liées aux fonctionnalités avancées
-- pour éviter les conflits de schéma, puis les recrée proprement.
-- Utilisation de CASCADE pour supprimer les dépendances (vues, triggers, FKs).

-- ⚠️ ATTENTION: Cela supprimera les données dans ces tables spécifiques si elles existent déjà.

BEGIN;

-- 1. Nettoyage (Drop avec CASCADE pour gérer les dépendances comme pending_driver_documents_view)
DROP VIEW IF EXISTS public.driver_detailed_stats_view CASCADE;
DROP TABLE IF EXISTS public.driver_document_history CASCADE;
DROP TABLE IF EXISTS public.driver_documents CASCADE;
DROP TABLE IF EXISTS public.driver_ratings CASCADE;
DROP TABLE IF EXISTS public.driver_earned_badges CASCADE;
DROP TABLE IF EXISTS public.driver_badges CASCADE;

-- 2. Création de la table driver_documents
CREATE TABLE public.driver_documents (
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

CREATE INDEX idx_driver_documents_driver_id ON public.driver_documents(driver_id);

-- 3. Création de la table driver_document_history
CREATE TABLE public.driver_document_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    document_id UUID REFERENCES public.driver_documents(id) ON DELETE SET NULL,
    driver_id UUID REFERENCES public.drivers(id) ON DELETE CASCADE,
    previous_status TEXT,
    new_status TEXT NOT NULL,
    changed_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    change_reason TEXT,
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Création de la table driver_ratings
CREATE TABLE public.driver_ratings (
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

CREATE INDEX idx_driver_ratings_driver_id ON public.driver_ratings(driver_id);

-- 5. Vue pour les stats détaillées
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

-- 6. Création des tables Badges
CREATE TABLE public.driver_badges (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL,
    icon_url TEXT,
    description TEXT,
    criteria TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE public.driver_earned_badges (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    driver_id UUID NOT NULL REFERENCES public.drivers(id) ON DELETE CASCADE,
    badge_id UUID NOT NULL REFERENCES public.driver_badges(id) ON DELETE CASCADE,
    earned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(driver_id, badge_id)
);

-- Données initiales Badges
INSERT INTO public.driver_badges (name, display_name, description) VALUES
('fast_delivery', 'Livreur Express', 'A effectué 50 livraisons en moins de 30 min'),
('top_rated', '5 Étoiles', 'A maintenu une note de 5.0 pendant un mois'),
('veteran', 'Vétéran', 'Plus de 1000 livraisons effectuées'),
('early_bird', 'Lève-tôt', 'Disponible régulièrement le matin')
ON CONFLICT (name) DO NOTHING;

-- 7. Activation RLS
ALTER TABLE public.driver_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_document_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_badges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_earned_badges ENABLE ROW LEVEL SECURITY;

-- 8. Politiques RLS

-- Admins
CREATE POLICY "Admins full access documents" ON public.driver_documents FOR ALL USING (EXISTS (SELECT 1 FROM public.user_admin_roles WHERE user_id = auth.uid()));
CREATE POLICY "Admins full access history" ON public.driver_document_history FOR ALL USING (EXISTS (SELECT 1 FROM public.user_admin_roles WHERE user_id = auth.uid()));
CREATE POLICY "Admins full access ratings" ON public.driver_ratings FOR ALL USING (EXISTS (SELECT 1 FROM public.user_admin_roles WHERE user_id = auth.uid()));
CREATE POLICY "Admins full access badges" ON public.driver_badges FOR ALL USING (EXISTS (SELECT 1 FROM public.user_admin_roles WHERE user_id = auth.uid()));
CREATE POLICY "Admins full access earned badges" ON public.driver_earned_badges FOR ALL USING (EXISTS (SELECT 1 FROM public.user_admin_roles WHERE user_id = auth.uid()));

-- Drivers (documents)
-- Note: auth.uid() retourne UUID dans Supabase PostgreSQL par défaut
CREATE POLICY "Drivers view own documents" ON public.driver_documents FOR SELECT USING (driver_id IN (SELECT id FROM public.drivers WHERE user_id = auth.uid()));
CREATE POLICY "Drivers insert own documents" ON public.driver_documents FOR INSERT WITH CHECK (driver_id IN (SELECT id FROM public.drivers WHERE user_id = auth.uid()));

COMMIT;

-- Script complet pour créer toutes les tables nécessaires
-- Exécutez ce script dans l'éditeur SQL de Supabase pour corriger les erreurs de tables manquantes

-- 1. Table messages (Chat)
CREATE TABLE IF NOT EXISTS public.messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id TEXT NOT NULL,
    sender_id TEXT NOT NULL,
    sender_name TEXT,
    content TEXT,
    is_from_driver BOOLEAN DEFAULT false,
    image_url TEXT,
    type TEXT DEFAULT 'text',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_messages_order_id ON public.messages(order_id);
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable access to all users" ON public.messages FOR ALL USING (true) WITH CHECK (true);
ALTER PUBLICATION supabase_realtime ADD TABLE messages;

-- 2. Table active_deliveries
CREATE TABLE IF NOT EXISTS public.active_deliveries (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id TEXT NOT NULL,
    delivery_id TEXT NOT NULL,
    status TEXT NOT NULL, -- assigned, accepted, picked_up, on_the_way, delivered
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    accepted_at TIMESTAMP WITH TIME ZONE,
    picked_up_at TIMESTAMP WITH TIME ZONE,
    started_delivery_at TIMESTAMP WITH TIME ZONE,
    delivered_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);
CREATE INDEX IF NOT EXISTS idx_active_deliveries_order_id ON public.active_deliveries(order_id);
CREATE INDEX IF NOT EXISTS idx_active_deliveries_delivery_id ON public.active_deliveries(delivery_id);
ALTER TABLE public.active_deliveries ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable access to all users" ON public.active_deliveries FOR ALL USING (true) WITH CHECK (true);
ALTER PUBLICATION supabase_realtime ADD TABLE active_deliveries;

-- 3. Table delivery_locations (Suivi GPS)
CREATE TABLE IF NOT EXISTS public.delivery_locations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id TEXT NOT NULL,
    delivery_id TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    accuracy DOUBLE PRECISION,
    speed DOUBLE PRECISION,
    heading DOUBLE PRECISION,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);
CREATE INDEX IF NOT EXISTS idx_delivery_locations_order_id ON public.delivery_locations(order_id);
ALTER TABLE public.delivery_locations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable access to all users" ON public.delivery_locations FOR ALL USING (true) WITH CHECK (true);
ALTER PUBLICATION supabase_realtime ADD TABLE delivery_locations;

-- 4. Table notifications
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    data JSONB,
    is_read BOOLEAN DEFAULT false,
    read_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable access to all users" ON public.notifications FOR ALL USING (true) WITH CHECK (true);
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;

-- 5. Table withdrawals (Retraits)
CREATE TABLE IF NOT EXISTS public.withdrawals (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id TEXT NOT NULL,
    amount DOUBLE PRECISION NOT NULL,
    transaction_id TEXT,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);
CREATE INDEX IF NOT EXISTS idx_withdrawals_user_id ON public.withdrawals(user_id);
ALTER TABLE public.withdrawals ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable access to all users" ON public.withdrawals FOR ALL USING (true) WITH CHECK (true);

-- 6. Table drivers (Profils livreurs)
CREATE TABLE IF NOT EXISTS public.drivers (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id TEXT NOT NULL UNIQUE, -- Lien vers la table users.id ou auth.users
    profile_photo_url TEXT,
    license_number TEXT,
    id_number TEXT,
    vehicle_type TEXT,
    vehicle_number TEXT,
    license_photo_url TEXT,
    id_card_photo_url TEXT,
    vehicle_photo_url TEXT,
    verification_status TEXT DEFAULT 'pending',
    is_available BOOLEAN DEFAULT false,
    current_location_latitude DOUBLE PRECISION,
    current_location_longitude DOUBLE PRECISION,
    last_location_update TIMESTAMP WITH TIME ZONE,
    rating DOUBLE PRECISION DEFAULT 5.0,
    total_deliveries INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);
ALTER TABLE public.drivers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable access to all users" ON public.drivers FOR ALL USING (true) WITH CHECK (true);

-- 7. Table driver_documents (Documents livreurs)
CREATE TABLE IF NOT EXISTS public.driver_documents (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id TEXT NOT NULL,
    document_type TEXT NOT NULL, -- license, identity, vehicle
    file_url TEXT NOT NULL,
    file_name TEXT,
    file_type TEXT,
    file_size INTEGER,
    status TEXT DEFAULT 'pending', -- pending, approved, rejected
    validation_notes TEXT,
    rejection_reason TEXT,
    validated_by TEXT,
    validated_at TIMESTAMP WITH TIME ZONE,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);
CREATE INDEX IF NOT EXISTS idx_driver_documents_user_id ON public.driver_documents(user_id);
ALTER TABLE public.driver_documents ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable access to all users" ON public.driver_documents FOR ALL USING (true) WITH CHECK (true);

-- 8. Table driver_ratings (Avis livreurs)
CREATE TABLE IF NOT EXISTS public.driver_ratings (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    driver_id TEXT NOT NULL,
    order_id TEXT NOT NULL,
    customer_id TEXT,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);
CREATE INDEX IF NOT EXISTS idx_driver_ratings_driver_id ON public.driver_ratings(driver_id);
ALTER TABLE public.driver_ratings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable access to all users" ON public.driver_ratings FOR ALL USING (true) WITH CHECK (true);

-- 9. Table driver_earned_badges (Badges livreurs)
CREATE TABLE IF NOT EXISTS public.driver_badges (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    icon_url TEXT,
    criteria JSONB
);

CREATE TABLE IF NOT EXISTS public.driver_earned_badges (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    driver_id TEXT NOT NULL,
    badge_id UUID NOT NULL REFERENCES public.driver_badges(id),
    earned_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);
CREATE INDEX IF NOT EXISTS idx_driver_earned_badges_driver_id ON public.driver_earned_badges(driver_id);
ALTER TABLE public.driver_badges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_earned_badges ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable access to all users" ON public.driver_badges FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Enable access to all users" ON public.driver_earned_badges FOR ALL USING (true) WITH CHECK (true);


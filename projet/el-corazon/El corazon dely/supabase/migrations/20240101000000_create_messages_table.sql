-- Création de la table messages pour le chat
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

-- Créer un index sur order_id pour optimiser les requêtes de récupération des messages
CREATE INDEX IF NOT EXISTS idx_messages_order_id ON public.messages(order_id);

-- Activer la sécurité au niveau des lignes (RLS)
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- Politique de sécurité pour le développement (accès public)
-- TODO: En production, restreindre l'accès aux participants de la commande (livreur, client, admin)
CREATE POLICY "Enable access to all users" ON public.messages FOR ALL USING (true) WITH CHECK (true);

-- Ajouter la table à la publication realtime pour les mises à jour en direct
ALTER PUBLICATION supabase_realtime ADD TABLE messages;

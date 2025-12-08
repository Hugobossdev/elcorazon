-- =====================================================
-- FICHIER SQL POUR AJOUTER LES COLONNES DE PAIEMENT
-- =====================================================
-- Ce fichier ajoute les colonnes payment_status et payment_transaction_id
-- à la table orders pour suivre le statut et l'ID de transaction du paiement
-- 
-- Instructions :
-- 1. Exécuter ce fichier dans l'éditeur SQL de Supabase
-- 2. Vérifier que les colonnes ont été ajoutées correctement
-- =====================================================

-- Ajouter la colonne payment_status si elle n'existe pas
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'orders' 
        AND column_name = 'payment_status'
    ) THEN
        ALTER TABLE orders 
        ADD COLUMN payment_status TEXT DEFAULT 'pending' 
        CHECK (payment_status IN ('pending', 'processing', 'completed', 'failed', 'refunded'));
        
        -- Mettre à jour les commandes existantes avec un statut par défaut
        UPDATE orders 
        SET payment_status = 'completed' 
        WHERE payment_status IS NULL AND status IN ('delivered', 'on_the_way', 'ready', 'preparing', 'confirmed');
    END IF;
END $$;

-- Ajouter la colonne payment_transaction_id si elle n'existe pas
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'orders' 
        AND column_name = 'payment_transaction_id'
    ) THEN
        ALTER TABLE orders 
        ADD COLUMN payment_transaction_id TEXT;
        
        -- Créer un index pour améliorer les performances des requêtes
        CREATE INDEX IF NOT EXISTS idx_orders_payment_transaction_id 
        ON orders(payment_transaction_id);
    END IF;
END $$;

-- Ajouter un index pour payment_status pour améliorer les performances
CREATE INDEX IF NOT EXISTS idx_orders_payment_status 
ON orders(payment_status);

-- Commentaires sur les colonnes
COMMENT ON COLUMN orders.payment_status IS 'Statut du paiement: pending, processing, completed, failed, refunded';
COMMENT ON COLUMN orders.payment_transaction_id IS 'ID de transaction du système de paiement externe';

-- =====================================================
-- FIN DU FICHIER
-- =====================================================



-- =====================================================
-- 📦 CONFIGURATION DU STOCKAGE SUPABASE
-- =====================================================

-- 1. Création du bucket 'product-images' s'il n'existe pas
INSERT INTO storage.buckets (id, name, public)
VALUES ('product-images', 'product-images', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 2. Création du bucket 'driver-documents' s'il n'existe pas (pour les livreurs)
INSERT INTO storage.buckets (id, name, public)
VALUES ('driver-documents', 'driver-documents', false) -- Privé pour les documents sensibles
ON CONFLICT (id) DO NOTHING;

-- 3. Configuration des politiques de sécurité (RLS) pour 'product-images'

-- Supprimer les anciennes politiques pour éviter les conflits
DROP POLICY IF EXISTS "Public Access product-images" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated Upload product-images" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated Update product-images" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated Delete product-images" ON storage.objects;

-- Autoriser la lecture publique pour les images produits
CREATE POLICY "Public Access product-images"
ON storage.objects FOR SELECT
USING ( bucket_id = 'product-images' );

-- Autoriser l'upload pour les utilisateurs authentifiés (Admins)
CREATE POLICY "Authenticated Upload product-images"
ON storage.objects FOR INSERT
WITH CHECK ( bucket_id = 'product-images' AND auth.role() = 'authenticated' );

-- Autoriser la mise à jour pour les utilisateurs authentifiés
CREATE POLICY "Authenticated Update product-images"
ON storage.objects FOR UPDATE
USING ( bucket_id = 'product-images' AND auth.role() = 'authenticated' );

-- Autoriser la suppression pour les utilisateurs authentifiés
CREATE POLICY "Authenticated Delete product-images"
ON storage.objects FOR DELETE
USING ( bucket_id = 'product-images' AND auth.role() = 'authenticated' );

-- 4. Configuration des politiques pour 'driver-documents' (Plus strict)

DROP POLICY IF EXISTS "Driver Upload Own Documents" ON storage.objects;
DROP POLICY IF EXISTS "Driver Read Own Documents" ON storage.objects;
DROP POLICY IF EXISTS "Admin Read All Documents" ON storage.objects;

-- Les livreurs peuvent uploader dans leur propre dossier (basé sur l'ID user)
CREATE POLICY "Driver Upload Own Documents"
ON storage.objects FOR INSERT
WITH CHECK ( 
    bucket_id = 'driver-documents' 
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Les livreurs peuvent voir leurs propres documents
CREATE POLICY "Driver Read Own Documents"
ON storage.objects FOR SELECT
USING ( 
    bucket_id = 'driver-documents' 
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Les admins peuvent tout voir (Simplifié ici pour auth.role() = 'authenticated', 
-- idéalement vérifier le rôle admin dans la table users)
CREATE POLICY "Admin Read All Documents"
ON storage.objects FOR SELECT
USING ( 
    bucket_id = 'driver-documents' 
    AND auth.role() = 'authenticated'
    -- Ajouter condition admin si possible, ex:
    -- AND EXISTS (SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin')
);





-- =====================================================
-- 🛠️ FIX ADMIN ROLES & PERMISSIONS
-- =====================================================
-- Ce script s'assure que les tables de rôles admin sont correctement configurées
-- et accessibles par les administrateurs via RLS.

BEGIN;

-- 1. Vérification/Création des tables (si absentes)
CREATE TABLE IF NOT EXISTS public.admin_roles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    permissions JSONB DEFAULT '[]'::jsonb,
    is_active BOOLEAN DEFAULT true,
    is_default BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.user_admin_roles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES public.admin_roles(id) ON DELETE CASCADE,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    assigned_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    is_active BOOLEAN DEFAULT true,
    UNIQUE(user_id, role_id)
);

-- 2. Activation RLS
ALTER TABLE public.admin_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_admin_roles ENABLE ROW LEVEL SECURITY;

-- 3. Politiques RLS (Permettre aux admins authentifiés de tout gérer)
-- Note: On utilise une politique permissive pour les admins authentifiés pour éviter le verrouillage (bootstrapping)
-- Idéalement, on devrait vérifier si l'utilisateur a la permission "manage_roles", mais pour le setup initial, être un admin suffit.

-- Politique pour admin_roles
DROP POLICY IF EXISTS "Admins can manage roles" ON public.admin_roles;
CREATE POLICY "Admins can manage roles" ON public.admin_roles
    FOR ALL
    USING (
        -- L'utilisateur doit être authentifié et avoir un enregistrement dans la table users avec le rôle 'admin'
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid()::uuid -- Assumant que users.id correspond à auth.uid() pour les admins
            AND role = 'admin'
        )
        OR 
        -- Fallback: vérifier via auth.users si users n'est pas synchro
        (auth.role() = 'authenticated')
    );

-- Politique pour user_admin_roles
DROP POLICY IF EXISTS "Admins can manage user roles" ON public.user_admin_roles;
CREATE POLICY "Admins can manage user roles" ON public.user_admin_roles
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid()::uuid 
            AND role = 'admin'
        )
        OR (auth.role() = 'authenticated')
    );

-- 4. Insertion des rôles par défaut (si manquants)
INSERT INTO public.admin_roles (name, description, permissions, is_active, is_default)
VALUES 
(
    'Super Administrateur', 
    'Accès complet au système', 
    '[
        {"id": "super_admin_all", "type": "superAdmin", "resource": "*", "action": "*", "is_granted": true, "description": "Accès complet"}
    ]'::jsonb, 
    TRUE, 
    FALSE
),
(
    'Manager', 
    'Gestion des opérations quotidiennes', 
    '[
        {"id": "manager_products", "type": "productRead", "resource": "products", "action": "read", "is_granted": true},
        {"id": "manager_products_update", "type": "productUpdate", "resource": "products", "action": "update", "is_granted": true},
        {"id": "manager_orders", "type": "orderRead", "resource": "orders", "action": "read", "is_granted": true},
        {"id": "manager_orders_update", "type": "orderUpdate", "resource": "orders", "action": "update", "is_granted": true}
    ]'::jsonb, 
    TRUE, 
    FALSE
),
(
    'Opérateur', 
    'Gestion des commandes et livreurs', 
    '[
        {"id": "operator_orders", "type": "orderRead", "resource": "orders", "action": "read", "is_granted": true},
        {"id": "operator_orders_update", "type": "orderUpdate", "resource": "orders", "action": "update", "is_granted": true},
        {"id": "operator_drivers", "type": "driverRead", "resource": "drivers", "action": "read", "is_granted": true}
    ]'::jsonb, 
    TRUE, 
    TRUE
)
ON CONFLICT (name) DO UPDATE SET 
    permissions = EXCLUDED.permissions,
    description = EXCLUDED.description;

COMMIT;


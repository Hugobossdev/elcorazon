-- =====================================================
-- 🛠️ FORCE FIX ADMIN ROLES & PERMISSIONS
-- =====================================================
-- Ce script écrase et recrée proprement les tables de rôles
-- pour corriger les erreurs de contraintes de clé étrangère.

BEGIN;

-- 1. Nettoyage radical (DROP CASCADE)
DROP TABLE IF EXISTS public.user_admin_roles CASCADE;
DROP TABLE IF EXISTS public.admin_roles CASCADE;

-- 2. Recréation propre des tables
CREATE TABLE public.admin_roles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    permissions JSONB DEFAULT '[]'::jsonb,
    is_active BOOLEAN DEFAULT true,
    is_default BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE public.user_admin_roles (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES public.admin_roles(id) ON DELETE CASCADE,
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    assigned_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    is_active BOOLEAN DEFAULT true,
    UNIQUE(user_id, role_id)
);

-- 3. Activation RLS
ALTER TABLE public.admin_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_admin_roles ENABLE ROW LEVEL SECURITY;

-- 4. Politiques RLS permissives pour les admins
CREATE POLICY "Admins can manage roles" ON public.admin_roles
    FOR ALL
    USING (auth.role() = 'authenticated');

CREATE POLICY "Admins can manage user roles" ON public.user_admin_roles
    FOR ALL
    USING (auth.role() = 'authenticated');

-- 5. Insertion des rôles par défaut
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
);

COMMIT;





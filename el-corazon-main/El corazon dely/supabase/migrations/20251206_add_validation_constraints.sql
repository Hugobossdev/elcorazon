-- Migration pour ajouter des validations de données côté serveur (CHECK constraints et Triggers)

-- ==========================================
-- 1. FONCTIONS UTILITAIRES
-- ==========================================

-- Fonction pour mettre à jour automatiquement updated_at
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- 2. CONTRAINTES DE VALIDATION (CHECK)
-- ==========================================

-- Table: active_deliveries
ALTER TABLE public.active_deliveries
ADD CONSTRAINT check_delivery_status 
CHECK (status IN ('assigned', 'accepted', 'picked_up', 'on_the_way', 'delivered', 'cancelled', 'returned'));

-- Table: withdrawals
ALTER TABLE public.withdrawals
ADD CONSTRAINT check_withdrawal_amount_positive 
CHECK (amount > 0);

ALTER TABLE public.withdrawals
ADD CONSTRAINT check_withdrawal_status 
CHECK (status IN ('pending', 'approved', 'rejected', 'processed', 'cancelled'));

-- Table: drivers
ALTER TABLE public.drivers
ADD CONSTRAINT check_driver_verification_status 
CHECK (verification_status IN ('pending', 'verified', 'rejected', 'suspended', 'incomplete'));

ALTER TABLE public.drivers
ADD CONSTRAINT check_driver_total_deliveries_positive 
CHECK (total_deliveries >= 0);

ALTER TABLE public.drivers
ADD CONSTRAINT check_driver_rating_range 
CHECK (rating >= 0 AND rating <= 5);

-- Table: driver_documents
ALTER TABLE public.driver_documents
ADD CONSTRAINT check_document_status 
CHECK (status IN ('pending', 'approved', 'rejected', 'expired'));

ALTER TABLE public.driver_documents
ADD CONSTRAINT check_document_type 
CHECK (document_type IN ('license', 'identity', 'vehicle', 'insurance', 'other'));

-- Table: delivery_locations
ALTER TABLE public.delivery_locations
ADD CONSTRAINT check_latitude_range 
CHECK (latitude >= -90 AND latitude <= 90);

ALTER TABLE public.delivery_locations
ADD CONSTRAINT check_longitude_range 
CHECK (longitude >= -180 AND longitude <= 180);

-- Table: messages
-- Si le type est 'text', le contenu ne doit pas être null ou vide
ALTER TABLE public.messages
ADD CONSTRAINT check_message_content 
CHECK (
    type != 'text' OR 
    (content IS NOT NULL AND length(trim(content)) > 0)
);

ALTER TABLE public.messages
ADD CONSTRAINT check_message_type 
CHECK (type IN ('text', 'image', 'audio', 'system', 'location'));

-- ==========================================
-- 3. TRIGGERS (Mise à jour automatique des dates)
-- ==========================================

-- Trigger pour active_deliveries
DROP TRIGGER IF EXISTS set_active_deliveries_updated_at ON public.active_deliveries;
CREATE TRIGGER set_active_deliveries_updated_at
BEFORE UPDATE ON public.active_deliveries
FOR EACH ROW
EXECUTE FUNCTION public.handle_updated_at();

-- Trigger pour withdrawals
DROP TRIGGER IF EXISTS set_withdrawals_updated_at ON public.withdrawals;
CREATE TRIGGER set_withdrawals_updated_at
BEFORE UPDATE ON public.withdrawals
FOR EACH ROW
EXECUTE FUNCTION public.handle_updated_at();

-- Trigger pour drivers
DROP TRIGGER IF EXISTS set_drivers_updated_at ON public.drivers;
CREATE TRIGGER set_drivers_updated_at
BEFORE UPDATE ON public.drivers
FOR EACH ROW
EXECUTE FUNCTION public.handle_updated_at();

-- Trigger pour driver_documents
DROP TRIGGER IF EXISTS set_driver_documents_updated_at ON public.driver_documents;
CREATE TRIGGER set_driver_documents_updated_at
BEFORE UPDATE ON public.driver_documents
FOR EACH ROW
EXECUTE FUNCTION public.handle_updated_at();

-- Migration pour corriger le schéma de la table calls
-- Ajoute les colonnes manquantes pour correspondre au code Dart

-- Ajouter les colonnes manquantes si elles n'existent pas
DO $$ 
BEGIN
    -- Ajouter caller_name si elle n'existe pas
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'calls' 
        AND column_name = 'caller_name'
    ) THEN
        ALTER TABLE public.calls ADD COLUMN caller_name TEXT;
    END IF;

    -- Ajouter receiver_name si elle n'existe pas
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'calls' 
        AND column_name = 'receiver_name'
    ) THEN
        ALTER TABLE public.calls ADD COLUMN receiver_name TEXT;
    END IF;

    -- Renommer callee_id en receiver_id si callee_id existe et receiver_id n'existe pas
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'calls' 
        AND column_name = 'callee_id'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'calls' 
        AND column_name = 'receiver_id'
    ) THEN
        ALTER TABLE public.calls RENAME COLUMN callee_id TO receiver_id;
    END IF;

    -- Renommer status en state si status existe et state n'existe pas
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'calls' 
        AND column_name = 'status'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'calls' 
        AND column_name = 'state'
    ) THEN
        -- Mapper les valeurs de status vers state
        ALTER TABLE public.calls 
        ADD COLUMN state TEXT DEFAULT 'idle';
        
        UPDATE public.calls 
        SET state = CASE 
            WHEN status = 'ringing' THEN 'ringing'
            WHEN status = 'accepted' THEN 'connected'
            WHEN status = 'declined' THEN 'rejected'
            WHEN status = 'ended' THEN 'ended'
            WHEN status = 'missed' THEN 'missed'
            ELSE 'idle'
        END;
        
        ALTER TABLE public.calls 
        ALTER COLUMN state SET NOT NULL,
        ALTER COLUMN state SET DEFAULT 'idle';
        
        -- Ajouter la contrainte CHECK pour state
        ALTER TABLE public.calls 
        ADD CONSTRAINT calls_state_check 
        CHECK (state IN ('idle', 'calling', 'ringing', 'connected', 'ended', 'rejected', 'missed', 'failed'));
    END IF;

    -- Renommer call_type en type si call_type existe et type n'existe pas
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'calls' 
        AND column_name = 'call_type'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'calls' 
        AND column_name = 'type'
    ) THEN
        ALTER TABLE public.calls RENAME COLUMN call_type TO type;
        
        -- Mettre à jour les valeurs pour correspondre au schéma attendu
        UPDATE public.calls SET type = 'voice' WHERE type = 'audio';
        
        -- Ajouter la contrainte CHECK pour type
        ALTER TABLE public.calls 
        ADD CONSTRAINT calls_type_check 
        CHECK (type IN ('voice', 'video'));
    END IF;

    -- Ajouter direction si elle n'existe pas
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'calls' 
        AND column_name = 'direction'
    ) THEN
        ALTER TABLE public.calls 
        ADD COLUMN direction TEXT DEFAULT 'outgoing' NOT NULL;
        
        ALTER TABLE public.calls 
        ADD CONSTRAINT calls_direction_check 
        CHECK (direction IN ('incoming', 'outgoing'));
    END IF;

    -- Ajouter started_at si elle n'existe pas
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'calls' 
        AND column_name = 'started_at'
    ) THEN
        ALTER TABLE public.calls 
        ADD COLUMN started_at TIMESTAMP WITH TIME ZONE;
    END IF;

    -- Ajouter ended_at si elle n'existe pas
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'calls' 
        AND column_name = 'ended_at'
    ) THEN
        ALTER TABLE public.calls 
        ADD COLUMN ended_at TIMESTAMP WITH TIME ZONE;
    END IF;

    -- Ajouter duration si elle n'existe pas
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'calls' 
        AND column_name = 'duration'
    ) THEN
        ALTER TABLE public.calls 
        ADD COLUMN duration INTEGER;
    END IF;

    -- S'assurer que channel_id existe (peut être NOT NULL dans l'ancien schéma)
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'calls' 
        AND column_name = 'channel_id'
        AND is_nullable = 'NO'
    ) THEN
        ALTER TABLE public.calls 
        ALTER COLUMN channel_id DROP NOT NULL;
    END IF;
END $$;

-- Recréer les index si nécessaire
CREATE INDEX IF NOT EXISTS idx_calls_caller_id ON public.calls(caller_id);
CREATE INDEX IF NOT EXISTS idx_calls_receiver_id ON public.calls(receiver_id);
CREATE INDEX IF NOT EXISTS idx_calls_state ON public.calls(state);
CREATE INDEX IF NOT EXISTS idx_calls_created_at ON public.calls(created_at);

-- S'assurer que la table est dans la publication Realtime
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
        AND tablename = 'calls'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.calls;
    END IF;
END $$;


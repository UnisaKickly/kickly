CREATE TABLE public.account (
    id uuid NOT NULL,
    ruolo_account text,
    nome text NOT NULL,
    cognome text NOT NULL,
    email text NOT NULL UNIQUE,
    eta integer,
    stato_account text NOT NULL DEFAULT 'attivo',
    stato_onboarding text NOT NULL DEFAULT 'in_corso',
    preferenze_notifiche jsonb NOT NULL DEFAULT '{}'::jsonb,
    CONSTRAINT account_pkey PRIMARY KEY (id),
    CONSTRAINT account_auth_user_id_fkey
        FOREIGN KEY (id) REFERENCES auth.users (id) ON DELETE CASCADE,
    CONSTRAINT account_ruolo_account_check
        CHECK (ruolo_account IS NULL OR ruolo_account IN ('Giocatore', 'GestoreCampo'))
);

COMMENT ON CONSTRAINT account_auth_user_id_fkey ON public.account IS
    'ON DELETE CASCADE elimina i dati personali dell''Account quando viene cancellato l''utente Auth, in conformità al DG4.';

CREATE TABLE public.giocatore (
    account_id uuid NOT NULL,
    ruolo_preferito_in_campo text NOT NULL,
    piede_dominante text NOT NULL,
    CONSTRAINT giocatore_pkey PRIMARY KEY (account_id),
    CONSTRAINT giocatore_account_id_fkey
        FOREIGN KEY (account_id) REFERENCES public.account (id) ON DELETE CASCADE
);

COMMENT ON CONSTRAINT giocatore_account_id_fkey ON public.giocatore IS
    'ON DELETE CASCADE elimina la specializzazione e i dati personali del Giocatore insieme al relativo Account, in conformità al DG4.';

CREATE TABLE public.gestore_campo (
    account_id uuid NOT NULL,
    id_account_pagamenti text,
    CONSTRAINT gestore_campo_pkey PRIMARY KEY (account_id),
    CONSTRAINT gestore_campo_account_id_fkey
        FOREIGN KEY (account_id) REFERENCES public.account (id) ON DELETE CASCADE
);

COMMENT ON CONSTRAINT gestore_campo_account_id_fkey ON public.gestore_campo IS
    'ON DELETE CASCADE elimina i dati personali del Gestore insieme al relativo Account, in conformità al DG4.';

CREATE TABLE public.dispositivo_registrato (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    account_id uuid NOT NULL,
    identificativo text NOT NULL,
    primo_accesso timestamptz NOT NULL,
    ultimo_accesso timestamptz NOT NULL,
    CONSTRAINT dispositivo_registrato_pkey PRIMARY KEY (id),
    CONSTRAINT dispositivo_registrato_account_id_fkey
        FOREIGN KEY (account_id) REFERENCES public.account (id) ON DELETE CASCADE
);

COMMENT ON CONSTRAINT dispositivo_registrato_account_id_fkey ON public.dispositivo_registrato IS
    'ON DELETE CASCADE elimina i dispositivi associati ai dati personali dell''Account cancellato, in conformità al DG4.';

CREATE TABLE public.lega (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    nome text NOT NULL,
    tipologia_match text NOT NULL,
    privacy text NOT NULL,
    codice_invito text UNIQUE,
    scadenza_codice_invito timestamptz,
    CONSTRAINT lega_pkey PRIMARY KEY (id),
    CONSTRAINT lega_tipologia_match_check
        CHECK (tipologia_match IN ('5v5', '6v6', '7v7', '8v8', '9v9', '10v10', '11v11')),
    CONSTRAINT lega_privacy_check
        CHECK (privacy IN ('pubblica', 'privata')),
    CONSTRAINT lega_codice_invito_scadenza_check
        CHECK (
            (codice_invito IS NULL AND scadenza_codice_invito IS NULL)
            OR (codice_invito IS NOT NULL AND scadenza_codice_invito IS NOT NULL)
        )
);

CREATE TABLE public.membro_lega (
    lega_id uuid NOT NULL,
    giocatore_id uuid NOT NULL,
    CONSTRAINT membro_lega_pkey PRIMARY KEY (lega_id, giocatore_id),
    CONSTRAINT membro_lega_lega_id_fkey
        FOREIGN KEY (lega_id) REFERENCES public.lega (id) ON DELETE CASCADE,
    CONSTRAINT membro_lega_giocatore_id_fkey
        FOREIGN KEY (giocatore_id) REFERENCES public.giocatore (account_id) ON DELETE CASCADE
);

COMMENT ON CONSTRAINT membro_lega_lega_id_fkey ON public.membro_lega IS
    'ON DELETE CASCADE elimina le associazioni ai membri quando la Lega viene cancellata, evitando dati personali di partecipazione residui (DG4).';
COMMENT ON CONSTRAINT membro_lega_giocatore_id_fkey ON public.membro_lega IS
    'ON DELETE CASCADE dissocia il Giocatore cancellato da tutte le Leghe, in conformità al DG4.';

CREATE TABLE public.amministratore_lega (
    lega_id uuid NOT NULL,
    giocatore_id uuid NOT NULL,
    CONSTRAINT amministratore_lega_pkey PRIMARY KEY (lega_id, giocatore_id),
    CONSTRAINT amministratore_lega_lega_id_fkey
        FOREIGN KEY (lega_id) REFERENCES public.lega (id) ON DELETE CASCADE,
    CONSTRAINT amministratore_lega_giocatore_id_fkey
        FOREIGN KEY (giocatore_id) REFERENCES public.giocatore (account_id) ON DELETE CASCADE
);

COMMENT ON CONSTRAINT amministratore_lega_lega_id_fkey ON public.amministratore_lega IS
    'ON DELETE CASCADE elimina le associazioni amministrative quando la Lega viene cancellata (DG4).';
COMMENT ON CONSTRAINT amministratore_lega_giocatore_id_fkey ON public.amministratore_lega IS
    'ON DELETE CASCADE dissocia il Giocatore cancellato dalle amministrazioni delle Leghe, in conformità al DG4.';

CREATE FUNCTION public.crea_account_per_nuovo_utente()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    INSERT INTO public.account (
        id,
        ruolo_account,
        nome,
        cognome,
        email,
        eta,
        stato_account,
        stato_onboarding,
        preferenze_notifiche
    )
    VALUES (
        NEW.id,
        NULL,
        COALESCE(NEW.raw_user_meta_data ->> 'nome', ''),
        COALESCE(NEW.raw_user_meta_data ->> 'cognome', ''),
        NEW.email,
        NULLIF(NEW.raw_user_meta_data ->> 'eta', '')::integer,
        'attivo',
        'in_corso',
        '{}'::jsonb
    );

    RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.crea_account_per_nuovo_utente();

CREATE FUNCTION public.verifica_integrita_amministratori_lega()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    lega_ids uuid[];
    lega_id_verificata uuid;
    giocatore_cancellato_id uuid;
BEGIN
    IF TG_TABLE_NAME = 'lega' THEN
        lega_ids := ARRAY[NEW.id];
    ELSIF TG_OP = 'INSERT' THEN
        lega_ids := ARRAY[NEW.lega_id];
    ELSIF TG_OP = 'DELETE' THEN
        lega_ids := ARRAY[OLD.lega_id];
        giocatore_cancellato_id := OLD.giocatore_id;
    ELSE
        lega_ids := ARRAY[OLD.lega_id, NEW.lega_id];
    END IF;

    FOREACH lega_id_verificata IN ARRAY lega_ids
    LOOP
        IF EXISTS (
            SELECT 1
            FROM public.lega
            WHERE id = lega_id_verificata
        ) THEN
            IF NOT EXISTS (
                SELECT 1
                FROM public.amministratore_lega
                WHERE lega_id = lega_id_verificata
            ) THEN
                IF giocatore_cancellato_id IS NULL OR EXISTS (
                    SELECT 1
                    FROM public.giocatore
                    WHERE account_id = giocatore_cancellato_id
                ) THEN
                    RAISE EXCEPTION 'Ogni lega deve avere almeno un amministratore'
                        USING ERRCODE = '23514';
                END IF;
            END IF;

            IF EXISTS (
                SELECT 1
                FROM public.amministratore_lega AS amministratore
                WHERE amministratore.lega_id = lega_id_verificata
                    AND NOT EXISTS (
                        SELECT 1
                        FROM public.membro_lega AS membro
                        WHERE membro.lega_id = amministratore.lega_id
                            AND membro.giocatore_id = amministratore.giocatore_id
                    )
            ) THEN
                RAISE EXCEPTION 'Ogni amministratore deve essere membro della stessa lega'
                    USING ERRCODE = '23514';
            END IF;
        END IF;
    END LOOP;

    RETURN NULL;
END;
$$;

CREATE CONSTRAINT TRIGGER lega_amministratore_obbligatorio
AFTER INSERT ON public.lega
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.verifica_integrita_amministratori_lega();

CREATE CONSTRAINT TRIGGER amministratore_lega_integrita_differita
AFTER INSERT OR UPDATE OR DELETE ON public.amministratore_lega
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.verifica_integrita_amministratori_lega();

CREATE CONSTRAINT TRIGGER membro_lega_amministratore_integrita_differita
AFTER INSERT OR UPDATE OR DELETE ON public.membro_lega
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.verifica_integrita_amministratori_lega();

ALTER TABLE public.account ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.giocatore ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gestore_campo ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dispositivo_registrato ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lega ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.membro_lega ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.amministratore_lega ENABLE ROW LEVEL SECURITY;

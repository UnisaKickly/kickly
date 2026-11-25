CREATE TABLE public.account (
    id uuid NOT NULL,
    ruolo_account text,
    nome text NOT NULL,
    cognome text NOT NULL,
    email text NOT NULL UNIQUE,
    eta integer NOT NULL,
    stato_account text NOT NULL DEFAULT 'attivo',
    stato_onboarding text NOT NULL DEFAULT 'in_corso',
    preferenze_notifiche text NOT NULL DEFAULT '{}',
    CONSTRAINT account_pkey PRIMARY KEY (id),
    CONSTRAINT account_auth_user_id_fkey
        FOREIGN KEY (id) REFERENCES auth.users (id) ON DELETE CASCADE,
    CONSTRAINT account_ruolo_account_check
        CHECK (ruolo_account IS NULL OR ruolo_account IN ('Giocatore', 'GestoreCampo')),
    CONSTRAINT account_nome_non_vuoto_check
        CHECK (length(btrim(nome)) > 0),
    CONSTRAINT account_cognome_non_vuoto_check
        CHECK (length(btrim(cognome)) > 0),
    CONSTRAINT account_eta_check
        CHECK (eta >= 14 AND eta <= 120),
    CONSTRAINT account_stato_account_check
        CHECK (stato_account IN ('attivo', 'in_cancellazione')),
    CONSTRAINT account_stato_onboarding_check
        CHECK (stato_onboarding IN ('in_corso', 'completato'))
);

COMMENT ON COLUMN public.account.email IS
    'Copia dell''email di auth.users, scritta dal trigger alla registrazione. Se l''utente cambia email in Supabase Auth questa colonna non si aggiorna da sola: va riallineata dal Control che gestisce il cambio.';
COMMENT ON CONSTRAINT account_eta_check ON public.account IS
    'Eta'' obbligatoria in registrazione (UC_ACC_1 passo 2) e di almeno 14 anni, eta'' minima in Italia per il consenso ai servizi online (GDPR art. 8): decisione D20.';

COMMENT ON CONSTRAINT account_auth_user_id_fkey ON public.account IS
    'ON DELETE CASCADE elimina i dati personali dell''Account quando viene cancellato l''utente Auth, in conformità al DG4.';

-- La coerenza tra ruolo e specializzazione è garantita dal Control di registrazione e dalle policy RLS, come deciso in D11.
-- ruolo_preferito_in_campo e piede_dominante sono facoltativi: nel sequence SD_UC_ACC_1
-- la riga del Giocatore nasce alla scelta del ruolo (Giocatore.create(), passo 7) e la
-- Player Card si salva dopo (aggiornaDati(), passo 9); se l'onboarding si interrompe
-- prima (UC_ACC_1 E3) la riga resta senza Player Card fino alla ripresa.
CREATE TABLE public.giocatore (
    account_id uuid NOT NULL,
    ruolo_preferito_in_campo text,
    piede_dominante text,
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
    CONSTRAINT dispositivo_registrato_account_identificativo_key
        UNIQUE (account_id, identificativo),
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
    CONSTRAINT lega_nome_non_vuoto_check
        CHECK (length(btrim(nome)) > 0),
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

-- Il nome della lega e' unico senza distinguere maiuscole e spazi iniziali/finali
-- (UC_LEG_1 E1 "nome lega gia' in uso", decisione D21). Garantirlo nel database evita
-- duplicati quando due Giocatori creano insieme una lega con lo stesso nome.
CREATE UNIQUE INDEX lega_nome_unico_idx ON public.lega (lower(btrim(nome)));

COMMENT ON COLUMN public.lega.tipologia_match IS
    'Valori nel formato 5v5 ... 11v11; i casi d''uso e i test frame scrivono 5vs5: la conversione la fa il codice Dart.';

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
        NULLIF(TRIM(NEW.raw_user_meta_data ->> 'nome'), ''),
        NULLIF(TRIM(NEW.raw_user_meta_data ->> 'cognome'), ''),
        NEW.email,
        NULLIF(NEW.raw_user_meta_data ->> 'eta', '')::integer,
        'attivo',
        'in_corso',
        '{}'
    );

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.crea_account_per_nuovo_utente() IS
    'Crea la riga Account dopo l''inserimento di un utente in auth.users. Legge nome e cognome dai metadati eliminando spazi iniziali/finali e convertendo i valori vuoti in NULL; i vincoli dell''Account rifiutano quindi metadati mancanti o vuoti invece di creare nomi non validi. Imposta i valori iniziali previsti da D9: stato_account attivo, stato_onboarding in_corso e preferenze_notifiche serializzate come testo JSON vuoto.';

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

COMMENT ON FUNCTION public.verifica_integrita_amministratori_lega() IS
    'Verifica, al termine della transazione, che ogni lega esistente abbia almeno un amministratore e che ogni amministratore sia anche membro della stessa lega. Controlla le leghe interessate dalle modifiche a lega, amministratore_lega e membro_lega. In base a D12, la rimozione manuale dell''ultimo amministratore è bloccata quando il relativo Giocatore esiste ancora; se invece l''Account viene cancellato a cascata per GDPR (DG4) e il Giocatore è già stato eliminato, lascia passare la rimozione dell''unico amministratore per non impedire la cancellazione dei dati personali. La lega rimasta senza amministratori la sistema CancellazioneAccountControl (KCK-204) secondo D19: diventa amministratore il membro con piu'' presenze confermate nella lega (a parita'' ordine alfabetico), oppure la lega viene cancellata se non ha altri membri.';

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

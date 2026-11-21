-- Migration C (KCK-218): votazione MVP, notifiche, quote e transazioni.
-- Le policy RLS sono del ticket KCK-226: qui la RLS e' solo attivata.

CREATE TABLE public.votazione_mvp (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    partita_id uuid NOT NULL,
    stato_votazione text NOT NULL,
    scadenza timestamptz NOT NULL,
    vincitore_id uuid,
    CONSTRAINT votazione_mvp_pkey PRIMARY KEY (id),
    CONSTRAINT votazione_mvp_stato_votazione_check
        CHECK (stato_votazione IN ('aperta', 'chiusa')),
    CONSTRAINT votazione_mvp_partita_id_key UNIQUE (partita_id),
    CONSTRAINT votazione_mvp_partita_id_fkey
        FOREIGN KEY (partita_id) REFERENCES public.partita (id) ON DELETE CASCADE,
    CONSTRAINT votazione_mvp_vincitore_id_fkey
        FOREIGN KEY (vincitore_id) REFERENCES public.giocatore (account_id) ON DELETE SET NULL
);

COMMENT ON COLUMN public.votazione_mvp.stato_votazione IS
    'Valori ammessi (D27): aperta, chiusa.';

CREATE TABLE public.preferenza_voto_mvp (
    votazione_id uuid NOT NULL,
    votante_id uuid NOT NULL,
    votato_id uuid NOT NULL,
    -- Un voto per votante nella stessa votazione (regola 6): e' anche la
    -- chiave primaria della tabella.
    CONSTRAINT preferenza_voto_mvp_pkey PRIMARY KEY (votazione_id, votante_id),
    -- D14: l'autovoto non e' ammesso. Il Control mostra l'errore; il CHECK e'
    -- la seconda difesa nel database.
    CONSTRAINT preferenza_voto_mvp_no_autovoto_check CHECK (votante_id <> votato_id),
    CONSTRAINT preferenza_voto_mvp_votazione_id_fkey
        FOREIGN KEY (votazione_id) REFERENCES public.votazione_mvp (id) ON DELETE CASCADE,
    CONSTRAINT preferenza_voto_mvp_votante_id_fkey
        FOREIGN KEY (votante_id) REFERENCES public.giocatore (account_id) ON DELETE CASCADE,
    CONSTRAINT preferenza_voto_mvp_votato_id_fkey
        FOREIGN KEY (votato_id) REFERENCES public.giocatore (account_id) ON DELETE CASCADE
);

CREATE TABLE public.notifica (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    account_id uuid NOT NULL,
    tipo text NOT NULL,
    messaggio text NOT NULL,
    stato_lettura boolean NOT NULL DEFAULT false,
    "timestamp" timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT notifica_pkey PRIMARY KEY (id),
    CONSTRAINT notifica_tipo_check
        CHECK (tipo IN ('apertura_sondaggio_mvp', 'apertura_convocazioni', 'partita_confermata')),
    CONSTRAINT notifica_account_id_fkey
        FOREIGN KEY (account_id) REFERENCES public.account (id) ON DELETE CASCADE
);

COMMENT ON COLUMN public.notifica.tipo IS
    'Valori ammessi (D27): apertura_sondaggio_mvp, apertura_convocazioni, partita_confermata.';

CREATE TABLE public.quota (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    partecipazione_id uuid NOT NULL,
    importo numeric(10, 2) NOT NULL,
    stato_versamento text NOT NULL,
    termine_versamento timestamptz NOT NULL,
    CONSTRAINT quota_pkey PRIMARY KEY (id),
    CONSTRAINT quota_partecipazione_id_key UNIQUE (partecipazione_id),
    CONSTRAINT quota_partecipazione_id_fkey
        FOREIGN KEY (partecipazione_id) REFERENCES public.partecipazione (id) ON DELETE CASCADE,
    CONSTRAINT quota_importo_check CHECK (importo >= 0),
    CONSTRAINT quota_stato_versamento_check
        CHECK (stato_versamento IN ('da_versare', 'versata', 'rimborsata'))
);

COMMENT ON COLUMN public.quota.stato_versamento IS
    'Valori ammessi: da_versare, versata, rimborsata.';

CREATE TABLE public.transazione (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    quota_id uuid,
    prenotazione_id uuid,
    gestore_campo_id uuid,
    transazione_originaria_id uuid,
    tipo text NOT NULL,
    importo numeric(10, 2) NOT NULL,
    stato text NOT NULL,
    data_esito timestamptz,
    riferimento_esterno text NOT NULL,
    CONSTRAINT transazione_pkey PRIMARY KEY (id),
    CONSTRAINT transazione_riferimento_esterno_key UNIQUE (riferimento_esterno),
    CONSTRAINT transazione_quota_id_fkey
        FOREIGN KEY (quota_id) REFERENCES public.quota (id) ON DELETE SET NULL,
    CONSTRAINT transazione_prenotazione_id_fkey
        FOREIGN KEY (prenotazione_id) REFERENCES public.prenotazione (id) ON DELETE SET NULL,
    CONSTRAINT transazione_gestore_campo_id_fkey
        FOREIGN KEY (gestore_campo_id) REFERENCES public.gestore_campo (account_id) ON DELETE SET NULL,
    CONSTRAINT transazione_originaria_id_fkey
        FOREIGN KEY (transazione_originaria_id) REFERENCES public.transazione (id) ON DELETE SET NULL,
    CONSTRAINT transazione_stato_check
        CHECK (stato IN ('in_attesa', 'completata', 'fallita')),
    CONSTRAINT transazione_tipo_check
        CHECK (tipo IN ('pagamento', 'rimborso', 'accredito')),
    CONSTRAINT transazione_importo_check CHECK (importo >= 0)
);

COMMENT ON COLUMN public.transazione.stato IS
    'Valori ammessi (D27): in_attesa, completata, fallita.';
COMMENT ON COLUMN public.transazione.riferimento_esterno IS
    'Identificativo testuale esterno usato per l''idempotenza; questa tabella non conserva dati di carta o IBAN.';

-- Un pagamento fallito non ha addebitato nulla: non conta, cosi' il Giocatore
-- puo' riprovare. Un pagamento in_attesa o completato invece blocca un secondo
-- addebito della stessa quota (DG2).
CREATE UNIQUE INDEX transazione_unico_pagamento_quota_idx
    ON public.transazione (quota_id)
    WHERE tipo = 'pagamento' AND quota_id IS NOT NULL AND stato <> 'fallita';

COMMENT ON INDEX public.transazione_unico_pagamento_quota_idx IS
    'Garantisce al massimo una transazione di pagamento non fallita per ogni Quota (DG2).';

ALTER TABLE public.votazione_mvp ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.preferenza_voto_mvp ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifica ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quota ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transazione ENABLE ROW LEVEL SECURITY;

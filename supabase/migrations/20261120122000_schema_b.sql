-- Migration B (KCK-210): Campo, Partita, Prenotazione e Partecipazione.
-- Segue le convenzioni della Migration A (20261119122000_schema_a.sql) e la
-- mappatura di docs/modelli/class_diagram_sdd.md (regole 1, 4, 5, 8, 9).
-- Le policy RLS sono del ticket KCK-226: qui la RLS e' solo attivata.

-- btree_gist serve al vincolo di esclusione sugli slot di Prenotazione
-- (uguaglianza su uuid e sovrapposizione di intervalli nello stesso indice GiST).
CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA extensions;

-- Campo: nomi delle colonne fissati dai PM (commento su KCK-210 del 20/11),
-- letti dall'entity Dart Campo (KCK-246). orari_disponibilita e' una colonna
-- e non una tabella (regola 5).
CREATE TABLE public.campo (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    gestore_campo_id uuid NOT NULL,
    nome text NOT NULL,
    ubicazione text NOT NULL,
    tariffa_oraria numeric(10, 2) NOT NULL,
    orari_disponibilita text NOT NULL,
    CONSTRAINT campo_pkey PRIMARY KEY (id),
    CONSTRAINT campo_gestore_campo_id_fkey
        FOREIGN KEY (gestore_campo_id) REFERENCES public.gestore_campo (account_id) ON DELETE CASCADE,
    CONSTRAINT campo_nome_non_vuoto_check
        CHECK (length(btrim(nome)) > 0),
    CONSTRAINT campo_ubicazione_non_vuoto_check
        CHECK (length(btrim(ubicazione)) > 0),
    CONSTRAINT campo_tariffa_oraria_check
        CHECK (tariffa_oraria > 0)
);

COMMENT ON CONSTRAINT campo_gestore_campo_id_fkey ON public.campo IS
    'ON DELETE CASCADE elimina i campi del Gestore insieme al relativo Account, in conformità al DG4.';
COMMENT ON COLUMN public.campo.orari_disponibilita IS
    'Rappresentazione testuale degli orari di disponibilità (regola 5 di class_diagram_sdd.md): da qui il Control ricava gli slot di Prenotazione.intervallo.';

-- Partita: l'organizzatore e' obbligatorio, la lega facoltativa (regola 8).
-- Gli stati sono tutti quelli dello statechart (statechart_partita.puml,
-- decisione PM C8 nel commento su KCK-210 del 18/11: compreso Confermata).
CREATE TABLE public.partita (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    giocatore_id uuid NOT NULL,
    lega_id uuid,
    data_ora timestamptz NOT NULL,
    tipologia text NOT NULL,
    privacy text NOT NULL,
    num_partecipanti_richiesti integer NOT NULL,
    stato text NOT NULL DEFAULT 'Aperta',
    link_condivisione text,
    CONSTRAINT partita_pkey PRIMARY KEY (id),
    CONSTRAINT partita_link_condivisione_key UNIQUE (link_condivisione),
    CONSTRAINT partita_giocatore_id_fkey
        FOREIGN KEY (giocatore_id) REFERENCES public.giocatore (account_id) ON DELETE CASCADE,
    CONSTRAINT partita_lega_id_fkey
        FOREIGN KEY (lega_id) REFERENCES public.lega (id) ON DELETE CASCADE,
    CONSTRAINT partita_tipologia_check
        CHECK (tipologia IN ('5v5', '6v6', '7v7', '8v8', '9v9', '10v10', '11v11')),
    CONSTRAINT partita_privacy_check
        CHECK (privacy IN ('pubblica', 'privata')),
    CONSTRAINT partita_num_partecipanti_richiesti_check
        CHECK (
            tipologia !~ '^[0-9]+v[0-9]+$'
            OR num_partecipanti_richiesti >= 2 * split_part(tipologia, 'v', 1)::integer
        ),
    CONSTRAINT partita_stato_check
        CHECK (stato IN ('Aperta', 'Completa', 'Confermata', 'Conclusa', 'Annullata'))
);

COMMENT ON COLUMN public.partita.giocatore_id IS
    'Organizzatore della partita (associazione Giocatore 1 — 0..* Partita). La colonna segue la regola 9 (<entity>_id), come amministratore_lega.giocatore_id nella Migration A.';
COMMENT ON CONSTRAINT partita_giocatore_id_fkey ON public.partita IS
    'ON DELETE CASCADE: la cancellazione dei dati personali non si blocca mai (D12); le partite organizzate dal Giocatore cancellato vengono eliminate con le relative partecipazioni, in conformità al DG4.';
COMMENT ON CONSTRAINT partita_lega_id_fkey ON public.partita IS
    'ON DELETE CASCADE elimina le partite della Lega cancellata (D19: la lega si cancella solo quando non ha più membri), senza lasciare partecipazioni residue (DG4).';
COMMENT ON CONSTRAINT partita_num_partecipanti_richiesti_check ON public.partita IS
    'D7: il numero di partecipanti non può essere inferiore ai giocatori in campo della tipologia (es. almeno 10 per il 5v5). Se la tipologia non è valida la rifiuta partita_tipologia_check.';
COMMENT ON COLUMN public.partita.tipologia IS
    'Valori nel formato 5v5 ... 11v11, come lega.tipologia_match; la conversione da 5vs5 la fa il codice Dart.';
COMMENT ON COLUMN public.partita.stato IS
    'I passaggi di stato (statechart) li fa il Control. Restano nel Control anche la data nel passato (D7), il limite di 24 ore per annullare (D5) e gestisciAnnullamento() (D6).';

-- Converte Prenotazione.intervallo ('AAAA-MM-GGTHH:MM/AAAA-MM-GGTHH:MM') in un
-- tsrange semiaperto [inizio, fine): due slot consecutivi (18:00/19:00 e
-- 19:00/20:00) non si sovrappongono. E' IMMUTABLE perche' serve nel vincolo
-- di esclusione; il formato ISO non dipende da DateStyle.
CREATE FUNCTION public.intervallo_prenotazione(intervallo text)
RETURNS tsrange
LANGUAGE sql
IMMUTABLE
STRICT
SET search_path = ''
AS $$
    SELECT pg_catalog.tsrange(
        pg_catalog.split_part(intervallo, '/', 1)::timestamp,
        pg_catalog.split_part(intervallo, '/', 2)::timestamp,
        '[)'
    );
$$;

COMMENT ON FUNCTION public.intervallo_prenotazione(text) IS
    'Converte la stringa Prenotazione.intervallo (regola 4) in un intervallo di tempo, usato dal vincolo che impedisce slot sovrapposti sullo stesso campo. La colonna resta String come nel class diagram.';

-- Prenotazione: una sola per partita (regola 8). Lo slot e' "attivo" (regola 4)
-- quando e' bloccato o confermato; uno slot liberato non occupa il campo.
CREATE TABLE public.prenotazione (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    partita_id uuid NOT NULL,
    campo_id uuid NOT NULL,
    intervallo text NOT NULL,
    stato_blocco text NOT NULL,
    scadenza_blocco timestamptz,
    costo_concordato numeric(10, 2) NOT NULL,
    quota_individuale numeric(10, 2) NOT NULL,
    commissione numeric(10, 2) NOT NULL,
    netto_gestore numeric(10, 2) NOT NULL,
    CONSTRAINT prenotazione_pkey PRIMARY KEY (id),
    CONSTRAINT prenotazione_partita_id_key UNIQUE (partita_id),
    CONSTRAINT prenotazione_partita_id_fkey
        FOREIGN KEY (partita_id) REFERENCES public.partita (id) ON DELETE CASCADE,
    CONSTRAINT prenotazione_campo_id_fkey
        FOREIGN KEY (campo_id) REFERENCES public.campo (id) ON DELETE CASCADE,
    CONSTRAINT prenotazione_intervallo_check
        CHECK (
            intervallo ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}/[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}$'
            AND split_part(intervallo, '/', 1)::timestamp < split_part(intervallo, '/', 2)::timestamp
        ),
    CONSTRAINT prenotazione_stato_blocco_check
        CHECK (stato_blocco IN ('bloccato', 'confermato', 'liberato')),
    CONSTRAINT prenotazione_scadenza_blocco_check
        CHECK (stato_blocco <> 'bloccato' OR scadenza_blocco IS NOT NULL),
    CONSTRAINT prenotazione_costo_concordato_check
        CHECK (costo_concordato >= 0),
    CONSTRAINT prenotazione_quota_individuale_check
        CHECK (quota_individuale >= 0),
    CONSTRAINT prenotazione_commissione_check
        CHECK (commissione >= 0),
    CONSTRAINT prenotazione_netto_gestore_check
        CHECK (netto_gestore >= 0),
    CONSTRAINT prenotazione_slot_non_sovrapposti_excl
        EXCLUDE USING gist (
            campo_id extensions.gist_uuid_ops WITH =,
            public.intervallo_prenotazione(intervallo) WITH &&
        ) WHERE (stato_blocco IN ('bloccato', 'confermato'))
);

COMMENT ON CONSTRAINT prenotazione_slot_non_sovrapposti_excl ON public.prenotazione IS
    'Due prenotazioni attive (bloccato o confermato) sullo stesso campo non possono avere intervalli sovrapposti: realizza la regola 4 e il criterio di KCK-210 "slot sovrapposti impossibili a livello DB". Copre anche lo stesso identico intervallo (UNIQUE della regola 4).';
COMMENT ON CONSTRAINT prenotazione_scadenza_blocco_check ON public.prenotazione IS
    'Uno slot solo bloccato deve avere la scadenza del blocco, dopo la quale PrenotazioneControl lo libera (regola 4).';
COMMENT ON CONSTRAINT prenotazione_partita_id_fkey ON public.prenotazione IS
    'ON DELETE CASCADE elimina la prenotazione della Partita cancellata, anche quando la cancellazione nasce da un Account cancellato (DG4).';
COMMENT ON CONSTRAINT prenotazione_campo_id_fkey ON public.prenotazione IS
    'ON DELETE CASCADE elimina le prenotazioni del Campo cancellato insieme al Gestore (DG4).';
COMMENT ON COLUMN public.prenotazione.stato_blocco IS
    'Valori: bloccato (blocco temporaneo), confermato, liberato, dalle operazioni di PrenotazioneControl nella tabella degli oggetti del RAD.';

-- Partecipazione: un Giocatore risponde una sola volta per partita (regola 8, DG3).
-- Il limite dei posti (0% overbooking) lo garantisce l'Edge Function RSVP.
CREATE TABLE public.partecipazione (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    giocatore_id uuid NOT NULL,
    partita_id uuid NOT NULL,
    risposta_stato text NOT NULL,
    data_risposta timestamptz NOT NULL,
    gol_partita integer NOT NULL DEFAULT 0,
    assist_partita integer NOT NULL DEFAULT 0,
    CONSTRAINT partecipazione_pkey PRIMARY KEY (id),
    CONSTRAINT partecipazione_giocatore_partita_key UNIQUE (giocatore_id, partita_id),
    CONSTRAINT partecipazione_giocatore_id_fkey
        FOREIGN KEY (giocatore_id) REFERENCES public.giocatore (account_id) ON DELETE CASCADE,
    CONSTRAINT partecipazione_partita_id_fkey
        FOREIGN KEY (partita_id) REFERENCES public.partita (id) ON DELETE CASCADE,
    CONSTRAINT partecipazione_risposta_stato_check
        CHECK (risposta_stato IN ('confermata', 'ritirata')),
    CONSTRAINT partecipazione_gol_partita_check
        CHECK (gol_partita >= 0),
    CONSTRAINT partecipazione_assist_partita_check
        CHECK (assist_partita >= 0)
);

COMMENT ON CONSTRAINT partecipazione_giocatore_partita_key ON public.partecipazione IS
    'Partecipazione univoca per (giocatore, partita): regola 8 e DG3, nessuna risposta doppia.';
COMMENT ON CONSTRAINT partecipazione_giocatore_id_fkey ON public.partecipazione IS
    'ON DELETE CASCADE dissocia il Giocatore cancellato da tutte le partite, in conformità al DG4.';
COMMENT ON CONSTRAINT partecipazione_partita_id_fkey ON public.partecipazione IS
    'ON DELETE CASCADE elimina le partecipazioni della Partita cancellata (DG4).';
COMMENT ON COLUMN public.partecipazione.risposta_stato IS
    'Valori: confermata (presenza confermata, come in D19) e ritirata (ritiro presenza dello statechart).';
COMMENT ON COLUMN public.partecipazione.gol_partita IS
    'Inseriti dall''Organizzatore a partita Conclusa (D2); restano 0 se non inseriti.';

ALTER TABLE public.campo ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partita ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prenotazione ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partecipazione ENABLE ROW LEVEL SECURITY;

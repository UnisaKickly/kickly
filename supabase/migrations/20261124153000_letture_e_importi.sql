-- Migration: letture_e_importi (KCK-271).
-- RPC pubbliche con dati minimizzati e trigger per importi, scadenze e RSVP organizzatore.

-- I profili si chiedono solo per id gia' noti (per esempio i membri di una
-- lega o i partecipanti di una partita): senza id, o con un array vuoto, la
-- funzione non restituisce niente. Altrimenti qualunque utente autenticato
-- potrebbe elencare nome e cognome di tutta l'anagrafica (KCK-271, revisione
-- dei PM).
CREATE OR REPLACE FUNCTION public.get_profili_pubblici(
    p_account_ids uuid[]
)
RETURNS TABLE (
    id uuid,
    nome text,
    cognome text,
    ruolo_preferito_in_campo text,
    piede_dominante text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT
        account.id,
        account.nome,
        account.cognome,
        giocatore.ruolo_preferito_in_campo,
        giocatore.piede_dominante
    FROM public.account AS account
    JOIN public.giocatore AS giocatore
        ON giocatore.account_id = account.id
    WHERE account.id = ANY (p_account_ids);
$$;

COMMENT ON FUNCTION public.get_profili_pubblici(uuid[]) IS
    'Restituisce solo i dati pubblici della Player Card, senza email o altri dati account (KCK-226 punto 2).';

REVOKE ALL ON FUNCTION public.get_profili_pubblici(uuid[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_profili_pubblici(uuid[]) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_slot_occupati(
    p_campo_id uuid,
    p_inizio timestamptz,
    p_fine timestamptz
)
RETURNS TABLE (
    intervallo text,
    stato_blocco text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT
        prenotazione.intervallo,
        prenotazione.stato_blocco
    FROM public.prenotazione AS prenotazione
    WHERE prenotazione.campo_id = p_campo_id
      AND prenotazione.stato_blocco IN ('bloccato', 'confermato')
      AND public.intervallo_prenotazione(prenotazione.intervallo)
          && pg_catalog.tsrange(
              (p_inizio AT TIME ZONE 'UTC')::timestamp,
              (p_fine AT TIME ZONE 'UTC')::timestamp,
              '[)'
          );
$$;

COMMENT ON FUNCTION public.get_slot_occupati(uuid, timestamptz, timestamptz) IS
    'Restituisce solo intervallo e stato del blocco degli slot attivi nel periodo richiesto (KCK-226 punto 8).';

REVOKE ALL ON FUNCTION public.get_slot_occupati(uuid, timestamptz, timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_slot_occupati(uuid, timestamptz, timestamptz) TO authenticated;

CREATE OR REPLACE FUNCTION public.calcola_importi_e_scadenza_prenotazione()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    aliquota_commissione CONSTANT numeric := 0.05;
    tariffa_oraria numeric;
    numero_partecipanti integer;
    data_partita timestamptz;
    slot tsrange;
    ore numeric;
    costo numeric(10, 2);
    quota numeric(10, 2);
    commissione numeric(10, 2);
BEGIN
    IF TG_OP = 'UPDATE'
       AND NEW.campo_id IS NOT DISTINCT FROM OLD.campo_id
       AND NEW.intervallo IS NOT DISTINCT FROM OLD.intervallo
       AND NEW.partita_id IS NOT DISTINCT FROM OLD.partita_id THEN
        RETURN NEW;
    END IF;

    SELECT campo.tariffa_oraria
    INTO tariffa_oraria
    FROM public.campo AS campo
    WHERE campo.id = NEW.campo_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Campo % non trovato', NEW.campo_id
            USING ERRCODE = '23503';
    END IF;

    SELECT partita.num_partecipanti_richiesti, partita.data_ora
    INTO numero_partecipanti, data_partita
    FROM public.partita AS partita
    WHERE partita.id = NEW.partita_id;

    IF NOT FOUND OR numero_partecipanti <= 0 THEN
        RAISE EXCEPTION 'Partita % non trovata o numero di partecipanti non valido', NEW.partita_id
            USING ERRCODE = '23503';
    END IF;

    IF NEW.intervallo !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}/[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}$' THEN
        RAISE EXCEPTION 'Intervallo prenotazione non valido: %', NEW.intervallo
            USING ERRCODE = '23514';
    END IF;

    IF pg_catalog.split_part(NEW.intervallo, '/', 1)::timestamp
       >= pg_catalog.split_part(NEW.intervallo, '/', 2)::timestamp THEN
        RAISE EXCEPTION 'Intervallo prenotazione non valido: %', NEW.intervallo
            USING ERRCODE = '23514';
    END IF;

    slot := public.intervallo_prenotazione(NEW.intervallo);
    ore := EXTRACT(EPOCH FROM (pg_catalog.upper(slot) - pg_catalog.lower(slot))) / 3600.0;

    IF ore <= 0 THEN
        RAISE EXCEPTION 'Intervallo prenotazione non valido: %', NEW.intervallo
            USING ERRCODE = '23514';
    END IF;

    costo := pg_catalog.round(tariffa_oraria * ore, 2);
    quota := pg_catalog.ceil((costo / numero_partecipanti) * 100.0) / 100.0;
    commissione := pg_catalog.round(costo * aliquota_commissione, 2);

    NEW.costo_concordato := costo;
    NEW.quota_individuale := quota;
    NEW.commissione := commissione;
    NEW.netto_gestore := costo - commissione;

    IF data_partita - pg_catalog.now() >= interval '24 hours' THEN
        NEW.scadenza_blocco := data_partita - interval '24 hours';
    ELSE
        NEW.scadenza_blocco := data_partita - interval '2 hours';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.calcola_importi_e_scadenza_prenotazione() IS
    'Ricalcola importi e scadenza a ogni INSERT e solo se cambiano campo_id, intervallo o partita_id in UPDATE.';

DROP TRIGGER IF EXISTS trg_calcola_importi_prenotazione ON public.prenotazione;

CREATE TRIGGER trg_calcola_importi_prenotazione
BEFORE INSERT OR UPDATE ON public.prenotazione
FOR EACH ROW
EXECUTE FUNCTION public.calcola_importi_e_scadenza_prenotazione();

CREATE OR REPLACE FUNCTION public.crea_partecipazione_organizzatore()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    INSERT INTO public.partecipazione (
        giocatore_id,
        partita_id,
        risposta_stato,
        data_risposta
    )
    VALUES (
        NEW.giocatore_id,
        NEW.id,
        'confermata',
        pg_catalog.now()
    )
    ON CONFLICT (giocatore_id, partita_id) DO NOTHING;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.crea_partecipazione_organizzatore() IS
    'Crea la partecipazione confermata dell''organizzatore dopo l''inserimento della partita, senza duplicati.';

DROP TRIGGER IF EXISTS trg_crea_partecipazione_organizzatore ON public.partita;

CREATE CONSTRAINT TRIGGER trg_crea_partecipazione_organizzatore
AFTER INSERT ON public.partita
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION public.crea_partecipazione_organizzatore();

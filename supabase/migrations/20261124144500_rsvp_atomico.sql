-- Edge Function RSVP atomico (KCK-219): serializza conferme e ritiri sulla Partita.
-- La `SELECT ... FOR UPDATE` crea il punto di serializzazione comune a tutte le
-- richieste; non e' sufficiente aggiornare un contatore derivato per evitare
-- race condition, perche' la transazione conta e modifica una sottoriga alla volta.
-- Questa funzione realizza DG3: 0 overbooking, posto liberato dal ritiro e
-- RSVP ripetuto idempotente. Nessun SDK o stato d'autenticazione vive nel DB.

CREATE OR REPLACE FUNCTION public.gestisci_rsvp(
    p_partita_id uuid,
    p_giocatore_id uuid,
    p_risposta text
)
RETURNS TABLE (
    esito text,
    posti_rimasti integer,
    stato_partita text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    v_partita public.partita%ROWTYPE;
    v_partecipazione public.partecipazione%ROWTYPE;
    v_confermati integer;
BEGIN
    -- Le risposte ammesse corrispondono alle azioni della Edge Function;
    -- altri valori sono rifiutati prima di qualsiasi lock o scrittura.
    IF p_risposta NOT IN ('conferma', 'ritiro') THEN
        RAISE EXCEPTION 'risposta RSVP non ammessa: %', p_risposta
            USING ERRCODE = '22023';
    END IF;

    -- Il lock sul record della Partita serializza tutte le richieste concorrenti
    -- che hanno lo stesso evento. La transazione attende il turno, poi rilegge
    -- il conteggio effettivo e decide se accettare o rifiutare.
    SELECT * INTO v_partita
    FROM public.partita
    WHERE id = p_partita_id
    FOR UPDATE;

    IF NOT FOUND THEN
        esito := 'partita_non_trovata';
        posti_rimasti := NULL;
        stato_partita := NULL;
        RETURN NEXT;
        RETURN;
    END IF;

    IF v_partita.stato NOT IN ('Aperta', 'Completa') THEN
        esito := 'partita_non_aperta';
        SELECT GREATEST(
            v_partita.num_partecipanti_richiesti - count(*),
            0
        ) INTO posti_rimasti
        FROM public.partecipazione
        WHERE partita_id = p_partita_id
          AND risposta_stato = 'confermata';
        stato_partita := v_partita.stato;
        RETURN NEXT;
        RETURN;
    END IF;

    SELECT * INTO v_partecipazione
    FROM public.partecipazione
    WHERE partita_id = p_partita_id
      AND giocatore_id = p_giocatore_id;

    IF p_risposta = 'ritiro' THEN
        IF FOUND AND v_partecipazione.risposta_stato = 'confermata' THEN
            UPDATE public.partecipazione
            SET risposta_stato = 'ritirata',
                data_risposta = clock_timestamp()
            WHERE id = v_partecipazione.id;
        END IF;

        SELECT count(*) INTO v_confermati
        FROM public.partecipazione
        WHERE partita_id = p_partita_id
          AND risposta_stato = 'confermata';

        IF v_partita.stato = 'Completa'
           AND v_confermati < v_partita.num_partecipanti_richiesti THEN
            UPDATE public.partita
            SET stato = 'Aperta'
            WHERE id = p_partita_id;
            v_partita.stato := 'Aperta';
        END IF;

        esito := 'ritirata';
        posti_rimasti := GREATEST(
            v_partita.num_partecipanti_richiesti - v_confermati,
            0
        );
        stato_partita := v_partita.stato;
        RETURN NEXT;
        RETURN;
    END IF;

    -- Riconferma dello stesso giocatore e risposta confermata gia' presente:
    -- nessuna seconda riga grazie al vincolo UNIQUE e nessuna modifica al conteggio.
    IF FOUND AND v_partecipazione.risposta_stato = 'confermata' THEN
        SELECT count(*) INTO v_confermati
        FROM public.partecipazione
        WHERE partita_id = p_partita_id
          AND risposta_stato = 'confermata';

        esito := 'gia_confermata';
        posti_rimasti := GREATEST(
            v_partita.num_partecipanti_richiesti - v_confermati,
            0
        );
        stato_partita := v_partita.stato;
        RETURN NEXT;
        RETURN;
    END IF;

    SELECT count(*) INTO v_confermati
    FROM public.partecipazione
    WHERE partita_id = p_partita_id
      AND risposta_stato = 'confermata';

    IF v_confermati >= v_partita.num_partecipanti_richiesti
       OR v_partita.stato = 'Completa' THEN
        esito := 'partita_al_completo';
        posti_rimasti := 0;
        stato_partita := 'Completa';
        RETURN NEXT;
        RETURN;
    END IF;

    IF v_partecipazione.id IS NOT NULL THEN
        UPDATE public.partecipazione
        SET risposta_stato = 'confermata',
            data_risposta = clock_timestamp()
        WHERE id = v_partecipazione.id;
    ELSE
        INSERT INTO public.partecipazione (
            giocatore_id,
            partita_id,
            risposta_stato,
            data_risposta
        ) VALUES (
            p_giocatore_id,
            p_partita_id,
            'confermata',
            clock_timestamp()
        );
    END IF;

    v_confermati := v_confermati + 1;
    posti_rimasti := GREATEST(
        v_partita.num_partecipanti_richiesti - v_confermati,
        0
    );

    IF v_confermati >= v_partita.num_partecipanti_richiesti THEN
        UPDATE public.partita
        SET stato = 'Completa'
        WHERE id = p_partita_id;
        stato_partita := 'Completa';
    ELSE
        stato_partita := 'Aperta';
    END IF;

    esito := 'confermata';
    RETURN NEXT;
END;
$$;

COMMENT ON FUNCTION public.gestisci_rsvp(uuid, uuid, text) IS
    'KCK-219/DG3: serializza gli RSVP con lock FOR UPDATE della Partita, impedisce overbooking, libera il posto al ritiro e rende idempotente una risposta gia'' confermata.';

-- Solo la Edge Function e i test server-side possono chiamarla. Il client resta
-- privo dei privilegi INSERT/UPDATE/DELETE sulla tabella Partecipazione (RLS AB).
REVOKE ALL ON FUNCTION public.gestisci_rsvp(uuid, uuid, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.gestisci_rsvp(uuid, uuid, text) TO service_role;

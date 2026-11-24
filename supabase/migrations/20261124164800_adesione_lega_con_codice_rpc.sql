-- Consente a un Giocatore autenticato di aderire a una lega tramite il codice
-- d'invito, anche quando la lega e' privata, senza modificare le policy RLS.
CREATE FUNCTION public.unisciti_lega_con_codice(p_codice_invito text)
RETURNS public.lega
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    codice_normalizzato text;
    lega_trovata public.lega;
BEGIN
    -- La RPC e' utilizzabile solo da un utente con una sessione autenticata.
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'E'' necessario autenticarsi per aderire a una lega'
            USING ERRCODE = '28000';
    END IF;

    -- D29: otto caratteri maiuscoli o cifre, escludendo i caratteri ambigui.
    codice_normalizzato := pg_catalog.upper(pg_catalog.btrim(p_codice_invito));
    IF codice_normalizzato IS NULL
        OR pg_catalog.length(codice_normalizzato) <> 8
        OR codice_normalizzato !~ '^[A-HJ-NP-Z2-9]{8}$'
    THEN
        RAISE EXCEPTION 'Codice invito non valido'
            USING ERRCODE = 'KCK01';
    END IF;

    -- Anche le leghe private sono cercate dalla RPC, senza esporle tramite RLS.
    SELECT lega.*
    INTO lega_trovata
    FROM public.lega AS lega
    WHERE lega.codice_invito = codice_normalizzato;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Codice invito non valido'
            USING ERRCODE = 'KCK01';
    END IF;

    -- Un invito senza scadenza o con scadenza raggiunta non consente l'adesione.
    IF lega_trovata.scadenza_codice_invito IS NULL
        OR lega_trovata.scadenza_codice_invito <= pg_catalog.now()
    THEN
        RAISE EXCEPTION 'Codice invito scaduto'
            USING ERRCODE = 'KCK02';
    END IF;

    -- Il controllo anticipato restituisce un errore chiaro per le adesioni ripetute.
    IF EXISTS (
        SELECT 1
        FROM public.membro_lega AS membro
        WHERE membro.lega_id = lega_trovata.id
          AND membro.giocatore_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'Il giocatore e'' gia'' membro della lega'
            USING ERRCODE = 'KCK03';
    END IF;

    -- La chiave primaria rende atomica la protezione anche contro richieste
    -- concorrenti che superano insieme il controllo di appartenenza precedente.
    BEGIN
        INSERT INTO public.membro_lega (lega_id, giocatore_id)
        VALUES (lega_trovata.id, auth.uid());
    EXCEPTION
        WHEN unique_violation THEN
            RAISE EXCEPTION 'Il giocatore e'' gia'' membro della lega'
                USING ERRCODE = 'KCK03';
    END;

    RETURN lega_trovata;
END;
$$;

COMMENT ON FUNCTION public.unisciti_lega_con_codice(text) IS
    'Aggiunge auth.uid() come membro della lega individuata dal codice invito valido, anche se privata. Verifica autenticazione, formato e scadenza D29 e impedisce adesioni duplicate nella stessa transazione.';

REVOKE ALL ON FUNCTION public.unisciti_lega_con_codice(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.unisciti_lega_con_codice(text) TO authenticated;

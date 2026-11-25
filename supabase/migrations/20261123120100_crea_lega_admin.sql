-- crea_lega: l'amministratore iniziale deve essere l'utente che crea la lega (KCK-226).
-- La funzione della migration 20261120130000_crea_lega_rpc.sql (KCK-242, Pietro
-- Senatore) e' SECURITY DEFINER e accettava qualunque p_admin_giocatore_id: un
-- utente poteva creare una lega con amministratore un altro Giocatore, e la RLS
-- non puo' impedirlo perche' la funzione la scavalca. Su autorizzazione dei PM
-- (KCK-226, punto 3) la si ridefinisce qui con la stessa firma e lo stesso corpo,
-- piu' il controllo sull'utente; il file originale non cambia. CREATE OR REPLACE
-- conserva proprietario e permessi: l'esecuzione resta tolta a PUBLIC e anon
-- (REVOKE nella migration originale) e concessa ad authenticated e service_role.
CREATE OR REPLACE FUNCTION public.crea_lega(
    p_nome text,
    p_tipologia_match text,
    p_privacy text,
    p_codice_invito text DEFAULT NULL,
    p_scadenza_codice_invito timestamptz DEFAULT NULL,
    p_admin_giocatore_id uuid DEFAULT NULL
)
RETURNS public.lega
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    lega_creata public.lega;
BEGIN
    -- Il creatore è obbligatorio per rispettare la molteplicità 1..*
    -- degli amministratori e per creare entrambe le associazioni.
    IF p_admin_giocatore_id IS NULL THEN
        RAISE EXCEPTION 'Il giocatore creatore è obbligatorio'
            USING ERRCODE = '23502';
    END IF;

    -- Un utente autenticato puo' nominare amministratore solo se stesso.
    -- Il controllo vale solo quando auth.uid() non e' NULL: anon non puo'
    -- eseguire la funzione, un utente authenticated ha sempre auth.uid(), mentre
    -- senza JWT chiamano solo postgres e il service role, che scavalcano
    -- comunque la RLS (e su cui si basa crea_lega_test.sql).
    IF auth.uid() IS NOT NULL AND p_admin_giocatore_id <> auth.uid() THEN
        RAISE EXCEPTION 'L''amministratore iniziale deve essere chi crea la lega'
            USING ERRCODE = '42501';
    END IF;

    -- Le tre scritture sono nella stessa chiamata SQL: i constraint trigger
    -- differiti verificano l'integrità solo dopo che le associazioni esistono.
    INSERT INTO public.lega (
        nome,
        tipologia_match,
        privacy,
        codice_invito,
        scadenza_codice_invito
    )
    VALUES (
        p_nome,
        p_tipologia_match,
        p_privacy,
        p_codice_invito,
        p_scadenza_codice_invito
    )
    RETURNING * INTO lega_creata;

    INSERT INTO public.membro_lega (lega_id, giocatore_id)
    VALUES (lega_creata.id, p_admin_giocatore_id);

    INSERT INTO public.amministratore_lega (lega_id, giocatore_id)
    VALUES (lega_creata.id, p_admin_giocatore_id);

    RETURN lega_creata;
END;
$$;

COMMENT ON FUNCTION public.crea_lega(
    text,
    text,
    text,
    text,
    timestamptz,
    uuid
) IS
    'Crea una lega e associa il giocatore creatore come membro e amministratore nella stessa transazione, così i constraint trigger differiti verificano uno stato coerente al commit. Se chiamata da un utente autenticato, il creatore deve essere l''utente stesso (KCK-226).';

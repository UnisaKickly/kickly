-- Crea una lega e le associazioni iniziali in un'unica transazione.
CREATE FUNCTION public.crea_lega(
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
    'Crea una lega e associa il giocatore creatore come membro e amministratore nella stessa transazione, così i constraint trigger differiti verificano uno stato coerente al commit.';

REVOKE ALL ON FUNCTION public.crea_lega(
    text,
    text,
    text,
    text,
    timestamptz,
    uuid
) FROM PUBLIC;

REVOKE ALL ON FUNCTION public.crea_lega(
    text,
    text,
    text,
    text,
    timestamptz,
    uuid
) FROM anon;

GRANT EXECUTE ON FUNCTION public.crea_lega(
    text,
    text,
    text,
    text,
    timestamptz,
    uuid
) TO authenticated;

GRANT EXECUTE ON FUNCTION public.crea_lega(
    text,
    text,
    text,
    text,
    timestamptz,
    uuid
) TO service_role;

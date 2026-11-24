-- Test pgTAP per le RPC e i trigger introdotti da KCK-271.
BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(19);

CREATE FUNCTION pg_temp.crea_utente(
    p_id uuid,
    p_email text,
    p_nome text,
    p_cognome text
)
RETURNS void
LANGUAGE sql
AS $$
    INSERT INTO auth.users (
        id,
        instance_id,
        aud,
        role,
        email,
        encrypted_password,
        email_confirmed_at,
        raw_app_meta_data,
        raw_user_meta_data,
        created_at,
        updated_at,
        confirmation_token,
        recovery_token,
        email_change,
        email_change_token_new
    )
    VALUES (
        p_id,
        '00000000-0000-4000-8000-000000000000',
        'authenticated',
        'authenticated',
        p_email,
        extensions.crypt('KicklyTest2026!', extensions.gen_salt('bf')),
        pg_catalog.now(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        jsonb_build_object('nome', p_nome, 'cognome', p_cognome, 'eta', '25'),
        pg_catalog.now(),
        pg_catalog.now(),
        '',
        '',
        '',
        ''
    );
$$;

CREATE FUNCTION pg_temp.imposta_jwt(p_id uuid, p_ruolo text)
RETURNS void
LANGUAGE sql
AS $$
    SELECT pg_catalog.set_config('request.jwt.claim.sub', coalesce(p_id::text, ''), true);
    SELECT pg_catalog.set_config(
        'request.jwt.claims',
        CASE
            WHEN p_id IS NULL THEN jsonb_build_object('role', p_ruolo)::text
            ELSE jsonb_build_object('sub', p_id, 'role', p_ruolo)::text
        END,
        true
    );
$$;

GRANT EXECUTE ON FUNCTION pg_temp.imposta_jwt(uuid, text) TO PUBLIC;

-- Fixture: tre account fittizi, due giocatori e un gestore campo.
RESET ROLE;

SELECT pg_temp.crea_utente(
    '27100000-0000-4000-8000-000000000001',
    'mario.271@example.test',
    'Mario',
    'Rossi'
);
SELECT pg_temp.crea_utente(
    '27100000-0000-4000-8000-000000000002',
    'luca.271@example.test',
    'Luca',
    'Bianchi'
);
SELECT pg_temp.crea_utente(
    '27100000-0000-4000-8000-000000000003',
    'gestore.271@example.test',
    'Gianni',
    'Verdi'
);

UPDATE public.account
SET ruolo_account = 'Giocatore',
    stato_onboarding = 'completato'
WHERE id IN (
    '27100000-0000-4000-8000-000000000001',
    '27100000-0000-4000-8000-000000000002'
);

UPDATE public.account
SET ruolo_account = 'GestoreCampo',
    stato_onboarding = 'completato'
WHERE id = '27100000-0000-4000-8000-000000000003';

INSERT INTO public.giocatore (
    account_id,
    ruolo_preferito_in_campo,
    piede_dominante
)
VALUES
    ('27100000-0000-4000-8000-000000000001', 'Attaccante', 'Destro'),
    ('27100000-0000-4000-8000-000000000002', 'Portiere', 'Sinistro');

INSERT INTO public.gestore_campo (account_id)
VALUES ('27100000-0000-4000-8000-000000000003');

INSERT INTO public.campo (
    id,
    gestore_campo_id,
    nome,
    ubicazione,
    tariffa_oraria,
    orari_disponibilita
)
VALUES (
    '27100000-0000-4000-8000-000000000101',
    '27100000-0000-4000-8000-000000000003',
    'Campo Test 271',
    'Via Roma 1, Salerno',
    60.00,
    'lun-dom 09:00-23:00'
);

-- Le RPC non sono eseguibili da anon.
SELECT pg_temp.imposta_jwt(NULL, 'anon');
SET LOCAL ROLE anon;

SELECT throws_ok(
    $$SELECT * FROM public.get_profili_pubblici(
        ARRAY['27100000-0000-4000-8000-000000000001'::uuid]
    )$$,
    '42501',
    NULL,
    'anon non puo'' eseguire get_profili_pubblici'
);

SELECT throws_ok(
    $$SELECT * FROM public.get_slot_occupati(
        '27100000-0000-4000-8000-000000000101',
        '2030-06-10 00:00:00+00',
        '2030-06-12 00:00:00+00'
    )$$,
    '42501',
    NULL,
    'anon non puo'' eseguire get_slot_occupati'
);

RESET ROLE;

SELECT ok(
    NOT has_function_privilege(
        'anon',
        'public.get_profili_pubblici(uuid[])',
        'EXECUTE'
    )
    AND has_function_privilege(
        'authenticated',
        'public.get_profili_pubblici(uuid[])',
        'EXECUTE'
    ),
    'get_profili_pubblici e'' eseguibile solo dal ruolo authenticated'
);

SELECT ok(
    NOT has_function_privilege(
        'anon',
        'public.get_slot_occupati(uuid,timestamptz,timestamptz)',
        'EXECUTE'
    )
    AND has_function_privilege(
        'authenticated',
        'public.get_slot_occupati(uuid,timestamptz,timestamptz)',
        'EXECUTE'
    ),
    'get_slot_occupati e'' eseguibile solo dal ruolo authenticated'
);

SELECT ok(
    (
        SELECT prosecdef
           AND proconfig @> ARRAY['search_path=""']
        FROM pg_catalog.pg_proc
        WHERE oid = 'public.get_profili_pubblici(uuid[])'::regprocedure
    ),
    'get_profili_pubblici usa SECURITY DEFINER e search_path vuoto'
);

SELECT ok(
    (
        SELECT prosecdef
           AND proconfig @> ARRAY['search_path=""']
        FROM pg_catalog.pg_proc
        WHERE oid = 'public.get_slot_occupati(uuid,timestamptz,timestamptz)'::regprocedure
    ),
    'get_slot_occupati usa SECURITY DEFINER e search_path vuoto'
);

SELECT is(
    pg_catalog.pg_get_function_result(
        'public.get_profili_pubblici(uuid[])'::regprocedure
    ),
    'TABLE(id uuid, nome text, cognome text, ruolo_preferito_in_campo text, piede_dominante text)',
    'get_profili_pubblici espone solo i campi pubblici della Player Card'
);

SELECT pg_temp.imposta_jwt(
    '27100000-0000-4000-8000-000000000002',
    'authenticated'
);
SET LOCAL ROLE authenticated;

SELECT results_eq(
    $$SELECT nome, cognome, ruolo_preferito_in_campo, piede_dominante
      FROM public.get_profili_pubblici(
          ARRAY['27100000-0000-4000-8000-000000000001'::uuid]
      )$$,
    $$VALUES ('Mario'::text, 'Rossi'::text, 'Attaccante'::text, 'Destro'::text)$$,
    'un utente autenticato legge nome e Player Card senza dati account'
);

-- Senza id (NULL) o con un array vuoto la funzione non restituisce nessun
-- profilo: nessun utente puo' elencare l'intera anagrafica (revisione dei PM).
SELECT is(
    (SELECT count(*)::integer
       FROM public.get_profili_pubblici(NULL::uuid[])) +
    (SELECT count(*)::integer
       FROM public.get_profili_pubblici(ARRAY[]::uuid[])),
    0,
    'get_profili_pubblici senza id o con array vuoto non restituisce nessun profilo'
);

RESET ROLE;

-- L'organizzatore viene aggiunto automaticamente alla partita.
INSERT INTO public.partita (
    id,
    giocatore_id,
    data_ora,
    tipologia,
    privacy,
    num_partecipanti_richiesti
)
VALUES (
    '27100000-0000-4000-8000-000000000201',
    '27100000-0000-4000-8000-000000000002',
    pg_catalog.now() + interval '48 hours',
    '5v5',
    'pubblica',
    10
);

SET CONSTRAINTS trg_crea_partecipazione_organizzatore IMMEDIATE;

SELECT results_eq(
    $$SELECT giocatore_id, risposta_stato
      FROM public.partecipazione
      WHERE partita_id = '27100000-0000-4000-8000-000000000201'$$,
    $$VALUES (
        '27100000-0000-4000-8000-000000000002'::uuid,
        'confermata'::text
    )$$,
    'la partita crea la partecipazione confermata dell''organizzatore'
);

INSERT INTO public.partita (
    id,
    giocatore_id,
    data_ora,
    tipologia,
    privacy,
    num_partecipanti_richiesti
)
VALUES
    (
        '27100000-0000-4000-8000-000000000202',
        '27100000-0000-4000-8000-000000000001',
        '2030-06-10 18:00:00+00'::timestamptz,
        '5v5',
        'pubblica',
        10
    ),
    (
        '27100000-0000-4000-8000-000000000203',
        '27100000-0000-4000-8000-000000000001',
        pg_catalog.now() + interval '10 hours',
        '5v5',
        'pubblica',
        11
    );

-- Il trigger ignora gli importi e la scadenza inviati dal client.
INSERT INTO public.prenotazione (
    id,
    partita_id,
    campo_id,
    intervallo,
    stato_blocco,
    scadenza_blocco,
    costo_concordato,
    quota_individuale,
    commissione,
    netto_gestore
)
VALUES (
    '27100000-0000-4000-8000-000000000301',
    '27100000-0000-4000-8000-000000000202',
    '27100000-0000-4000-8000-000000000101',
    '2030-06-10T18:00/2030-06-10T19:00',
    'bloccato',
    '2035-01-01 00:00:00+00'::timestamptz,
    1.00,
    0.10,
    0.00,
    1.00
);

SELECT results_eq(
    $$SELECT costo_concordato, quota_individuale, commissione, netto_gestore
      FROM public.prenotazione
      WHERE id = '27100000-0000-4000-8000-000000000301'$$,
    $$VALUES (60.00::numeric, 6.00::numeric, 3.00::numeric, 57.00::numeric)$$,
    'il trigger sovrascrive gli importi falsi inviati dal client'
);

SELECT is(
    (
        SELECT scadenza_blocco
        FROM public.prenotazione
        WHERE id = '27100000-0000-4000-8000-000000000301'
    ),
    '2030-06-09 18:00:00+00'::timestamptz,
    'la scadenza e'' impostata a 24 ore prima della partita'
);

INSERT INTO public.prenotazione (
    id,
    partita_id,
    campo_id,
    intervallo,
    stato_blocco,
    scadenza_blocco,
    costo_concordato,
    quota_individuale,
    commissione,
    netto_gestore
)
VALUES (
    '27100000-0000-4000-8000-000000000302',
    '27100000-0000-4000-8000-000000000203',
    '27100000-0000-4000-8000-000000000101',
    '2030-06-11T18:00/2030-06-11T19:00',
    'liberato',
    pg_catalog.now() + interval '5 days',
    999.00,
    999.00,
    999.00,
    999.00
);

SELECT is(
    (
        SELECT quota_individuale
        FROM public.prenotazione
        WHERE id = '27100000-0000-4000-8000-000000000302'
    ),
    5.46::numeric,
    'la quota individuale e'' arrotondata per eccesso al centesimo'
);

SELECT is(
    (
        SELECT scadenza_blocco
        FROM public.prenotazione
        WHERE id = '27100000-0000-4000-8000-000000000302'
    ),
    (
        SELECT data_ora - interval '2 hours'
        FROM public.partita
        WHERE id = '27100000-0000-4000-8000-000000000203'
    ),
    'la scadenza e'' impostata a 2 ore prima se mancano meno di 24 ore'
);

-- Il solo cambio di stato non deve ricalcolare importi o scadenza.
UPDATE public.prenotazione
SET costo_concordato = 777.00,
    scadenza_blocco = '2030-06-09 12:00:00+00'::timestamptz
WHERE id = '27100000-0000-4000-8000-000000000301';

UPDATE public.prenotazione
SET stato_blocco = 'confermato'
WHERE id = '27100000-0000-4000-8000-000000000301';

SELECT is(
    (
        SELECT costo_concordato
        FROM public.prenotazione
        WHERE id = '27100000-0000-4000-8000-000000000301'
    ),
    777.00::numeric,
    'il cambio del solo stato_blocco non ricalcola gli importi'
);

SELECT is(
    (
        SELECT scadenza_blocco
        FROM public.prenotazione
        WHERE id = '27100000-0000-4000-8000-000000000301'
    ),
    '2030-06-09 12:00:00+00'::timestamptz,
    'il cambio del solo stato_blocco non ricalcola la scadenza'
);

UPDATE public.prenotazione
SET intervallo = '2030-06-10T18:00/2030-06-10T20:00'
WHERE id = '27100000-0000-4000-8000-000000000301';

SELECT results_eq(
    $$SELECT costo_concordato, quota_individuale, commissione, netto_gestore
      FROM public.prenotazione
      WHERE id = '27100000-0000-4000-8000-000000000301'$$,
    $$VALUES (120.00::numeric, 12.00::numeric, 6.00::numeric, 114.00::numeric)$$,
    'il cambio di intervallo ricalcola gli importi'
);

-- La RPC slot espone solo intervallo e stato, ed esclude le prenotazioni liberate.
SELECT is(
    pg_catalog.pg_get_function_result(
        'public.get_slot_occupati(uuid,timestamptz,timestamptz)'::regprocedure
    ),
    'TABLE(intervallo text, stato_blocco text)',
    'get_slot_occupati espone solo intervallo e stato_blocco'
);

SELECT pg_temp.imposta_jwt(
    '27100000-0000-4000-8000-000000000002',
    'authenticated'
);
SET LOCAL ROLE authenticated;

SELECT results_eq(
    $$SELECT intervallo, stato_blocco
      FROM public.get_slot_occupati(
          '27100000-0000-4000-8000-000000000101',
          '2030-06-10 00:00:00+00',
          '2030-06-12 00:00:00+00'
      )$$,
    $$VALUES (
        '2030-06-10T18:00/2030-06-10T20:00'::text,
        'confermato'::text
    )$$,
    'get_slot_occupati restituisce gli slot attivi e omette quelli liberati'
);

RESET ROLE;
SELECT * FROM finish();

ROLLBACK;

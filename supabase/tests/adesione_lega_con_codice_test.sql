-- Test pgTAP della RPC di adesione tramite codice d'invito (KCK-274).
-- Le fixture sono isolate in una transazione annullata al termine.
BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(11);

-- Crea un utente Auth; il trigger della migration A crea il relativo Account.
CREATE FUNCTION pg_temp.crea_utente(p_id uuid, p_email text, p_nome text)
RETURNS void
LANGUAGE sql
AS $$
    INSERT INTO auth.users (
        id, instance_id, aud, role, email, encrypted_password,
        email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
        created_at, updated_at, confirmation_token, recovery_token,
        email_change, email_change_token_new
    )
    VALUES (
        p_id,
        '00000000-0000-0000-0000-000000000000',
        'authenticated',
        'authenticated',
        p_email,
        extensions.crypt('KicklyTest2026!', extensions.gen_salt('bf')),
        pg_catalog.now(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        jsonb_build_object('nome', p_nome, 'cognome', 'Test', 'eta', '25'),
        pg_catalog.now(),
        pg_catalog.now(),
        '',
        '',
        '',
        ''
    );
$$;

-- Imposta il JWT della sessione simulata. Un id NULL produce auth.uid() NULL.
CREATE FUNCTION pg_temp.imposta_jwt(p_id uuid, p_ruolo text)
RETURNS void
LANGUAGE sql
AS $$
    SELECT set_config('request.jwt.claim.sub', coalesce(p_id::text, ''), true);
    SELECT set_config(
        'request.jwt.claims',
        CASE
            WHEN p_id IS NULL THEN jsonb_build_object('role', p_ruolo)::text
            ELSE jsonb_build_object('sub', p_id, 'role', p_ruolo)::text
        END,
        true
    );
$$;

-- Utenti fittizi: admin, adesione valida, invito scaduto, codice errato,
-- giocatore già membro.
SELECT pg_temp.crea_utente(
    '27400000-0000-4000-8000-000000000001',
    'admin.adesione@example.test',
    'Ada'
);
SELECT pg_temp.crea_utente(
    '27400000-0000-4000-8000-000000000002',
    'valido.adesione@example.test',
    'Valeria'
);
SELECT pg_temp.crea_utente(
    '27400000-0000-4000-8000-000000000003',
    'scaduto.adesione@example.test',
    'Scilla'
);
SELECT pg_temp.crea_utente(
    '27400000-0000-4000-8000-000000000004',
    'errato.adesione@example.test',
    'Ennio'
);
SELECT pg_temp.crea_utente(
    '27400000-0000-4000-8000-000000000005',
    'membro.adesione@example.test',
    'Marta'
);

UPDATE public.account
SET ruolo_account = 'Giocatore',
    stato_onboarding = 'completato'
WHERE id BETWEEN
    '27400000-0000-4000-8000-000000000001'::uuid AND
    '27400000-0000-4000-8000-000000000005'::uuid;

INSERT INTO public.giocatore (account_id)
VALUES
    ('27400000-0000-4000-8000-000000000001'),
    ('27400000-0000-4000-8000-000000000002'),
    ('27400000-0000-4000-8000-000000000003'),
    ('27400000-0000-4000-8000-000000000004'),
    ('27400000-0000-4000-8000-000000000005');

-- Tre leghe private: codice valido, codice scaduto e giocatore già membro.
INSERT INTO public.lega (
    id, nome, tipologia_match, privacy, codice_invito, scadenza_codice_invito
)
VALUES
    (
        '27400000-0000-4000-8000-000000000101',
        'Lega invito valido KCK-274',
        '5v5',
        'privata',
        'ABC23456',
        pg_catalog.now() + interval '7 days'
    ),
    (
        '27400000-0000-4000-8000-000000000102',
        'Lega invito scaduto KCK-274',
        '5v5',
        'privata',
        'DEF23456',
        pg_catalog.now() - interval '1 second'
    ),
    (
        '27400000-0000-4000-8000-000000000103',
        'Lega membro esistente KCK-274',
        '5v5',
        'privata',
        'GHJ23456',
        pg_catalog.now() + interval '7 days'
    );

-- Ogni lega ha un amministratore iniziale; l'ultima ha anche il Giocatore
-- usato per verificare l'adesione duplicata.
INSERT INTO public.membro_lega (lega_id, giocatore_id)
VALUES
    ('27400000-0000-4000-8000-000000000101', '27400000-0000-4000-8000-000000000001'),
    ('27400000-0000-4000-8000-000000000102', '27400000-0000-4000-8000-000000000001'),
    ('27400000-0000-4000-8000-000000000103', '27400000-0000-4000-8000-000000000001'),
    ('27400000-0000-4000-8000-000000000103', '27400000-0000-4000-8000-000000000005');

INSERT INTO public.amministratore_lega (lega_id, giocatore_id)
VALUES
    ('27400000-0000-4000-8000-000000000101', '27400000-0000-4000-8000-000000000001'),
    ('27400000-0000-4000-8000-000000000102', '27400000-0000-4000-8000-000000000001'),
    ('27400000-0000-4000-8000-000000000103', '27400000-0000-4000-8000-000000000001');

-- Caso 1: un Giocatore autenticato aderisce tramite un codice valido a una
-- lega privata; la RPC restituisce la Lega.
SELECT pg_temp.imposta_jwt(
    '27400000-0000-4000-8000-000000000002',
    'authenticated'
);
SET LOCAL ROLE authenticated;
SELECT is(
    (public.unisciti_lega_con_codice('ABC23456')).id,
    '27400000-0000-4000-8000-000000000101'::uuid,
    'un codice valido restituisce la lega privata'
);
RESET ROLE;
SELECT is(
    (
        SELECT count(*)::integer
        FROM public.membro_lega
        WHERE lega_id = '27400000-0000-4000-8000-000000000101'
          AND giocatore_id = '27400000-0000-4000-8000-000000000002'
    ),
    1,
    'un codice valido inserisce il Giocatore tra i membri'
);

-- Caso 2: un invito scaduto viene rifiutato senza inserire il Giocatore.
SELECT pg_temp.imposta_jwt(
    '27400000-0000-4000-8000-000000000003',
    'authenticated'
);
SET LOCAL ROLE authenticated;
SELECT throws_ok(
    $$SELECT public.unisciti_lega_con_codice('DEF23456')$$,
    'KCK02',
    NULL,
    'un codice scaduto solleva KCK02'
);
RESET ROLE;
SELECT is(
    (
        SELECT count(*)::integer
        FROM public.membro_lega
        WHERE lega_id = '27400000-0000-4000-8000-000000000102'
          AND giocatore_id = '27400000-0000-4000-8000-000000000003'
    ),
    0,
    'un codice scaduto non inserisce il Giocatore tra i membri'
);

-- Caso 3: sia un codice inesistente sia uno malformato sollevano KCK01.
SELECT pg_temp.imposta_jwt(
    '27400000-0000-4000-8000-000000000004',
    'authenticated'
);
SET LOCAL ROLE authenticated;
SELECT throws_ok(
    $$SELECT public.unisciti_lega_con_codice('ZZZ23456')$$,
    'KCK01',
    NULL,
    'un codice inesistente solleva KCK01'
);
SELECT throws_ok(
    $$SELECT public.unisciti_lega_con_codice('AIO23456')$$,
    'KCK01',
    NULL,
    'un codice malformato solleva KCK01'
);
RESET ROLE;
SELECT is(
    (
        SELECT count(*)::integer
        FROM public.membro_lega
        WHERE giocatore_id = '27400000-0000-4000-8000-000000000004'
    ),
    0,
    'codici inesistenti o malformati non aggiungono membri'
);

-- Caso 4: un Giocatore già membro riceve KCK03 e non viene duplicato.
SELECT pg_temp.imposta_jwt(
    '27400000-0000-4000-8000-000000000005',
    'authenticated'
);
SET LOCAL ROLE authenticated;
SELECT throws_ok(
    $$SELECT public.unisciti_lega_con_codice('GHJ23456')$$,
    'KCK03',
    NULL,
    'un Giocatore già membro riceve KCK03'
);
RESET ROLE;
SELECT is(
    (
        SELECT count(*)::integer
        FROM public.membro_lega
        WHERE lega_id = '27400000-0000-4000-8000-000000000103'
          AND giocatore_id = '27400000-0000-4000-8000-000000000005'
    ),
    1,
    'il rifiuto dell''adesione duplicata lascia una sola riga membro'
);

-- Caso 5: senza subject nel JWT auth.uid() e' NULL e la RPC solleva 28000.
SELECT pg_temp.imposta_jwt(NULL, 'authenticated');
SET LOCAL ROLE authenticated;
SELECT throws_ok(
    $$SELECT public.unisciti_lega_con_codice('ABC23456')$$,
    '28000',
    NULL,
    'senza auth.uid() la RPC solleva 28000'
);
RESET ROLE;
SELECT is(
    (
        SELECT count(*)::integer
        FROM public.membro_lega
    ),
    5,
    'una chiamata non autenticata non inserisce associazioni membro'
);

SELECT * FROM finish();

ROLLBACK;

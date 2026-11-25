BEGIN;

SELECT plan(8);

-- Fixture autonoma: il trigger della migration A crea public.account.
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
    '20300000-0000-4000-8000-000000000001',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'creatore.lega@example.test',
    extensions.crypt('KicklyTest2026!', extensions.gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"nome":"Creatore","cognome":"Lega","eta":"28"}'::jsonb,
    now(),
    now(),
    '',
    '',
    '',
    ''
);

UPDATE public.account
SET ruolo_account = 'Giocatore',
    stato_onboarding = 'completato'
WHERE id = '20300000-0000-4000-8000-000000000001';

INSERT INTO public.giocatore (account_id)
VALUES ('20300000-0000-4000-8000-000000000001');

CREATE TEMP TABLE lega_creata_test AS
SELECT *
FROM public.crea_lega(
    '  Lega PgTAP  ',
    '5v5',
    'privata',
    'PGTAP-INVITO',
    '2026-12-01T20:00:00+00:00'::timestamptz,
    '20300000-0000-4000-8000-000000000001'::uuid
);

SELECT is(
    (SELECT count(*)::integer FROM lega_creata_test),
    1,
    'crea_lega restituisce la lega creata'
);

SELECT is(
    (SELECT nome FROM lega_creata_test),
    '  Lega PgTAP  ',
    'la lega restituita conserva il nome passato'
);

SELECT is(
    (SELECT count(*)::integer
     FROM public.lega
     WHERE nome = '  Lega PgTAP  '),
    1,
    'crea_lega inserisce la riga in lega'
);

SELECT is(
    (SELECT count(*)::integer
     FROM public.membro_lega
     WHERE lega_id = (SELECT id FROM lega_creata_test)
       AND giocatore_id = '20300000-0000-4000-8000-000000000001'),
    1,
    'crea_lega inserisce il creatore come membro'
);

SELECT is(
    (SELECT count(*)::integer
     FROM public.amministratore_lega
     WHERE lega_id = (SELECT id FROM lega_creata_test)
       AND giocatore_id = '20300000-0000-4000-8000-000000000001'),
    1,
    'crea_lega inserisce il creatore come amministratore'
);

SELECT is(
    (SELECT codice_invito FROM lega_creata_test),
    'PGTAP-INVITO',
    'crea_lega conserva il codice invito fornito'
);

SELECT throws_ok(
    $$
    SELECT public.crea_lega(
        'lega pgtap',
        '5v5',
        'privata',
        'PGTAP-INVITO-2',
        '2026-12-02T20:00:00+00:00'::timestamptz,
        '20300000-0000-4000-8000-000000000001'::uuid
    )
    $$,
    '23505',
    NULL,
    'un nome già esistente anche con maiuscole e spazi fallisce'
);

SELECT throws_ok(
    $$
    SELECT public.crea_lega(
        'Lega senza creatore',
        '5v5',
        'privata'
    )
    $$,
    '23502',
    NULL,
    'un creatore nullo viene rifiutato'
);

SELECT * FROM finish();

ROLLBACK;

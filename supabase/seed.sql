BEGIN;

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
VALUES
    (
        '20200000-0000-4000-8000-000000000001',
        '00000000-0000-0000-0000-000000000000',
        'authenticated',
        'authenticated',
        'mario.rossi@example.test',
        extensions.crypt('KicklyTest2026!', extensions.gen_salt('bf')),
        now(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        '{"nome":"Mario","cognome":"Rossi","eta":"28"}'::jsonb,
        now(),
        now(),
        '',
        '',
        '',
        ''
    ),
    (
        '20200000-0000-4000-8000-000000000002',
        '00000000-0000-0000-0000-000000000000',
        'authenticated',
        'authenticated',
        'luca.bianchi@example.test',
        extensions.crypt('KicklyTest2026!', extensions.gen_salt('bf')),
        now(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        '{"nome":"Luca","cognome":"Bianchi","eta":"31"}'::jsonb,
        now(),
        now(),
        '',
        '',
        '',
        ''
    ),
    (
        '20200000-0000-4000-8000-000000000003',
        '00000000-0000-0000-0000-000000000000',
        'authenticated',
        'authenticated',
        'andrea.verdi@example.test',
        extensions.crypt('KicklyTest2026!', extensions.gen_salt('bf')),
        now(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        '{"nome":"Andrea","cognome":"Verdi","eta":"25"}'::jsonb,
        now(),
        now(),
        '',
        '',
        '',
        ''
    ),
    (
        '20200000-0000-4000-8000-000000000004',
        '00000000-0000-0000-0000-000000000000',
        'authenticated',
        'authenticated',
        'paolo.ferri@example.test',
        extensions.crypt('KicklyTest2026!', extensions.gen_salt('bf')),
        now(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        '{"nome":"Paolo","cognome":"Ferri"}'::jsonb,
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
WHERE id IN (
    '20200000-0000-4000-8000-000000000001',
    '20200000-0000-4000-8000-000000000002',
    '20200000-0000-4000-8000-000000000003'
);

UPDATE public.account
SET ruolo_account = 'GestoreCampo',
    stato_onboarding = 'completato'
WHERE id = '20200000-0000-4000-8000-000000000004';

INSERT INTO public.giocatore (account_id, ruolo_preferito_in_campo, piede_dominante)
VALUES
    ('20200000-0000-4000-8000-000000000001', 'Centrocampista', 'Destro'),
    ('20200000-0000-4000-8000-000000000002', 'Difensore', 'Sinistro'),
    ('20200000-0000-4000-8000-000000000003', 'Attaccante', 'Destro');

INSERT INTO public.gestore_campo (account_id)
VALUES ('20200000-0000-4000-8000-000000000004');

INSERT INTO public.lega (
    id,
    nome,
    tipologia_match,
    privacy,
    codice_invito,
    scadenza_codice_invito
)
VALUES
    (
        '20200000-0000-4000-8000-000000000101',
        'Amici del Venerdi',
        '5v5',
        'pubblica',
        'KICKLY-A-2026',
        now() + interval '30 days'
    ),
    (
        '20200000-0000-4000-8000-000000000102',
        'Dilettanti Salerno',
        '8v8',
        'privata',
        'KICKLY-B-2026',
        now() + interval '30 days'
    );

INSERT INTO public.membro_lega (lega_id, giocatore_id)
VALUES
    (
        '20200000-0000-4000-8000-000000000101',
        '20200000-0000-4000-8000-000000000001'
    ),
    (
        '20200000-0000-4000-8000-000000000101',
        '20200000-0000-4000-8000-000000000002'
    ),
    (
        '20200000-0000-4000-8000-000000000102',
        '20200000-0000-4000-8000-000000000002'
    ),
    (
        '20200000-0000-4000-8000-000000000102',
        '20200000-0000-4000-8000-000000000003'
    );

INSERT INTO public.amministratore_lega (lega_id, giocatore_id)
VALUES
    (
        '20200000-0000-4000-8000-000000000101',
        '20200000-0000-4000-8000-000000000001'
    ),
    (
        '20200000-0000-4000-8000-000000000102',
        '20200000-0000-4000-8000-000000000002'
    );

COMMIT;

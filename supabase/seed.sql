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
        '{"nome":"Paolo","cognome":"Ferri","eta":"45"}'::jsonb,
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

-- Parte B (KCK-210): campi, partite, prenotazioni e partecipazioni.
-- Usa gli account della parte A: Gestore ...0004, Giocatori ...0001-0003,
-- leghe ...0101 (5v5) e ...0102 (8v8). Dati e importi fittizi.

INSERT INTO public.campo (
    id,
    gestore_campo_id,
    nome,
    ubicazione,
    tariffa_oraria,
    orari_disponibilita
)
VALUES
    (
        '20200000-0000-4000-8000-000000000201',
        '20200000-0000-4000-8000-000000000004',
        'Campo Uno',
        'Via dei Test 1, Salerno',
        60.00,
        'lun-dom 09:00-23:00'
    ),
    (
        '20200000-0000-4000-8000-000000000202',
        '20200000-0000-4000-8000-000000000004',
        'Campo Due',
        'Via dei Test 1, Salerno',
        80.00,
        'lun-ven 17:00-23:00'
    );

-- Tre partite: una Aperta nella lega 5v5, una Annullata nella lega 8v8 (il suo
-- slot e' liberato) e una pubblica senza lega, Aperta. Le partite di una lega
-- sono private: "partita pubblica = senza lega" (associazione 10 di class_diagram_sdd.md).
INSERT INTO public.partita (
    id,
    giocatore_id,
    lega_id,
    data_ora,
    tipologia,
    privacy,
    num_partecipanti_richiesti,
    stato,
    link_condivisione
)
VALUES
    (
        '20200000-0000-4000-8000-000000000301',
        '20200000-0000-4000-8000-000000000001',
        '20200000-0000-4000-8000-000000000101',
        '2026-12-04 19:00:00+01',
        '5v5',
        'privata',
        10,
        'Aperta',
        NULL
    ),
    (
        '20200000-0000-4000-8000-000000000302',
        '20200000-0000-4000-8000-000000000002',
        '20200000-0000-4000-8000-000000000102',
        '2026-12-05 18:00:00+01',
        '8v8',
        'privata',
        16,
        'Annullata',
        NULL
    ),
    (
        '20200000-0000-4000-8000-000000000303',
        '20200000-0000-4000-8000-000000000003',
        NULL,
        '2026-12-05 18:30:00+01',
        '5v5',
        'pubblica',
        10,
        'Aperta',
        'https://kickly.example.test/partita/20200000-0000-4000-8000-000000000303'
    );

-- La prenotazione liberata (...0402) e quella bloccata (...0403) sono sullo
-- stesso campo con orari che si sovrappongono: e' ammesso, perche' uno slot
-- liberato non occupa piu' il campo.
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
VALUES
    (
        '20200000-0000-4000-8000-000000000401',
        '20200000-0000-4000-8000-000000000301',
        '20200000-0000-4000-8000-000000000202',
        '2026-12-04T19:00/2026-12-04T20:00',
        'confermato',
        NULL,
        80.00,
        8.00,
        4.00,
        76.00
    ),
    (
        '20200000-0000-4000-8000-000000000402',
        '20200000-0000-4000-8000-000000000302',
        '20200000-0000-4000-8000-000000000201',
        '2026-12-05T18:00/2026-12-05T19:00',
        'liberato',
        NULL,
        60.00,
        3.75,
        3.00,
        57.00
    ),
    (
        '20200000-0000-4000-8000-000000000403',
        '20200000-0000-4000-8000-000000000303',
        '20200000-0000-4000-8000-000000000201',
        '2026-12-05T18:30/2026-12-05T19:30',
        'bloccato',
        now() + interval '1 day',
        60.00,
        6.00,
        3.00,
        57.00
    );

-- Partecipazioni coerenti con lo stato: nessuna partita ha raggiunto il numero
-- richiesto, quindi nessuna e' Completa; nella partita annullata Andrea si era ritirato.
INSERT INTO public.partecipazione (
    id,
    giocatore_id,
    partita_id,
    risposta_stato,
    data_risposta
)
VALUES
    (
        '20200000-0000-4000-8000-000000000501',
        '20200000-0000-4000-8000-000000000001',
        '20200000-0000-4000-8000-000000000301',
        'confermata',
        now()
    ),
    (
        '20200000-0000-4000-8000-000000000502',
        '20200000-0000-4000-8000-000000000002',
        '20200000-0000-4000-8000-000000000301',
        'confermata',
        now()
    ),
    (
        '20200000-0000-4000-8000-000000000503',
        '20200000-0000-4000-8000-000000000002',
        '20200000-0000-4000-8000-000000000302',
        'confermata',
        now()
    ),
    (
        '20200000-0000-4000-8000-000000000504',
        '20200000-0000-4000-8000-000000000003',
        '20200000-0000-4000-8000-000000000302',
        'ritirata',
        now()
    ),
    (
        '20200000-0000-4000-8000-000000000505',
        '20200000-0000-4000-8000-000000000003',
        '20200000-0000-4000-8000-000000000303',
        'confermata',
        now()
    ),
    (
        '20200000-0000-4000-8000-000000000506',
        '20200000-0000-4000-8000-000000000001',
        '20200000-0000-4000-8000-000000000303',
        'confermata',
        now()
    );

-- Parte C (KCK-218): votazione, notifiche, quote e transazioni.
-- Fixture dedicata: partita conclusa con due partecipanti per verificare
-- l'unicita' del voto per votante e l'idempotenza delle transazioni.
INSERT INTO public.partita (
    id,
    giocatore_id,
    lega_id,
    data_ora,
    tipologia,
    privacy,
    num_partecipanti_richiesti,
    stato,
    link_condivisione
)
VALUES (
    '20200000-0000-4000-8000-000000000304',
    '20200000-0000-4000-8000-000000000001',
    NULL,
    now() - interval '1 day',
    '5v5',
    'pubblica',
    10,
    'Conclusa',
    'https://kickly.example.test/partita/20200000-0000-4000-8000-000000000304'
);

INSERT INTO public.partecipazione (
    id,
    giocatore_id,
    partita_id,
    risposta_stato,
    data_risposta
)
VALUES
    (
        '20200000-0000-4000-8000-000000000507',
        '20200000-0000-4000-8000-000000000002',
        '20200000-0000-4000-8000-000000000304',
        'confermata',
        now() - interval '1 day'
    ),
    (
        '20200000-0000-4000-8000-000000000508',
        '20200000-0000-4000-8000-000000000003',
        '20200000-0000-4000-8000-000000000304',
        'confermata',
        now() - interval '1 day'
    );

INSERT INTO public.votazione_mvp (
    id,
    partita_id,
    stato_votazione,
    scadenza
)
VALUES (
    '20200000-0000-4000-8000-000000000601',
    '20200000-0000-4000-8000-000000000304',
    'aperta',
    now() + interval '1 day'
);

INSERT INTO public.preferenza_voto_mvp (votazione_id, votante_id, votato_id)
VALUES (
    '20200000-0000-4000-8000-000000000601',
    '20200000-0000-4000-8000-000000000002',
    '20200000-0000-4000-8000-000000000003'
);

INSERT INTO public.notifica (id, account_id, tipo, messaggio)
VALUES (
    '20200000-0000-4000-8000-000000000701',
    '20200000-0000-4000-8000-000000000002',
    'apertura_sondaggio_mvp',
    'La votazione MVP della partita e'' aperta.'
);

INSERT INTO public.quota (
    id,
    partecipazione_id,
    importo,
    stato_versamento,
    termine_versamento
)
VALUES
    (
        '20200000-0000-4000-8000-000000000801',
        '20200000-0000-4000-8000-000000000507',
        8.00,
        'versata',
        now() + interval '1 day'
    ),
    (
        '20200000-0000-4000-8000-000000000802',
        '20200000-0000-4000-8000-000000000508',
        8.00,
        'da_versare',
        now() + interval '1 day'
    );

INSERT INTO public.transazione (
    id,
    quota_id,
    tipo,
    importo,
    stato,
    data_esito,
    riferimento_esterno
)
VALUES (
    '20200000-0000-4000-8000-000000000901',
    '20200000-0000-4000-8000-000000000801',
    'pagamento',
    8.00,
    'completata',
    now(),
    'evt_kickly_test_pagamento_20200000000000000000000000000801'
);

COMMIT;

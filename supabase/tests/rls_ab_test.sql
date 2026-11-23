-- Test pgTAP delle policy RLS degli schemi A e B (KCK-226), del controllo
-- sull'amministratore di crea_lega e dei trigger (D11, D2, stato della partita).
-- Per ogni tabella: chi non e' autorizzato non legge e non scrive, chi e'
-- autorizzato legge e scrive. Un UPDATE o DELETE filtrato dalla RLS non da'
-- errore: l'effetto si verifica dopo RESET ROLE, come postgres, perche' da
-- authenticated la riga potrebbe essere solo nascosta.
-- Il file e' diviso in quattro sezioni: A (tabelle A), B (tabelle B),
-- crea_lega, trigger. Ogni sezione parte come postgres (RESET ROLE).
-- I dati sono fittizi e tutto avviene in una transazione annullata.
BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(62);

-- ---------------------------------------------------------------------------
-- Funzioni di appoggio del test (schema temporaneo, spariscono a fine sessione)
-- ---------------------------------------------------------------------------

-- Crea un utente Auth fittizio: il trigger della migration A crea l'Account.
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
        now(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        jsonb_build_object('nome', p_nome, 'cognome', 'Test', 'eta', '25'),
        now(), now(), '', '', '', ''
    );
$$;

-- Imposta le claim JWT: con un id simula un utente autenticato, con NULL una
-- chiamata senza utente (anon o service role). Il ruolo si cambia poi con
-- SET LOCAL ROLE, che non si puo' eseguire dentro una funzione SQL.
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

GRANT EXECUTE ON FUNCTION pg_temp.imposta_jwt(uuid, text) TO PUBLIC;

-- ###########################################################################
-- ###########################################################################
-- ##                                                                       ##
-- ##  SEZIONE A - Tabelle A                                                ##
-- ##  account, giocatore, gestore_campo, dispositivo_registrato, lega,     ##
-- ##  membro_lega, amministratore_lega                                     ##
-- ##                                                                       ##
-- ###########################################################################
-- ###########################################################################
RESET ROLE;

-- ---------------------------------------------------------------------------
-- Dati fittizi delle tabelle A (come postgres)
-- ---------------------------------------------------------------------------
-- G1 organizzatore e amministratore, G2 membro e partecipante, G3 esterno,
-- GC1 e GC2 Gestori, N1 e N2 account con onboarding in corso.
SELECT pg_temp.crea_utente('20400000-0000-4000-8000-000000000001', 'g1.rls@example.test', 'Gino');
SELECT pg_temp.crea_utente('20400000-0000-4000-8000-000000000002', 'g2.rls@example.test', 'Gaia');
SELECT pg_temp.crea_utente('20400000-0000-4000-8000-000000000003', 'g3.rls@example.test', 'Guido');
SELECT pg_temp.crea_utente('20400000-0000-4000-8000-000000000004', 'gc1.rls@example.test', 'Carla');
SELECT pg_temp.crea_utente('20400000-0000-4000-8000-000000000005', 'gc2.rls@example.test', 'Carlo');
SELECT pg_temp.crea_utente('20400000-0000-4000-8000-000000000006', 'n1.rls@example.test', 'Nina');
SELECT pg_temp.crea_utente('20400000-0000-4000-8000-000000000007', 'n2.rls@example.test', 'Nico');

UPDATE public.account
SET ruolo_account = 'Giocatore', stato_onboarding = 'completato'
WHERE id IN (
    '20400000-0000-4000-8000-000000000001',
    '20400000-0000-4000-8000-000000000002',
    '20400000-0000-4000-8000-000000000003'
);
UPDATE public.account
SET ruolo_account = 'GestoreCampo', stato_onboarding = 'completato'
WHERE id IN (
    '20400000-0000-4000-8000-000000000004',
    '20400000-0000-4000-8000-000000000005'
);
UPDATE public.account
SET ruolo_account = 'GestoreCampo'
WHERE id = '20400000-0000-4000-8000-000000000007';

INSERT INTO public.giocatore (account_id, ruolo_preferito_in_campo, piede_dominante)
VALUES
    ('20400000-0000-4000-8000-000000000001', 'Centrocampista', 'Destro'),
    ('20400000-0000-4000-8000-000000000002', 'Difensore', 'Sinistro'),
    ('20400000-0000-4000-8000-000000000003', 'Attaccante', 'Destro');

INSERT INTO public.gestore_campo (account_id, id_account_pagamenti)
VALUES
    ('20400000-0000-4000-8000-000000000004', NULL),
    ('20400000-0000-4000-8000-000000000005', NULL);

INSERT INTO public.dispositivo_registrato (id, account_id, identificativo, primo_accesso, ultimo_accesso)
VALUES (
    '20400000-0000-4000-8000-000000000101',
    '20400000-0000-4000-8000-000000000001',
    'dispositivo-fittizio-g1',
    '2026-11-01T10:00:00+00:00',
    '2026-11-01T10:00:00+00:00'
);

-- L1 privata e L2 pubblica di G1, L3 privata di G3 (G1 non ne e' membro).
CREATE TEMP TABLE leghe_test AS
SELECT 'L1'::text AS sigla, id FROM public.crea_lega(
    'Lega RLS AB privata', '5v5', 'privata', 'RLSAB-INVITO', '2026-12-31T20:00:00+00:00',
    '20400000-0000-4000-8000-000000000001'
)
UNION ALL
SELECT 'L2', id FROM public.crea_lega(
    'Lega RLS AB pubblica', '5v5', 'pubblica', NULL, NULL,
    '20400000-0000-4000-8000-000000000001'
)
UNION ALL
SELECT 'L3', id FROM public.crea_lega(
    'Lega RLS AB di Guido', '5v5', 'privata', NULL, NULL,
    '20400000-0000-4000-8000-000000000003'
);
GRANT SELECT ON leghe_test TO PUBLIC;

INSERT INTO public.membro_lega (lega_id, giocatore_id)
SELECT id, '20400000-0000-4000-8000-000000000002' FROM leghe_test WHERE sigla = 'L1';

-- ===========================================================================
-- account
-- ===========================================================================
SELECT pg_temp.imposta_jwt('20400000-0000-4000-8000-000000000001', 'authenticated');
SET LOCAL ROLE authenticated;

SELECT is(
    (SELECT count(*)::integer FROM public.account WHERE id = '20400000-0000-4000-8000-000000000001'),
    1,
    'account: l''utente legge il proprio Account'
);
SELECT is(
    (SELECT count(*)::integer FROM public.account WHERE id = '20400000-0000-4000-8000-000000000002'),
    0,
    'account: l''utente non legge l''Account di un altro'
);
SELECT lives_ok(
    $$UPDATE public.account SET nome = 'Gino Modificato' WHERE id = '20400000-0000-4000-8000-000000000001'$$,
    'account: l''utente aggiorna il proprio nome'
);
SELECT lives_ok(
    $$UPDATE public.account SET nome = 'Intruso' WHERE id = '20400000-0000-4000-8000-000000000002'$$,
    'account: l''UPDATE dell''Account altrui non solleva errori ma e'' filtrato'
);
SELECT throws_ok(
    $$UPDATE public.account SET email = 'altra@example.test' WHERE id = '20400000-0000-4000-8000-000000000001'$$,
    '42501', NULL,
    'account: email non e'' modificabile dal client (GRANT per colonna)'
);
SELECT throws_ok(
    $$UPDATE public.account SET stato_account = 'in_cancellazione' WHERE id = '20400000-0000-4000-8000-000000000001'$$,
    '42501', NULL,
    'account: stato_account non e'' modificabile dal client (GRANT per colonna)'
);
SELECT throws_ok(
    $$INSERT INTO public.account (id, nome, cognome, email, eta)
      VALUES ('20400000-0000-4000-8000-000000000099', 'Nuovo', 'Test', 'nuovo.rls@example.test', 30)$$,
    '42501', NULL,
    'account: nessuna INSERT dal client (la riga la crea il trigger)'
);
SELECT lives_ok(
    $$DELETE FROM public.account WHERE id = '20400000-0000-4000-8000-000000000001'$$,
    'account: la DELETE dal client non solleva errori ma e'' filtrata'
);

RESET ROLE;
SELECT is(
    (SELECT nome FROM public.account WHERE id = '20400000-0000-4000-8000-000000000001'),
    'Gino Modificato',
    'account: il proprio nome risulta aggiornato'
);
SELECT is(
    (SELECT nome FROM public.account WHERE id = '20400000-0000-4000-8000-000000000002'),
    'Gaia',
    'account: il nome dell''Account altrui resta invariato'
);
SELECT is(
    (SELECT count(*)::integer FROM public.account WHERE id = '20400000-0000-4000-8000-000000000001'),
    1,
    'account: dopo la DELETE dal client l''Account esiste ancora'
);

-- N1 ha l'onboarding in corso: puo' scegliere il ruolo.
SELECT pg_temp.imposta_jwt('20400000-0000-4000-8000-000000000006', 'authenticated');
SET LOCAL ROLE authenticated;
SELECT lives_ok(
    $$UPDATE public.account SET ruolo_account = 'Giocatore' WHERE id = '20400000-0000-4000-8000-000000000006'$$,
    'account: D11, durante l''onboarding l''utente sceglie il ruolo'
);

-- ===========================================================================
-- giocatore
-- ===========================================================================
SELECT lives_ok(
    $$INSERT INTO public.giocatore (account_id) VALUES ('20400000-0000-4000-8000-000000000006')$$,
    'giocatore: chi ha ruolo Giocatore crea la propria riga'
);

SELECT pg_temp.imposta_jwt('20400000-0000-4000-8000-000000000007', 'authenticated');
SELECT throws_ok(
    $$INSERT INTO public.giocatore (account_id) VALUES ('20400000-0000-4000-8000-000000000007')$$,
    '42501', NULL,
    'giocatore: chi ha ruolo GestoreCampo non crea una riga Giocatore'
);

SELECT pg_temp.imposta_jwt('20400000-0000-4000-8000-000000000001', 'authenticated');
SELECT throws_ok(
    $$INSERT INTO public.giocatore (account_id) VALUES ('20400000-0000-4000-8000-000000000005')$$,
    '42501', NULL,
    'giocatore: non si crea la riga Giocatore di un altro Account'
);
SELECT is(
    (SELECT count(*)::integer FROM public.giocatore WHERE account_id = '20400000-0000-4000-8000-000000000001'),
    1,
    'giocatore: il Giocatore legge la propria Player Card'
);
SELECT is(
    (SELECT count(*)::integer FROM public.giocatore WHERE account_id = '20400000-0000-4000-8000-000000000002'),
    0,
    'giocatore: il Giocatore non legge la Player Card altrui'
);
SELECT lives_ok(
    $$UPDATE public.giocatore SET piede_dominante = 'Sinistro' WHERE account_id = '20400000-0000-4000-8000-000000000001'$$,
    'giocatore: il Giocatore aggiorna la propria Player Card'
);
SELECT lives_ok(
    $$UPDATE public.giocatore SET piede_dominante = 'Destro' WHERE account_id = '20400000-0000-4000-8000-000000000002'$$,
    'giocatore: l''UPDATE della Player Card altrui non solleva errori ma e'' filtrato'
);
SELECT throws_ok(
    $$UPDATE public.giocatore SET account_id = '20400000-0000-4000-8000-000000000003' WHERE account_id = '20400000-0000-4000-8000-000000000001'$$,
    '42501', NULL,
    'giocatore: account_id non e'' modificabile (GRANT per colonna)'
);

RESET ROLE;
SELECT is(
    (SELECT piede_dominante FROM public.giocatore WHERE account_id = '20400000-0000-4000-8000-000000000001'),
    'Sinistro',
    'giocatore: la propria Player Card risulta aggiornata'
);
SELECT is(
    (SELECT piede_dominante FROM public.giocatore WHERE account_id = '20400000-0000-4000-8000-000000000002'),
    'Sinistro',
    'giocatore: la Player Card altrui resta invariata'
);

-- ===========================================================================
-- gestore_campo
-- ===========================================================================
SELECT pg_temp.imposta_jwt('20400000-0000-4000-8000-000000000007', 'authenticated');
SET LOCAL ROLE authenticated;
SELECT throws_ok(
    $$INSERT INTO public.gestore_campo (account_id, id_account_pagamenti)
      VALUES ('20400000-0000-4000-8000-000000000007', 'acct_fittizio_rls')$$,
    '42501', NULL,
    'gestore_campo: il client non scrive l''identificativo del fornitore (D3)'
);
SELECT lives_ok(
    $$INSERT INTO public.gestore_campo (account_id) VALUES ('20400000-0000-4000-8000-000000000007')$$,
    'gestore_campo: chi ha ruolo GestoreCampo crea la propria riga senza identificativo'
);

SELECT pg_temp.imposta_jwt('20400000-0000-4000-8000-000000000004', 'authenticated');
SELECT is(
    (SELECT count(*)::integer FROM public.gestore_campo WHERE account_id = '20400000-0000-4000-8000-000000000004'),
    1,
    'gestore_campo: il Gestore legge la propria riga'
);
SELECT throws_ok(
    $$UPDATE public.gestore_campo SET id_account_pagamenti = 'acct_fittizio_rls' WHERE account_id = '20400000-0000-4000-8000-000000000004'$$,
    '42501', NULL,
    'gestore_campo: nessun UPDATE dal client'
);

SELECT pg_temp.imposta_jwt('20400000-0000-4000-8000-000000000001', 'authenticated');
SELECT is(
    (SELECT count(*)::integer FROM public.gestore_campo WHERE account_id = '20400000-0000-4000-8000-000000000004'),
    0,
    'gestore_campo: un altro utente non legge la riga del Gestore'
);

-- L'identificativo lo scrive l'Edge Function dei pagamenti con la service role.
RESET ROLE;
SELECT pg_temp.imposta_jwt(NULL, 'service_role');
SET LOCAL ROLE service_role;
SELECT lives_ok(
    $$UPDATE public.gestore_campo SET id_account_pagamenti = 'acct_fittizio_rls' WHERE account_id = '20400000-0000-4000-8000-000000000004'$$,
    'gestore_campo: la service role scrive l''identificativo del fornitore'
);

-- ===========================================================================
-- dispositivo_registrato
-- ===========================================================================
SELECT lives_ok(
    $$INSERT INTO public.dispositivo_registrato (account_id, identificativo, primo_accesso, ultimo_accesso)
      VALUES ('20400000-0000-4000-8000-000000000001', 'dispositivo-fittizio-server', now(), now())$$,
    'dispositivo_registrato: la service role (Edge Function al login) registra un dispositivo'
);

RESET ROLE;
SELECT pg_temp.imposta_jwt('20400000-0000-4000-8000-000000000001', 'authenticated');
SET LOCAL ROLE authenticated;
SELECT is(
    (SELECT count(*)::integer FROM public.dispositivo_registrato WHERE id = '20400000-0000-4000-8000-000000000101'),
    1,
    'dispositivo_registrato: l''utente legge i propri dispositivi'
);
SELECT throws_ok(
    $$INSERT INTO public.dispositivo_registrato (account_id, identificativo, primo_accesso, ultimo_accesso)
      VALUES ('20400000-0000-4000-8000-000000000001', 'dispositivo-fittizio-client', now(), now())$$,
    '42501', NULL,
    'dispositivo_registrato: il client non registra dispositivi'
);
SELECT throws_ok(
    $$UPDATE public.dispositivo_registrato SET ultimo_accesso = now() WHERE id = '20400000-0000-4000-8000-000000000101'$$,
    '42501', NULL,
    'dispositivo_registrato: il client non aggiorna i dispositivi'
);

SELECT pg_temp.imposta_jwt('20400000-0000-4000-8000-000000000002', 'authenticated');
SELECT is(
    (SELECT count(*)::integer FROM public.dispositivo_registrato WHERE id = '20400000-0000-4000-8000-000000000101'),
    0,
    'dispositivo_registrato: un altro utente non legge i dispositivi altrui'
);

-- ===========================================================================
-- lega
-- ===========================================================================
-- G2, membro di L1
SELECT is(
    (SELECT count(*)::integer FROM public.lega WHERE id = (SELECT id FROM leghe_test WHERE sigla = 'L1')),
    1,
    'lega: un membro legge la lega privata'
);
SELECT lives_ok(
    $$UPDATE public.lega SET nome = 'Lega RLS AB intrusa' WHERE id = (SELECT id FROM leghe_test WHERE sigla = 'L1')$$,
    'lega: l''UPDATE di un membro non amministratore non solleva errori ma e'' filtrato'
);

SELECT pg_temp.imposta_jwt('20400000-0000-4000-8000-000000000003', 'authenticated');
SELECT is(
    (SELECT count(*)::integer FROM public.lega WHERE id = (SELECT id FROM leghe_test WHERE sigla = 'L1')),
    0,
    'lega: un non membro non legge la lega privata'
);
SELECT is(
    (SELECT count(*)::integer FROM public.lega WHERE id = (SELECT id FROM leghe_test WHERE sigla = 'L2')),
    1,
    'lega: un non membro legge la lega pubblica'
);
SELECT throws_ok(
    $$INSERT INTO public.lega (nome, tipologia_match, privacy) VALUES ('Lega RLS AB diretta', '5v5', 'pubblica')$$,
    '42501', NULL,
    'lega: nessuna INSERT diretta (si crea con crea_lega)'
);

SELECT pg_temp.imposta_jwt('20400000-0000-4000-8000-000000000001', 'authenticated');
SELECT lives_ok(
    $$UPDATE public.lega SET nome = 'Lega RLS AB rinominata' WHERE id = (SELECT id FROM leghe_test WHERE sigla = 'L1')$$,
    'lega: l''amministratore modifica la lega'
);
SELECT lives_ok(
    $$DELETE FROM public.lega WHERE id = (SELECT id FROM leghe_test WHERE sigla = 'L2')$$,
    'lega: la DELETE dal client non solleva errori ma e'' filtrata'
);

RESET ROLE;
SELECT is(
    (SELECT nome FROM public.lega WHERE id = (SELECT id FROM leghe_test WHERE sigla = 'L1')),
    'Lega RLS AB rinominata',
    'lega: la modifica dell''amministratore e'' salvata e quella del membro no'
);
SELECT is(
    (SELECT count(*)::integer FROM public.lega WHERE id = (SELECT id FROM leghe_test WHERE sigla = 'L2')),
    1,
    'lega: dopo la DELETE dal client la lega esiste ancora'
);

-- ===========================================================================
-- membro_lega
-- ===========================================================================
SELECT pg_temp.imposta_jwt('20400000-0000-4000-8000-000000000002', 'authenticated');
SET LOCAL ROLE authenticated;
SELECT is(
    (SELECT count(*)::integer FROM public.membro_lega WHERE lega_id = (SELECT id FROM leghe_test WHERE sigla = 'L1')),
    2,
    'membro_lega: un membro legge i membri della propria lega'
);
SELECT lives_ok(
    $$DELETE FROM public.membro_lega
      WHERE lega_id = (SELECT id FROM leghe_test WHERE sigla = 'L1')
        AND giocatore_id = '20400000-0000-4000-8000-000000000001'$$,
    'membro_lega: la rimozione di un altro membro da parte di un non amministratore e'' filtrata'
);

SELECT pg_temp.imposta_jwt('20400000-0000-4000-8000-000000000003', 'authenticated');
SELECT is(
    (SELECT count(*)::integer FROM public.membro_lega WHERE lega_id = (SELECT id FROM leghe_test WHERE sigla = 'L1')),
    0,
    'membro_lega: un non membro non legge i membri della lega'
);
SELECT throws_ok(
    $$INSERT INTO public.membro_lega (lega_id, giocatore_id)
      SELECT id, '20400000-0000-4000-8000-000000000003' FROM leghe_test WHERE sigla = 'L1'$$,
    '42501', NULL,
    'membro_lega: un Giocatore non entra da solo in una lega privata'
);
SELECT lives_ok(
    $$INSERT INTO public.membro_lega (lega_id, giocatore_id)
      SELECT id, '20400000-0000-4000-8000-000000000003' FROM leghe_test WHERE sigla = 'L2'$$,
    'membro_lega: un Giocatore entra da solo in una lega pubblica'
);
SELECT lives_ok(
    $$DELETE FROM public.membro_lega
      WHERE lega_id = (SELECT id FROM leghe_test WHERE sigla = 'L2')
        AND giocatore_id = '20400000-0000-4000-8000-000000000003'$$,
    'membro_lega: un membro esce dalla lega'
);

RESET ROLE;
SELECT is(
    (SELECT count(*)::integer FROM public.membro_lega
     WHERE lega_id = (SELECT id FROM leghe_test WHERE sigla = 'L2')
       AND giocatore_id = '20400000-0000-4000-8000-000000000003'),
    0,
    'membro_lega: dopo l''uscita il Giocatore non e'' piu'' membro'
);
SELECT is(
    (SELECT count(*)::integer FROM public.membro_lega
     WHERE lega_id = (SELECT id FROM leghe_test WHERE sigla = 'L1')
       AND giocatore_id = '20400000-0000-4000-8000-000000000001'),
    1,
    'membro_lega: il membro rimosso da un non amministratore resta nella lega'
);

-- G3 rientra in L2 e l'amministratore G1 lo rimuove.
SELECT pg_temp.imposta_jwt('20400000-0000-4000-8000-000000000003', 'authenticated');
SET LOCAL ROLE authenticated;
INSERT INTO public.membro_lega (lega_id, giocatore_id)
SELECT id, '20400000-0000-4000-8000-000000000003' FROM leghe_test WHERE sigla = 'L2';

SELECT pg_temp.imposta_jwt('20400000-0000-4000-8000-000000000001', 'authenticated');
SELECT throws_ok(
    $$INSERT INTO public.membro_lega (lega_id, giocatore_id)
      SELECT id, '20400000-0000-4000-8000-000000000003' FROM leghe_test WHERE sigla = 'L1'$$,
    '42501', NULL,
    'membro_lega: l''amministratore non aggiunge un altro Giocatore senza il suo consenso'
);
SELECT lives_ok(
    $$DELETE FROM public.membro_lega
      WHERE lega_id = (SELECT id FROM leghe_test WHERE sigla = 'L2')
        AND giocatore_id = '20400000-0000-4000-8000-000000000003'$$,
    'membro_lega: l''amministratore rimuove un membro'
);

RESET ROLE;
SELECT is(
    (SELECT count(*)::integer FROM public.membro_lega
     WHERE lega_id = (SELECT id FROM leghe_test WHERE sigla = 'L2')
       AND giocatore_id = '20400000-0000-4000-8000-000000000003'),
    0,
    'membro_lega: il membro rimosso dall''amministratore non e'' piu'' nella lega'
);

-- ===========================================================================
-- amministratore_lega
-- ===========================================================================
SELECT pg_temp.imposta_jwt('20400000-0000-4000-8000-000000000002', 'authenticated');
SET LOCAL ROLE authenticated;
SELECT is(
    (SELECT count(*)::integer FROM public.amministratore_lega WHERE lega_id = (SELECT id FROM leghe_test WHERE sigla = 'L1')),
    1,
    'amministratore_lega: un membro sa chi amministra la lega'
);
SELECT throws_ok(
    $$INSERT INTO public.amministratore_lega (lega_id, giocatore_id)
      SELECT id, '20400000-0000-4000-8000-000000000002' FROM leghe_test WHERE sigla = 'L1'$$,
    '42501', NULL,
    'amministratore_lega: un membro non si promuove da solo'
);

SELECT pg_temp.imposta_jwt('20400000-0000-4000-8000-000000000003', 'authenticated');
SELECT is(
    (SELECT count(*)::integer FROM public.amministratore_lega WHERE lega_id = (SELECT id FROM leghe_test WHERE sigla = 'L1')),
    0,
    'amministratore_lega: un non membro non legge gli amministratori'
);
SELECT lives_ok(
    $$DELETE FROM public.amministratore_lega WHERE lega_id = (SELECT id FROM leghe_test WHERE sigla = 'L1')$$,
    'amministratore_lega: la DELETE di un non amministratore e'' filtrata'
);

SELECT pg_temp.imposta_jwt('20400000-0000-4000-8000-000000000001', 'authenticated');
SELECT lives_ok(
    $$INSERT INTO public.amministratore_lega (lega_id, giocatore_id)
      SELECT id, '20400000-0000-4000-8000-000000000002' FROM leghe_test WHERE sigla = 'L1'$$,
    'amministratore_lega: l''amministratore promuove un membro'
);

RESET ROLE;
SELECT is(
    (SELECT count(*)::integer FROM public.amministratore_lega WHERE lega_id = (SELECT id FROM leghe_test WHERE sigla = 'L1')),
    2,
    'amministratore_lega: dopo la promozione gli amministratori sono due e la DELETE filtrata non ha tolto nulla'
);

SELECT pg_temp.imposta_jwt('20400000-0000-4000-8000-000000000001', 'authenticated');
SET LOCAL ROLE authenticated;
SELECT lives_ok(
    $$DELETE FROM public.amministratore_lega
      WHERE lega_id = (SELECT id FROM leghe_test WHERE sigla = 'L1')
        AND giocatore_id = '20400000-0000-4000-8000-000000000002'$$,
    'amministratore_lega: l''amministratore toglie il ruolo a un altro amministratore'
);

RESET ROLE;
SELECT is(
    (SELECT count(*)::integer FROM public.amministratore_lega WHERE lega_id = (SELECT id FROM leghe_test WHERE sigla = 'L1')),
    1,
    'amministratore_lega: il ruolo tolto non c''e'' piu'''
);

-- ===========================================================================
-- anon: nessuna tabella A e' leggibile senza autenticazione
-- ===========================================================================
SELECT pg_temp.imposta_jwt(NULL, 'anon');
SET LOCAL ROLE anon;
SELECT is(
    ARRAY[
        (SELECT count(*)::integer FROM public.account),
        (SELECT count(*)::integer FROM public.giocatore),
        (SELECT count(*)::integer FROM public.gestore_campo),
        (SELECT count(*)::integer FROM public.dispositivo_registrato),
        (SELECT count(*)::integer FROM public.lega),
        (SELECT count(*)::integer FROM public.membro_lega),
        (SELECT count(*)::integer FROM public.amministratore_lega)
    ],
    ARRAY[0, 0, 0, 0, 0, 0, 0],
    'anon: nessuna tabella dello schema A e'' leggibile senza autenticazione'
);

RESET ROLE;
SELECT * FROM finish();

ROLLBACK;

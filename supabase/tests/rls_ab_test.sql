-- Test pgTAP delle policy RLS degli schemi A e B (KCK-226), del controllo
-- sull'amministratore di crea_lega e dei trigger (D2, D11, stato della partita).
-- Per ogni tabella: chi non e' autorizzato non legge e non scrive, chi e'
-- autorizzato legge e scrive. Un UPDATE o DELETE filtrato dalla RLS non da'
-- errore: l'effetto si verifica dopo RESET ROLE, come postgres, perche' da
-- authenticated la riga potrebbe essere solo nascosta.
-- Il file e' diviso in quattro sezioni: A (tabelle A), B (tabelle B),
-- crea_lega, trigger. Ogni sezione parte come postgres (RESET ROLE).
-- I dati sono fittizi e tutto avviene in una transazione annullata.
BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(145);

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

-- ###########################################################################
-- ###########################################################################
-- ##                                                                       ##
-- ##  SEZIONE B - Tabelle B                                                ##
-- ##  campo, partita, prenotazione, partecipazione                         ##
-- ##                                                                       ##
-- ###########################################################################
-- ###########################################################################
RESET ROLE;

-- ---------------------------------------------------------------------------
-- Dati fittizi delle tabelle B (come postgres)
-- ---------------------------------------------------------------------------
INSERT INTO public.campo (id, gestore_campo_id, nome, ubicazione, tariffa_oraria, orari_disponibilita)
VALUES (
    '20400000-0000-4000-8000-000000000201',
    '20400000-0000-4000-8000-000000000004',
    'Campo RLS 1', 'Via Fittizia 1, Salerno', 60.00, 'lun-dom 09:00-23:00'
);

-- P1 di lega L1 Conclusa, P2 pubblica Aperta tra 17 giorni, P3 privata senza
-- lega tra 10 giorni, P4 di lega L1 Aperta senza prenotazione, P5 privata tra
-- 12 ore. Organizzatore sempre G1. P2, P3 e P5 sono relative a now() perche' il
-- limite di 24 ore per l'annullamento (D5) dipende dall'ora in cui gira il test.
INSERT INTO public.partita (id, giocatore_id, lega_id, data_ora, tipologia, privacy, num_partecipanti_richiesti, stato)
SELECT '20400000-0000-4000-8000-000000000301'::uuid, '20400000-0000-4000-8000-000000000001'::uuid,
       id, '2026-11-20T18:00:00+00:00'::timestamptz, '5v5', 'privata', 10, 'Conclusa'
FROM leghe_test WHERE sigla = 'L1'
UNION ALL
SELECT '20400000-0000-4000-8000-000000000302', '20400000-0000-4000-8000-000000000001',
       NULL, now() + interval '17 days', '5v5', 'pubblica', 10, 'Aperta'
UNION ALL
SELECT '20400000-0000-4000-8000-000000000303', '20400000-0000-4000-8000-000000000001',
       NULL, now() + interval '10 days', '5v5', 'privata', 10, 'Aperta'
UNION ALL
SELECT '20400000-0000-4000-8000-000000000304', '20400000-0000-4000-8000-000000000001',
       id, '2026-12-12T18:00:00+00:00', '5v5', 'privata', 10, 'Aperta'
FROM leghe_test WHERE sigla = 'L1'
UNION ALL
SELECT '20400000-0000-4000-8000-000000000305', '20400000-0000-4000-8000-000000000001',
       NULL, now() + interval '12 hours', '5v5', 'privata', 10, 'Aperta';

INSERT INTO public.prenotazione (
    id, partita_id, campo_id, intervallo, stato_blocco, scadenza_blocco,
    costo_concordato, quota_individuale, commissione, netto_gestore
)
VALUES
    ('20400000-0000-4000-8000-000000000401', '20400000-0000-4000-8000-000000000301',
     '20400000-0000-4000-8000-000000000201', '2026-11-20T18:00/2026-11-20T19:00',
     'confermato', NULL, 60.00, 6.00, 3.00, 57.00),
    ('20400000-0000-4000-8000-000000000402', '20400000-0000-4000-8000-000000000302',
     '20400000-0000-4000-8000-000000000201', '2026-12-10T18:00/2026-12-10T19:00',
     'bloccato', '2026-12-09T18:00:00+00:00', 60.00, 6.00, 3.00, 57.00),
    -- PR4 su P3: G1 la organizza senza parteciparvi, per provare da solo il ramo
    -- "organizzatore" della lettura.
    ('20400000-0000-4000-8000-000000000404', '20400000-0000-4000-8000-000000000303',
     '20400000-0000-4000-8000-000000000201', '2026-12-13T18:00/2026-12-13T19:00',
     'bloccato', '2026-12-12T18:00:00+00:00', 60.00, 6.00, 3.00, 57.00);

INSERT INTO public.partecipazione (id, giocatore_id, partita_id, risposta_stato, data_risposta)
VALUES
    ('20400000-0000-4000-8000-000000000501', '20400000-0000-4000-8000-000000000001',
     '20400000-0000-4000-8000-000000000301', 'confermata', '2026-11-15T10:00:00+00:00'),
    ('20400000-0000-4000-8000-000000000502', '20400000-0000-4000-8000-000000000002',
     '20400000-0000-4000-8000-000000000301', 'confermata', '2026-11-15T11:00:00+00:00'),
    ('20400000-0000-4000-8000-000000000503', '20400000-0000-4000-8000-000000000001',
     '20400000-0000-4000-8000-000000000302', 'confermata', '2026-11-16T10:00:00+00:00'),
    ('20400000-0000-4000-8000-000000000504', '20400000-0000-4000-8000-000000000001',
     '20400000-0000-4000-8000-000000000304', 'confermata', '2026-11-16T11:00:00+00:00'),
    -- 505: G2 su P3, partita privata senza lega che G1 organizza senza parteciparvi.
    ('20400000-0000-4000-8000-000000000505', '20400000-0000-4000-8000-000000000002',
     '20400000-0000-4000-8000-000000000303', 'confermata', '2026-11-17T10:00:00+00:00');

-- ===========================================================================
-- campo
-- ===========================================================================
SELECT pg_temp.imposta_jwt('20400000-0000-4000-8000-000000000003', 'authenticated');
SET LOCAL ROLE authenticated;
SELECT is(
    (SELECT count(*)::integer FROM public.campo WHERE id = '20400000-0000-4000-8000-000000000201'),
    1,
    'campo: un Giocatore autenticato legge i campi'
);

SELECT pg_temp.imposta_jwt('20400000-0000-4000-8000-000000000004', 'authenticated');
SELECT lives_ok(
    $$INSERT INTO public.campo (gestore_campo_id, nome, ubicazione, tariffa_oraria, orari_disponibilita)
      VALUES ('20400000-0000-4000-8000-000000000004', 'Campo RLS 2', 'Via Fittizia 2, Salerno', 50.00, 'lun-ven 18:00-23:00')$$,
    'campo: il Gestore inserisce un proprio campo'
);
SELECT lives_ok(
    $$UPDATE public.campo SET tariffa_oraria = 70.00 WHERE id = '20400000-0000-4000-8000-000000000201'$$,
    'campo: il Gestore modifica il proprio campo'
);
SELECT lives_ok(
    $$DELETE FROM public.campo WHERE id = '20400000-0000-4000-8000-000000000201'$$,
    'campo: la DELETE dal client non solleva errori ma e'' filtrata'
);

SELECT pg_temp.imposta_jwt('20400000-0000-4000-8000-000000000005', 'authenticated');
SELECT throws_ok(
    $$INSERT INTO public.campo (gestore_campo_id, nome, ubicazione, tariffa_oraria, orari_disponibilita)
      VALUES ('20400000-0000-4000-8000-000000000004', 'Campo RLS falso', 'Via Fittizia 3, Salerno', 50.00, 'lun-ven 18:00-23:00')$$,
    '42501', NULL,
    'campo: un Gestore non inserisce campi a nome di un altro'
);
SELECT lives_ok(
    $$UPDATE public.campo SET tariffa_oraria = 1.00 WHERE id = '20400000-0000-4000-8000-000000000201'$$,
    'campo: l''UPDATE del campo altrui non solleva errori ma e'' filtrato'
);

RESET ROLE;
SELECT is(
    (SELECT tariffa_oraria FROM public.campo WHERE id = '20400000-0000-4000-8000-000000000201'),
    70.00::numeric,
    'campo: vale la modifica del proprietario, non quella dell''altro Gestore, e il campo non e'' cancellato'
);

SELECT pg_temp.imposta_jwt(NULL, 'anon');
SET LOCAL ROLE anon;
SELECT is(
    (SELECT count(*)::integer FROM public.campo WHERE id = '20400000-0000-4000-8000-000000000201'),
    0,
    'campo: un utente non autenticato non legge i campi'
);

-- ===========================================================================
-- partita
-- ===========================================================================
RESET ROLE;
SELECT pg_temp.imposta_jwt('20400000-0000-4000-8000-000000000002', 'authenticated');
SET LOCAL ROLE authenticated;
SELECT is(
    (SELECT count(*)::integer FROM public.partita WHERE id = '20400000-0000-4000-8000-000000000304'),
    1,
    'partita: un membro della lega legge una partita di lega a cui non partecipa'
);
SELECT lives_ok(
    $$UPDATE public.partita SET stato = 'Annullata' WHERE id = '20400000-0000-4000-8000-000000000301'$$,
    'partita: l''UPDATE di chi non organizza non solleva errori ma e'' filtrato'
);

SELECT pg_temp.imposta_jwt('20400000-0000-4000-8000-000000000003', 'authenticated');
SELECT is(
    (SELECT count(*)::integer FROM public.partita WHERE id IN (
        '20400000-0000-4000-8000-000000000301',
        '20400000-0000-4000-8000-000000000303',
        '20400000-0000-4000-8000-000000000304'
    )),
    0,
    'partita: un esterno non legge partite private o di leghe altrui'
);
SELECT is(
    (SELECT count(*)::integer FROM public.partita WHERE id = '20400000-0000-4000-8000-000000000302'),
    1,
    'partita: un esterno legge la partita pubblica (bacheca)'
);
SELECT throws_ok(
    $$INSERT INTO public.partita (giocatore_id, lega_id, data_ora, tipologia, privacy, num_partecipanti_richiesti)
      SELECT '20400000-0000-4000-8000-000000000003', id, '2026-12-20T18:00:00+00:00', '5v5', 'privata', 10
      FROM leghe_test WHERE sigla = 'L1'$$,
    '42501', NULL,
    'partita: un non membro non crea partite nella lega'
);
SELECT throws_ok(
    $$INSERT INTO public.partita (giocatore_id, data_ora, tipologia, privacy, num_partecipanti_richiesti)
      VALUES ('20400000-0000-4000-8000-000000000001', '2026-12-20T18:00:00+00:00', '5v5', 'pubblica', 10)$$,
    '42501', NULL,
    'partita: non si crea una partita a nome di un altro organizzatore'
);

SELECT pg_temp.imposta_jwt('20400000-0000-4000-8000-000000000001', 'authenticated');
SELECT lives_ok(
    $$INSERT INTO public.partita (giocatore_id, lega_id, data_ora, tipologia, privacy, num_partecipanti_richiesti)
      SELECT '20400000-0000-4000-8000-000000000001', id, '2026-12-20T18:00:00+00:00', '5v5', 'privata', 10
      FROM leghe_test WHERE sigla = 'L1'$$,
    'partita: un membro crea una partita nella propria lega'
);
SELECT throws_ok(
    $$INSERT INTO public.partita (giocatore_id, data_ora, tipologia, privacy, num_partecipanti_richiesti, stato)
      VALUES ('20400000-0000-4000-8000-000000000001', '2026-12-21T18:00:00+00:00', '5v5', 'privata', 10, 'Confermata')$$,
    '42501', NULL,
    'partita: il client non crea una partita gia'' Confermata (statechart)'
);
SELECT lives_ok(
    $$UPDATE public.partita SET stato = 'Annullata' WHERE id = '20400000-0000-4000-8000-000000000303'$$,
    'partita: l''organizzatore annulla la partita'
);
SELECT throws_ok(
    $$UPDATE public.partita SET giocatore_id = '20400000-0000-4000-8000-000000000002' WHERE id = '20400000-0000-4000-8000-000000000303'$$,
    '42501', NULL,
    'partita: l''organizzatore non cede la partita a un altro'
);
SELECT throws_ok(
    $$UPDATE public.partita SET lega_id = (SELECT id FROM leghe_test WHERE sigla = 'L3') WHERE id = '20400000-0000-4000-8000-000000000303'$$,
    '42501', NULL,
    'partita: l''organizzatore non sposta la partita in una lega di cui non e'' membro'
);
SELECT lives_ok(
    $$DELETE FROM public.partita WHERE id = '20400000-0000-4000-8000-000000000302'$$,
    'partita: la DELETE dal client non solleva errori ma e'' filtrata'
);

RESET ROLE;
SELECT is(
    (SELECT stato FROM public.partita WHERE id = '20400000-0000-4000-8000-000000000303'),
    'Annullata',
    'partita: l''annullamento dell''organizzatore e'' salvato'
);
SELECT is(
    (SELECT stato FROM public.partita WHERE id = '20400000-0000-4000-8000-000000000301'),
    'Conclusa',
    'partita: la partita resta invariata dopo l''UPDATE di chi non organizza'
);
SELECT is(
    (SELECT count(*)::integer FROM public.partita WHERE id = '20400000-0000-4000-8000-000000000302'),
    1,
    'partita: dopo la DELETE dal client la partita esiste ancora'
);

-- ===========================================================================
-- prenotazione
-- ===========================================================================
SELECT pg_temp.imposta_jwt('20400000-0000-4000-8000-000000000004', 'authenticated');
SET LOCAL ROLE authenticated;
SELECT is(
    (SELECT count(*)::integer FROM public.prenotazione WHERE id = '20400000-0000-4000-8000-000000000401'),
    1,
    'prenotazione: il Gestore del campo legge la prenotazione'
);

SELECT pg_temp.imposta_jwt('20400000-0000-4000-8000-000000000002', 'authenticated');
SELECT is(
    (SELECT count(*)::integer FROM public.prenotazione WHERE id = '20400000-0000-4000-8000-000000000401'),
    1,
    'prenotazione: un partecipante legge la prenotazione della partita'
);

SELECT pg_temp.imposta_jwt('20400000-0000-4000-8000-000000000003', 'authenticated');
SELECT is(
    (SELECT count(*)::integer FROM public.prenotazione WHERE id = '20400000-0000-4000-8000-000000000401'),
    0,
    'prenotazione: un esterno non legge la prenotazione'
);
SELECT throws_ok(
    $$INSERT INTO public.prenotazione (partita_id, campo_id, intervallo, stato_blocco, scadenza_blocco,
                                       costo_concordato, quota_individuale, commissione, netto_gestore)
      VALUES ('20400000-0000-4000-8000-000000000304', '20400000-0000-4000-8000-000000000201',
              '2026-12-12T18:00/2026-12-12T19:00', 'bloccato', '2026-12-11T18:00:00+00:00',
              60.00, 6.00, 3.00, 57.00)$$,
    '42501', NULL,
    'prenotazione: chi non organizza non prenota per la partita'
);

SELECT pg_temp.imposta_jwt('20400000-0000-4000-8000-000000000005', 'authenticated');
SELECT is(
    (SELECT count(*)::integer FROM public.prenotazione WHERE id = '20400000-0000-4000-8000-000000000401'),
    0,
    'prenotazione: il Gestore di un altro campo non legge la prenotazione'
);

SELECT pg_temp.imposta_jwt('20400000-0000-4000-8000-000000000001', 'authenticated');
SELECT is(
    (SELECT count(*)::integer FROM public.prenotazione WHERE id = '20400000-0000-4000-8000-000000000404'),
    1,
    'prenotazione: l''organizzatore che non partecipa legge la prenotazione della propria partita'
);
SELECT lives_ok(
    $$DELETE FROM public.prenotazione WHERE id = '20400000-0000-4000-8000-000000000401'$$,
    'prenotazione: la DELETE dal client non solleva errori ma e'' filtrata'
);
SELECT throws_ok(
    $$INSERT INTO public.prenotazione (partita_id, campo_id, intervallo, stato_blocco, scadenza_blocco,
                                       costo_concordato, quota_individuale, commissione, netto_gestore)
      VALUES ('20400000-0000-4000-8000-000000000304', '20400000-0000-4000-8000-000000000201',
              '2026-12-12T18:00/2026-12-12T19:00', 'confermato', NULL,
              60.00, 6.00, 3.00, 57.00)$$,
    '42501', NULL,
    'prenotazione: il client non crea una prenotazione gia'' confermata (D26)'
);
-- P1 e' Conclusa: la WITH CHECK della RLS si valuta prima dei vincoli di
-- unicita' (P1 ha gia' una prenotazione), quindi l'errore e' 42501 e non 23505.
SELECT throws_ok(
    $$INSERT INTO public.prenotazione (partita_id, campo_id, intervallo, stato_blocco, scadenza_blocco,
                                       costo_concordato, quota_individuale, commissione, netto_gestore)
      VALUES ('20400000-0000-4000-8000-000000000301', '20400000-0000-4000-8000-000000000201',
              '2026-12-14T18:00/2026-12-14T19:00', 'bloccato', '2026-12-13T18:00:00+00:00',
              60.00, 6.00, 3.00, 57.00)$$,
    '42501', NULL,
    'prenotazione: l''organizzatore non prenota per una partita non Aperta (UC_PAR_1 passo 5)'
);
SELECT lives_ok(
    $$INSERT INTO public.prenotazione (id, partita_id, campo_id, intervallo, stato_blocco, scadenza_blocco,
                                       costo_concordato, quota_individuale, commissione, netto_gestore)
      VALUES ('20400000-0000-4000-8000-000000000403', '20400000-0000-4000-8000-000000000304',
              '20400000-0000-4000-8000-000000000201', '2026-12-12T18:00/2026-12-12T19:00',
              'bloccato', '2026-12-11T18:00:00+00:00', 60.00, 6.00, 3.00, 57.00)$$,
    'prenotazione: l''organizzatore blocca lo slot'
);
SELECT throws_ok(
    $$UPDATE public.prenotazione SET stato_blocco = 'confermato' WHERE id = '20400000-0000-4000-8000-000000000403'$$,
    '42501', NULL,
    'prenotazione: il client non conferma lo slot (D26)'
);
SELECT throws_ok(
    $$UPDATE public.prenotazione SET costo_concordato = 1.00 WHERE id = '20400000-0000-4000-8000-000000000403'$$,
    '42501', NULL,
    'prenotazione: gli importi non sono modificabili dal client (GRANT per colonna)'
);
SELECT throws_ok(
    $$UPDATE public.prenotazione SET scadenza_blocco = now() + interval '30 days' WHERE id = '20400000-0000-4000-8000-000000000403'$$,
    '42501', NULL,
    'prenotazione: l''organizzatore non prolunga il blocco dello slot'
);
SELECT throws_ok(
    $$UPDATE public.prenotazione SET stato_blocco = 'liberato', scadenza_blocco = NULL
      WHERE id = '20400000-0000-4000-8000-000000000402'$$,
    '42501', NULL,
    'prenotazione: l''organizzatore non libera lo slot di una partita non Annullata (D6)'
);
-- D6: prima la partita passa ad Annullata, poi si libera lo slot.
SELECT lives_ok(
    $$UPDATE public.partita SET stato = 'Annullata' WHERE id = '20400000-0000-4000-8000-000000000302'$$,
    'prenotazione: l''organizzatore annulla la partita prima di liberare lo slot'
);
SELECT lives_ok(
    $$UPDATE public.prenotazione SET stato_blocco = 'liberato', scadenza_blocco = NULL
      WHERE id = '20400000-0000-4000-8000-000000000402'$$,
    'prenotazione: l''organizzatore libera lo slot della partita Annullata e azzera la scadenza (D6, D24)'
);

SELECT pg_temp.imposta_jwt('20400000-0000-4000-8000-000000000002', 'authenticated');
SELECT lives_ok(
    $$UPDATE public.prenotazione SET stato_blocco = 'liberato' WHERE id = '20400000-0000-4000-8000-000000000403'$$,
    'prenotazione: la liberazione da parte di chi non organizza non solleva errori ma e'' filtrata'
);

RESET ROLE;
SELECT is(
    (SELECT stato_blocco || '/' || coalesce(scadenza_blocco::text, 'nessuna') FROM public.prenotazione WHERE id = '20400000-0000-4000-8000-000000000402'),
    'liberato/nessuna',
    'prenotazione: lo slot liberato dall''organizzatore risulta liberato e senza scadenza'
);
SELECT is(
    (SELECT stato_blocco FROM public.prenotazione WHERE id = '20400000-0000-4000-8000-000000000403'),
    'bloccato',
    'prenotazione: lo slot resta bloccato dopo i tentativi non autorizzati'
);
SELECT is(
    (SELECT count(*)::integer FROM public.prenotazione WHERE id = '20400000-0000-4000-8000-000000000401'),
    1,
    'prenotazione: dopo la DELETE dal client la prenotazione esiste ancora'
);

-- ===========================================================================
-- partecipazione
-- ===========================================================================
SELECT pg_temp.imposta_jwt('20400000-0000-4000-8000-000000000002', 'authenticated');
SET LOCAL ROLE authenticated;
SELECT is(
    (SELECT count(*)::integer FROM public.partecipazione WHERE id = '20400000-0000-4000-8000-000000000501'),
    1,
    'partecipazione: un partecipante legge le partecipazioni della stessa partita'
);
SELECT is(
    (SELECT count(*)::integer FROM public.partecipazione WHERE id = '20400000-0000-4000-8000-000000000504'),
    1,
    'partecipazione: un membro della lega legge le partecipazioni di una partita di lega (RF_LEG_4)'
);
SELECT lives_ok(
    $$UPDATE public.partecipazione SET gol_partita = 5 WHERE id = '20400000-0000-4000-8000-000000000502'$$,
    'partecipazione: il partecipante che non organizza non aggiorna i propri gol (filtrato)'
);

SELECT pg_temp.imposta_jwt('20400000-0000-4000-8000-000000000003', 'authenticated');
SELECT is(
    (SELECT count(*)::integer FROM public.partecipazione WHERE partita_id = '20400000-0000-4000-8000-000000000301'),
    0,
    'partecipazione: un esterno non legge le partecipazioni di una partita privata'
);
SELECT is(
    (SELECT count(*)::integer FROM public.partecipazione WHERE partita_id = '20400000-0000-4000-8000-000000000302'),
    1,
    'partecipazione: un autenticato legge le partecipazioni di una partita pubblica (posti, KCK-203)'
);

SELECT pg_temp.imposta_jwt('20400000-0000-4000-8000-000000000001', 'authenticated');
SELECT is(
    (SELECT count(*)::integer FROM public.partecipazione WHERE id = '20400000-0000-4000-8000-000000000505'),
    1,
    'partecipazione: l''organizzatore che non partecipa legge le partecipazioni della propria partita privata'
);
SELECT lives_ok(
    $$UPDATE public.partecipazione SET gol_partita = 2, assist_partita = 1 WHERE id = '20400000-0000-4000-8000-000000000502'$$,
    'partecipazione: l''organizzatore inserisce gol e assist a partita Conclusa (D2)'
);
SELECT throws_ok(
    $$UPDATE public.partecipazione SET risposta_stato = 'ritirata' WHERE id = '20400000-0000-4000-8000-000000000504'$$,
    '42501', NULL,
    'partecipazione: risposta_stato non e'' modificabile dal client (GRANT per colonna)'
);
SELECT throws_ok(
    $$INSERT INTO public.partecipazione (giocatore_id, partita_id, risposta_stato, data_risposta)
      VALUES ('20400000-0000-4000-8000-000000000001', '20400000-0000-4000-8000-000000000303', 'confermata', now())$$,
    '42501', NULL,
    'partecipazione: nessuna INSERT dal client (RSVP lato server)'
);
SELECT throws_ok(
    $$DELETE FROM public.partecipazione WHERE id = '20400000-0000-4000-8000-000000000504'$$,
    '42501', NULL,
    'partecipazione: nessuna DELETE dal client'
);

RESET ROLE;
SELECT is(
    (SELECT gol_partita || '/' || assist_partita FROM public.partecipazione WHERE id = '20400000-0000-4000-8000-000000000502'),
    '2/1',
    'partecipazione: gol e assist dell''organizzatore salvati, quelli del partecipante no'
);

-- ===========================================================================
-- anon: nessuna tabella B e' leggibile senza autenticazione
-- ===========================================================================
SELECT pg_temp.imposta_jwt(NULL, 'anon');
SET LOCAL ROLE anon;
SELECT is(
    ARRAY[
        (SELECT count(*)::integer FROM public.campo),
        (SELECT count(*)::integer FROM public.partita),
        (SELECT count(*)::integer FROM public.prenotazione),
        (SELECT count(*)::integer FROM public.partecipazione)
    ],
    ARRAY[0, 0, 0, 0],
    'anon: nessuna tabella dello schema B e'' leggibile senza autenticazione'
);

-- ###########################################################################
-- ###########################################################################
-- ##                                                                       ##
-- ##  SEZIONE crea_lega - Amministratore iniziale (migration               ##
-- ##  20261123120100_crea_lega_admin.sql)                                  ##
-- ##                                                                       ##
-- ###########################################################################
-- ###########################################################################
RESET ROLE;

SELECT pg_temp.imposta_jwt('20400000-0000-4000-8000-000000000003', 'authenticated');
SET LOCAL ROLE authenticated;
SELECT throws_ok(
    $$SELECT public.crea_lega('Lega RLS AB altrui', '5v5', 'privata', NULL, NULL,
                              '20400000-0000-4000-8000-000000000001'::uuid)$$,
    '42501', NULL,
    'crea_lega: un utente non nomina amministratore un altro Giocatore'
);
SELECT lives_ok(
    $$SELECT public.crea_lega('Lega RLS AB propria', '5v5', 'privata', NULL, NULL,
                              '20400000-0000-4000-8000-000000000003'::uuid)$$,
    'crea_lega: un utente crea una lega di cui e'' amministratore'
);

RESET ROLE;
SELECT pg_temp.imposta_jwt(NULL, 'anon');
SET LOCAL ROLE anon;
SELECT throws_ok(
    $$SELECT public.crea_lega('Lega RLS AB anonima', '5v5', 'privata', NULL, NULL,
                              '20400000-0000-4000-8000-000000000001'::uuid)$$,
    '42501', NULL,
    'crea_lega: un utente non autenticato non puo'' eseguire la funzione'
);

-- ###########################################################################
-- ###########################################################################
-- ##                                                                       ##
-- ##  SEZIONE trigger - D11 (ruolo definitivo), D2 (gol e assist),         ##
-- ##  stato della partita                                                  ##
-- ##                                                                       ##
-- ###########################################################################
-- ###########################################################################
RESET ROLE;

-- ===========================================================================
-- account: ruolo definitivo (D11)
-- ===========================================================================
SELECT pg_temp.imposta_jwt('20400000-0000-4000-8000-000000000001', 'authenticated');
SET LOCAL ROLE authenticated;
SELECT throws_ok(
    $$UPDATE public.account SET ruolo_account = 'GestoreCampo' WHERE id = '20400000-0000-4000-8000-000000000001'$$,
    '42501', NULL,
    'account: D11, il ruolo non cambia dopo l''onboarding completato'
);
SELECT throws_ok(
    $$UPDATE public.account SET stato_onboarding = 'in_corso' WHERE id = '20400000-0000-4000-8000-000000000001'$$,
    '42501', NULL,
    'account: D11, un onboarding completato non torna in corso'
);

-- ===========================================================================
-- partecipazione: gol e assist (D2)
-- ===========================================================================
SELECT throws_ok(
    $$UPDATE public.partecipazione SET gol_partita = 1 WHERE id = '20400000-0000-4000-8000-000000000504'$$,
    '23514', NULL,
    'partecipazione: gol e assist solo a partita Conclusa (D2)'
);

-- L'Edge Function RSVP aggiorna risposta_stato con la service role.
RESET ROLE;
SELECT pg_temp.imposta_jwt(NULL, 'service_role');
SET LOCAL ROLE service_role;
SELECT lives_ok(
    $$UPDATE public.partecipazione SET risposta_stato = 'ritirata' WHERE id = '20400000-0000-4000-8000-000000000504'$$,
    'partecipazione: la service role aggiorna risposta_stato senza intervento del trigger'
);
SELECT throws_ok(
    $$UPDATE public.partecipazione SET gol_partita = 3 WHERE id = '20400000-0000-4000-8000-000000000501'$$,
    '42501', NULL,
    'partecipazione: gol e assist li inserisce solo l''organizzatore, non la service role (D2)'
);

-- ===========================================================================
-- partita: passaggi di stato (statechart, D1, D5, D6, D26)
-- ===========================================================================
RESET ROLE;
SELECT pg_temp.imposta_jwt('20400000-0000-4000-8000-000000000001', 'authenticated');
SET LOCAL ROLE authenticated;
SELECT throws_ok(
    $$UPDATE public.partita SET stato = 'Conclusa' WHERE id = '20400000-0000-4000-8000-000000000304'$$,
    '42501', NULL,
    'partita: il client non porta la partita a Conclusa (D1)'
);
SELECT throws_ok(
    $$UPDATE public.partita SET stato = 'Annullata' WHERE id = '20400000-0000-4000-8000-000000000305'$$,
    '42501', NULL,
    'partita: l''annullamento a meno di 24 ore e'' rifiutato (D5)'
);
-- Il RAD non prevede la modifica della partita: il GRANT per colonna ammette
-- solo stato (decisione dei PM su KCK-226).
SELECT throws_ok(
    $$UPDATE public.partita SET num_partecipanti_richiesti = 12
      WHERE id = '20400000-0000-4000-8000-000000000304'$$,
    '42501', NULL,
    'partita: l''organizzatore non modifica num_partecipanti_richiesti (GRANT per colonna)'
);
SELECT throws_ok(
    $$UPDATE public.partita SET data_ora = '2026-12-19T18:00:00+00:00'
      WHERE id = '20400000-0000-4000-8000-000000000304'$$,
    '42501', NULL,
    'partita: l''organizzatore non modifica data_ora (GRANT per colonna)'
);
-- Primo passo dell'aggiramento del limite di 24 ore: spostare in avanti la data
-- di una partita vicina (P5, tra 12 ore) per poi annullarla.
SELECT throws_ok(
    $$UPDATE public.partita SET data_ora = now() + interval '10 days'
      WHERE id = '20400000-0000-4000-8000-000000000305'$$,
    '42501', NULL,
    'partita: l''organizzatore non sposta la data per aggirare il limite di 24 ore (D5)'
);
SELECT lives_ok(
    $$UPDATE public.partita SET stato = 'Aperta' WHERE id = '20400000-0000-4000-8000-000000000304'$$,
    'partita: l''UPDATE dell''organizzatore che riscrive lo stesso stato e'' accettato'
);

RESET ROLE;
SELECT is(
    (SELECT stato || '/' || num_partecipanti_richiesti FROM public.partita WHERE id = '20400000-0000-4000-8000-000000000304'),
    'Aperta/10',
    'partita: i passaggi e le modifiche rifiutati non hanno cambiato la partita'
);
SELECT cmp_ok(
    (SELECT data_ora FROM public.partita WHERE id = '20400000-0000-4000-8000-000000000305'),
    '<', now() + interval '1 day',
    'partita: la data della partita vicina non e'' stata spostata'
);

-- Il trigger rifiuta anche chi non organizza. Dal client la RLS filtra gia'
-- la riga (sezione B): qui si esegue come postgres, che scavalca la RLS, con
-- il JWT di G2, per verificare la condizione del trigger da sola.
SELECT pg_temp.imposta_jwt('20400000-0000-4000-8000-000000000002', 'authenticated');
SELECT throws_ok(
    $$UPDATE public.partita SET stato = 'Annullata' WHERE id = '20400000-0000-4000-8000-000000000304'$$,
    '42501', NULL,
    'partita: il trigger rifiuta l''annullamento da parte di chi non organizza'
);

-- I passaggi automatici li fa il server con la service role.
SELECT pg_temp.imposta_jwt(NULL, 'service_role');
SET LOCAL ROLE service_role;
SELECT lives_ok(
    $$UPDATE public.partita SET stato = 'Completa' WHERE id = '20400000-0000-4000-8000-000000000305'$$,
    'partita: la service role cambia lo stato senza limiti'
);
RESET ROLE;
SELECT is(
    (SELECT stato FROM public.partita WHERE id = '20400000-0000-4000-8000-000000000305'),
    'Completa',
    'partita: il cambio di stato della service role e'' salvato'
);

-- Annullamento da Completa e da Confermata: P6 e P7, private senza lega,
-- organizzate da G1 a piu' di 24 ore (D5).
INSERT INTO public.partita (id, giocatore_id, data_ora, tipologia, privacy, num_partecipanti_richiesti, stato)
VALUES
    ('20400000-0000-4000-8000-000000000306', '20400000-0000-4000-8000-000000000001',
     now() + interval '5 days', '5v5', 'privata', 10, 'Completa'),
    ('20400000-0000-4000-8000-000000000307', '20400000-0000-4000-8000-000000000001',
     now() + interval '6 days', '5v5', 'privata', 10, 'Confermata');

SELECT pg_temp.imposta_jwt('20400000-0000-4000-8000-000000000001', 'authenticated');
SET LOCAL ROLE authenticated;
SELECT lives_ok(
    $$UPDATE public.partita SET stato = 'Annullata' WHERE id = '20400000-0000-4000-8000-000000000306'$$,
    'partita: l''organizzatore annulla una partita Completa a piu'' di 24 ore'
);
SELECT lives_ok(
    $$UPDATE public.partita SET stato = 'Annullata' WHERE id = '20400000-0000-4000-8000-000000000307'$$,
    'partita: l''organizzatore annulla una partita Confermata a piu'' di 24 ore'
);

RESET ROLE;
SELECT is(
    (SELECT array_agg(stato ORDER BY id) FROM public.partita
     WHERE id IN ('20400000-0000-4000-8000-000000000306', '20400000-0000-4000-8000-000000000307')),
    ARRAY['Annullata', 'Annullata'],
    'partita: le partite Completa e Confermata risultano Annullata'
);

-- ===========================================================================
-- onboarding: ruolo e specializzazione (D11)
-- ===========================================================================
-- Questo blocco sta in fondo al file perche' SET CONSTRAINTS ... IMMEDIATE
-- resta in vigore fino alla fine della transazione.

-- Cambio di ruolo con la specializzazione gia' presente: N1 ha l'onboarding in
-- corso, ruolo Giocatore e la riga di giocatore (sezione A).
SELECT pg_temp.imposta_jwt('20400000-0000-4000-8000-000000000006', 'authenticated');
SET LOCAL ROLE authenticated;
SELECT throws_ok(
    $$UPDATE public.account SET ruolo_account = 'GestoreCampo' WHERE id = '20400000-0000-4000-8000-000000000006'$$,
    '42501', NULL,
    'onboarding: D11, il ruolo non cambia se esiste gia'' la specializzazione'
);

-- Specializzazione con ruolo non corrispondente, scritta dal server.
RESET ROLE;
SELECT pg_temp.imposta_jwt(NULL, 'service_role');
SET LOCAL ROLE service_role;
SELECT throws_ok(
    $$INSERT INTO public.giocatore (account_id) VALUES ('20400000-0000-4000-8000-000000000005')$$,
    '42501', NULL,
    'onboarding: D11, anche il server non crea una riga Giocatore per un GestoreCampo'
);
SELECT throws_ok(
    $$INSERT INTO public.gestore_campo (account_id) VALUES ('20400000-0000-4000-8000-000000000003')$$,
    '42501', NULL,
    'onboarding: D11, anche il server non crea una riga GestoreCampo per un Giocatore'
);

-- N3 e N4: onboarding in corso con ruolo Giocatore e senza specializzazione.
RESET ROLE;
SELECT pg_temp.crea_utente('20400000-0000-4000-8000-000000000008', 'n3.rls@example.test', 'Nora');
SELECT pg_temp.crea_utente('20400000-0000-4000-8000-000000000009', 'n4.rls@example.test', 'Nando');
UPDATE public.account
SET ruolo_account = 'Giocatore'
WHERE id IN ('20400000-0000-4000-8000-000000000008', '20400000-0000-4000-8000-000000000009');

-- Con il ruolo corrispondente il trigger lascia passare: a rifiutare la riga di
-- un altro Account resta la RLS, provata qui da sola.
SELECT pg_temp.imposta_jwt('20400000-0000-4000-8000-000000000001', 'authenticated');
SET LOCAL ROLE authenticated;
SELECT throws_ok(
    $$INSERT INTO public.giocatore (account_id) VALUES ('20400000-0000-4000-8000-000000000008')$$,
    '42501', NULL,
    'giocatore: la RLS rifiuta la riga Giocatore di un altro Account anche con il ruolo corrispondente'
);

-- Rifiuto: N3 completa l'onboarding senza specializzazione. Il controllo e'
-- differito: SET CONSTRAINTS ... IMMEDIATE lo esegue subito, altrimenti col
-- ROLLBACK finale non scatterebbe mai.
RESET ROLE;
UPDATE public.account
SET stato_onboarding = 'completato'
WHERE id = '20400000-0000-4000-8000-000000000008';
SELECT throws_ok(
    $$SET CONSTRAINTS account_onboarding_completato IMMEDIATE$$,
    '23514', NULL,
    'onboarding: D11, un onboarding completato senza specializzazione e'' rifiutato'
);

-- La SET CONSTRAINTS fallita e' annullata con il suo savepoint e il controllo
-- su N3 resta in coda: si aggiunge la specializzazione, cosi' il caso valido
-- sotto verifica solo N4.
INSERT INTO public.giocatore (account_id) VALUES ('20400000-0000-4000-8000-000000000008');

-- Caso valido: N4 completa l'onboarding e la specializzazione arriva dopo
-- l'UPDATE ma prima del controllo, come nel seed.
UPDATE public.account
SET stato_onboarding = 'completato'
WHERE id = '20400000-0000-4000-8000-000000000009';
INSERT INTO public.giocatore (account_id) VALUES ('20400000-0000-4000-8000-000000000009');
SELECT lives_ok(
    $$SET CONSTRAINTS account_onboarding_completato IMMEDIATE$$,
    'onboarding: D11, con la specializzazione inserita prima del controllo l''onboarding completato e'' accettato'
);

RESET ROLE;
SELECT * FROM finish();

ROLLBACK;

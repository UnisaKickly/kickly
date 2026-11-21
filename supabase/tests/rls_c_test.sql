-- Test pgTAP delle policy RLS della Migration C (KCK-233).
-- Impersona utenti autenticati distinti e verifica privacy e divieti di scrittura;
-- ogni modifica avviene in una transazione annullata.
BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(22);

-- Impostazioni JWT locali per autenticare Luca Bianchi come account 002.
SELECT set_config(
    'request.jwt.claim.sub',
    '20200000-0000-4000-8000-000000000002',
    true
);
SELECT set_config(
    'request.jwt.claims',
    '{"sub":"20200000-0000-4000-8000-000000000002","role":"authenticated"}',
    true
);
SET LOCAL ROLE authenticated;

-- Luca vede la propria notifica e puo' cambiarne lo stato di lettura.
SELECT is(
    (SELECT count(*)::integer
     FROM public.notifica
     WHERE id = '20200000-0000-4000-8000-000000000701'),
    1,
    'l''utente autenticato legge la propria Notifica'
);

SELECT lives_ok(
    $$UPDATE public.notifica
      SET stato_lettura = true
      WHERE id = '20200000-0000-4000-8000-000000000701'$$,
    'l''utente autenticato aggiorna lo stato di lettura della propria Notifica'
);

RESET ROLE;
UPDATE public.notifica
SET stato_lettura = false
WHERE id = '20200000-0000-4000-8000-000000000701';

SELECT set_config(
    'request.jwt.claim.sub',
    '20200000-0000-4000-8000-000000000003',
    true
);
SELECT set_config(
    'request.jwt.claims',
    '{"sub":"20200000-0000-4000-8000-000000000003","role":"authenticated"}',
    true
);
SET LOCAL ROLE authenticated;

-- Andrea non deve vedere la notifica indirizzata a Luca.
SELECT is(
    (SELECT count(*)::integer
     FROM public.notifica
     WHERE id = '20200000-0000-4000-8000-000000000701'),
    0,
    'un utente non vede la Notifica indirizzata a un altro account'
);

-- PostgreSQL filtra la riga fuori dalla clausola USING senza sollevare 42501.
SELECT lives_ok(
    $$UPDATE public.notifica
      SET stato_lettura = true
      WHERE id = '20200000-0000-4000-8000-000000000701'$$,
    'un utente non puo'' aggiornare la Notifica altrui'
);

RESET ROLE;
SELECT is(
    (SELECT stato_lettura
     FROM public.notifica
     WHERE id = '20200000-0000-4000-8000-000000000701'),
    false,
    'l''UPDATE della Notifica altrui lascia stato_lettura invariato a false'
);

SELECT set_config(
    'request.jwt.claim.sub',
    '20200000-0000-4000-8000-000000000003',
    true
);
SELECT set_config(
    'request.jwt.claims',
    '{"sub":"20200000-0000-4000-8000-000000000003","role":"authenticated"}',
    true
);
SET LOCAL ROLE authenticated;

-- Andrea deve vedere solo la quota della propria partecipazione 508.
SELECT is(
    (SELECT count(*)::integer
     FROM public.quota
     WHERE id = '20200000-0000-4000-8000-000000000802'),
    1,
    'il Giocatore vede la quota della propria Partecipazione'
);

SELECT is(
    (SELECT count(*)::integer
     FROM public.quota
     WHERE id = '20200000-0000-4000-8000-000000000801'),
    0,
    'il Giocatore non vede la quota di un altra Partecipazione'
);

-- Andrea non deve leggere il voto gia' registrato da Luca.
SELECT is(
    (SELECT count(*)::integer
     FROM public.preferenza_voto_mvp
     WHERE votazione_id = '20200000-0000-4000-8000-000000000601'
       AND votante_id = '20200000-0000-4000-8000-000000000002'),
    0,
    'un votante non legge la preferenza MVP di un altro votante'
);

RESET ROLE;
SELECT set_config(
    'request.jwt.claim.sub',
    '20200000-0000-4000-8000-000000000002',
    true
);
SELECT set_config(
    'request.jwt.claims',
    '{"sub":"20200000-0000-4000-8000-000000000002","role":"authenticated"}',
    true
);
SET LOCAL ROLE authenticated;

-- Luca vede solo la propria preferenza MVP.
SELECT is(
    (SELECT count(*)::integer
     FROM public.preferenza_voto_mvp
     WHERE votazione_id = '20200000-0000-4000-8000-000000000601'
       AND votante_id = '20200000-0000-4000-8000-000000000002'),
    1,
    'il votante legge la propria PreferenzaVotoMVP'
);

-- Luca aggiorna solo il proprio voto e non puo' cambiare il votante proprietario.
SELECT lives_ok(
    $$UPDATE public.preferenza_voto_mvp
      SET votato_id = '20200000-0000-4000-8000-000000000001'
      WHERE votazione_id = '20200000-0000-4000-8000-000000000601'
        AND votante_id = '20200000-0000-4000-8000-000000000002'$$,
    'il votante aggiorna la propria PreferenzaVotoMVP'
);

-- Andrea tenta di inserire o modificare un voto attribuito a Luca.
RESET ROLE;
SELECT set_config(
    'request.jwt.claim.sub',
    '20200000-0000-4000-8000-000000000003',
    true
);
SELECT set_config(
    'request.jwt.claims',
    '{"sub":"20200000-0000-4000-8000-000000000003","role":"authenticated"}',
    true
);
SET LOCAL ROLE authenticated;

SELECT throws_ok(
    $$INSERT INTO public.preferenza_voto_mvp
      (votazione_id, votante_id, votato_id)
      VALUES (
          '20200000-0000-4000-8000-000000000601',
          '20200000-0000-4000-8000-000000000002',
          '20200000-0000-4000-8000-000000000001'
      )$$,
    '42501',
    NULL,
    'un utente non puo'' registrare un voto attribuito a un altro votante'
);

-- PostgreSQL filtra l'UPDATE altrui tramite USING senza sollevare 42501.
SELECT lives_ok(
    $$UPDATE public.preferenza_voto_mvp
      SET votante_id = '20200000-0000-4000-8000-000000000003'
      WHERE votazione_id = '20200000-0000-4000-8000-000000000601'
        AND votante_id = '20200000-0000-4000-8000-000000000002'$$,
    'WITH CHECK impedisce di trasferire il voto a un altro votante'
);

RESET ROLE;
SELECT is(
    (SELECT votante_id
     FROM public.preferenza_voto_mvp
     WHERE votazione_id = '20200000-0000-4000-8000-000000000601'
       AND votante_id = '20200000-0000-4000-8000-000000000002'),
    '20200000-0000-4000-8000-000000000002'::uuid,
    'l''UPDATE altrui lascia invariato il proprietario della PreferenzaVotoMVP'
);

-- Andrea inserisce una propria preferenza valida.
RESET ROLE;
SELECT set_config(
    'request.jwt.claim.sub',
    '20200000-0000-4000-8000-000000000003',
    true
);
SELECT set_config(
    'request.jwt.claims',
    '{"sub":"20200000-0000-4000-8000-000000000003","role":"authenticated"}',
    true
);
SET LOCAL ROLE authenticated;

SELECT lives_ok(
    $$INSERT INTO public.preferenza_voto_mvp
      (votazione_id, votante_id, votato_id)
      VALUES (
          '20200000-0000-4000-8000-000000000601',
          '20200000-0000-4000-8000-000000000003',
          '20200000-0000-4000-8000-000000000001'
      )$$,
    'il votante puo'' inserire la propria PreferenzaVotoMVP'
);

-- Luca tenta di cancellare la preferenza inserita da Andrea.
RESET ROLE;
SELECT set_config(
    'request.jwt.claim.sub',
    '20200000-0000-4000-8000-000000000002',
    true
);
SELECT set_config(
    'request.jwt.claims',
    '{"sub":"20200000-0000-4000-8000-000000000002","role":"authenticated"}',
    true
);
SET LOCAL ROLE authenticated;

SELECT lives_ok(
    $$DELETE FROM public.preferenza_voto_mvp
      WHERE votazione_id = '20200000-0000-4000-8000-000000000601'
        AND votante_id = '20200000-0000-4000-8000-000000000003'$$,
    'l''utente non puo'' cancellare la PreferenzaVotoMVP altrui'
);

RESET ROLE;
SELECT is(
    (SELECT count(*)::integer
     FROM public.preferenza_voto_mvp
     WHERE votazione_id = '20200000-0000-4000-8000-000000000601'
       AND votante_id = '20200000-0000-4000-8000-000000000003'),
    1,
    'il DELETE altrui lascia presente la riga di Andrea'
);

-- Andrea elimina la propria preferenza MVP.
SELECT set_config(
    'request.jwt.claim.sub',
    '20200000-0000-4000-8000-000000000003',
    true
);
SELECT set_config(
    'request.jwt.claims',
    '{"sub":"20200000-0000-4000-8000-000000000003","role":"authenticated"}',
    true
);
SET LOCAL ROLE authenticated;

SELECT lives_ok(
    $$DELETE FROM public.preferenza_voto_mvp
      WHERE votazione_id = '20200000-0000-4000-8000-000000000601'
        AND votante_id = '20200000-0000-4000-8000-000000000003'$$,
    'il votante cancella la propria PreferenzaVotoMVP'
);

RESET ROLE;
SELECT is(
    (SELECT count(*)::integer
     FROM public.preferenza_voto_mvp
     WHERE votazione_id = '20200000-0000-4000-8000-000000000601'
       AND votante_id = '20200000-0000-4000-8000-000000000003'),
    0,
    'il DELETE del votante rimuove effettivamente la propria riga'
);

-- Il client non puo' inserire ne' aggiornare Transazione.
RESET ROLE;
SELECT set_config(
    'request.jwt.claim.sub',
    '20200000-0000-4000-8000-000000000002',
    true
);
SELECT set_config(
    'request.jwt.claims',
    '{"sub":"20200000-0000-4000-8000-000000000002","role":"authenticated"}',
    true
);
SET LOCAL ROLE authenticated;

SELECT throws_ok(
    $$INSERT INTO public.transazione
      (quota_id, tipo, importo, stato, riferimento_esterno)
      VALUES (
          '20200000-0000-4000-8000-000000000801',
          'pagamento',
          8.00,
          'completata',
          'evt_kickly_test_rls_cliente_901'
      )$$,
    '42501',
    NULL,
    'il client autenticato non puo'' inserire una Transazione'
);

SELECT throws_ok(
    $$UPDATE public.transazione
      SET stato = 'fallita'
      WHERE id = '20200000-0000-4000-8000-000000000901'$$,
    '42501',
    NULL,
    'il client autenticato non puo'' aggiornare una Transazione'
);

-- Luca legge la transazione della propria quota, mentre il Gestore legge gli accrediti propri.
SELECT is(
    (SELECT count(*)::integer
     FROM public.transazione
     WHERE id = '20200000-0000-4000-8000-000000000901'),
    1,
    'il Giocatore legge la Transazione della propria quota'
);

RESET ROLE;

-- Associa la Transazione seed a un Gestore esistente, usando solo UUID del seed.
UPDATE public.transazione
SET gestore_campo_id = '20200000-0000-4000-8000-000000000004'
WHERE id = '20200000-0000-4000-8000-000000000901';

SELECT set_config(
    'request.jwt.claim.sub',
    '20200000-0000-4000-8000-000000000004',
    true
);
SELECT set_config(
    'request.jwt.claims',
    '{"sub":"20200000-0000-4000-8000-000000000004","role":"authenticated"}',
    true
);
SET LOCAL ROLE authenticated;

SELECT is(
    (SELECT count(*)::integer
     FROM public.transazione
     WHERE id = '20200000-0000-4000-8000-000000000901'),
    1,
    'il GestoreCampo legge solo gli accrediti associati al proprio account'
);

SELECT * FROM finish();

RESET ROLE;
ROLLBACK;

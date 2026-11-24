-- Test pgTAP della funzione SQL transazionale RSVP (KCK-219).
-- Verifica i frame TF_PAR_04–TF_PAR_09, incluso l'uso concorrente del database.
-- Tutto avviene in una transazione annullata; la partita del test concorrente
-- viene creata e rimossa dalle connessioni dblink per essere visibile ai peer.
BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS dblink WITH SCHEMA extensions;

SELECT plan(25);

INSERT INTO public.partita (
    id, giocatore_id, data_ora, tipologia, privacy,
    num_partecipanti_richiesti, stato
)
VALUES
    (
        '21900000-0000-4000-8000-000000000001',
        '20200000-0000-4000-8000-000000000001',
        now() + interval '7 days', '5v5', 'pubblica', 10, 'Aperta'
    ),
    (
        '21900000-0000-4000-8000-000000000002',
        '20200000-0000-4000-8000-000000000001',
        now() + interval '8 days', '5v5', 'pubblica', 10, 'Aperta'
    );

-- TF_PAR_04: con piu' posti liberi, una conferma viene registrata e ne riduce
-- il contatore di uno; la Partecipazione e la partita restano nello stato atteso.
CREATE TEMP TABLE rsvp_tf_par_04 AS
SELECT * FROM public.gestisci_rsvp(
    '21900000-0000-4000-8000-000000000001',
    '20200000-0000-4000-8000-000000000001', 'conferma'
);
SELECT is(
    (SELECT esito FROM rsvp_tf_par_04),
    'confermata',
    'tf_par_04 la conferma viene registrata'
);
SELECT is(
    (SELECT posti_rimasti FROM rsvp_tf_par_04),
    9,
    'tf_par_04 il contatore diminuisce di uno'
);
SELECT is(
    (SELECT count(*)::integer FROM public.partecipazione
      WHERE partita_id = '21900000-0000-4000-8000-000000000001'
        AND giocatore_id = '20200000-0000-4000-8000-000000000001'
        AND risposta_stato = 'confermata'),
    1,
    'tf_par_04 il Giocatore compare tra i confermati'
);
SELECT is(
    (SELECT stato FROM public.partita
      WHERE id = '21900000-0000-4000-8000-000000000001'),
    'Aperta',
    'tf_par_04 la partita con posti liberi resta Aperta'
);

-- Crea Giocatori di test indipendenti, necessari per riempire la capienza minima
-- del formato 5v5 prima di provare l'ultimo posto e la concorrenza.
SELECT extensions.dblink_connect(
    'rsvp_concorrente_1',
    'dbname=' || current_database()
);
SELECT extensions.dblink_connect(
    'rsvp_concorrente_2',
    'dbname=' || current_database()
);
SELECT extensions.dblink_exec(
    'rsvp_concorrente_1',
    $$DELETE FROM public.partita
      WHERE id = '21900000-0000-4000-8000-000000000003'$$
);
SELECT extensions.dblink_exec(
    'rsvp_concorrente_1',
    $$DELETE FROM auth.users
      WHERE email LIKE 'rsvp-kck219-%@example.invalid'$$
);
SELECT extensions.dblink_exec(
    'rsvp_concorrente_1',
    $$INSERT INTO auth.users (
        id, aud, role, email, encrypted_password, email_confirmed_at,
        raw_app_meta_data, raw_user_meta_data, created_at, updated_at
    )
    SELECT
        ('21900000-0000-4000-8000-' || lpad(giocatore_num::text, 12, '0'))::uuid,
        'authenticated', 'authenticated',
        'rsvp-kck219-' || giocatore_num || '@example.invalid',
        '', now(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        jsonb_build_object(
            'role', 'Giocatore', 'nome', 'Test', 'cognome', 'Rsvp',
            'name', 'KCK219 Test Rsvp', 'eta', 20
        ),
        now(), now()
    FROM generate_series(201, 211) AS giocatore_num$$
);
SELECT extensions.dblink_exec(
    'rsvp_concorrente_1',
    $$INSERT INTO public.giocatore (account_id)
      SELECT id FROM auth.users
      WHERE email LIKE 'rsvp-kck219-%@example.invalid'$$
);

-- TF_PAR_05: la conferma dell'ultimo posto azzera il contatore e completa la partita.
DO $rsvp_fixture$
DECLARE
    giocatore_num integer;
BEGIN
    FOR giocatore_num IN 201..209 LOOP
        PERFORM 1 FROM public.gestisci_rsvp(
            '21900000-0000-4000-8000-000000000002',
            ('21900000-0000-4000-8000-' || lpad(giocatore_num::text, 12, '0'))::uuid,
            'conferma'
        );
    END LOOP;
END
$rsvp_fixture$;
CREATE TEMP TABLE rsvp_tf_par_05 AS
SELECT * FROM public.gestisci_rsvp(
    '21900000-0000-4000-8000-000000000002',
    '21900000-0000-4000-8000-000000000210', 'conferma'
);
SELECT is(
    (SELECT esito FROM rsvp_tf_par_05),
    'confermata',
    'tf_par_05 la conferma dell''ultimo posto viene registrata'
);
SELECT is(
    (SELECT posti_rimasti FROM rsvp_tf_par_05),
    0,
    'tf_par_05 il contatore arriva a zero'
);
SELECT is(
    (SELECT stato FROM public.partita
      WHERE id = '21900000-0000-4000-8000-000000000002'),
    'Completa',
    'tf_par_05 la partita passa a Completa'
);

-- TF_PAR_06: una conferma a partita completa e' rifiutata senza mutare i dati.
CREATE TEMP TABLE rsvp_tf_par_06 AS
SELECT * FROM public.gestisci_rsvp(
    '21900000-0000-4000-8000-000000000002',
    '21900000-0000-4000-8000-000000000211', 'conferma'
);
SELECT is(
    (SELECT esito FROM rsvp_tf_par_06),
    'partita_al_completo',
    'tf_par_06 il Giocatore riceve l''esito partita al completo'
);
SELECT is(
    (SELECT posti_rimasti FROM rsvp_tf_par_06),
    0,
    'tf_par_06 il contatore resta a zero'
);
SELECT is(
    (SELECT count(*)::integer FROM public.partecipazione
      WHERE partita_id = '21900000-0000-4000-8000-000000000002'
        AND giocatore_id = '21900000-0000-4000-8000-000000000211'),
    0,
    'tf_par_06 la Partecipazione non viene registrata'
);
SELECT is(
    (SELECT stato FROM public.partita
      WHERE id = '21900000-0000-4000-8000-000000000002'),
    'Completa',
    'tf_par_06 la partita resta Completa'
);

-- TF_PAR_07: due sessioni PostgreSQL inviano contemporaneamente una conferma
-- per l'ultimo posto; la funzione atomica deve ammetterne una sola.
SELECT extensions.dblink_exec(
    'rsvp_concorrente_1',
    $$INSERT INTO public.partita (
        id, giocatore_id, data_ora, tipologia, privacy,
        num_partecipanti_richiesti, stato
    ) VALUES (
        '21900000-0000-4000-8000-000000000003',
        '20200000-0000-4000-8000-000000000001',
        now() + interval '9 days', '5v5', 'pubblica', 10, 'Aperta'
    )$$
);
SELECT extensions.dblink_exec(
    'rsvp_concorrente_1',
    $$DO $rsvp_fixture$
      DECLARE
          giocatore_num integer;
      BEGIN
          FOR giocatore_num IN 201..209 LOOP
              PERFORM 1 FROM public.gestisci_rsvp(
                  '21900000-0000-4000-8000-000000000003',
                  ('21900000-0000-4000-8000-' || lpad(giocatore_num::text, 12, '0'))::uuid,
                  'conferma'
              );
          END LOOP;
      END
      $rsvp_fixture$;$$
);
SELECT is(
    extensions.dblink_send_query(
        'rsvp_concorrente_1',
        $$SELECT esito, posti_rimasti, stato_partita
          FROM public.gestisci_rsvp(
            '21900000-0000-4000-8000-000000000003',
            '21900000-0000-4000-8000-000000000210', 'conferma')$$
    ),
    1,
    'tf_par_07 prima richiesta concorrente inviata'
);
SELECT is(
    extensions.dblink_send_query(
        'rsvp_concorrente_2',
        $$SELECT esito, posti_rimasti, stato_partita
          FROM public.gestisci_rsvp(
            '21900000-0000-4000-8000-000000000003',
            '21900000-0000-4000-8000-000000000211', 'conferma')$$
    ),
    1,
    'tf_par_07 seconda richiesta concorrente inviata'
);
CREATE TEMP TABLE rsvp_concorrenza_esiti (
    esito text,
    posti_rimasti integer,
    stato_partita text
);
INSERT INTO rsvp_concorrenza_esiti
SELECT esito, posti_rimasti, stato_partita
FROM extensions.dblink_get_result('rsvp_concorrente_1', false)
  AS risultato(esito text, posti_rimasti integer, stato_partita text);
INSERT INTO rsvp_concorrenza_esiti
SELECT esito, posti_rimasti, stato_partita
FROM extensions.dblink_get_result('rsvp_concorrente_2', false)
  AS risultato(esito text, posti_rimasti integer, stato_partita text);
SELECT is(
    (SELECT count(*)::integer FROM rsvp_concorrenza_esiti
      WHERE esito = 'confermata'),
    1,
    'tf_par_07 viene registrata una sola conferma'
);
SELECT is(
    (SELECT count(*)::integer FROM rsvp_concorrenza_esiti
      WHERE esito = 'partita_al_completo'),
    1,
    'tf_par_07 la richiesta perdente riceve partita al completo'
);
SELECT ok(
    (SELECT min(posti_rimasti) >= 0 FROM rsvp_concorrenza_esiti),
    'tf_par_07 nessuna risposta riporta posti disponibili negativi'
);
SELECT is(
    (SELECT count(*)::integer FROM public.partecipazione
      WHERE partita_id = '21900000-0000-4000-8000-000000000003'
        AND risposta_stato = 'confermata'),
    10,
    'tf_par_07 i confermati non superano la capienza di dieci posti'
);
SELECT is(
    (SELECT stato FROM public.partita
      WHERE id = '21900000-0000-4000-8000-000000000003'),
    'Completa',
    'tf_par_07 la partita termina Completa'
);

-- TF_PAR_08: ripetere una conferma gia' registrata non crea duplicati o consuma
-- un altro posto.
CREATE TEMP TABLE rsvp_tf_par_08 AS
SELECT * FROM public.gestisci_rsvp(
    '21900000-0000-4000-8000-000000000001',
    '20200000-0000-4000-8000-000000000001', 'conferma'
);
SELECT is(
    (SELECT esito FROM rsvp_tf_par_08),
    'gia_confermata',
    'tf_par_08 la riconferma e'' idempotente'
);
SELECT is(
    (SELECT posti_rimasti FROM rsvp_tf_par_08),
    9,
    'tf_par_08 il contatore resta invariato'
);
SELECT is(
    (SELECT count(*)::integer FROM public.partecipazione
      WHERE partita_id = '21900000-0000-4000-8000-000000000001'
        AND giocatore_id = '20200000-0000-4000-8000-000000000001'),
    1,
    'tf_par_08 esiste una sola Partecipazione per Giocatore e Partita'
);

-- TF_PAR_09: il ritiro del Giocatore confermato libera il posto e riapre la partita.
CREATE TEMP TABLE rsvp_tf_par_09 AS
SELECT * FROM public.gestisci_rsvp(
    '21900000-0000-4000-8000-000000000002',
    '21900000-0000-4000-8000-000000000210', 'ritiro'
);
SELECT is(
    (SELECT esito FROM rsvp_tf_par_09),
    'ritirata',
    'tf_par_09 il ritiro viene registrato'
);
SELECT is(
    (SELECT posti_rimasti FROM rsvp_tf_par_09),
    1,
    'tf_par_09 il contatore sale di uno'
);
SELECT is(
    (SELECT risposta_stato FROM public.partecipazione
      WHERE partita_id = '21900000-0000-4000-8000-000000000002'
        AND giocatore_id = '21900000-0000-4000-8000-000000000210'),
    'ritirata',
    'tf_par_09 la Partecipazione passa a ritirata'
);
SELECT is(
    (SELECT stato FROM public.partita
      WHERE id = '21900000-0000-4000-8000-000000000002'),
    'Aperta',
    'tf_par_09 la partita torna Aperta'
);

SELECT extensions.dblink_exec(
    'rsvp_concorrente_1',
    $$DELETE FROM public.partecipazione
      WHERE partita_id = '21900000-0000-4000-8000-000000000003'$$
);
SELECT extensions.dblink_exec(
    'rsvp_concorrente_1',
    $$DELETE FROM public.partita
      WHERE id = '21900000-0000-4000-8000-000000000003'$$
);
SELECT extensions.dblink_exec(
    'rsvp_concorrente_1',
    $$DELETE FROM auth.users
      WHERE email LIKE 'rsvp-kck219-%@example.invalid'$$
);
SELECT extensions.dblink_disconnect('rsvp_concorrente_1');
SELECT extensions.dblink_disconnect('rsvp_concorrente_2');

SELECT * FROM finish();
ROLLBACK;

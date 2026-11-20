-- Test pgTAP della Migration C (KCK-218): vincoli di votazione, idempotenza e pagamento.
-- Usa i dati seed delle migration A, B e C; ogni verifica avviene in una transazione annullata.
BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(3);

-- Un votante puo' registrare una sola preferenza per la stessa votazione.
SELECT throws_ok(
    $$INSERT INTO public.preferenza_voto_mvp (votazione_id, votante_id, votato_id)
      VALUES (
          '20200000-0000-4000-8000-000000000601',
          '20200000-0000-4000-8000-000000000002',
          '20200000-0000-4000-8000-000000000003'
      )$$,
    '23505',
    NULL,
    'un secondo voto dello stesso votante nella stessa votazione viene rifiutato'
);

-- Il riferimento esterno identifica una transazione in modo univoco.
SELECT throws_ok(
    $$INSERT INTO public.transazione (
        quota_id,
        tipo,
        importo,
        stato,
        riferimento_esterno
      )
      VALUES (
        NULL,
        'rimborso',
        8.00,
        'completata',
        'evt_kickly_test_pagamento_20200000000000000000000000000801'
      )$$,
    '23505',
    NULL,
    'un riferimento_esterno duplicato viene rifiutato'
);

-- Al massimo una transazione di tipo pagamento puo' riferirsi alla stessa quota.
SELECT throws_ok(
    $$INSERT INTO public.transazione (
        quota_id,
        tipo,
        importo,
        stato,
        riferimento_esterno
      )
      VALUES (
        '20200000-0000-4000-8000-000000000801',
        'pagamento',
        8.00,
        'completata',
        'evt_kickly_test_pagamento_secondo_20200000000000000000000801'
      )$$,
    '23505',
    NULL,
    'un secondo pagamento sulla stessa quota viene rifiutato'
);

SELECT * FROM finish();

ROLLBACK;

-- Test pgTAP della migration Realtime (KCK-203): la tabella partecipazione deve
-- stare nella publication `supabase_realtime`, altrimenti lo stream dei posti
-- disponibili non riceve gli eventi. Tutto avviene in una transazione annullata.
BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(1);

-- Esattamente una riga: la tabella e' pubblicata una sola volta.
SELECT is(
    (SELECT count(*)::integer
       FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = 'partecipazione'),
    1,
    'partecipazione e'' nella publication supabase_realtime'
);

SELECT * FROM finish();

ROLLBACK;

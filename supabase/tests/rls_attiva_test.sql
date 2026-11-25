-- Test pgTAP (KCK-269): ogni tabella dello schema `public` ha la RLS attiva.
--
-- Perche': senza RLS una tabella e' leggibile e scrivibile da chiunque abbia la
-- chiave anon dell'app, cioe' da chiunque. Le policy (KCK-233, KCK-226) sono la
-- parte piu' delicata del progetto, e una tabella nuova dimenticata passerebbe
-- la CI in silenzio: questo test la fa fallire.
--
-- Se fallisce, nel messaggio di differenza "have" compaiono i nomi delle
-- tabelle senza RLS. Si risolve con, nella migration della tabella:
--   ALTER TABLE public.<nome> ENABLE ROW LEVEL SECURITY;
-- piu' le policy che servono (senza policy la tabella e' chiusa a tutti tranne
-- al service role, che e' il comportamento sicuro di partenza).
-- Tutto avviene in una transazione annullata.
BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(1);

-- L'elenco delle tabelle senza RLS deve essere vuoto.
SELECT is(
    (SELECT coalesce(array_agg(tablename::text ORDER BY tablename::text), ARRAY[]::text[])
       FROM pg_tables
      WHERE schemaname = 'public'
        AND NOT rowsecurity),
    ARRAY[]::text[],
    'ogni tabella di public ha la RLS attiva'
);

SELECT * FROM finish();

ROLLBACK;

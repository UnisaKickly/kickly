-- Test pgTAP della Migration B (KCK-210): le tre prove della Verifica del ticket
-- (prenotazioni sovrapposte, doppia partecipazione, stato partita non previsto)
-- e i casi limite dei vincoli. Usa i dati del seed (parti A e B).
-- Si esegue con `supabase test db`; tutto avviene in una transazione annullata.
BEGIN;

CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

SELECT plan(12);

-- Seed: tre partite (criterio di accettazione).
SELECT is(
    (SELECT count(*)::integer FROM public.partita),
    3,
    'il seed contiene 3 partite'
);

-- Partite di appoggio, senza prenotazione, per provare gli slot.
INSERT INTO public.partita (id, giocatore_id, data_ora, tipologia, privacy, num_partecipanti_richiesti)
VALUES
    ('20200000-0000-4000-8000-000000000391', '20200000-0000-4000-8000-000000000001', '2026-12-10 18:00:00+01', '5v5', 'pubblica', 10),
    ('20200000-0000-4000-8000-000000000392', '20200000-0000-4000-8000-000000000001', '2026-12-10 19:00:00+01', '5v5', 'pubblica', 10),
    ('20200000-0000-4000-8000-000000000393', '20200000-0000-4000-8000-000000000001', '2026-12-10 18:30:00+01', '5v5', 'pubblica', 10);

-- Slot sovrapposti impossibili a livello DB (criterio di accettazione).
SELECT lives_ok(
    $$INSERT INTO public.prenotazione (partita_id, campo_id, intervallo, stato_blocco, scadenza_blocco, costo_concordato, quota_individuale, commissione, netto_gestore)
      VALUES ('20200000-0000-4000-8000-000000000391', '20200000-0000-4000-8000-000000000202', '2026-12-10T18:00/2026-12-10T19:00', 'bloccato', now() + interval '1 day', 80, 8, 4, 76)$$,
    'una prenotazione su uno slot libero viene accettata'
);

SELECT throws_ok(
    $$INSERT INTO public.prenotazione (partita_id, campo_id, intervallo, stato_blocco, scadenza_blocco, costo_concordato, quota_individuale, commissione, netto_gestore)
      VALUES ('20200000-0000-4000-8000-000000000393', '20200000-0000-4000-8000-000000000202', '2026-12-10T18:30/2026-12-10T19:30', 'confermato', NULL, 80, 8, 4, 76)$$,
    '23P01',
    NULL,
    'due prenotazioni attive sovrapposte sullo stesso campo vengono rifiutate'
);

SELECT lives_ok(
    $$INSERT INTO public.prenotazione (partita_id, campo_id, intervallo, stato_blocco, scadenza_blocco, costo_concordato, quota_individuale, commissione, netto_gestore)
      VALUES ('20200000-0000-4000-8000-000000000392', '20200000-0000-4000-8000-000000000202', '2026-12-10T19:00/2026-12-10T20:00', 'bloccato', now() + interval '1 day', 80, 8, 4, 76)$$,
    'uno slot che inizia quando finisce il precedente viene accettato'
);

SELECT lives_ok(
    $$INSERT INTO public.prenotazione (partita_id, campo_id, intervallo, stato_blocco, scadenza_blocco, costo_concordato, quota_individuale, commissione, netto_gestore)
      VALUES ('20200000-0000-4000-8000-000000000393', '20200000-0000-4000-8000-000000000201', '2026-12-10T18:30/2026-12-10T19:30', 'bloccato', now() + interval '1 day', 60, 6, 3, 57)$$,
    'lo stesso orario su un altro campo viene accettato'
);

SELECT throws_ok(
    $$INSERT INTO public.prenotazione (partita_id, campo_id, intervallo, stato_blocco, scadenza_blocco, costo_concordato, quota_individuale, commissione, netto_gestore)
      VALUES ('20200000-0000-4000-8000-000000000303', '20200000-0000-4000-8000-000000000202', '2026-12-11T18:00/2026-12-11T19:00', 'bloccato', now() + interval '1 day', 80, 8, 4, 76)$$,
    '23505',
    NULL,
    'una seconda prenotazione per la stessa partita viene rifiutata'
);

SELECT throws_ok(
    $$INSERT INTO public.prenotazione (partita_id, campo_id, intervallo, stato_blocco, scadenza_blocco, costo_concordato, quota_individuale, commissione, netto_gestore)
      VALUES ('20200000-0000-4000-8000-000000000301', '20200000-0000-4000-8000-000000000201', '2026-12-11T19:00/2026-12-11T18:00', 'bloccato', now() + interval '1 day', 60, 6, 3, 57)$$,
    '23514',
    NULL,
    'un intervallo con la fine prima dell''inizio viene rifiutato'
);

SELECT throws_ok(
    $$UPDATE public.prenotazione SET scadenza_blocco = NULL
      WHERE id = '20200000-0000-4000-8000-000000000403'$$,
    '23514',
    NULL,
    'uno slot bloccato senza scadenza del blocco viene rifiutato'
);

-- Partecipazione univoca (criterio di accettazione).
SELECT throws_ok(
    $$INSERT INTO public.partecipazione (giocatore_id, partita_id, risposta_stato, data_risposta)
      VALUES ('20200000-0000-4000-8000-000000000001', '20200000-0000-4000-8000-000000000301', 'confermata', now())$$,
    '23505',
    NULL,
    'una doppia partecipazione dello stesso giocatore alla stessa partita viene rifiutata'
);

-- Stato della partita coerente con lo statechart.
SELECT throws_ok(
    $$UPDATE public.partita SET stato = 'Rinviata'
      WHERE id = '20200000-0000-4000-8000-000000000301'$$,
    '23514',
    NULL,
    'uno stato della partita non previsto dallo statechart viene rifiutato'
);

SELECT lives_ok(
    $$UPDATE public.partita SET stato = 'Confermata'
      WHERE id = '20200000-0000-4000-8000-000000000391'$$,
    'lo stato Confermata dello statechart viene accettato'
);

-- D7: partecipanti richiesti non inferiori ai giocatori in campo.
SELECT throws_ok(
    $$INSERT INTO public.partita (giocatore_id, data_ora, tipologia, privacy, num_partecipanti_richiesti)
      VALUES ('20200000-0000-4000-8000-000000000001', '2026-12-12 18:00:00+01', '5v5', 'pubblica', 9)$$,
    '23514',
    NULL,
    'una partita 5v5 con meno di 10 partecipanti richiesti viene rifiutata'
);

SELECT * FROM finish();

ROLLBACK;

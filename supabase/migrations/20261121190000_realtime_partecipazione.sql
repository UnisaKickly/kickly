-- Realtime della tabella partecipazione (KCK-203, RF_PAR_2).
--
-- Perche': PartecipazioneRepository.osservaPartecipazioni() si abbona ai
-- cambiamenti di `partecipazione` con Supabase Realtime, per aggiornare i posti
-- disponibili in tempo reale. Realtime emette eventi solo per le tabelle della
-- publication `supabase_realtime`: senza questa riga lo stream mostrerebbe
-- soltanto la lettura iniziale e non si aggiornerebbe mai.
--
-- Cosa fa: aggiunge `public.partecipazione` alla publication, se la publication
-- esiste e la tabella non c'e' ancora (cosi' la migration si puo' rieseguire).
-- Il Realtime rispetta la RLS: chi riceve gli eventi lo decidono le policy di
-- `partecipazione` (KCK-226), non questa migration.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_publication
        WHERE pubname = 'supabase_realtime'
    ) AND NOT EXISTS (
        SELECT 1
        FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
          AND schemaname = 'public'
          AND tablename = 'partecipazione'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.partecipazione;
    END IF;
END
$$;

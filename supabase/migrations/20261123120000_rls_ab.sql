-- RLS delle tabelle degli schemi A e B (KCK-226).
-- Le tabelle hanno gia' la RLS attiva (migration A e B) ma nessuna policy: qui si
-- stabilisce chi legge e chi scrive ogni riga in base all'utente autenticato
-- (auth.uid()). Fonti: RAD v2.9 (§3.1.1 attori, RF_ACC, RF_LEG, RF_PAR, tabella
-- degli oggetti), decisioni D1, D2, D3, D5, D6, D9, D11, D13, D17, D24, D26 e risposte dei PM
-- nel ticket KCK-226. Dove una scrittura non e' prevista dal client la si chiude
-- anche con REVOKE, cosi' una policy aggiunta per errore non basta ad aprirla.
-- Restano chiuse di proposito: lettura di account e Player Card altrui, slot
-- occupati di un campo e importi lato server (KCK-271), adesione con codice
-- (KCK-256), registrazione dei dispositivi (KCK-195).
--
-- Il file e' diviso in tre sezioni:
--   1. funzioni di supporto e policy delle tabelle A
--   2. policy delle tabelle B
--   3. trigger (D11, gol e assist, stato della partita)

-- ###########################################################################
-- ###########################################################################
-- ##                                                                       ##
-- ##  SEZIONE 1 - Funzioni di supporto e policy delle tabelle A            ##
-- ##  account, giocatore, gestore_campo, dispositivo_registrato, lega,     ##
-- ##  membro_lega, amministratore_lega                                     ##
-- ##                                                                       ##
-- ###########################################################################
-- ###########################################################################

-- ---------------------------------------------------------------------------
-- Funzioni di supporto
-- ---------------------------------------------------------------------------
-- Sono SECURITY DEFINER perche' una policy di membro_lega che interroga
-- membro_lega (o di partita che interroga partecipazione e viceversa) andrebbe in
-- ricorsione infinita (errore 42P17): la funzione legge la tabella come
-- proprietario, senza riapplicare la RLS. Restituiscono solo un booleano o il
-- ruolo dell'utente collegato, quindi non espongono righe altrui.

-- Dice se l'utente collegato e' membro della lega.
CREATE FUNCTION public.e_membro_lega(p_lega_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.membro_lega
        WHERE lega_id = p_lega_id
          AND giocatore_id = auth.uid()
    );
$$;

COMMENT ON FUNCTION public.e_membro_lega(uuid) IS
    'Vero se l''utente autenticato e'' membro della lega. Usata dalle policy RLS per evitare la ricorsione su membro_lega.';

-- Dice se l'utente collegato e' amministratore della lega.
CREATE FUNCTION public.e_amministratore_lega(p_lega_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.amministratore_lega
        WHERE lega_id = p_lega_id
          AND giocatore_id = auth.uid()
    );
$$;

COMMENT ON FUNCTION public.e_amministratore_lega(uuid) IS
    'Vero se l''utente autenticato e'' amministratore della lega (comandi riservati, D13 e RF_LEG_3).';

-- Dice se l'utente collegato ha una Partecipazione alla partita, qualunque sia la
-- risposta: anche chi si e' ritirato resta legato alla partita (storico, RSVP).
CREATE FUNCTION public.partecipa_a_partita(p_partita_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.partecipazione
        WHERE partita_id = p_partita_id
          AND giocatore_id = auth.uid()
    );
$$;

COMMENT ON FUNCTION public.partecipa_a_partita(uuid) IS
    'Vero se l''utente autenticato ha una Partecipazione alla partita. Evita la ricorsione tra le policy di partita e partecipazione.';

-- Restituisce il ruolo_account salvato dell'utente collegato (NULL prima dell'onboarding).
CREATE FUNCTION public.ruolo_account_corrente()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT ruolo_account
    FROM public.account
    WHERE id = auth.uid();
$$;

COMMENT ON FUNCTION public.ruolo_account_corrente() IS
    'Ruolo salvato dell''utente autenticato: la specializzazione (giocatore o gestore_campo) si crea solo se coincide con il ruolo scelto (D11).';

REVOKE ALL ON FUNCTION public.e_membro_lega(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.e_amministratore_lega(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.partecipa_a_partita(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.ruolo_account_corrente() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.e_membro_lega(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.e_amministratore_lega(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.partecipa_a_partita(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.ruolo_account_corrente() TO authenticated, service_role;

-- ---------------------------------------------------------------------------
-- account
-- ---------------------------------------------------------------------------
-- La riga la crea il trigger crea_account_per_nuovo_utente e la cancellazione
-- passa da CancellazioneAccountControl (KCK-204, D19, RNF_L_1): nessuna INSERT o
-- DELETE dal client. email cambia solo tramite Supabase Auth e stato_account
-- solo con KCK-204, quindi l'UPDATE e' concesso solo sulle altre colonne.
-- Il ruolo definitivo (D11) e' garantito dal trigger della sezione 3.

CREATE POLICY account_select_own
    ON public.account
    FOR SELECT
    TO authenticated
    USING (id = auth.uid());

COMMENT ON POLICY account_select_own ON public.account IS
    'Ogni utente legge solo il proprio Account: email ed eta'' sono dati personali e la RLS non filtra per colonne.';

CREATE POLICY account_update_own
    ON public.account
    FOR UPDATE
    TO authenticated
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());

COMMENT ON POLICY account_update_own ON public.account IS
    'L''utente aggiorna solo il proprio Account (onboarding, dati anagrafici, preferenze notifiche RF_NOT_2); le colonne ammesse sono fissate dal GRANT per colonna.';

REVOKE UPDATE ON public.account FROM authenticated, anon;
GRANT UPDATE (nome, cognome, eta, preferenze_notifiche, ruolo_account, stato_onboarding)
    ON public.account TO authenticated;

-- ---------------------------------------------------------------------------
-- giocatore
-- ---------------------------------------------------------------------------

CREATE POLICY giocatore_select_own
    ON public.giocatore
    FOR SELECT
    TO authenticated
    USING (account_id = auth.uid());

COMMENT ON POLICY giocatore_select_own ON public.giocatore IS
    'Ogni Giocatore legge solo la propria Player Card; la lettura di quelle altrui resta chiusa in attesa di una vista dedicata.';

CREATE POLICY giocatore_insert_own
    ON public.giocatore
    FOR INSERT
    TO authenticated
    WITH CHECK (
        account_id = auth.uid()
        AND public.ruolo_account_corrente() = 'Giocatore'
    );

COMMENT ON POLICY giocatore_insert_own ON public.giocatore IS
    'La riga Giocatore nasce alla scelta del ruolo (SD_UC_ACC_1 passo 7) solo per il proprio Account con ruolo Giocatore (RF_ACC_2, D11).';

CREATE POLICY giocatore_update_own
    ON public.giocatore
    FOR UPDATE
    TO authenticated
    USING (account_id = auth.uid())
    WITH CHECK (
        account_id = auth.uid()
        AND public.ruolo_account_corrente() = 'Giocatore'
    );

COMMENT ON POLICY giocatore_update_own ON public.giocatore IS
    'Il Giocatore aggiorna solo la propria Player Card (SD_UC_ACC_1 passo 9); le colonne ammesse sono fissate dal GRANT per colonna.';

REVOKE UPDATE ON public.giocatore FROM authenticated, anon;
GRANT UPDATE (ruolo_preferito_in_campo, piede_dominante) ON public.giocatore TO authenticated;

-- ---------------------------------------------------------------------------
-- gestore_campo
-- ---------------------------------------------------------------------------
-- id_account_pagamenti lo scrive l'Edge Function dei pagamenti con la service
-- role (D3, DG1, RNF_IN_1): il client crea la riga senza identificativo e non la
-- aggiorna.

CREATE POLICY gestore_campo_select_own
    ON public.gestore_campo
    FOR SELECT
    TO authenticated
    USING (account_id = auth.uid());

COMMENT ON POLICY gestore_campo_select_own ON public.gestore_campo IS
    'Ogni Gestore del Campo legge solo la propria riga.';

CREATE POLICY gestore_campo_insert_own
    ON public.gestore_campo
    FOR INSERT
    TO authenticated
    WITH CHECK (
        account_id = auth.uid()
        AND public.ruolo_account_corrente() = 'GestoreCampo'
        AND id_account_pagamenti IS NULL
    );

COMMENT ON POLICY gestore_campo_insert_own ON public.gestore_campo IS
    'La riga GestoreCampo nasce all''onboarding solo per il proprio Account con ruolo GestoreCampo (RF_ACC_1, D11) e senza identificativo del fornitore, che scrive il server (D3).';

REVOKE UPDATE ON public.gestore_campo FROM authenticated, anon;

-- ---------------------------------------------------------------------------
-- dispositivo_registrato
-- ---------------------------------------------------------------------------
-- La registrazione dei dispositivi passa da un'Edge Function al login (KCK-195):
-- se la facesse il client, chi ruba le credenziali potrebbe registrare il proprio
-- dispositivo prima del controllo di RF_SS_2.

CREATE POLICY dispositivo_registrato_select_own
    ON public.dispositivo_registrato
    FOR SELECT
    TO authenticated
    USING (account_id = auth.uid());

COMMENT ON POLICY dispositivo_registrato_select_own ON public.dispositivo_registrato IS
    'Ogni utente legge solo i propri dispositivi registrati; le scritture le fa il server (KCK-195).';

REVOKE INSERT, UPDATE, DELETE ON public.dispositivo_registrato FROM authenticated, anon;

-- ---------------------------------------------------------------------------
-- lega
-- ---------------------------------------------------------------------------
-- La lega si crea solo con la RPC crea_lega (D23): nessuna INSERT diretta.
-- Nessuna DELETE: la lega si cancella solo nel flusso di D19 (server).

CREATE POLICY lega_select_pubblica_o_membro
    ON public.lega
    FOR SELECT
    TO authenticated
    USING (
        privacy = 'pubblica'
        OR public.e_membro_lega(id)
    );

COMMENT ON POLICY lega_select_pubblica_o_membro ON public.lega IS
    'Le leghe pubbliche sono visibili a tutti per cercarle e unirsi (VistaLeghe, UC_LEG_1 A1); le private solo ai membri (D17).';

CREATE POLICY lega_update_amministratore
    ON public.lega
    FOR UPDATE
    TO authenticated
    USING (public.e_amministratore_lega(id))
    WITH CHECK (public.e_amministratore_lega(id));

COMMENT ON POLICY lega_update_amministratore ON public.lega IS
    'Solo un amministratore modifica i dettagli della lega e genera il codice invito (RF_LEG_1, RF_LEG_2, D13).';

-- ---------------------------------------------------------------------------
-- membro_lega
-- ---------------------------------------------------------------------------

CREATE POLICY membro_lega_select_stessa_lega
    ON public.membro_lega
    FOR SELECT
    TO authenticated
    USING (public.e_membro_lega(lega_id));

COMMENT ON POLICY membro_lega_select_stessa_lega ON public.membro_lega IS
    'I membri di una lega ne vedono la lista dei membri (RF_LEG_3, RF_LEG_4).';

CREATE POLICY membro_lega_insert_se_stesso_pubblica
    ON public.membro_lega
    FOR INSERT
    TO authenticated
    WITH CHECK (
        giocatore_id = auth.uid()
        AND EXISTS (
            SELECT 1
            FROM public.lega
            WHERE lega.id = membro_lega.lega_id
              AND lega.privacy = 'pubblica'
        )
    );

COMMENT ON POLICY membro_lega_insert_se_stesso_pubblica ON public.membro_lega IS
    'Un Giocatore puo'' aggiungere solo se stesso e solo a una lega pubblica (UC_LEG_1 A1). L''adesione con codice a una lega privata e'' la RPC di KCK-256; nessuno aggiunge altri senza il loro consenso (RF_LEG_3).';

CREATE POLICY membro_lega_delete_se_stesso_o_amministratore
    ON public.membro_lega
    FOR DELETE
    TO authenticated
    USING (
        giocatore_id = auth.uid()
        OR public.e_amministratore_lega(lega_id)
    );

COMMENT ON POLICY membro_lega_delete_se_stesso_o_amministratore ON public.membro_lega IS
    'Un membro puo'' uscire dalla lega (D17) e un amministratore puo'' rimuovere un membro (RF_LEG_3). L''unico amministratore resta protetto dal trigger di integrita'' della migration A.';

-- ---------------------------------------------------------------------------
-- amministratore_lega
-- ---------------------------------------------------------------------------

CREATE POLICY amministratore_lega_select_stessa_lega
    ON public.amministratore_lega
    FOR SELECT
    TO authenticated
    USING (public.e_membro_lega(lega_id));

COMMENT ON POLICY amministratore_lega_select_stessa_lega ON public.amministratore_lega IS
    'I membri sanno chi amministra la lega: serve a mostrare i comandi riservati solo agli amministratori (D13).';

CREATE POLICY amministratore_lega_insert_amministratore
    ON public.amministratore_lega
    FOR INSERT
    TO authenticated
    WITH CHECK (public.e_amministratore_lega(lega_id));

COMMENT ON POLICY amministratore_lega_insert_amministratore ON public.amministratore_lega IS
    'Solo un amministratore promuove un membro ad amministratore (RF_LEG_3).';

CREATE POLICY amministratore_lega_delete_amministratore
    ON public.amministratore_lega
    FOR DELETE
    TO authenticated
    USING (public.e_amministratore_lega(lega_id));

COMMENT ON POLICY amministratore_lega_delete_amministratore ON public.amministratore_lega IS
    'Solo un amministratore toglie il ruolo di amministratore, anche a se stesso prima di uscire (RF_LEG_3, D17).';

-- ###########################################################################
-- ###########################################################################
-- ##                                                                       ##
-- ##  SEZIONE 2 - Policy delle tabelle B                                   ##
-- ##  campo, partita, prenotazione, partecipazione                         ##
-- ##                                                                       ##
-- ###########################################################################
-- ###########################################################################

-- ---------------------------------------------------------------------------
-- campo
-- ---------------------------------------------------------------------------
-- Nessuna DELETE: cancellerebbe a cascata le prenotazioni di partite di altri, e
-- GestioneCampiControl prevede configurazione e modifica, non cancellazione.

CREATE POLICY campo_select_authenticated
    ON public.campo
    FOR SELECT
    TO authenticated
    USING (true);

COMMENT ON POLICY campo_select_authenticated ON public.campo IS
    'Ogni utente autenticato vede i campi per sceglierne uno nella creazione della partita (UC_PAR_1 passo 2, FormCreazionePartita).';

CREATE POLICY campo_insert_gestore
    ON public.campo
    FOR INSERT
    TO authenticated
    WITH CHECK (gestore_campo_id = auth.uid());

COMMENT ON POLICY campo_insert_gestore ON public.campo IS
    'Il Gestore del Campo inserisce solo campi propri (RF_ACC_1, GestioneCampiControl).';

CREATE POLICY campo_update_gestore
    ON public.campo
    FOR UPDATE
    TO authenticated
    USING (gestore_campo_id = auth.uid())
    WITH CHECK (gestore_campo_id = auth.uid());

COMMENT ON POLICY campo_update_gestore ON public.campo IS
    'Il Gestore modifica solo i propri campi e non puo'' cederli a un altro Gestore.';

-- ---------------------------------------------------------------------------
-- partita
-- ---------------------------------------------------------------------------
-- Nessuna DELETE: l'annullamento e' uno stato (statechart, RF_PAR_3) che innesca
-- i rimborsi (RF_PAG_3); una DELETE cancellerebbe a cascata prenotazione e
-- partecipazioni. I passaggi di stato ammessi al client li controlla il trigger
-- della sezione 3.

CREATE POLICY partita_select_visibile
    ON public.partita
    FOR SELECT
    TO authenticated
    USING (
        privacy = 'pubblica'
        OR giocatore_id = auth.uid()
        OR (lega_id IS NOT NULL AND public.e_membro_lega(lega_id))
        OR public.partecipa_a_partita(id)
    );

COMMENT ON POLICY partita_select_visibile ON public.partita IS
    'Visibili: partite pubbliche (bacheca della Dashboard), partite delle proprie leghe (RF_LEG_4), partite organizzate da se'' e quelle a cui si partecipa (DettaglioPartita).';

CREATE POLICY partita_insert_organizzatore
    ON public.partita
    FOR INSERT
    TO authenticated
    WITH CHECK (
        giocatore_id = auth.uid()
        AND (lega_id IS NULL OR public.e_membro_lega(lega_id))
        AND stato = 'Aperta'
    );

COMMENT ON POLICY partita_insert_organizzatore ON public.partita IS
    'Il Giocatore crea partite solo come organizzatore di se stesso (RF_PAR_1), se di lega solo in una lega di cui e'' membro, e sempre nello stato iniziale Aperta (statechart): gli altri stati li raggiunge il server.';

CREATE POLICY partita_update_organizzatore
    ON public.partita
    FOR UPDATE
    TO authenticated
    USING (giocatore_id = auth.uid())
    WITH CHECK (
        giocatore_id = auth.uid()
        AND (lega_id IS NULL OR public.e_membro_lega(lega_id))
    );

COMMENT ON POLICY partita_update_organizzatore ON public.partita IS
    'Solo l''organizzatore modifica o annulla la partita (RF_PAR_3); il WITH CHECK ripete le condizioni dell''INSERT, cosi'' non puo'' cederla ad altri ne'' spostarla in una lega altrui.';

-- ---------------------------------------------------------------------------
-- prenotazione
-- ---------------------------------------------------------------------------
-- Il client blocca lo slot alla creazione e lo libera all'annullamento (D6); la
-- conferma la fa il server (D26). Gli importi li ricalcolera' un trigger di
-- KCK-271: qui non si toccano.

CREATE POLICY prenotazione_select_coinvolti
    ON public.prenotazione
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1
            FROM public.partita
            WHERE partita.id = prenotazione.partita_id
              AND partita.giocatore_id = auth.uid()
        )
        OR public.partecipa_a_partita(partita_id)
        OR EXISTS (
            SELECT 1
            FROM public.campo
            WHERE campo.id = prenotazione.campo_id
              AND campo.gestore_campo_id = auth.uid()
        )
    );

COMMENT ON POLICY prenotazione_select_coinvolti ON public.prenotazione IS
    'La prenotazione e'' visibile all''organizzatore, ai partecipanti (quote in DettaglioPartita) e al Gestore del campo, che riceve le prenotazioni (RAD §3.1.1).';

CREATE POLICY prenotazione_insert_organizzatore
    ON public.prenotazione
    FOR INSERT
    TO authenticated
    WITH CHECK (
        stato_blocco = 'bloccato'
        AND EXISTS (
            SELECT 1
            FROM public.partita
            WHERE partita.id = prenotazione.partita_id
              AND partita.giocatore_id = auth.uid()
        )
    );

COMMENT ON POLICY prenotazione_insert_organizzatore ON public.prenotazione IS
    'Solo l''organizzatore della partita crea la prenotazione, e solo come blocco temporaneo dello slot (PrenotazioneControl): la conferma la fa il server (D26).';

CREATE POLICY prenotazione_update_organizzatore_libera
    ON public.prenotazione
    FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1
            FROM public.partita
            WHERE partita.id = prenotazione.partita_id
              AND partita.giocatore_id = auth.uid()
        )
    )
    WITH CHECK (
        stato_blocco = 'liberato'
        AND EXISTS (
            SELECT 1
            FROM public.partita
            WHERE partita.id = prenotazione.partita_id
              AND partita.giocatore_id = auth.uid()
              AND partita.stato = 'Annullata'
        )
    );

-- La condizione sullo stato sta nella stessa sottoquery sull'organizzatore:
-- l'organizzatore vede sempre le proprie partite (partita_select_visibile), quindi
-- non serve una funzione SECURITY DEFINER e non c'e' ricorsione, perche' le
-- policy di partita non leggono prenotazione.
COMMENT ON POLICY prenotazione_update_organizzatore_libera ON public.prenotazione IS
    'L''organizzatore puo'' solo liberare lo slot, e solo dopo che la partita e'' passata ad Annullata (D6): altrimenti potrebbe liberare lo slot di una partita ancora Confermata e permettere una seconda prenotazione dello stesso campo. Il GRANT per colonna limita l''UPDATE a stato_blocco e scadenza_blocco (D24, nessun valore economico), gli importi restano esclusi.';

-- scadenza_blocco e' nel GRANT perche' chi libera lo slot azzera anche la
-- scadenza (D24); il WITH CHECK su 'liberato' impedisce di usarla per prolungare
-- un blocco.
REVOKE UPDATE ON public.prenotazione FROM authenticated, anon;
GRANT UPDATE (stato_blocco, scadenza_blocco) ON public.prenotazione TO authenticated;

-- ---------------------------------------------------------------------------
-- partecipazione
-- ---------------------------------------------------------------------------
-- partecipazione_select_own (KCK-233, migration rls_c) resta: le policy
-- permissive si sommano. L'RSVP lo scrive l'Edge Function con la service role
-- (migration B, DG3): dal client solo gol e assist dell'organizzatore (D2), con
-- il trigger della sezione 3.

CREATE POLICY partecipazione_select_visibile
    ON public.partecipazione
    FOR SELECT
    TO authenticated
    USING (
        public.partecipa_a_partita(partita_id)
        OR EXISTS (
            SELECT 1
            FROM public.partita
            WHERE partita.id = partecipazione.partita_id
              AND (
                  partita.giocatore_id = auth.uid()
                  OR partita.privacy = 'pubblica'
                  OR (partita.lega_id IS NOT NULL AND public.e_membro_lega(partita.lega_id))
              )
        )
    );

COMMENT ON POLICY partecipazione_select_visibile ON public.partecipazione IS
    'Vedono le partecipazioni: chi partecipa alla stessa partita (DettaglioPartita, FormVotoMVP), l''organizzatore, i membri della lega della partita (RF_LEG_4) e, per le partite pubbliche, tutti gli autenticati (conteggio dei posti, KCK-203).';

CREATE POLICY partecipazione_update_organizzatore
    ON public.partecipazione
    FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1
            FROM public.partita
            WHERE partita.id = partecipazione.partita_id
              AND partita.giocatore_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1
            FROM public.partita
            WHERE partita.id = partecipazione.partita_id
              AND partita.giocatore_id = auth.uid()
        )
    );

COMMENT ON POLICY partecipazione_update_organizzatore ON public.partecipazione IS
    'Solo l''organizzatore aggiorna le partecipazioni della propria partita; il GRANT per colonna limita l''UPDATE a gol e assist (D2).';

REVOKE INSERT, UPDATE, DELETE ON public.partecipazione FROM authenticated, anon;
GRANT UPDATE (gol_partita, assist_partita) ON public.partecipazione TO authenticated;

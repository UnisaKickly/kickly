-- RLS delle Tabelle C (KCK-233): protegge voti, notifiche, quote e transazioni
-- usando l'identita dell'utente autenticato. DG1 evita dati sensibili nell'app;
-- DG2 impedisce che il client possa alterare direttamente gli esiti dei pagamenti.

-- Le cinque tabelle C devono avere RLS attiva esplicitamente anche prima delle policy.
ALTER TABLE public.votazione_mvp ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.preferenza_voto_mvp ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifica ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quota ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transazione ENABLE ROW LEVEL SECURITY;

CREATE POLICY votazione_mvp_select_authenticated
    ON public.votazione_mvp
    FOR SELECT
    TO authenticated
    USING (true);

COMMENT ON POLICY votazione_mvp_select_authenticated ON public.votazione_mvp IS
    'Consente agli utenti autenticati di consultare le votazioni MVP, senza concedere scritture lato client.';

-- La privacy stretta del voto richiede che lettura e modifica restino sul votante.
CREATE POLICY preferenza_voto_mvp_select_own
    ON public.preferenza_voto_mvp
    FOR SELECT
    TO authenticated
    USING (votante_id = auth.uid());

COMMENT ON POLICY preferenza_voto_mvp_select_own ON public.preferenza_voto_mvp IS
    'Ogni votante puo'' leggere solo la preferenza MVP che ha registrato lui.';

CREATE POLICY preferenza_voto_mvp_insert_own
    ON public.preferenza_voto_mvp
    FOR INSERT
    TO authenticated
    WITH CHECK (votante_id = auth.uid());

COMMENT ON POLICY preferenza_voto_mvp_insert_own ON public.preferenza_voto_mvp IS
    'Un inserimento voto e'' valido solo se la riga appartiene al votante autenticato.';

CREATE POLICY preferenza_voto_mvp_update_own
    ON public.preferenza_voto_mvp
    FOR UPDATE
    TO authenticated
    USING (votante_id = auth.uid())
    WITH CHECK (votante_id = auth.uid());

COMMENT ON POLICY preferenza_voto_mvp_update_own ON public.preferenza_voto_mvp IS
    'USING e WITH CHECK impediscono sia la modifica dei voti altrui sia il cambio del proprietario del voto.';

CREATE POLICY preferenza_voto_mvp_delete_own
    ON public.preferenza_voto_mvp
    FOR DELETE
    TO authenticated
    USING (votante_id = auth.uid());

COMMENT ON POLICY preferenza_voto_mvp_delete_own ON public.preferenza_voto_mvp IS
    'L''utente autenticato puo'' cancellare solo la propria preferenza MVP.';

-- La partecipazione deve essere leggibile dal proprietario per poter verificare
-- la relazione Quota -> Partecipazione nelle policy RLS.
CREATE POLICY partecipazione_select_own
    ON public.partecipazione
    FOR SELECT
    TO authenticated
    USING (giocatore_id = auth.uid());

COMMENT ON POLICY partecipazione_select_own ON public.partecipazione IS
    'Espone al Giocatore solo le proprie partecipazioni, rendendo sicura la successiva lettura delle quote.';

CREATE POLICY notifica_select_own
    ON public.notifica
    FOR SELECT
    TO authenticated
    USING (account_id = auth.uid());

COMMENT ON POLICY notifica_select_own ON public.notifica IS
    'Limita la lettura delle notifiche all''Account a cui sono state indirizzate.';

CREATE POLICY notifica_update_own
    ON public.notifica
    FOR UPDATE
    TO authenticated
    USING (account_id = auth.uid())
    WITH CHECK (account_id = auth.uid());

COMMENT ON POLICY notifica_update_own ON public.notifica IS
    'Permette a NotificaControl di aggiornare lo stato di lettura solo sulla propria notifica.';

CREATE POLICY quota_select_own
    ON public.quota
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1
            FROM public.partecipazione
            WHERE partecipazione.id = quota.partecipazione_id
              AND partecipazione.giocatore_id = auth.uid()
        )
    );

COMMENT ON POLICY quota_select_own ON public.quota IS
    'Una quota e'' visibile solo al Giocatore proprietario della Partecipazione collegata.';

CREATE POLICY transazione_select_own_quota
    ON public.transazione
    FOR SELECT
    TO authenticated
    USING (
        quota_id IS NOT NULL
        AND EXISTS (
            SELECT 1
            FROM public.quota
            JOIN public.partecipazione
              ON partecipazione.id = quota.partecipazione_id
            WHERE quota.id = transazione.quota_id
              AND partecipazione.giocatore_id = auth.uid()
        )
    );

COMMENT ON POLICY transazione_select_own_quota ON public.transazione IS
    'Il pagatore puo'' consultare solo le transazioni associate alle proprie quote.';

CREATE POLICY transazione_select_gestore_accredito
    ON public.transazione
    FOR SELECT
    TO authenticated
    USING (
        gestore_campo_id IS NOT NULL
        AND gestore_campo_id = auth.uid()
    );

COMMENT ON POLICY transazione_select_gestore_accredito ON public.transazione IS
    'Il GestoreCampo puo'' consultare solo gli accrediti associati al proprio account.';

-- La separazione di privilegi impedisce al client di inserire, aggiornare o
-- cancellare transazioni anche se una policy viene configurata in modo errato.
REVOKE INSERT, UPDATE, DELETE ON public.transazione FROM authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.transazione FROM anon;

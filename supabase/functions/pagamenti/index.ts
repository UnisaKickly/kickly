// Edge Function `pagamenti` (KCK-225): onboarding Stripe Connect del Gestore del
// Campo e creazione del pagamento della Quota, in modalita' test.
//
// Perche' sul server: la chiave segreta di Stripe resta solo lato server e
// l'importo lo decide il server, mai il client (DG1 Sicurezza dei dati di
// pagamento, trade-off SDD v1.4 §1.3, mapping §3.3, RNF_IN_1). Nessun dato di
// carta o IBAN passa di qui: il Giocatore paga sulla pagina Checkout di Stripe e
// del Gestore si salva solo l'identificativo dell'account (idAccountPagamenti).
//
// Azioni (campo `azione` del corpo JSON):
// - `onboarding_gestore`: collega l'account Stripe del Gestore (D3).
// - `crea_pagamento`: crea la Checkout Session della Quota (RF_PAG_1, UC_PAG_1)
//   e registra la Transazione `pagamento` in_attesa. Il webhook che la completa
//   e mette la Quota a `versata` e' KCK-231.

import { createClient } from "jsr:@supabase/supabase-js@2.119.0";
import {
  collegaAccountGestore,
  creaSessioneCheckout,
  ErroreStripe,
  type Fetch,
  leggiSessioneCheckout,
  type SessioneCheckout,
} from "./stripe_api.ts";

/** Configurazione letta dalle variabili d'ambiente. Nessun valore nel codice. */
export interface Configurazione {
  chiaveSegretaStripe: string;
  urlSuccesso: string;
  urlAnnullamento: string;
  urlRitornoAccount: string;
  urlAggiornamentoAccount: string;
  /** Origine ammessa dal CORS, ricavata da STRIPE_SUCCESS_URL. */
  origineConsentita: string;
}

/** Quota letta dal DB insieme a Partecipazione e Partita (entry condition UC_PAG_1). */
export interface DatiQuota {
  id: string;
  /** numeric di PostgreSQL: puo' arrivare come numero o come stringa. */
  importo: unknown;
  statoVersamento: string;
  termineVersamento: string;
  giocatoreId: string;
  rispostaStato: string;
  partitaId: string;
  statoPartita: string;
}

/** Transazione di tipo `pagamento` di una Quota. */
export interface TransazionePagamento {
  id: string;
  stato: string;
  riferimentoEsterno: string;
}

/**
 * Tutto cio' che la funzione usa dall'esterno. Viene iniettato perche' i test
 * possano sostituire Stripe (`fetch`), il DB e l'autenticazione con dei finti.
 */
export interface Dipendenze {
  env: (nome: string) => string | undefined;
  fetch: Fetch;
  adesso: () => Date;
  /** Restituisce l'id dell'Account del JWT, o null se il token non e' valido. */
  leggiUtente: (token: string) => Promise<string | null>;
  leggiQuota: (quotaId: string) => Promise<DatiQuota | null>;
  leggiPagamentiQuota: (quotaId: string) => Promise<TransazionePagamento[]>;
  /** Restituisce "conflitto" se il DB rifiuta l'inserimento con 23505. */
  creaTransazione: (dati: {
    quotaId: string;
    importo: number;
    riferimentoEsterno: string;
  }) => Promise<"creata" | "conflitto">;
  /** `dataEsito` e' l'istante della richiesta (Dipendenze.adesso). */
  segnaTransazioneFallita: (
    transazioneId: string,
    dataEsito: Date,
  ) => Promise<void>;
  leggiGestoreCampo: (
    accountId: string,
  ) => Promise<{ idAccountPagamenti: string | null } | null>;
  salvaIdAccountPagamenti: (
    accountId: string,
    idAccountPagamenti: string,
  ) => Promise<void>;
}

/**
 * Legge e valida la configurazione.
 *
 * Restituisce null se manca una variabile, se un URL non e' valido o se la chiave
 * non e' di test (`sk_test_`): cosi' la funzione non chiama mai Stripe con una
 * chiave live o assente. L'origine del CORS si ricava da STRIPE_SUCCESS_URL
 * (decisione dei PM su KCK-225), per non scrivere indirizzi nel codice.
 */
export function leggiConfigurazione(
  env: (nome: string) => string | undefined,
): Configurazione | null {
  const chiaveSegretaStripe = env("STRIPE_SECRET_KEY");
  const urlSuccesso = env("STRIPE_SUCCESS_URL");
  const urlAnnullamento = env("STRIPE_CANCEL_URL");
  const urlRitornoAccount = env("STRIPE_ACCOUNT_RETURN_URL");
  const urlAggiornamentoAccount = env("STRIPE_ACCOUNT_REFRESH_URL");
  if (
    !chiaveSegretaStripe?.startsWith("sk_test_") ||
    !urlSuccesso || !urlAnnullamento || !urlRitornoAccount ||
    !urlAggiornamentoAccount
  ) {
    return null;
  }
  let origineConsentita: string;
  try {
    origineConsentita = new URL(urlSuccesso).origin;
  } catch {
    return null;
  }
  return {
    chiaveSegretaStripe,
    urlSuccesso,
    urlAnnullamento,
    urlRitornoAccount,
    urlAggiornamentoAccount,
    origineConsentita,
  };
}

/**
 * Punto d'ingresso della funzione: CORS, configurazione, autenticazione e
 * smistamento sull'azione richiesta.
 *
 * Ogni errore inatteso diventa un 500 generico: nei log e nelle risposte non
 * finiscono mai la chiave di Stripe ne' i dettagli delle risposte di Stripe.
 */
export async function gestisciRichiesta(
  req: Request,
  dipendenze: Dipendenze,
): Promise<Response> {
  const configurazione = leggiConfigurazione(dipendenze.env);
  if (configurazione === null) {
    console.error("pagamenti: configurazione non valida");
    return rispondiErrore(
      500,
      "configurazione_non_valida",
      "configurazione non valida",
      null,
    );
  }
  const origine = configurazione.origineConsentita;

  // Preflight CORS della versione web dell'app (GitHub Pages).
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: intestazioniCors(origine),
    });
  }
  if (req.method !== "POST") {
    return rispondiErrore(
      405,
      "metodo_non_ammesso",
      "metodo non ammesso",
      origine,
    );
  }

  // Tutto cio' che segue e' dentro il try, autenticazione compresa: anche un
  // errore di leggiUtente diventa una risposta con gli header CORS.
  try {
    const token = req.headers.get("Authorization")?.replace(
      /^Bearer\s+/i,
      "",
    );
    const accountId = token ? await dipendenze.leggiUtente(token) : null;
    if (accountId === null) {
      return rispondiErrore(
        401,
        "non_autenticato",
        "utente non autenticato",
        origine,
      );
    }

    let corpo: Record<string, unknown>;
    try {
      const json = await req.json();
      if (typeof json !== "object" || json === null) throw new Error();
      corpo = json as Record<string, unknown>;
    } catch {
      return rispondiErrore(
        400,
        "richiesta_non_valida",
        "corpo della richiesta non valido",
        origine,
      );
    }

    switch (corpo.azione) {
      case "onboarding_gestore":
        return await onboardingGestore(accountId, configurazione, dipendenze);
      case "crea_pagamento":
        if (typeof corpo.quota_id !== "string" || corpo.quota_id === "") {
          return rispondiErrore(
            400,
            "richiesta_non_valida",
            "quota_id mancante",
            origine,
          );
        }
        return await creaPagamento(
          accountId,
          corpo.quota_id,
          configurazione,
          dipendenze,
        );
      default:
        return rispondiErrore(
          400,
          "azione_non_valida",
          "azione sconosciuta",
          origine,
        );
    }
  } catch (errore) {
    if (errore instanceof ErroreStripe) {
      // Errore Stripe o rete interrotta (E2): nessuna transazione completata e la
      // Quota resta da_versare (DG2). Si logga solo lo stato HTTP.
      console.error(
        `pagamenti: errore Stripe (stato ${errore.stato ?? "rete"})`,
      );
      return rispondiErrore(
        502,
        "servizio_pagamento_non_disponibile",
        "servizio di pagamento non disponibile, riprova",
        origine,
      );
    }
    console.error(
      "pagamenti: errore interno",
      errore instanceof Error ? errore.name : "",
    );
    return rispondiErrore(500, "errore_interno", "errore interno", origine);
  }
}

/**
 * Durata della finestra delle chiavi di idempotenza (pagamento e onboarding):
 * 10 minuti. Serve perche' Stripe conserva per 24 ore anche le risposte 500
 * associate a una chiave: con la finestra, dopo un errore si puo' riprovare
 * dalla finestra successiva (decisione dei PM su KCK-225).
 */
const FINESTRA_IDEMPOTENZA_MS = 600_000;

/**
 * Azione `onboarding_gestore` (D3, RF_PAG_2).
 *
 * Ordine delle chiamate (non c'e' sequence diagram):
 * 1. leggiGestoreCampo(): solo un Gestore del Campo puo' collegare un account;
 * 2. collegaAccountGestore(): se manca l'account lo crea su Stripe con la chiave
 *    `onboarding_<account_id>_<finestra>` e lo fa salvare con
 *    salvaIdAccountPagamenti() prima di chiedere il link;
 * 3. risposta con l'URL dell'onboarding ospitato da Stripe.
 */
async function onboardingGestore(
  accountId: string,
  configurazione: Configurazione,
  dipendenze: Dipendenze,
): Promise<Response> {
  const origine = configurazione.origineConsentita;
  const gestore = await dipendenze.leggiGestoreCampo(accountId);
  if (gestore === null) {
    return rispondiErrore(
      403,
      "non_gestore",
      "solo il Gestore del Campo puo' collegare un account",
      origine,
    );
  }

  const collegamento = await collegaAccountGestore(
    dipendenze.fetch,
    configurazione.chiaveSegretaStripe,
    {
      idAccountPagamenti: gestore.idAccountPagamenti,
      urlRitorno: configurazione.urlRitornoAccount,
      urlAggiornamento: configurazione.urlAggiornamentoAccount,
      // Stessa finestra di 10 minuti del pagamento, stesso orologio iniettato.
      // Un account creato su Stripe ma non salvato (errore tra le due finestre)
      // resta orfano solo in modalita' test e non ha effetti; una volta salvato,
      // idAccountPagamenti impedisce altri duplicati.
      chiaveIdempotenza: `onboarding_${accountId}_${
        Math.floor(dipendenze.adesso().getTime() / FINESTRA_IDEMPOTENZA_MS)
      }`,
      salvaIdAccount: (id) => dipendenze.salvaIdAccountPagamenti(accountId, id),
    },
  );
  return rispondi(200, { url: collegamento.url }, origine);
}

/**
 * Azione `crea_pagamento` (RF_PAG_1, UC_PAG_1, D25, D27).
 *
 * Ordine delle chiamate:
 * 1. leggiQuota(): verifica le entry condition di UC_PAG_1 (Quota del chiamante,
 *    iscritto, partita Completa, Quota da_versare, termine non scaduto);
 * 2. leggiPagamentiQuota(): se c'e' un pagamento completata si risponde
 *    "pagamento in verifica" senza chiamare Stripe; se ce n'e' uno in_attesa si guarda la
 *    sessione su Stripe (open: stesso URL; complete: si attende il webhook di
 *    KCK-231; expired o non trovata da Stripe (404 resource_missing): la
 *    transazione diventa fallita e se ne crea una nuova);
 * 3. creaSessioneCheckout() con l'importo letto dal DB e la chiave di idempotenza
 *    `pagamento_<quota_id>_<n>_<finestra>`, n = pagamenti falliti della Quota,
 *    finestra = adesso / 10 minuti;
 * 4. creaTransazione() `pagamento` in_attesa con riferimento = id della sessione.
 */
async function creaPagamento(
  accountId: string,
  quotaId: string,
  configurazione: Configurazione,
  dipendenze: Dipendenze,
): Promise<Response> {
  const origine = configurazione.origineConsentita;
  const chiave = configurazione.chiaveSegretaStripe;

  // 1. Entry condition di UC_PAG_1. Una Quota di un altro Giocatore risponde come
  //    una Quota inesistente, per non rivelarne l'esistenza.
  const quota = await dipendenze.leggiQuota(quotaId);
  if (quota === null || quota.giocatoreId !== accountId) {
    return rispondiErrore(
      404,
      "quota_non_trovata",
      "quota non trovata",
      origine,
    );
  }
  if (quota.rispostaStato !== "confermata") {
    return rispondiErrore(
      409,
      "non_iscritto",
      "non risulti iscritto alla partita",
      origine,
    );
  }
  if (quota.statoPartita !== "Completa") {
    return rispondiErrore(
      409,
      "partita_non_completa",
      "la partita non e' nello stato Completa",
      origine,
    );
  }
  // versata e rimborsata hanno codici distinti: una Quota rimborsata non e'
  // "gia' versata". Ogni altro valore e' escluso dal CHECK del DB (D25), quindi
  // e' un guasto del server e diventa errore_interno.
  if (quota.statoVersamento === "versata") {
    return rispondiErrore(
      409,
      "quota_gia_versata",
      "la quota non e' da versare",
      origine,
    );
  }
  if (quota.statoVersamento === "rimborsata") {
    return rispondiErrore(
      409,
      "quota_rimborsata",
      "la quota non e' da versare",
      origine,
    );
  }
  if (quota.statoVersamento !== "da_versare") {
    throw new Error("stato_versamento non ammesso");
  }
  const termine = new Date(quota.termineVersamento).getTime();
  if (Number.isNaN(termine)) {
    throw new Error("termine_versamento non valido");
  }
  // Un solo istante per tutta la richiesta: termine e finestra della chiave di
  // idempotenza si calcolano sullo stesso orologio (iniettato nei test).
  const adesso = dipendenze.adesso().getTime();
  if (termine <= adesso) {
    return rispondiErrore(
      409,
      "termine_scaduto",
      "il termine per il versamento e' scaduto",
      origine,
    );
  }

  // L'importo viene solo dal DB (D25: importo = quotaIndividuale); qualunque
  // importo mandato dal client e' ignorato. Se non e' un numero finito ci si
  // ferma prima di chiamare Stripe.
  const importo = Number(quota.importo);
  if (!Number.isFinite(importo)) {
    throw new Error("importo della quota non valido");
  }
  // Math.round esplicito: 8.29 * 100 in virgola mobile vale 828.999...
  const importoCentesimi = Math.round(importo * 100);

  // 2. Pagamento gia' avviato per questa Quota.
  const pagamenti = await dipendenze.leggiPagamentiQuota(quotaId);
  // Pagamento gia' completato su Stripe ma Quota non ancora versata: si attende
  // il webhook di KCK-231 senza chiamare Stripe, per non creare una seconda
  // sessione per la stessa Quota (DG2).
  if (pagamenti.some((t) => t.stato === "completata")) {
    return rispostaPagamentoInVerifica(origine);
  }
  let falliti = pagamenti.filter((t) => t.stato === "fallita").length;
  const inAttesa = pagamenti.find((t) => t.stato === "in_attesa");
  if (inAttesa !== undefined) {
    const sessione = await leggiSessioneSeEsiste(
      dipendenze,
      chiave,
      inAttesa.riferimentoEsterno,
    );
    if (sessione !== null && sessione.status !== "expired") {
      return rispostaSessioneEsistente(sessione, origine);
    }
    // Sessione scaduta o che Stripe non trova: non ha addebitato nulla, il
    // Giocatore puo' riprovare.
    await dipendenze.segnaTransazioneFallita(inAttesa.id, new Date(adesso));
    falliti += 1;
  }

  // 3. Nuova sessione. Chiave `pagamento_<quota_id>_<n>_<finestra>` (decisione
  //    dei PM su KCK-225): una richiesta ripetuta nella stessa finestra di 10
  //    minuti riceve da Stripe la stessa sessione (DG2); n cresce dopo un
  //    pagamento fallito. La finestra serve perche' Stripe conserva per 24 ore
  //    anche le risposte 500 associate a una chiave: senza finestra, dopo un 500
  //    il Giocatore non potrebbe riprovare per un giorno. Il doppio URL tra due
  //    finestre lo impedisce l'indice univoco su transazione (un solo pagamento
  //    non fallito per Quota, D27) gestito al passo 4.
  const finestra = Math.floor(adesso / FINESTRA_IDEMPOTENZA_MS);
  const sessione = await creaSessioneCheckout(dipendenze.fetch, chiave, {
    importoCentesimi,
    quotaId,
    partitaId: quota.partitaId,
    urlSuccesso: configurazione.urlSuccesso,
    urlAnnullamento: configurazione.urlAnnullamento,
    chiaveIdempotenza: `pagamento_${quotaId}_${falliti}_${finestra}`,
  });

  // 4. Registrazione della Transazione in_attesa.
  const esito = await dipendenze.creaTransazione({
    quotaId,
    importo,
    riferimentoEsterno: sessione.id,
  });
  if (esito === "conflitto") {
    // Richiesta concorrente: l'indice univoco del DB ha gia' un pagamento non
    // fallito per la Quota. Se e' completata si attende il webhook; se e'
    // in_attesa si restituisce la sua sessione; negli altri casi la situazione
    // e' transitoria e un nuovo tentativo funziona (pagamento_in_corso).
    const riletti = await dipendenze.leggiPagamentiQuota(quotaId);
    if (riletti.some((t) => t.stato === "completata")) {
      return rispostaPagamentoInVerifica(origine);
    }
    const registrata = riletti.find((t) => t.stato === "in_attesa");
    if (registrata === undefined) {
      return rispostaPagamentoInCorso(origine);
    }
    const esistente = registrata.riferimentoEsterno === sessione.id
      ? sessione
      : await leggiSessioneCheckout(
        dipendenze.fetch,
        chiave,
        registrata.riferimentoEsterno,
      );
    if (esistente.status === "expired") {
      return rispostaPagamentoInCorso(origine);
    }
    return rispostaSessioneEsistente(esistente, origine);
  }

  return rispondi(200, { url: sessione.url }, origine);
}

/**
 * Legge la sessione di un pagamento in_attesa. Restituisce null se Stripe
 * risponde 404 con `error.code` = `resource_missing`: la sessione non esiste e
 * si tratta come scaduta (decisione dei PM su KCK-225). Ogni altro errore,
 * compreso un 404 con un altro codice, si propaga e diventa un 502.
 */
async function leggiSessioneSeEsiste(
  dipendenze: Dipendenze,
  chiave: string,
  idSessione: string,
): Promise<SessioneCheckout | null> {
  try {
    return await leggiSessioneCheckout(dipendenze.fetch, chiave, idSessione);
  } catch (errore) {
    if (
      errore instanceof ErroreStripe && errore.stato === 404 &&
      errore.codice === "resource_missing"
    ) {
      return null;
    }
    throw errore;
  }
}

/**
 * Risposta per una sessione gia' registrata e non scaduta: se e' aperta si
 * restituisce lo stesso URL; se e' completa non se ne crea un'altra e si attende
 * l'esito del webhook (KCK-231), per non addebitare due volte la Quota (DG2).
 */
function rispostaSessioneEsistente(
  sessione: SessioneCheckout,
  origine: string,
): Response {
  if (sessione.status === "complete") {
    return rispostaPagamentoInVerifica(origine);
  }
  return rispondi(200, { url: sessione.url }, origine);
}

/** Pagamento gia' completato su Stripe, in attesa del webhook di KCK-231. */
function rispostaPagamentoInVerifica(origine: string): Response {
  return rispondiErrore(
    409,
    "pagamento_in_verifica",
    "pagamento in verifica",
    origine,
  );
}

/** Richiesta concorrente in una situazione transitoria: si puo' riprovare. */
function rispostaPagamentoInCorso(origine: string): Response {
  return rispondiErrore(
    409,
    "pagamento_in_corso",
    "pagamento gia' in corso, riprova",
    origine,
  );
}

/** Header CORS: solo l'origine dell'app web, mai `*`. */
function intestazioniCors(origine: string): Record<string, string> {
  return {
    "Access-Control-Allow-Origin": origine,
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Vary": "Origin",
  };
}

/**
 * Codici stabili delle risposte di errore (decisione dei PM su KCK-225): l'app
 * decide cosa mostrare dal codice, non dal testo di `errore`. I testi per il
 * Giocatore sono di KCK-214.
 */
type CodiceErrore =
  | "richiesta_non_valida"
  | "metodo_non_ammesso"
  | "azione_non_valida"
  | "non_autenticato"
  | "non_gestore"
  | "quota_non_trovata"
  | "non_iscritto"
  | "partita_non_completa"
  | "termine_scaduto"
  | "quota_gia_versata"
  | "quota_rimborsata"
  | "pagamento_in_verifica"
  | "pagamento_in_corso"
  | "servizio_pagamento_non_disponibile"
  | "configurazione_non_valida"
  | "errore_interno";

/** Risposta di errore: `codice` stabile accanto al testo `errore`. */
function rispondiErrore(
  stato: number,
  codice: CodiceErrore,
  errore: string,
  origine: string | null,
): Response {
  return rispondi(stato, { codice, errore }, origine);
}

/** Risposta JSON con gli header CORS (assenti se la configurazione non e' valida). */
function rispondi(
  stato: number,
  corpo: Record<string, unknown>,
  origine: string | null,
): Response {
  return new Response(JSON.stringify(corpo), {
    status: stato,
    headers: {
      "Content-Type": "application/json",
      ...(origine === null ? {} : intestazioniCors(origine)),
    },
  });
}

/**
 * Dipendenze reali: client Supabase con il service role (le scritture su
 * transazione e gestore_campo non sono concesse al client dalle policy RLS) e
 * `fetch` vero verso Stripe. SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY li fornisce
 * il runtime delle Edge Functions.
 */
function creaDipendenzeSupabase(): Dipendenze {
  const url = Deno.env.get("SUPABASE_URL");
  const chiaveServizio = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !chiaveServizio) {
    throw new Error("SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY mancanti");
  }
  const db = createClient(url, chiaveServizio, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  return {
    env: (nome) => Deno.env.get(nome),
    fetch: (input, init) => fetch(input, init),
    adesso: () => new Date(),

    async leggiUtente(token) {
      const { data, error } = await db.auth.getUser(token);
      return error || !data.user ? null : data.user.id;
    },

    async leggiQuota(quotaId) {
      const { data, error } = await db
        .from("quota")
        .select(
          "id, importo, stato_versamento, termine_versamento, " +
            "partecipazione!inner(giocatore_id, risposta_stato, partita!inner(id, stato))",
        )
        .eq("id", quotaId)
        .maybeSingle();
      if (error) throw new Error(`leggiQuota: ${error.code}`);
      if (!data) return null;
      // deno-lint-ignore no-explicit-any
      const riga = data as any;
      return {
        id: riga.id,
        importo: riga.importo,
        statoVersamento: riga.stato_versamento,
        termineVersamento: riga.termine_versamento,
        giocatoreId: riga.partecipazione.giocatore_id,
        rispostaStato: riga.partecipazione.risposta_stato,
        partitaId: riga.partecipazione.partita.id,
        statoPartita: riga.partecipazione.partita.stato,
      };
    },

    async leggiPagamentiQuota(quotaId) {
      const { data, error } = await db
        .from("transazione")
        .select("id, stato, riferimento_esterno")
        .eq("quota_id", quotaId)
        .eq("tipo", "pagamento");
      if (error) throw new Error(`leggiPagamentiQuota: ${error.code}`);
      return (data ?? []).map((t) => ({
        id: t.id as string,
        stato: t.stato as string,
        riferimentoEsterno: t.riferimento_esterno as string,
      }));
    },

    async creaTransazione(dati) {
      const { error } = await db.from("transazione").insert({
        quota_id: dati.quotaId,
        tipo: "pagamento",
        importo: dati.importo,
        stato: "in_attesa",
        riferimento_esterno: dati.riferimentoEsterno,
      });
      if (error?.code === "23505") return "conflitto";
      if (error) throw new Error(`creaTransazione: ${error.code}`);
      return "creata";
    },

    async segnaTransazioneFallita(transazioneId, dataEsito) {
      const { error } = await db
        .from("transazione")
        .update({ stato: "fallita", data_esito: dataEsito.toISOString() })
        .eq("id", transazioneId)
        .eq("stato", "in_attesa");
      if (error) throw new Error(`segnaTransazioneFallita: ${error.code}`);
    },

    async leggiGestoreCampo(accountId) {
      const { data, error } = await db
        .from("gestore_campo")
        .select("id_account_pagamenti")
        .eq("account_id", accountId)
        .maybeSingle();
      if (error) throw new Error(`leggiGestoreCampo: ${error.code}`);
      return data
        ? {
          idAccountPagamenti: (data.id_account_pagamenti as string | null) ??
            null,
        }
        : null;
    },

    async salvaIdAccountPagamenti(accountId, idAccountPagamenti) {
      const { error } = await db
        .from("gestore_campo")
        .update({ id_account_pagamenti: idAccountPagamenti })
        .eq("account_id", accountId);
      if (error) throw new Error(`salvaIdAccountPagamenti: ${error.code}`);
    },
  };
}

// Avvio del server solo quando il file e' il modulo principale: i test importano
// gestisciRichiesta senza aprire porte.
if (import.meta.main) {
  const dipendenze = creaDipendenzeSupabase();
  Deno.serve((req) => gestisciRichiesta(req, dipendenze));
}

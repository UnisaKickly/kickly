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
  segnaTransazioneFallita: (transazioneId: string) => Promise<void>;
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
    return rispondi(500, { errore: "configurazione non valida" }, null);
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
    return rispondi(405, { errore: "metodo non ammesso" }, origine);
  }

  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  const accountId = token ? await dipendenze.leggiUtente(token) : null;
  if (accountId === null) {
    return rispondi(401, { errore: "utente non autenticato" }, origine);
  }

  let corpo: Record<string, unknown>;
  try {
    const json = await req.json();
    if (typeof json !== "object" || json === null) throw new Error();
    corpo = json as Record<string, unknown>;
  } catch {
    return rispondi(
      400,
      { errore: "corpo della richiesta non valido" },
      origine,
    );
  }

  try {
    switch (corpo.azione) {
      case "onboarding_gestore":
        return await onboardingGestore(accountId, configurazione, dipendenze);
      case "crea_pagamento":
        if (typeof corpo.quota_id !== "string" || corpo.quota_id === "") {
          return rispondi(400, { errore: "quota_id mancante" }, origine);
        }
        return await creaPagamento(
          accountId,
          corpo.quota_id,
          configurazione,
          dipendenze,
        );
      default:
        return rispondi(400, { errore: "azione sconosciuta" }, origine);
    }
  } catch (errore) {
    if (errore instanceof ErroreStripe) {
      // Errore Stripe o rete interrotta (E2): nessuna transazione completata e la
      // Quota resta da_versare (DG2). Si logga solo lo stato HTTP.
      console.error(
        `pagamenti: errore Stripe (stato ${errore.stato ?? "rete"})`,
      );
      return rispondi(
        502,
        { errore: "servizio di pagamento non disponibile, riprova" },
        origine,
      );
    }
    console.error(
      "pagamenti: errore interno",
      errore instanceof Error ? errore.name : "",
    );
    return rispondi(500, { errore: "errore interno" }, origine);
  }
}

/**
 * Azione `onboarding_gestore` (D3, RF_PAG_2).
 *
 * Ordine delle chiamate (non c'e' sequence diagram):
 * 1. leggiGestoreCampo(): solo un Gestore del Campo puo' collegare un account;
 * 2. collegaAccountGestore(): se manca l'account lo crea su Stripe e lo fa
 *    salvare con salvaIdAccountPagamenti() prima di chiedere il link;
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
    return rispondi(403, {
      errore: "solo il Gestore del Campo puo' collegare un account",
    }, origine);
  }

  const collegamento = await collegaAccountGestore(
    dipendenze.fetch,
    configurazione.chiaveSegretaStripe,
    {
      accountId,
      idAccountPagamenti: gestore.idAccountPagamenti,
      urlRitorno: configurazione.urlRitornoAccount,
      urlAggiornamento: configurazione.urlAggiornamentoAccount,
      salvaIdAccount: (id) => dipendenze.salvaIdAccountPagamenti(accountId, id),
    },
  );
  return rispondi(200, { url: collegamento.url }, origine);
}

/** Durata della finestra della chiave di idempotenza del pagamento: 10 minuti. */
const FINESTRA_IDEMPOTENZA_MS = 600_000;

/**
 * Azione `crea_pagamento` (RF_PAG_1, UC_PAG_1, D25, D27).
 *
 * Ordine delle chiamate:
 * 1. leggiQuota(): verifica le entry condition di UC_PAG_1 (Quota del chiamante,
 *    iscritto, partita Completa, Quota da_versare, termine non scaduto);
 * 2. leggiPagamentiQuota(): se c'e' gia' un pagamento in_attesa si guarda la
 *    sessione su Stripe (open: stesso URL; complete: si attende il webhook di
 *    KCK-231; expired: la transazione diventa fallita e se ne crea una nuova);
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
    return rispondi(404, { errore: "quota non trovata" }, origine);
  }
  if (quota.rispostaStato !== "confermata") {
    return rispondi(
      409,
      { errore: "non risulti iscritto alla partita" },
      origine,
    );
  }
  if (quota.statoPartita !== "Completa") {
    return rispondi(
      409,
      { errore: "la partita non e' nello stato Completa" },
      origine,
    );
  }
  if (quota.statoVersamento !== "da_versare") {
    return rispondi(409, { errore: "la quota non e' da versare" }, origine);
  }
  const termine = new Date(quota.termineVersamento).getTime();
  if (Number.isNaN(termine)) {
    throw new Error("termine_versamento non valido");
  }
  // Un solo istante per tutta la richiesta: termine e finestra della chiave di
  // idempotenza si calcolano sullo stesso orologio (iniettato nei test).
  const adesso = dipendenze.adesso().getTime();
  if (termine <= adesso) {
    return rispondi(
      409,
      { errore: "il termine per il versamento e' scaduto" },
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
  let falliti = pagamenti.filter((t) => t.stato === "fallita").length;
  const inAttesa = pagamenti.find((t) => t.stato === "in_attesa");
  if (inAttesa !== undefined) {
    const sessione = await leggiSessioneCheckout(
      dipendenze.fetch,
      chiave,
      inAttesa.riferimentoEsterno,
    );
    if (sessione.status !== "expired") {
      return rispostaSessioneEsistente(sessione, origine);
    }
    // Sessione scaduta: non ha addebitato nulla, il Giocatore puo' riprovare.
    await dipendenze.segnaTransazioneFallita(inAttesa.id);
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
    // Richiesta concorrente: l'indice univoco del DB ha gia' una Transazione
    // in_attesa per la Quota. Si restituisce la sessione gia' registrata.
    const registrata = (await dipendenze.leggiPagamentiQuota(quotaId))
      .find((t) => t.stato === "in_attesa");
    if (registrata === undefined) {
      return rispondi(
        409,
        { errore: "pagamento gia' in corso, riprova" },
        origine,
      );
    }
    const esistente = registrata.riferimentoEsterno === sessione.id
      ? sessione
      : await leggiSessioneCheckout(
        dipendenze.fetch,
        chiave,
        registrata.riferimentoEsterno,
      );
    if (esistente.status === "expired") {
      return rispondi(
        409,
        { errore: "pagamento gia' in corso, riprova" },
        origine,
      );
    }
    return rispostaSessioneEsistente(esistente, origine);
  }

  return rispondi(200, { url: sessione.url }, origine);
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
    return rispondi(409, { errore: "pagamento in verifica" }, origine);
  }
  return rispondi(200, { url: sessione.url }, origine);
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

    async segnaTransazioneFallita(transazioneId) {
      const { error } = await db
        .from("transazione")
        .update({ stato: "fallita", data_esito: new Date().toISOString() })
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

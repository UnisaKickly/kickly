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

import { createClient } from "jsr:@supabase/supabase-js@2.119.0";
import {
  collegaAccountGestore,
  ErroreStripe,
  type Fetch,
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

/**
 * Tutto cio' che la funzione usa dall'esterno. Viene iniettato perche' i test
 * possano sostituire Stripe (`fetch`), il DB e l'autenticazione con dei finti.
 */
export interface Dipendenze {
  env: (nome: string) => string | undefined;
  fetch: Fetch;
  /** Restituisce l'id dell'Account del JWT, o null se il token non e' valido. */
  leggiUtente: (token: string) => Promise<string | null>;
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

    async leggiUtente(token) {
      const { data, error } = await db.auth.getUser(token);
      return error || !data.user ? null : data.user.id;
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

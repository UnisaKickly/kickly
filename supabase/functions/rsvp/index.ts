// Edge Function RSVP (KCK-219): realizza GestionePartecipazioneControl lato server.
// Autentica il Giocatore, valida la richiesta e delega l'aggiornamento atomico
// alla funzione PostgreSQL gestisci_rsvp. La chiave service role e le risorse
// esterne restano nell'ambiente; non vengono mai inserite nel repository.

import { createClient } from "jsr:@supabase/supabase-js@2.119.0";

/** Formato UUID delle entity Partita e Account/Giocatore. */
const FORMATO_UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Esito restituito dalla funzione SQL transazionale gestisci_rsvp. */
export interface EsitoRsvp {
  esito: string;
  posti_rimasti: number | null;
  stato_partita: string | null;
}

/** Dipendenze esterne iniettate: autentica e invoca la transazione PostgreSQL. */
export interface DipendenzeRsvp {
  env: (nome: string) => string | undefined;
  leggiUtente: (token: string) => Promise<string | null>;
  gestisciRsvp: (
    partitaId: string,
    giocatoreId: string,
    risposta: "conferma" | "ritiro",
  ) => Promise<EsitoRsvp | null>;
}

/**
 * Legge la configurazione delle Edge Functions senza conservare segreti nel codice.
 * L'origine CORS e' una variabile d'ambiente, cosi' il dominio web resta sostituibile.
 */
export function leggiConfigurazioneRsvp(
  env: (nome: string) => string | undefined,
): { origine: string } | null {
  const origine = env("RSVP_ALLOWED_ORIGIN");
  if (!origine) return null;
  try {
    return { origine: new URL(origine).origin };
  } catch {
    return null;
  }
}

/**
 * Punto d'ingresso HTTP: gestisce CORS, autenticazione, validazione e RPC.
 * Ogni risposta JSON contiene `posti_rimasti`, anche con valore null quando il
 * contesto non consente di conoscere il conteggio (autenticazione o JSON non valido).
 */
export async function gestisciRichiestaRsvp(
  req: Request,
  dipendenze: DipendenzeRsvp,
): Promise<Response> {
  const configurazione = leggiConfigurazioneRsvp(dipendenze.env);
  if (configurazione === null) {
    console.error("rsvp: configurazione non valida");
    return rispondiRsvp(500, { codice: "configurazione_non_valida", error: "configurazione non valida", posti_rimasti: null }, null);
  }
  const origine = configurazione.origine;

  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: intestazioniCors(origine) });
  }
  if (req.method !== "POST") {
    return rispondiRsvp(405, { codice: "metodo_non_ammesso", error: "metodo non ammesso", posti_rimasti: null }, origine);
  }

  try {
    const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
    const giocatoreId = token ? await dipendenze.leggiUtente(token) : null;
    if (!giocatoreId) {
      return rispondiRsvp(401, { codice: "non_autenticato", error: "utente non autenticato", posti_rimasti: null }, origine);
    }

    let corpo: Record<string, unknown>;
    try {
      const json = await req.json();
      if (typeof json !== "object" || json === null || Array.isArray(json)) throw new Error();
      corpo = json as Record<string, unknown>;
    } catch {
      return rispondiRsvp(400, { codice: "richiesta_non_valida", error: "corpo della richiesta non valido", posti_rimasti: null }, origine);
    }

    if (typeof corpo.partita_id !== "string" || !FORMATO_UUID.test(corpo.partita_id)) {
      return rispondiRsvp(400, { codice: "richiesta_non_valida", error: "partita_id mancante o non valido", posti_rimasti: null }, origine);
    }
    if (corpo.risposta !== "conferma" && corpo.risposta !== "ritiro") {
      return rispondiRsvp(400, { codice: "risposta_non_valida", error: "risposta RSVP non valida", posti_rimasti: null }, origine);
    }

    const esito = await dipendenze.gestisciRsvp(
      corpo.partita_id,
      giocatoreId,
      corpo.risposta,
    );
    if (esito === null) {
      return rispondiRsvp(404, { codice: "partita_non_trovata", error: "partita non trovata", posti_rimasti: null }, origine);
    }

    if (esito.esito === "partita_al_completo") {
      return rispondiRsvp(409, {
        codice: "partita_al_completo",
        error: "Partita al completo",
        posti_rimasti: esito.posti_rimasti,
        stato_partita: esito.stato_partita,
      }, origine);
    }
    if (esito.esito === "partita_non_aperta") {
      return rispondiRsvp(409, {
        codice: "partita_non_aperta",
        error: "la partita non accetta RSVP",
        posti_rimasti: esito.posti_rimasti,
        stato_partita: esito.stato_partita,
      }, origine);
    }

    if (esito.esito === "partita_non_trovata") {
      return rispondiRsvp(404, { codice: "partita_non_trovata", error: "partita non trovata", posti_rimasti: null }, origine);
    }

    return rispondiRsvp(200, {
      esito: esito.esito,
      posti_rimasti: esito.posti_rimasti,
      stato_partita: esito.stato_partita,
    }, origine);
  } catch (errore) {
    console.error("rsvp: errore interno", errore instanceof Error ? errore.name : "");
    return rispondiRsvp(500, { codice: "errore_interno", error: "errore interno", posti_rimasti: null }, origine);
  }
}

/** Header CORS restrittivi: il dominio consentito viene dalla configurazione. */
function intestazioniCors(origine: string): HeadersInit {
  return {
    "Access-Control-Allow-Origin": origine,
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "authorization, content-type",
  };
}

/** Serializza una risposta JSON aggiungendo CORS e mantenendo posti_rimasti. */
function rispondiRsvp(
  stato: number,
  corpo: Record<string, unknown>,
  origine: string | null,
): Response {
  if (!("posti_rimasti" in corpo)) corpo.posti_rimasti = null;
  return new Response(JSON.stringify(corpo), {
    status: stato,
    headers: {
      "Content-Type": "application/json",
      ...(origine === null ? {} : intestazioniCors(origine)),
    },
  });
}

/** Costruisce le dipendenze reali con la service role fornita dal runtime. */
function creaDipendenzeRsvp(): DipendenzeRsvp {
  const url = Deno.env.get("SUPABASE_URL");
  const chiaveServizio = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !chiaveServizio) throw new Error("SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY mancanti");

  const db = createClient(url, chiaveServizio, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  return {
    env: (nome) => Deno.env.get(nome),
    async leggiUtente(token) {
      const { data, error } = await db.auth.getUser(token);
      return error || !data.user ? null : data.user.id;
    },
    async gestisciRsvp(partitaId, giocatoreId, risposta) {
      const { data, error } = await db.rpc("gestisci_rsvp", {
        p_partita_id: partitaId,
        p_giocatore_id: giocatoreId,
        p_risposta: risposta,
      });
      if (error) throw new Error(`gestisci_rsvp: ${error.code}`);
      if (!Array.isArray(data) || data.length !== 1) return null;
      const riga = data[0] as Record<string, unknown>;
      return {
        esito: riga.esito as string,
        posti_rimasti: riga.posti_rimasti as number | null,
        stato_partita: riga.stato_partita as string | null,
      };
    },
  };
}

// Avvio del server senza interferire con i test, che importano gestisciRichiestaRsvp.
if (import.meta.main) {
  const dipendenze = creaDipendenzeRsvp();
  Deno.serve((req) => gestisciRichiestaRsvp(req, dipendenze));
}

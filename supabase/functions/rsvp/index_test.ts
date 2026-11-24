// Test Deno dell'Edge Function RSVP (KCK-219).
// Il database e' simulato con una coda atomica in memoria: tutte le richieste
// concorrenti si serializzano prima di contare i confermati, come il lock
// PostgreSQL FOR UPDATE della migration. Gli esiti vengono dalle entry condition
// TF_PAR_04–TF_PAR_09 del category partition, non dal comportamento dell'impl.

import assert from "node:assert/strict";
import {
  type DipendenzeRsvp,
  type EsitoRsvp,
  gestisciRichiestaRsvp,
} from "./index.ts";

/** Identificatori fittizi validi nel formato UUID accettato dalla funzione. */
const PARTITA = "21900000-0000-4000-8000-000000000001";
const G1 = "21900000-0000-4000-8000-000000000101";
const G2 = "21900000-0000-4000-8000-000000000102";
const G3 = "21900000-0000-4000-8000-000000000103";

/** Ambiente atomico fittizio: la coda garantisce un solo aggiornamento alla volta. */
interface AmbienteRsvp {
  dipendenze: DipendenzeRsvp;
  posti: number;
  stato: "Aperta" | "Completa";
  confermati: Set<string>;
  ritirati: Set<string>;
}

/** Crea un ambiente con M posti e una coda di mutazioni serializzate. */
function creaAmbiente(posti: number): AmbienteRsvp {
  const confermati = new Set<string>();
  const ritirati = new Set<string>();
  let coda: Promise<void> = Promise.resolve();

  const ambiente: AmbienteRsvp = {
    posti,
    stato: "Aperta",
    confermati,
    ritirati,
    dipendenze: undefined as unknown as DipendenzeRsvp,
  };

  ambiente.dipendenze = {
    env: (nome) => nome === "RSVP_ALLOWED_ORIGIN"
      ? "https://unisakickly.github.io"
      : undefined,
    leggiUtente: async (token) => token === "Bearer" ? G1 : token,
    gestisciRsvp: (
      partitaId,
      giocatoreId,
      risposta,
    ): Promise<EsitoRsvp | null> => {
      const precedente = coda;
      let risolvi!: () => void;
      coda = new Promise((resolve) => { risolvi = resolve; });
      return precedente.then(async () => {
        try {
          if (partitaId !== PARTITA) {
            return {
              esito: "partita_non_trovata",
              posti_rimasti: null,
              stato_partita: null,
            };
          }

          if (risposta === "ritiro") {
            if (confermati.delete(giocatoreId)) ritirati.add(giocatoreId);
            const rimasti = Math.max(posti - confermati.size, 0);
            ambiente.stato = rimasti > 0 ? "Aperta" : "Completa";
            return { esito: "ritirata", posti_rimasti: rimasti, stato_partita: ambiente.stato };
          }

          if (confermati.has(giocatoreId)) {
            return {
              esito: "gia_confermata",
              posti_rimasti: Math.max(posti - confermati.size, 0),
              stato_partita: ambiente.stato,
            };
          }
          if (confermati.size >= posti) {
            ambiente.stato = "Completa";
            return { esito: "partita_al_completo", posti_rimasti: 0, stato_partita: "Completa" };
          }

          confermati.add(giocatoreId);
          ritirati.delete(giocatoreId);
          const rimasti = Math.max(posti - confermati.size, 0);
          ambiente.stato = rimasti === 0 ? "Completa" : "Aperta";
          return { esito: "confermata", posti_rimasti: rimasti, stato_partita: ambiente.stato };
        } finally {
          risolvi();
        }
      });
    },
  };
  return ambiente;
}

/** Chiama l'Edge Function con un JWT fittizio e restituisce stato e JSON. */
async function chiama(
  ambiente: AmbienteRsvp,
  corpo: Record<string, unknown>,
  token = G1,
): Promise<{ stato: number; json: Record<string, unknown> }> {
  const response = await gestisciRichiestaRsvp(new Request(
    "http://localhost/functions/v1/rsvp",
    {
      method: "POST",
      headers: { "Authorization": `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify(corpo),
    },
  ), ambiente.dipendenze);
  return { stato: response.status, json: await response.json() as Record<string, unknown> };
}

// Prepara una partita aperta con piu' posti liberi; la conferma deve essere registrata una sola volta e aggiornare contatore e presenza.
Deno.test("tf_par_04_conferma_con_posti_disponibili", async () => {
  const ambiente = creaAmbiente(3);
  const risposta = await chiama(ambiente, { partita_id: PARTITA, risposta: "conferma" }, G1);
  assert.equal(risposta.stato, 200);
  assert.equal(risposta.json.esito, "confermata");
  assert.equal(risposta.json.posti_rimasti, 2);
  assert.equal(risposta.json.stato_partita, "Aperta");
  assert.equal(ambiente.confermati.size, 1);
  assert.equal(ambiente.stato, "Aperta");
});

// Prepara l'ultimo posto libero; la conferma deve azzerare il contatore e completare la partita.
Deno.test("tf_par_05_ultimo_posto_porta_la_partita_a_completa", async () => {
  const ambiente = creaAmbiente(1);
  const risposta = await chiama(ambiente, { partita_id: PARTITA, risposta: "conferma" }, G1);
  assert.equal(risposta.stato, 200);
  assert.equal(risposta.json.esito, "confermata");
  assert.equal(risposta.json.posti_rimasti, 0);
  assert.equal(risposta.json.stato_partita, "Completa");
  assert.equal(ambiente.confermati.size, 1);
  assert.equal(ambiente.stato, "Completa");
});

// Prepara una partita gia' completa; il nuovo Giocatore non deve essere aggiunto ne' ridurre ulteriormente i posti.
Deno.test("tf_par_06_conferma_senza_posti_risponde_partita_al_completo", async () => {
  const ambiente = creaAmbiente(1);
  await chiama(ambiente, { partita_id: PARTITA, risposta: "conferma" }, G1);
  const risposta = await chiama(ambiente, { partita_id: PARTITA, risposta: "conferma" }, G2);
  assert.equal(risposta.stato, 409);
  assert.equal(risposta.json.codice, "partita_al_completo");
  assert.equal(risposta.json.posti_rimasti, 0);
  assert.equal(ambiente.confermati.size, 1);
  assert.equal(ambiente.stato, "Completa");
});

// Due Giocatori inviano l'RSVP nello stesso istante per l'ultimo posto: una sola conferma deve riuscire.
Deno.test("tf_par_07_richieste_concorrenti_sull_ultimo_posto_non_fanno_overbooking", async () => {
  const ambiente = creaAmbiente(1);
  const risposte = await Promise.all([
    chiama(ambiente, { partita_id: PARTITA, risposta: "conferma" }, G1),
    chiama(ambiente, { partita_id: PARTITA, risposta: "conferma" }, G2),
    chiama(ambiente, { partita_id: PARTITA, risposta: "conferma" }, G3),
  ]);
  const confermate = risposte.filter((r) => r.stato === 200).length;
  assert.equal(confermate, 1);
  assert.equal(risposte.filter((r) => r.stato === 409).length, 2);
  assert.ok(risposte.every((r) => r.json.posti_rimasti === 0));
  assert.equal(ambiente.confermati.size, 1);
  assert.equal(ambiente.posti - ambiente.confermati.size, 0);
  assert.equal(ambiente.stato, "Completa");
});

// Il Giocatore e' gia' confermato; una seconda richiesta non deve creare un'altra Partecipazione o consumare un posto.
Deno.test("tf_par_08_rsvp_ripetuto_idempotente_senza_seconda_partecipazione", async () => {
  const ambiente = creaAmbiente(3);
  await chiama(ambiente, { partita_id: PARTITA, risposta: "conferma" }, G1);
  const risposta = await chiama(ambiente, { partita_id: PARTITA, risposta: "conferma" }, G1);
  assert.equal(risposta.stato, 200);
  assert.equal(risposta.json.esito, "gia_confermata");
  assert.equal(risposta.json.posti_rimasti, 2);
  assert.equal(ambiente.confermati.size, 1);
  assert.equal(ambiente.stato, "Aperta");
});

// La partita e' completa e il Giocatore e' confermato; il ritiro deve liberare il posto e riaprire la partita.
Deno.test("tf_par_09_ritiro_da_completa_libera_il_posto_e_torna_aperta", async () => {
  const ambiente = creaAmbiente(1);
  await chiama(ambiente, { partita_id: PARTITA, risposta: "conferma" }, G1);
  const risposta = await chiama(ambiente, { partita_id: PARTITA, risposta: "ritiro" }, G1);
  assert.equal(risposta.stato, 200);
  assert.equal(risposta.json.esito, "ritirata");
  assert.equal(risposta.json.posti_rimasti, 1);
  assert.equal(risposta.json.stato_partita, "Aperta");
  assert.equal(ambiente.confermati.size, 0);
  assert.equal(ambiente.ritirati.has(G1), true);
  assert.equal(ambiente.stato, "Aperta");
});

// N richieste concorrenti con M posti non devono mai confermare piu' di M Giocatori o restituire posti negativi.
Deno.test("N_richieste_con_M_posti_non_superano_mai_M_confermati", async () => {
  const ambiente = creaAmbiente(4);
  const richieste: Promise<{ stato: number; json: Record<string, unknown> }>[] = [];
  for (let i = 0; i < 20; i++) {
    richieste.push(chiama(
      ambiente,
      { partita_id: PARTITA, risposta: "conferma" },
      `21900000-0000-4000-8000-${String(i + 1).padStart(12, "0")}`,
    ));
  }
  const risposte = await Promise.all(richieste);
  assert.equal(risposte.filter((r) => r.stato === 200).length, ambiente.posti);
  assert.equal(risposte.filter((r) => r.stato === 409).length, 20 - ambiente.posti);
  assert.ok(risposte.every((r) => Number(r.json.posti_rimasti) >= 0));
  assert.equal(Math.min(...risposte.map((r) => Number(r.json.posti_rimasti))), 0);
  assert.equal(ambiente.confermati.size, 4);
  assert.equal(ambiente.posti - ambiente.confermati.size, 0);
  assert.equal(ambiente.stato, "Completa");
});

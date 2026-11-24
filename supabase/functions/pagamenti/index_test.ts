// Test della Edge Function `pagamenti` (KCK-225) con Stripe finto e DB finto.
//
// Stripe e' sostituito da un `fetch` iniettato che registra le richieste; il DB
// da un archivio in memoria. Nessun file letto, nessuna rete reale: i test girano
// con `deno test --allow-env --allow-net`. Gli esiti attesi vengono dalle entry
// condition di UC_PAG_1, da D3/D25/D27 e dalle verifiche del ticket. Chiavi e
// dati sono fittizi.

import assert from "node:assert/strict";
import {
  type DatiQuota,
  type Dipendenze,
  gestisciRichiesta,
  type TransazionePagamento,
} from "./index.ts";

const GIOCATORE = "giocatore-1";
const ALTRO_GIOCATORE = "giocatore-2";
const GESTORE = "gestore-1";
/** uuid fittizio: crea_pagamento accetta solo quota_id in formato uuid. */
const QUOTA = "00000000-0000-4000-8000-000000000001";
const PARTITA = "partita-1";
const CHIAVE_TEST = "sk_test_finta";

/** Variabili d'ambiente fittizie; l'origine attesa per il CORS e' quella dei PM. */
const ENV_VALIDO: Record<string, string> = {
  STRIPE_SECRET_KEY: CHIAVE_TEST,
  STRIPE_SUCCESS_URL: "https://unisakickly.github.io/kickly/#/pagamento/ok",
  STRIPE_CANCEL_URL:
    "https://unisakickly.github.io/kickly/#/pagamento/annullato",
  STRIPE_ACCOUNT_RETURN_URL:
    "https://unisakickly.github.io/kickly/#/gestore/ok",
  STRIPE_ACCOUNT_REFRESH_URL:
    "https://unisakickly.github.io/kickly/#/gestore/ripeti",
};
const ORIGINE = "https://unisakickly.github.io";

/** Richiesta registrata dallo Stripe finto. */
interface RichiestaStripe {
  metodo: string;
  percorso: string;
  parametri: URLSearchParams;
  idempotenza: string | null;
  autorizzazione: string | null;
}

/** Risposta forzata dello Stripe finto per un percorso: errore HTTP o rete interrotta. */
/** `codice` diventa error.code del corpo, come nelle risposte di errore di Stripe. */
type Guasto = { stato: number; codice?: string } | "rete";

/** Stato condiviso di Stripe finto e DB finto. */
interface Ambiente {
  dipendenze: Dipendenze;
  richiesteStripe: RichiestaStripe[];
  transazioni: (TransazionePagamento & {
    quotaId: string;
    importo: number;
    dataEsito?: Date;
  })[];
  sessioni: Map<string, { status: string; url: string }>;
  gestori: Map<string, string | null>;
  guasti: Map<string, Guasto>;
  /** Orologio iniettato in Dipendenze.adesso: i test lo spostano a mano. */
  orologio: { adesso: Date };
}

/** Istante iniziale dell'orologio finto, all'inizio di una finestra di 10 minuti. */
const INIZIO = new Date("2026-11-24T10:00:00Z");
/** Finestra della chiave di idempotenza per INIZIO (regola dei PM su KCK-225). */
const FINESTRA = Math.floor(INIZIO.getTime() / 600_000);

/** Sposta in avanti l'orologio finto di `minuti`. */
function avanzaMinuti(ambiente: Ambiente, minuti: number): void {
  ambiente.orologio.adesso = new Date(
    ambiente.orologio.adesso.getTime() + minuti * 60_000,
  );
}

/** Crea l'ambiente con una Quota valida secondo le entry condition di UC_PAG_1. */
function creaAmbiente(opzioni: {
  env?: Record<string, string>;
  quota?: Partial<DatiQuota> | null;
  gestori?: [string, string | null][];
} = {}): Ambiente {
  const env = opzioni.env ?? ENV_VALIDO;
  const quota: DatiQuota | null = opzioni.quota === null ? null : {
    id: QUOTA,
    importo: "8.29",
    statoVersamento: "da_versare",
    termineVersamento: "2026-12-01T18:00:00Z",
    giocatoreId: GIOCATORE,
    rispostaStato: "confermata",
    partitaId: PARTITA,
    statoPartita: "Completa",
    ...opzioni.quota,
  };

  const ambiente: Ambiente = {
    richiesteStripe: [],
    transazioni: [],
    sessioni: new Map(),
    gestori: new Map(opzioni.gestori ?? []),
    guasti: new Map(),
    orologio: { adesso: INIZIO },
    dipendenze: undefined as unknown as Dipendenze,
  };
  // Stripe finto rispetta l'idempotenza come Stripe: stessa chiave, stessa
  // risposta, anche quando la risposta era un errore 500.
  const risposteIdempotenti = new Map<
    string,
    { corpo: unknown; stato: number }
  >();
  let contatore = 0;

  const fetchFinto = (
    input: string | URL | Request,
    init?: RequestInit,
  ): Promise<Response> => {
    const url = new URL(input instanceof Request ? input.url : input);
    const intestazioni = new Headers(init?.headers);
    const percorso = url.pathname.replace(/^\/v1/, "");
    const metodo = init?.method ?? "GET";
    ambiente.richiesteStripe.push({
      metodo,
      percorso,
      parametri: new URLSearchParams(
        typeof init?.body === "string" ? init.body : "",
      ),
      idempotenza: intestazioni.get("Idempotency-Key"),
      autorizzazione: intestazioni.get("Authorization"),
    });

    const guasto = ambiente.guasti.get(
      `${metodo} ${percorso.replace(/\/cs_.*/, "/:id")}`,
    );
    if (guasto === "rete") {
      return Promise.reject(new TypeError("connessione interrotta"));
    }

    const chiave = intestazioni.get("Idempotency-Key");
    const salvata = chiave ? risposteIdempotenti.get(chiave) : undefined;
    if (salvata) {
      return Promise.resolve(
        Response.json(salvata.corpo, { status: salvata.stato }),
      );
    }
    if (guasto) {
      const errore = { error: { code: guasto.codice, message: "guasto" } };
      if (chiave) {
        risposteIdempotenti.set(chiave, { corpo: errore, stato: guasto.stato });
      }
      return Promise.resolve(Response.json(errore, { status: guasto.stato }));
    }
    let corpo: unknown;
    if (metodo === "POST" && percorso === "/checkout/sessions") {
      contatore += 1;
      const id = `cs_test_${contatore}`;
      const sessione = {
        status: "open",
        url: `https://checkout.stripe.test/${id}`,
      };
      ambiente.sessioni.set(id, sessione);
      corpo = { id, ...sessione };
    } else if (metodo === "GET" && percorso.startsWith("/checkout/sessions/")) {
      const id = percorso.split("/").pop()!;
      const sessione = ambiente.sessioni.get(id);
      if (!sessione) {
        // Come Stripe per un oggetto che non esiste.
        return Promise.resolve(
          Response.json({
            error: { code: "resource_missing", message: "No such session" },
          }, { status: 404 }),
        );
      }
      corpo = { id, ...sessione };
    } else if (metodo === "POST" && percorso === "/accounts") {
      contatore += 1;
      corpo = { id: `acct_test_${contatore}` };
    } else if (metodo === "POST" && percorso === "/account_links") {
      corpo = { url: "https://connect.stripe.test/onboarding" };
    } else {
      return Promise.resolve(Response.json({}, { status: 404 }));
    }
    if (chiave) risposteIdempotenti.set(chiave, { corpo, stato: 200 });
    return Promise.resolve(Response.json(corpo));
  };

  ambiente.dipendenze = {
    env: (nome) => env[nome],
    fetch: fetchFinto,
    adesso: () => ambiente.orologio.adesso,
    leggiUtente: (token) =>
      Promise.resolve(token.startsWith("jwt-") ? token.slice(4) : null),
    // Come PostgreSQL, l'uuid si confronta senza badare alle maiuscole.
    leggiQuota: (id) =>
      Promise.resolve(quota && quota.id === id.toLowerCase() ? quota : null),
    leggiPagamentiQuota: (id) =>
      Promise.resolve(
        ambiente.transazioni
          .filter((t) => t.quotaId === id)
          .map(({ id, stato, riferimentoEsterno }) => ({
            id,
            stato,
            riferimentoEsterno,
          })),
      ),
    creaTransazione: (dati) => {
      // Come l'indice univoco parziale di D27 e l'UNIQUE di riferimento_esterno.
      const doppione = ambiente.transazioni.some((t) =>
        (t.quotaId === dati.quotaId && t.stato !== "fallita") ||
        t.riferimentoEsterno === dati.riferimentoEsterno
      );
      if (doppione) return Promise.resolve("conflitto" as const);
      ambiente.transazioni.push({
        id: `tr-${ambiente.transazioni.length + 1}`,
        stato: "in_attesa",
        ...dati,
      });
      return Promise.resolve("creata" as const);
    },
    segnaTransazioneFallita: (id, dataEsito) => {
      const t = ambiente.transazioni.find((t) => t.id === id);
      if (t) {
        t.stato = "fallita";
        t.dataEsito = dataEsito;
      }
      return Promise.resolve();
    },
    leggiGestoreCampo: (id) =>
      Promise.resolve(
        ambiente.gestori.has(id)
          ? { idAccountPagamenti: ambiente.gestori.get(id) ?? null }
          : null,
      ),
    salvaIdAccountPagamenti: (id, idAccount) => {
      ambiente.gestori.set(id, idAccount);
      return Promise.resolve();
    },
  };
  return ambiente;
}

/** Chiama la funzione come farebbe l'app, con il JWT dell'utente indicato. */
async function chiama(
  ambiente: Ambiente,
  corpo: Record<string, unknown>,
  utente: string | null = GIOCATORE,
): Promise<
  { stato: number; json: Record<string, unknown>; risposta: Response }
> {
  const intestazioni: Record<string, string> = {
    "Content-Type": "application/json",
  };
  if (utente) intestazioni.Authorization = `Bearer jwt-${utente}`;
  const risposta = await gestisciRichiesta(
    new Request("http://localhost/functions/v1/pagamenti", {
      method: "POST",
      headers: intestazioni,
      body: JSON.stringify(corpo),
    }),
    ambiente.dipendenze,
  );
  const testo = await risposta.text();
  return { stato: risposta.status, json: JSON.parse(testo), risposta };
}

const PAGA = { azione: "crea_pagamento", quota_id: QUOTA };
const sessioniCreate = (a: Ambiente) =>
  a.richiesteStripe.filter((r) =>
    r.metodo === "POST" && r.percorso === "/checkout/sessions"
  );

// --- crea_pagamento: importo, idempotenza, errori Stripe (verifiche del ticket) ---

Deno.test("importo_in_centesimi_calcolato_dal_server_ignora_importo_del_client", async () => {
  const ambiente = creaAmbiente({ quota: { importo: "8.29" } });

  const { stato, json } = await chiama(ambiente, {
    ...PAGA,
    importo: 1,
    importo_centesimi: 100,
  });

  assert.equal(stato, 200);
  assert.equal(json.url, "https://checkout.stripe.test/cs_test_1");
  const [richiesta] = sessioniCreate(ambiente);
  // 8.29 * 100 = 828.9999999999999 in virgola mobile: deve arrivare 829.
  assert.equal(
    richiesta.parametri.get("line_items[0][price_data][unit_amount]"),
    "829",
  );
  assert.equal(
    richiesta.parametri.get("line_items[0][price_data][currency]"),
    "eur",
  );
  assert.equal(ambiente.transazioni[0].importo, 8.29);
});

Deno.test("importo_della_quota_non_numerico_rifiutato_senza_chiamare_stripe", async () => {
  const ambiente = creaAmbiente({ quota: { importo: "non-un-numero" } });

  const { stato, json } = await chiama(ambiente, PAGA);

  assert.equal(stato, 500);
  assert.equal(json.codice, "errore_interno");
  assert.equal(ambiente.richiesteStripe.length, 0);
  assert.equal(ambiente.transazioni.length, 0);
});

Deno.test("stessa_chiave_di_idempotenza_per_due_richieste_nella_stessa_finestra", async () => {
  const ambiente = creaAmbiente();
  // Prima richiesta: Stripe crea la sessione ma il salvataggio della Transazione
  // fallisce (es. connessione al DB persa). La richiesta ripetuta 5 minuti dopo,
  // nella stessa finestra di 10 minuti, deve riusare la stessa chiave e ricevere
  // la stessa sessione, senza un secondo addebito.
  const creaVera = ambiente.dipendenze.creaTransazione;
  ambiente.dipendenze.creaTransazione = () =>
    Promise.reject(new Error("DB non raggiungibile"));
  const prima = await chiama(ambiente, PAGA);
  ambiente.dipendenze.creaTransazione = creaVera;
  avanzaMinuti(ambiente, 5);
  const seconda = await chiama(ambiente, PAGA);

  assert.equal(prima.stato, 500);
  assert.equal(prima.json.codice, "errore_interno");
  assert.equal(seconda.stato, 200);
  const chiavi = sessioniCreate(ambiente).map((r) => r.idempotenza);
  const attesa = `pagamento_${QUOTA}_0_${FINESTRA}`;
  assert.deepEqual(chiavi, [attesa, attesa]);
  assert.equal(ambiente.sessioni.size, 1);
  assert.equal(ambiente.transazioni.length, 1);
  assert.equal(ambiente.transazioni[0].riferimentoEsterno, "cs_test_1");
});

Deno.test("chiave_diversa_dopo_errore_stripe_500_nella_finestra_successiva", async () => {
  const ambiente = creaAmbiente();
  ambiente.guasti.set("POST /checkout/sessions", { stato: 500 });
  const prima = await chiama(ambiente, PAGA);
  // Stripe torna disponibile, ma conserva il 500 associato alla chiave: nella
  // stessa finestra il nuovo tentativo riceve ancora l'errore.
  ambiente.guasti.clear();
  avanzaMinuti(ambiente, 3);
  const stessaFinestra = await chiama(ambiente, PAGA);
  // Iniziata la finestra successiva la chiave cambia e la sessione si crea.
  avanzaMinuti(ambiente, 7);
  const finestraSuccessiva = await chiama(ambiente, PAGA);

  assert.equal(prima.stato, 502);
  assert.equal(prima.json.codice, "servizio_pagamento_non_disponibile");
  assert.equal(stessaFinestra.stato, 502);
  assert.equal(
    stessaFinestra.json.codice,
    "servizio_pagamento_non_disponibile",
  );
  assert.equal(finestraSuccessiva.stato, 200);
  assert.equal(
    finestraSuccessiva.json.url,
    "https://checkout.stripe.test/cs_test_1",
  );
  assert.deepEqual(sessioniCreate(ambiente).map((r) => r.idempotenza), [
    `pagamento_${QUOTA}_0_${FINESTRA}`,
    `pagamento_${QUOTA}_0_${FINESTRA}`,
    `pagamento_${QUOTA}_0_${FINESTRA + 1}`,
  ]);
  assert.equal(ambiente.transazioni.length, 1);
});

Deno.test("nuova_chiave_di_idempotenza_dopo_pagamento_fallito", async () => {
  const ambiente = creaAmbiente();
  ambiente.transazioni.push({
    id: "tr-vecchia",
    quotaId: QUOTA,
    importo: 8.29,
    stato: "fallita",
    riferimentoEsterno: "cs_test_fallita",
  });

  const { stato } = await chiama(ambiente, PAGA);

  assert.equal(stato, 200);
  assert.equal(
    sessioniCreate(ambiente)[0].idempotenza,
    `pagamento_${QUOTA}_1_${FINESTRA}`,
  );
});

Deno.test("errore_stripe_500_gestito_senza_transazione", async () => {
  const ambiente = creaAmbiente();
  ambiente.guasti.set("POST /checkout/sessions", { stato: 500 });

  const { stato, json } = await chiama(ambiente, PAGA);

  assert.equal(stato, 502);
  assert.equal(json.codice, "servizio_pagamento_non_disponibile");
  assert.equal(typeof json.errore, "string");
  assert.ok(
    !JSON.stringify(json).includes("guasto"),
    "nessun dettaglio di Stripe al client",
  );
  assert.equal(ambiente.transazioni.length, 0);
});

Deno.test("rete_interrotta_fetch_lancia_eccezione_gestita", async () => {
  const ambiente = creaAmbiente();
  ambiente.guasti.set("POST /checkout/sessions", "rete");

  const { stato, json } = await chiama(ambiente, PAGA);

  assert.equal(stato, 502);
  assert.equal(json.codice, "servizio_pagamento_non_disponibile");
  assert.equal(ambiente.transazioni.length, 0);
});

Deno.test("chiave_stripe_mancante_o_non_di_test_rifiutata_senza_chiamare_stripe", async () => {
  const senzaChiave = { ...ENV_VALIDO };
  delete senzaChiave.STRIPE_SECRET_KEY;
  const chiaveLive = { ...ENV_VALIDO, STRIPE_SECRET_KEY: "sk_live_finta" };

  for (const env of [senzaChiave, chiaveLive]) {
    const ambiente = creaAmbiente({ env });
    const { stato, json } = await chiama(ambiente, PAGA);

    assert.equal(stato, 500);
    assert.equal(json.codice, "configurazione_non_valida");
    assert.equal(ambiente.richiesteStripe.length, 0);
    assert.ok(
      !JSON.stringify(json).includes("sk_"),
      "la chiave non compare nella risposta",
    );
  }
});

Deno.test("chiave_stripe_inviata_solo_a_stripe_e_mai_nella_risposta", async () => {
  const ambiente = creaAmbiente();

  const { json } = await chiama(ambiente, PAGA);

  assert.equal(
    ambiente.richiesteStripe[0].autorizzazione,
    `Bearer ${CHIAVE_TEST}`,
  );
  assert.ok(!JSON.stringify(json).includes(CHIAVE_TEST));
});

// --- crea_pagamento: entry condition di UC_PAG_1 ---

Deno.test("pagamento_rifiutato_se_utente_non_autenticato", async () => {
  const ambiente = creaAmbiente();

  const { stato, json } = await chiama(ambiente, PAGA, null);

  assert.equal(stato, 401);
  assert.equal(json.codice, "non_autenticato");
  assert.equal(ambiente.richiesteStripe.length, 0);
});

Deno.test("pagamento_rifiutato_se_partita_non_completa", async () => {
  for (
    const statoPartita of ["Aperta", "Confermata", "Conclusa", "Annullata"]
  ) {
    const ambiente = creaAmbiente({ quota: { statoPartita } });

    const { stato, json } = await chiama(ambiente, PAGA);

    assert.equal(stato, 409, statoPartita);
    assert.equal(json.codice, "partita_non_completa", statoPartita);
    assert.equal(ambiente.richiesteStripe.length, 0);
  }
});

Deno.test("pagamento_rifiutato_se_termine_versamento_scaduto", async () => {
  // adesso() = 2026-11-24T10:00:00Z: termine gia' passato e termine esatto.
  for (
    const termineVersamento of ["2026-11-24T09:00:00Z", "2026-11-24T10:00:00Z"]
  ) {
    const ambiente = creaAmbiente({ quota: { termineVersamento } });

    const { stato, json } = await chiama(ambiente, PAGA);

    assert.equal(stato, 409, termineVersamento);
    assert.equal(json.codice, "termine_scaduto", termineVersamento);
    assert.equal(ambiente.richiesteStripe.length, 0);
  }
});

Deno.test("pagamento_rifiutato_se_giocatore_non_iscritto_alla_partita", async () => {
  const ambiente = creaAmbiente({ quota: { rispostaStato: "ritirata" } });

  const { stato, json } = await chiama(ambiente, PAGA);

  assert.equal(stato, 409);
  assert.equal(json.codice, "non_iscritto");
  assert.equal(ambiente.richiesteStripe.length, 0);
});

Deno.test("pagamento_rifiutato_se_quota_di_altro_giocatore_o_gia_versata", async () => {
  const altrui = creaAmbiente({ quota: { giocatoreId: ALTRO_GIOCATORE } });
  const versata = creaAmbiente({ quota: { statoVersamento: "versata" } });
  const inesistente = creaAmbiente({ quota: null });

  const rAltrui = await chiama(altrui, PAGA);
  const rInesistente = await chiama(inesistente, PAGA);
  const rVersata = await chiama(versata, PAGA);

  assert.equal(rAltrui.stato, 404);
  assert.equal(rAltrui.json.codice, "quota_non_trovata");
  assert.equal(rInesistente.stato, 404);
  assert.equal(rInesistente.json.codice, "quota_non_trovata");
  assert.equal(rVersata.stato, 409);
  assert.equal(rVersata.json.codice, "quota_gia_versata");
  for (const a of [altrui, versata, inesistente]) {
    assert.equal(a.richiesteStripe.length, 0);
  }
});

// --- crea_pagamento: pagamento gia' in_attesa (decisione dei PM) ---

Deno.test("sessione_open_restituisce_stesso_url", async () => {
  const ambiente = creaAmbiente();

  const prima = await chiama(ambiente, PAGA);
  const seconda = await chiama(ambiente, PAGA);

  assert.equal(seconda.stato, 200);
  assert.equal(seconda.json.url, prima.json.url);
  assert.equal(sessioniCreate(ambiente).length, 1);
  assert.equal(ambiente.transazioni.length, 1);
});

Deno.test("sessione_expired_segna_fallita_e_crea_nuova_sessione", async () => {
  const ambiente = creaAmbiente();
  await chiama(ambiente, PAGA);
  ambiente.sessioni.get("cs_test_1")!.status = "expired";

  const { stato, json } = await chiama(ambiente, PAGA);

  assert.equal(stato, 200);
  assert.equal(json.url, "https://checkout.stripe.test/cs_test_2");
  assert.deepEqual(
    ambiente.transazioni.map((t) => [t.riferimentoEsterno, t.stato]),
    [["cs_test_1", "fallita"], ["cs_test_2", "in_attesa"]],
  );
  assert.equal(
    sessioniCreate(ambiente)[1].idempotenza,
    `pagamento_${QUOTA}_1_${FINESTRA}`,
  );
});

Deno.test("transazione_scaduta_segnata_fallita_con_l_istante_della_richiesta", async () => {
  const ambiente = creaAmbiente();
  await chiama(ambiente, PAGA);
  ambiente.sessioni.get("cs_test_1")!.status = "expired";
  avanzaMinuti(ambiente, 2);

  await chiama(ambiente, PAGA);

  assert.deepEqual(
    ambiente.transazioni[0].dataEsito,
    new Date(INIZIO.getTime() + 2 * 60_000),
  );
});

Deno.test("pagamento_completata_risponde_in_verifica_senza_chiamare_stripe", async () => {
  const ambiente = creaAmbiente();
  ambiente.transazioni.push({
    id: "tr-completata",
    quotaId: QUOTA,
    importo: 8.29,
    stato: "completata",
    riferimentoEsterno: "cs_test_completata",
  });

  const { stato, json } = await chiama(ambiente, PAGA);

  assert.equal(stato, 409);
  assert.equal(json.codice, "pagamento_in_verifica");
  assert.equal(json.errore, "pagamento in verifica");
  assert.equal(ambiente.richiesteStripe.length, 0);
  assert.equal(ambiente.transazioni.length, 1);
});

Deno.test("errore_stripe_sulla_lettura_della_sessione_esistente_gestito", async () => {
  const ambiente = creaAmbiente();
  await chiama(ambiente, PAGA);
  const prima = structuredClone(ambiente.transazioni);
  ambiente.guasti.set("GET /checkout/sessions/:id", { stato: 500 });

  const { stato, json } = await chiama(ambiente, PAGA);

  assert.equal(stato, 502);
  assert.equal(json.codice, "servizio_pagamento_non_disponibile");
  assert.equal(sessioniCreate(ambiente).length, 1);
  assert.deepEqual(ambiente.transazioni, prima);
});

Deno.test("sessione_non_trovata_resource_missing_segna_fallita_e_crea_nuova_sessione", async () => {
  const ambiente = creaAmbiente();
  await chiama(ambiente, PAGA);
  // Stripe non conosce piu' la sessione: GET risponde 404 resource_missing.
  ambiente.sessioni.delete("cs_test_1");
  avanzaMinuti(ambiente, 2);

  const { stato, json } = await chiama(ambiente, PAGA);

  assert.equal(stato, 200);
  assert.equal(json.url, "https://checkout.stripe.test/cs_test_2");
  assert.deepEqual(
    ambiente.transazioni.map((t) => [t.riferimentoEsterno, t.stato]),
    [["cs_test_1", "fallita"], ["cs_test_2", "in_attesa"]],
  );
  assert.deepEqual(
    ambiente.transazioni[0].dataEsito,
    new Date(INIZIO.getTime() + 2 * 60_000),
  );
  assert.equal(
    sessioniCreate(ambiente)[1].idempotenza,
    `pagamento_${QUOTA}_1_${FINESTRA}`,
  );
});

Deno.test("sessione_404_con_altro_codice_resta_errore_502", async () => {
  const ambiente = creaAmbiente();
  await chiama(ambiente, PAGA);
  const prima = structuredClone(ambiente.transazioni);
  ambiente.guasti.set("GET /checkout/sessions/:id", {
    stato: 404,
    codice: "altro_codice",
  });

  const { stato, json } = await chiama(ambiente, PAGA);

  assert.equal(stato, 502);
  assert.equal(json.codice, "servizio_pagamento_non_disponibile");
  assert.ok(!JSON.stringify(json).includes("guasto"));
  assert.ok(!JSON.stringify(json).includes("altro_codice"));
  assert.equal(sessioniCreate(ambiente).length, 1);
  assert.deepEqual(ambiente.transazioni, prima);
});

Deno.test("sessione_complete_nessuna_nuova_sessione_pagamento_in_verifica", async () => {
  const ambiente = creaAmbiente();
  await chiama(ambiente, PAGA);
  ambiente.sessioni.get("cs_test_1")!.status = "complete";

  const { stato, json } = await chiama(ambiente, PAGA);

  assert.equal(stato, 409);
  assert.equal(json.codice, "pagamento_in_verifica");
  assert.equal(json.errore, "pagamento in verifica");
  assert.equal(sessioniCreate(ambiente).length, 1);
  assert.deepEqual(ambiente.transazioni.map((t) => t.stato), ["in_attesa"]);
});

Deno.test("richieste_concorrenti_conflitto_23505_restituisce_url_esistente", async () => {
  const ambiente = creaAmbiente();
  // Una richiesta concorrente ha gia' registrato la sua sessione dopo che questa
  // ha letto i pagamenti: l'inserimento va in conflitto (23505).
  ambiente.sessioni.set("cs_test_concorrente", {
    status: "open",
    url: "https://checkout.stripe.test/cs_test_concorrente",
  });
  const leggiVera = ambiente.dipendenze.leggiPagamentiQuota;
  let letture = 0;
  ambiente.dipendenze.leggiPagamentiQuota = (id) => {
    letture += 1;
    if (letture === 1) return Promise.resolve([]);
    return leggiVera(id);
  };
  ambiente.transazioni.push({
    id: "tr-concorrente",
    quotaId: QUOTA,
    importo: 8.29,
    stato: "in_attesa",
    riferimentoEsterno: "cs_test_concorrente",
  });

  const { stato, json } = await chiama(ambiente, PAGA);

  assert.equal(stato, 200);
  assert.equal(json.url, "https://checkout.stripe.test/cs_test_concorrente");
  assert.equal(ambiente.transazioni.length, 1);
});

Deno.test("sessione_contiene_metadata_quota_id_e_transfer_group_partita", async () => {
  const ambiente = creaAmbiente();

  await chiama(ambiente, PAGA);

  const parametri = sessioniCreate(ambiente)[0].parametri;
  assert.equal(parametri.get("metadata[quota_id]"), QUOTA);
  assert.equal(parametri.get("payment_intent_data[transfer_group]"), PARTITA);
  assert.equal(parametri.get("success_url"), ENV_VALIDO.STRIPE_SUCCESS_URL);
  assert.equal(parametri.get("cancel_url"), ENV_VALIDO.STRIPE_CANCEL_URL);
});

// --- CORS ---

Deno.test("errore_dell_autenticazione_restituisce_errore_con_header_cors", async () => {
  const ambiente = creaAmbiente();
  ambiente.dipendenze.leggiUtente = () =>
    Promise.reject(new Error("Auth non raggiungibile"));

  const { stato, json, risposta } = await chiama(ambiente, PAGA);

  assert.equal(stato, 500);
  assert.equal(json.codice, "errore_interno");
  assert.equal(risposta.headers.get("Access-Control-Allow-Origin"), ORIGINE);
  assert.equal(ambiente.richiesteStripe.length, 0);
});

Deno.test("options_restituisce_header_cors", async () => {
  const ambiente = creaAmbiente();

  const risposta = await gestisciRichiesta(
    new Request("http://localhost/functions/v1/pagamenti", {
      method: "OPTIONS",
    }),
    ambiente.dipendenze,
  );
  await risposta.body?.cancel();
  const post = await chiama(ambiente, PAGA);

  assert.equal(risposta.status, 204);
  assert.equal(risposta.headers.get("Access-Control-Allow-Origin"), ORIGINE);
  assert.match(
    risposta.headers.get("Access-Control-Allow-Headers") ?? "",
    /authorization/,
  );
  assert.equal(
    post.risposta.headers.get("Access-Control-Allow-Origin"),
    ORIGINE,
  );
});

// --- onboarding_gestore (D3) ---

const ONBOARDING = { azione: "onboarding_gestore" };

Deno.test("onboarding_crea_account_express_it_e_salva_id", async () => {
  const ambiente = creaAmbiente({ gestori: [[GESTORE, null]] });

  const { stato, json } = await chiama(ambiente, ONBOARDING, GESTORE);

  assert.equal(stato, 200);
  assert.equal(json.url, "https://connect.stripe.test/onboarding");
  const [account, link] = ambiente.richiesteStripe;
  assert.equal(account.percorso, "/accounts");
  assert.equal(account.idempotenza, `onboarding_${GESTORE}_${FINESTRA}`);
  assert.equal(account.parametri.get("country"), "IT");
  assert.equal(
    account.parametri.get("controller[stripe_dashboard][type]"),
    "express",
  );
  assert.equal(account.parametri.get("controller[fees][payer]"), "application");
  assert.equal(
    account.parametri.get("controller[losses][payments]"),
    "application",
  );
  assert.equal(
    account.parametri.get("controller[requirement_collection]"),
    "stripe",
  );
  assert.equal(
    account.parametri.get("capabilities[transfers][requested]"),
    "true",
  );
  assert.equal(account.parametri.get("type"), null);
  assert.equal(
    account.parametri.get("capabilities[card_payments][requested]"),
    null,
  );
  assert.equal(link.percorso, "/account_links");
  assert.equal(link.parametri.get("account"), "acct_test_1");
  assert.equal(link.parametri.get("type"), "account_onboarding");
  assert.equal(
    link.parametri.get("return_url"),
    ENV_VALIDO.STRIPE_ACCOUNT_RETURN_URL,
  );
  assert.equal(
    link.parametri.get("refresh_url"),
    ENV_VALIDO.STRIPE_ACCOUNT_REFRESH_URL,
  );
  assert.equal(ambiente.gestori.get(GESTORE), "acct_test_1");
});

Deno.test("onboarding_stessa_chiave_di_idempotenza_nella_stessa_finestra", async () => {
  const ambiente = creaAmbiente({ gestori: [[GESTORE, null]] });
  // Stripe crea l'account ma il salvataggio dell'id fallisce: il nuovo tentativo
  // 5 minuti dopo, nella stessa finestra, riceve da Stripe lo stesso account.
  const salvaVera = ambiente.dipendenze.salvaIdAccountPagamenti;
  ambiente.dipendenze.salvaIdAccountPagamenti = () =>
    Promise.reject(new Error("DB non raggiungibile"));
  const prima = await chiama(ambiente, ONBOARDING, GESTORE);
  ambiente.dipendenze.salvaIdAccountPagamenti = salvaVera;
  avanzaMinuti(ambiente, 5);
  const seconda = await chiama(ambiente, ONBOARDING, GESTORE);

  assert.equal(prima.stato, 500);
  assert.equal(prima.json.codice, "errore_interno");
  assert.equal(seconda.stato, 200);
  const creazioni = ambiente.richiesteStripe.filter((r) =>
    r.percorso === "/accounts"
  );
  const attesa = `onboarding_${GESTORE}_${FINESTRA}`;
  assert.deepEqual(creazioni.map((r) => r.idempotenza), [attesa, attesa]);
  assert.equal(ambiente.gestori.get(GESTORE), "acct_test_1");
});

Deno.test("onboarding_chiave_diversa_dopo_errore_500_nella_finestra_successiva", async () => {
  const ambiente = creaAmbiente({ gestori: [[GESTORE, null]] });
  ambiente.guasti.set("POST /accounts", { stato: 500 });
  const prima = await chiama(ambiente, ONBOARDING, GESTORE);
  // Stripe conserva il 500 per la chiave: nella stessa finestra resta l'errore.
  ambiente.guasti.clear();
  avanzaMinuti(ambiente, 3);
  const stessaFinestra = await chiama(ambiente, ONBOARDING, GESTORE);
  avanzaMinuti(ambiente, 7);
  const finestraSuccessiva = await chiama(ambiente, ONBOARDING, GESTORE);

  assert.equal(prima.stato, 502);
  assert.equal(prima.json.codice, "servizio_pagamento_non_disponibile");
  assert.equal(stessaFinestra.stato, 502);
  assert.equal(
    stessaFinestra.json.codice,
    "servizio_pagamento_non_disponibile",
  );
  assert.equal(finestraSuccessiva.stato, 200);
  assert.deepEqual(
    ambiente.richiesteStripe
      .filter((r) => r.percorso === "/accounts")
      .map((r) => r.idempotenza),
    [
      `onboarding_${GESTORE}_${FINESTRA}`,
      `onboarding_${GESTORE}_${FINESTRA}`,
      `onboarding_${GESTORE}_${FINESTRA + 1}`,
    ],
  );
  assert.equal(ambiente.gestori.get(GESTORE), "acct_test_1");
});

Deno.test("onboarding_riusa_account_esistente", async () => {
  const ambiente = creaAmbiente({
    gestori: [[GESTORE, "acct_test_esistente"]],
  });

  const { stato } = await chiama(ambiente, ONBOARDING, GESTORE);

  assert.equal(stato, 200);
  assert.deepEqual(ambiente.richiesteStripe.map((r) => r.percorso), [
    "/account_links",
  ]);
  assert.equal(
    ambiente.richiesteStripe[0].parametri.get("account"),
    "acct_test_esistente",
  );
});

Deno.test("onboarding_link_fallito_id_account_gia_salvato", async () => {
  const ambiente = creaAmbiente({ gestori: [[GESTORE, null]] });
  ambiente.guasti.set("POST /account_links", { stato: 500 });

  const { stato, json } = await chiama(ambiente, ONBOARDING, GESTORE);

  assert.equal(stato, 502);
  assert.equal(json.codice, "servizio_pagamento_non_disponibile");
  assert.equal(ambiente.gestori.get(GESTORE), "acct_test_1");

  // Al nuovo tentativo l'account si riusa, senza crearne un secondo.
  ambiente.guasti.clear();
  const ripetuta = await chiama(ambiente, ONBOARDING, GESTORE);
  assert.equal(ripetuta.stato, 200);
  assert.equal(
    ambiente.richiesteStripe.filter((r) => r.percorso === "/accounts").length,
    1,
  );
});

Deno.test("onboarding_rifiutato_se_non_gestore", async () => {
  const ambiente = creaAmbiente({ gestori: [[GESTORE, null]] });

  const { stato, json } = await chiama(ambiente, ONBOARDING, GIOCATORE);

  assert.equal(stato, 403);
  assert.equal(json.codice, "non_gestore");
  assert.equal(ambiente.richiesteStripe.length, 0);
});

// --- Codici di errore senza un test dedicato (decisione dei PM su KCK-225) ---

/** Chiama la funzione con un corpo grezzo e un metodo a scelta. */
async function chiamaGrezzo(
  ambiente: Ambiente,
  metodo: string,
  corpo: string | null,
): Promise<{ stato: number; json: Record<string, unknown> }> {
  const risposta = await gestisciRichiesta(
    new Request("http://localhost/functions/v1/pagamenti", {
      method: metodo,
      headers: { Authorization: `Bearer jwt-${GIOCATORE}` },
      body: corpo,
    }),
    ambiente.dipendenze,
  );
  return { stato: risposta.status, json: await risposta.json() };
}

Deno.test("corpo_non_valido_o_quota_id_mancante_codice_richiesta_non_valida", async () => {
  const ambiente = creaAmbiente();

  const corpoNonJson = await chiamaGrezzo(ambiente, "POST", "non e' json");
  const corpoNonOggetto = await chiamaGrezzo(ambiente, "POST", "42");
  const senzaQuota = await chiama(ambiente, { azione: "crea_pagamento" });

  for (const r of [corpoNonJson, corpoNonOggetto, senzaQuota]) {
    assert.equal(r.stato, 400);
    assert.equal(r.json.codice, "richiesta_non_valida");
  }
  assert.equal(ambiente.richiesteStripe.length, 0);
});

Deno.test("metodo_diverso_da_post_codice_metodo_non_ammesso", async () => {
  const ambiente = creaAmbiente();

  const { stato, json } = await chiamaGrezzo(ambiente, "GET", null);

  assert.equal(stato, 405);
  assert.equal(json.codice, "metodo_non_ammesso");
});

Deno.test("azione_sconosciuta_codice_azione_non_valida", async () => {
  const ambiente = creaAmbiente();

  const { stato, json } = await chiama(ambiente, { azione: "rimborsa" });

  assert.equal(stato, 400);
  assert.equal(json.codice, "azione_non_valida");
  assert.equal(ambiente.richiesteStripe.length, 0);
});

Deno.test("quota_rimborsata_codice_quota_rimborsata", async () => {
  const ambiente = creaAmbiente({ quota: { statoVersamento: "rimborsata" } });

  const { stato, json } = await chiama(ambiente, PAGA);

  assert.equal(stato, 409);
  assert.equal(json.codice, "quota_rimborsata");
  assert.equal(ambiente.richiesteStripe.length, 0);
});

Deno.test("stato_versamento_non_ammesso_codice_errore_interno", async () => {
  const ambiente = creaAmbiente({ quota: { statoVersamento: "sconosciuto" } });

  const { stato, json } = await chiama(ambiente, PAGA);

  assert.equal(stato, 500);
  assert.equal(json.codice, "errore_interno");
  assert.equal(ambiente.richiesteStripe.length, 0);
});

/**
 * Simula una richiesta concorrente: la prima lettura dei pagamenti e' vuota,
 * poi compare `transazione`, registrata dall'altra richiesta, e l'inserimento
 * di questa va in conflitto (23505).
 */
function simulaConflitto(
  ambiente: Ambiente,
  transazione: { stato: string; riferimentoEsterno: string } | null,
): void {
  const leggiVera = ambiente.dipendenze.leggiPagamentiQuota;
  let letture = 0;
  ambiente.dipendenze.leggiPagamentiQuota = (id) => {
    letture += 1;
    return letture === 1 ? Promise.resolve([]) : leggiVera(id);
  };
  ambiente.dipendenze.creaTransazione = () =>
    Promise.resolve("conflitto" as const);
  if (transazione) {
    ambiente.transazioni.push({
      id: "tr-concorrente",
      quotaId: QUOTA,
      importo: 8.29,
      ...transazione,
    });
  }
}

Deno.test("conflitto_23505_con_pagamento_completata_codice_pagamento_in_verifica", async () => {
  const ambiente = creaAmbiente();
  simulaConflitto(ambiente, {
    stato: "completata",
    riferimentoEsterno: "cs_test_concorrente",
  });

  const { stato, json } = await chiama(ambiente, PAGA);

  assert.equal(stato, 409);
  assert.equal(json.codice, "pagamento_in_verifica");
});

Deno.test("conflitto_23505_senza_pagamento_in_attesa_codice_pagamento_in_corso", async () => {
  const ambiente = creaAmbiente();
  // L'altra richiesta e' gia' passata a fallita prima della rilettura.
  simulaConflitto(ambiente, {
    stato: "fallita",
    riferimentoEsterno: "cs_test_concorrente",
  });

  const { stato, json } = await chiama(ambiente, PAGA);

  assert.equal(stato, 409);
  assert.equal(json.codice, "pagamento_in_corso");
});

Deno.test("conflitto_23505_con_sessione_scaduta_codice_pagamento_in_corso", async () => {
  const ambiente = creaAmbiente();
  ambiente.sessioni.set("cs_test_concorrente", {
    status: "expired",
    url: "https://checkout.stripe.test/cs_test_concorrente",
  });
  simulaConflitto(ambiente, {
    stato: "in_attesa",
    riferimentoEsterno: "cs_test_concorrente",
  });

  const { stato, json } = await chiama(ambiente, PAGA);

  assert.equal(stato, 409);
  assert.equal(json.codice, "pagamento_in_corso");
});

// --- Seconda revisione: ordine dei controlli (D8, TF_PAG_07) e input ---

Deno.test("quota_versata_con_partita_confermata_codice_quota_gia_versata", async () => {
  const ambiente = creaAmbiente({
    quota: { statoVersamento: "versata", statoPartita: "Confermata" },
  });

  const { stato, json } = await chiama(ambiente, PAGA);

  assert.equal(stato, 409);
  assert.equal(json.codice, "quota_gia_versata");
  assert.equal(ambiente.richiesteStripe.length, 0);
});

Deno.test("quota_rimborsata_con_partita_annullata_codice_quota_rimborsata", async () => {
  const ambiente = creaAmbiente({
    quota: { statoVersamento: "rimborsata", statoPartita: "Annullata" },
  });

  const { stato, json } = await chiama(ambiente, PAGA);

  assert.equal(stato, 409);
  assert.equal(json.codice, "quota_rimborsata");
  assert.equal(ambiente.richiesteStripe.length, 0);
});

Deno.test("quota_rimborsata_con_partecipazione_ritirata_codice_quota_rimborsata", async () => {
  const ambiente = creaAmbiente({
    quota: { statoVersamento: "rimborsata", rispostaStato: "ritirata" },
  });

  const { stato, json } = await chiama(ambiente, PAGA);

  assert.equal(stato, 409);
  assert.equal(json.codice, "quota_rimborsata");
  assert.equal(ambiente.richiesteStripe.length, 0);
});

Deno.test("quota_id_in_maiuscolo_stessa_chiave_e_una_sola_sessione", async () => {
  const ambiente = creaAmbiente();
  // Prima richiesta con l'uuid in maiuscolo: Stripe crea la sessione ma il
  // salvataggio della Transazione fallisce. La seconda, in minuscolo, arriva di
  // nuovo a Stripe: chiave, metadata e transazione usano l'id letto dal DB,
  // quindi la chiave e' la stessa e la sessione una sola.
  const creaVera = ambiente.dipendenze.creaTransazione;
  ambiente.dipendenze.creaTransazione = () =>
    Promise.reject(new Error("DB non raggiungibile"));
  const maiuscolo = await chiama(ambiente, {
    azione: "crea_pagamento",
    quota_id: QUOTA.toUpperCase(),
  });
  ambiente.dipendenze.creaTransazione = creaVera;
  const minuscolo = await chiama(ambiente, PAGA);

  assert.equal(maiuscolo.stato, 500);
  assert.equal(maiuscolo.json.codice, "errore_interno");
  assert.equal(minuscolo.stato, 200);
  const richieste = sessioniCreate(ambiente);
  const attesa = `pagamento_${QUOTA}_0_${FINESTRA}`;
  assert.deepEqual(richieste.map((r) => r.idempotenza), [attesa, attesa]);
  assert.equal(richieste[0].parametri.get("metadata[quota_id]"), QUOTA);
  assert.equal(ambiente.sessioni.size, 1);
  assert.equal(ambiente.transazioni.length, 1);
  assert.equal(ambiente.transazioni[0].quotaId, QUOTA);
});

Deno.test("quota_id_non_uuid_codice_richiesta_non_valida_senza_leggere_il_db", async () => {
  const ambiente = creaAmbiente();
  let lettureQuota = 0;
  ambiente.dipendenze.leggiQuota = () => {
    lettureQuota += 1;
    return Promise.resolve(null);
  };

  for (const quota_id of ["quota-1", "", 42, "' OR 1=1 --"]) {
    const { stato, json } = await chiama(ambiente, {
      azione: "crea_pagamento",
      quota_id,
    });

    assert.equal(stato, 400, String(quota_id));
    assert.equal(json.codice, "richiesta_non_valida", String(quota_id));
  }
  assert.equal(lettureQuota, 0);
  assert.equal(ambiente.richiesteStripe.length, 0);
});

Deno.test("corpo_array_codice_richiesta_non_valida", async () => {
  const ambiente = creaAmbiente();

  const { stato, json } = await chiamaGrezzo(
    ambiente,
    "POST",
    JSON.stringify([PAGA]),
  );

  assert.equal(stato, 400);
  assert.equal(json.codice, "richiesta_non_valida");
  assert.equal(ambiente.richiesteStripe.length, 0);
});

Deno.test("conflitto_23505_con_sessione_non_trovata_codice_pagamento_in_corso", async () => {
  const ambiente = creaAmbiente();
  // La transazione dell'altra richiesta punta a una sessione che Stripe non
  // trova: GET risponde 404 resource_missing.
  simulaConflitto(ambiente, {
    stato: "in_attesa",
    riferimentoEsterno: "cs_test_sconosciuta",
  });

  const { stato, json } = await chiama(ambiente, PAGA);

  assert.equal(stato, 409);
  assert.equal(json.codice, "pagamento_in_corso");
});

Deno.test("url_di_configurazione_assente_o_non_valido_codice_configurazione_non_valida", async () => {
  const senzaUrl = { ...ENV_VALIDO };
  delete senzaUrl.STRIPE_ACCOUNT_REFRESH_URL;
  const urlNonValido = { ...ENV_VALIDO, STRIPE_CANCEL_URL: "non un url" };

  for (const env of [senzaUrl, urlNonValido]) {
    const ambiente = creaAmbiente({ env });

    const { stato, json } = await chiama(ambiente, PAGA);

    assert.equal(stato, 500);
    assert.equal(json.codice, "configurazione_non_valida");
    assert.equal(ambiente.richiesteStripe.length, 0);
  }
});

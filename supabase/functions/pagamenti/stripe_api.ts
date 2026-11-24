// Chiamate alla REST API di Stripe (modalita' test) usate dalla Edge Function
// `pagamenti` (KCK-225).
//
// Perche' un file a parte: e' l'unico punto del server che parla con Stripe
// (DG1 Sicurezza dei dati di pagamento, SDD v1.4 §1.2 e §3.3). La chiave segreta
// arriva come parametro e non esce mai da qui: non compare in errori, log o
// risposte. Si usa solo `fetch`, senza librerie (decisione dei PM su KCK-225).
// Il `fetch` e' iniettato per poter sostituire Stripe con un finto nei test.

/** Firma di `fetch`, iniettabile nei test. */
export type Fetch = (
  input: string | URL | Request,
  init?: RequestInit,
) => Promise<Response>;

/** Indirizzo base della REST API di Stripe. */
const BASE_STRIPE = "https://api.stripe.com/v1";

/**
 * Errore di una chiamata a Stripe.
 *
 * `stato` e' lo status HTTP della risposta, oppure null se la chiamata non e'
 * arrivata a Stripe (rete interrotta, E2 di UC_PAG_1). Il messaggio e' generico
 * di proposito: il corpo della risposta di Stripe non viene propagato al client.
 */
export class ErroreStripe extends Error {
  constructor(readonly stato: number | null) {
    super(
      stato === null
        ? "Stripe non raggiungibile"
        : `Stripe ha risposto con stato ${stato}`,
    );
    this.name = "ErroreStripe";
  }
}

/** Stato di una Checkout Session, come lo restituisce Stripe. */
export type StatoSessioneCheckout = "open" | "complete" | "expired";

/** Dati di una Checkout Session usati dalla Edge Function. */
export interface SessioneCheckout {
  id: string;
  url: string | null;
  status: StatoSessioneCheckout;
}

/**
 * Esegue una richiesta verso Stripe e restituisce il JSON della risposta.
 *
 * I parametri vanno in `application/x-www-form-urlencoded`, il formato della
 * REST API di Stripe. Se c'e' una chiave di idempotenza la manda nell'header
 * `Idempotency-Key`, cosi' una richiesta ripetuta non crea un secondo oggetto
 * (DG2 Integrita' delle transazioni di pagamento). Un'eccezione di `fetch` o una
 * risposta non 2xx diventano un ErroreStripe.
 */
async function chiamaStripe(
  fetchStripe: Fetch,
  chiaveSegreta: string,
  metodo: "GET" | "POST",
  percorso: string,
  parametri?: Record<string, string>,
  chiaveIdempotenza?: string,
): Promise<Record<string, unknown>> {
  const intestazioni: Record<string, string> = {
    Authorization: `Bearer ${chiaveSegreta}`,
  };
  let corpo: string | undefined;
  if (parametri !== undefined) {
    intestazioni["Content-Type"] = "application/x-www-form-urlencoded";
    corpo = new URLSearchParams(parametri).toString();
  }
  if (chiaveIdempotenza !== undefined) {
    intestazioni["Idempotency-Key"] = chiaveIdempotenza;
  }

  let risposta: Response;
  try {
    risposta = await fetchStripe(`${BASE_STRIPE}${percorso}`, {
      method: metodo,
      headers: intestazioni,
      body: corpo,
    });
  } catch {
    // Rete interrotta: non si sa nulla dell'esito, nessuna transazione completata.
    throw new ErroreStripe(null);
  }

  if (!risposta.ok) {
    // Il corpo viene consumato per liberare la connessione, ma non propagato.
    await risposta.body?.cancel();
    throw new ErroreStripe(risposta.status);
  }
  try {
    return await risposta.json() as Record<string, unknown>;
  } catch {
    throw new ErroreStripe(risposta.status);
  }
}

/**
 * Crea la Checkout Session per versare una Quota (RF_PAG_1, UC_PAG_1).
 *
 * L'importo e' gia' in centesimi e calcolato dal server. Il pagamento e' incassato
 * dalla piattaforma (separate charges and transfers, niente `on_behalf_of`):
 * l'accredito al Gestore arriva dopo con un transfer (RF_PAG_2, D26), per questo
 * `transfer_group` e' l'id della partita. `metadata.quota_id` serve al webhook di
 * KCK-231 per ritrovare la Quota.
 */
export async function creaSessioneCheckout(
  fetchStripe: Fetch,
  chiaveSegreta: string,
  dati: {
    importoCentesimi: number;
    quotaId: string;
    partitaId: string;
    urlSuccesso: string;
    urlAnnullamento: string;
    chiaveIdempotenza: string;
  },
): Promise<SessioneCheckout> {
  const json = await chiamaStripe(
    fetchStripe,
    chiaveSegreta,
    "POST",
    "/checkout/sessions",
    {
      "mode": "payment",
      "line_items[0][quantity]": "1",
      "line_items[0][price_data][currency]": "eur",
      "line_items[0][price_data][unit_amount]": String(dati.importoCentesimi),
      "line_items[0][price_data][product_data][name]": "Quota partita Kickly",
      "success_url": dati.urlSuccesso,
      "cancel_url": dati.urlAnnullamento,
      "metadata[quota_id]": dati.quotaId,
      "payment_intent_data[transfer_group]": dati.partitaId,
    },
    dati.chiaveIdempotenza,
  );
  return leggiSessione(json);
}

/**
 * Legge lo stato di una Checkout Session gia' creata.
 *
 * Serve quando la Quota ha gia' un pagamento `in_attesa`: secondo lo stato della
 * sessione si riusa l'URL, si attende il webhook o se ne crea una nuova (decisione
 * dei PM su KCK-225).
 */
export async function leggiSessioneCheckout(
  fetchStripe: Fetch,
  chiaveSegreta: string,
  idSessione: string,
): Promise<SessioneCheckout> {
  const json = await chiamaStripe(
    fetchStripe,
    chiaveSegreta,
    "GET",
    `/checkout/sessions/${encodeURIComponent(idSessione)}`,
  );
  return leggiSessione(json);
}

/**
 * Collega l'account Stripe del Gestore del Campo (D3) e restituisce l'URL
 * dell'onboarding ospitato da Stripe.
 *
 * Se il Gestore non ha ancora un account (`idAccountPagamenti` vuoto) lo crea con
 * POST /v1/accounts e lo fa salvare con `salvaIdAccount` SUBITO, prima di chiedere
 * il link: se poi il link fallisce l'account non resta orfano e al tentativo
 * successivo si riusa. La chiave di idempotenza `onboarding_<account_id>` evita
 * un secondo account se la stessa richiesta viene ripetuta.
 *
 * Perche' i `controller` e non `type=express`: Stripe indica `type` come
 * parametro dei tipi di account legacy; i controller sono l'equivalente per le
 * piattaforme nuove. Con Dashboard Express, commissioni e perdite a carico della
 * piattaforma e requisiti raccolti da Stripe si ottiene lo stesso comportamento di
 * un account Express. Si chiede solo la capability `transfers`, l'unica che serve
 * per separate charges and transfers (la piattaforma incassa, il Gestore riceve il
 * transfer). Documentazione:
 * - https://docs.stripe.com/connect/express-accounts
 * - https://docs.stripe.com/connect/account-capabilities
 * - https://docs.stripe.com/connect/separate-charges-and-transfers
 */
export async function collegaAccountGestore(
  fetchStripe: Fetch,
  chiaveSegreta: string,
  dati: {
    accountId: string;
    idAccountPagamenti: string | null;
    urlRitorno: string;
    urlAggiornamento: string;
    salvaIdAccount: (idAccountPagamenti: string) => Promise<void>;
  },
): Promise<{ idAccountPagamenti: string; url: string }> {
  let idAccountPagamenti = dati.idAccountPagamenti;
  if (idAccountPagamenti === null) {
    const account = await chiamaStripe(
      fetchStripe,
      chiaveSegreta,
      "POST",
      "/accounts",
      {
        "country": "IT",
        "controller[stripe_dashboard][type]": "express",
        "controller[fees][payer]": "application",
        "controller[losses][payments]": "application",
        "controller[requirement_collection]": "stripe",
        "capabilities[transfers][requested]": "true",
      },
      `onboarding_${dati.accountId}`,
    );
    if (typeof account.id !== "string") {
      throw new ErroreStripe(null);
    }
    idAccountPagamenti = account.id;
    await dati.salvaIdAccount(idAccountPagamenti);
  }

  const link = await chiamaStripe(
    fetchStripe,
    chiaveSegreta,
    "POST",
    "/account_links",
    {
      "account": idAccountPagamenti,
      "refresh_url": dati.urlAggiornamento,
      "return_url": dati.urlRitorno,
      "type": "account_onboarding",
    },
  );
  if (typeof link.url !== "string") {
    throw new ErroreStripe(null);
  }
  return { idAccountPagamenti, url: link.url };
}

/** Estrae dal JSON di Stripe i campi della Checkout Session usati qui. */
function leggiSessione(json: Record<string, unknown>): SessioneCheckout {
  const stato = json.status;
  if (
    typeof json.id !== "string" ||
    (stato !== "open" && stato !== "complete" && stato !== "expired")
  ) {
    throw new ErroreStripe(null);
  }
  return {
    id: json.id,
    url: typeof json.url === "string" ? json.url : null,
    status: stato,
  };
}

# Edge Function `pagamenti` (KCK-225)

Collega l'account Stripe del Gestore del Campo (`onboarding_gestore`, D3) e crea
la Checkout Session per versare una Quota (`crea_pagamento`, RF_PAG_1,
UC_PAG_1). Funziona solo in **modalità test** di Stripe: la funzione rifiuta
qualsiasi chiave che non inizi con `sk_test_`.

La chiave segreta di Stripe resta solo sul server (DG1, SDD v1.4 §1.3 e §3.3).
Nessun dato di carta o IBAN passa dall'app: il Giocatore paga sulla pagina
Checkout di Stripe.

Fuori da questo ticket:

- il webhook che porta la Transazione a `completata` o `fallita` e la Quota a
  `versata` (KCK-231);
- l'accredito al Gestore (RF_PAG_2).

## Azioni

Tutte le richieste sono `POST` con il JWT dell'utente nell'header
`Authorization` e un corpo JSON.

| Azione               | Corpo                                                  | Risposta                                                  |
| -------------------- | ------------------------------------------------------ | --------------------------------------------------------- |
| `onboarding_gestore` | `{ "azione": "onboarding_gestore" }`                   | `{ "url": ... }`: pagina di onboarding ospitata da Stripe |
| `crea_pagamento`     | `{ "azione": "crea_pagamento", "quota_id": "<uuid>" }` | `{ "url": ... }`: pagina Checkout di Stripe               |

L'importo non si manda: lo legge il server da `quota.importo`.

## Chiave di idempotenza del pagamento

`crea_pagamento` manda a Stripe l'header `Idempotency-Key` con il valore
`pagamento_<quota_id>_<n>_<finestra>`:

- `n` è il numero di pagamenti `fallita` già registrati per la Quota, quindi
  dopo un pagamento fallito la chiave cambia e il Giocatore può riprovare;
- `finestra` è `Math.floor(adesso / 600000)`, cioè una finestra di 10 minuti.

Due richieste ripetute nella stessa finestra ricevono da Stripe la stessa
sessione, quindi non c'è un doppio addebito (DG2).

La finestra serve perché Stripe conserva per 24 ore la risposta associata a una
chiave, **anche se era un errore 500**. Senza finestra, dopo un 500 ogni nuovo
tentativo riceverebbe lo stesso errore per un giorno intero.

Tra due finestre diverse non nascono due URL validi per la stessa Quota:

- se la Quota ha già un pagamento `completata`, la funzione risponde "pagamento
  in verifica" senza chiamare Stripe (si attende il webhook di KCK-231);
- se ne ha uno `in_attesa`, riusa la sua sessione: stesso URL se è aperta,
  "pagamento in verifica" se è completa, nuova sessione solo se è scaduta;
- se due richieste concorrenti superano insieme questi controlli, l'indice
  univoco su `transazione` (un solo pagamento non fallito per Quota, D27) fa
  scattare il conflitto e la funzione restituisce la sessione già registrata.

## Variabili d'ambiente

| Variabile                    | Uso                                                                                       |
| ---------------------------- | ----------------------------------------------------------------------------------------- |
| `STRIPE_SECRET_KEY`          | chiave segreta di **test** (`sk_test_...`)                                                |
| `STRIPE_SUCCESS_URL`         | ritorno dalla Checkout dopo il pagamento. La sua origine è anche l'unica ammessa dal CORS |
| `STRIPE_CANCEL_URL`          | ritorno dalla Checkout se il Giocatore annulla                                            |
| `STRIPE_ACCOUNT_RETURN_URL`  | ritorno dall'onboarding del Gestore                                                       |
| `STRIPE_ACCOUNT_REFRESH_URL` | link di onboarding scaduto, da rigenerare                                                 |

`SUPABASE_URL` e `SUPABASE_SERVICE_ROLE_KEY` li fornisce il runtime delle Edge
Functions.

## Prova in locale

### Prerequisiti

1. Un account Stripe personale in **modalità test**.
2. In quell'account va **attivato Connect** e **completato il profilo della
   piattaforma** (Dashboard Stripe, sezione Connect). Senza questo passo
   `POST /v1/accounts` fallisce e `onboarding_gestore` risponde 502.
3. Supabase CLI lanciata con `npx supabase@3.2.0`, la stessa versione della CI.
   Database locale: `npx supabase@3.2.0 start` e `npx supabase@3.2.0 db reset`.
4. Su Fedora con SELinux attivo, una volta sola dalla radice della repo:

   ```sh
   chcon -R -t container_file_t supabase/functions
   ```

   Senza questo passo il container delle Edge Functions non può leggere i file e
   la funzione si ferma con `BOOT_ERROR` "failed to determine entrypoint".

### Passi

1. Crea un file di variabili **fuori dalla repo**, per esempio
   `~/.config/kickly/pagamenti.env`. Inserisci le cinque variabili della tabella
   e, come `STRIPE_SECRET_KEY`, la tua chiave di test personale, copiata dalla
   Dashboard Stripe (Sviluppatori, Chiavi API). Non copiare mai questo file
   nella repo e non incollare la chiave in issue, PR o chat.
2. Avvia la funzione:

   ```sh
   npx supabase@3.2.0 functions serve pagamenti --env-file ~/.config/kickly/pagamenti.env
   ```

3. Chiama `crea_pagamento` con il JWT di un Giocatore che ha una Quota
   `da_versare` in una partita `Completa`. Apri l'URL restituito e paga con la
   carta di test **4242 4242 4242 4242**, una data di scadenza futura, un CVC
   qualsiasi di 3 cifre e un CAP qualsiasi.
4. Chiama `onboarding_gestore` con il JWT di un Gestore del Campo. Apri l'URL
   restituito e completa l'onboarding con i dati di test che propone Stripe.

## Test

I test usano Stripe e il DB finti, quindi non serve nessuna chiave:

```sh
deno test --allow-env --allow-net supabase/functions/pagamenti
```

import 'account.dart';
import 'gestore_campo.dart';
import 'giocatore.dart';

/// Contratto di persistenza per Account e per le sue specializzazioni.
///
/// L'interfaccia appartiene al Domain Layer e non dipende da Supabase o da
/// altri SDK, così il Control può usare implementazioni diverse.
abstract interface class AccountRepository {
  /// Codice dell'AppException lanciata da [accedi] quando il servizio di
  /// autenticazione rifiuta email e password (KCK-208, risposta dei PM).
  static const codiceCredenzialiNonValide = 'credenziali_non_valide';

  /// Codice dell'AppException lanciata da [registra] quando l'email esiste gia'.
  static const codiceEmailGiaRegistrata = 'email_gia_registrata';

  /// Codice dell'AppException lanciata da [registra] quando il servizio di
  /// autenticazione rifiuta l'indirizzo email (formato o dominio non validi).
  ///
  /// Serve a mostrare un errore specifico (UC_ACC_1 E2) al posto del messaggio
  /// generico sui permessi (KCK-277).
  static const codiceEmailNonValida = 'email_non_valida';

  /// Codice dell'AppException lanciata da [registra] quando il servizio di
  /// autenticazione blocca temporaneamente le richieste (limite di invii).
  ///
  /// L'utente deve solo riprovare tra poco: non e' un problema di permessi.
  static const codiceTroppeRichieste = 'troppe_richieste';

  /// Crea le credenziali Auth e restituisce l'id dell'account creato.
  ///
  /// Nome, cognome ed eta' vengono passati nei metadati perche' il trigger
  /// della Migration A crei la riga Account. La password non viene persistita
  /// in Account.
  Future<String> registra(
    String email,
    String password,
    String nome,
    String cognome,
    int eta,
  );

  /// Salva il ruolo scelto e, per il Giocatore, crea la Player Card vuota.
  Future<void> salvaRuolo(String accountId, String ruolo);

  /// Autentica l'utente con le credenziali della registrazione (RF_ACC_3) e
  /// restituisce l'id del suo account.
  ///
  /// Se le credenziali sono rifiutate lancia un'AppException con codice
  /// [codiceCredenzialiNonValide]; gli altri errori (es. rete) restano
  /// AppException con il proprio codice. La password non viene salvata: passa
  /// solo al servizio di autenticazione (class_diagram_sdd.md §3, regola 2).
  Future<String> accedi(String email, String password);

  /// Chiude la sessione dell'utente autenticato (logout, RF_ACC_3).
  Future<void> esci();

  /// Restituisce l'id dell'account con una sessione aperta, o null se nessun
  /// utente e' autenticato.
  String? idAccountAutenticato();

  /// Emette l'id dell'account autenticato a ogni cambio di sessione (login,
  /// logout, sessione chiusa dal servizio); null quando non c'e' sessione.
  Stream<String?> cambiamentiAutenticazione();

  /// Cerca un account e restituisce la specializzazione eventualmente presente.
  Future<Account?> findById(String id);

  /// Cerca un account tramite l'indirizzo email.
  Future<Account?> findByEmail(String email);

  /// Salva i dati comuni dell'account e restituisce la riga persistita.
  Future<Account> createAccount(Account account);

  /// Completa il ruolo e la Player Card di un Giocatore.
  Future<Giocatore> completaOnboardingGiocatore(Giocatore giocatore);

  /// Completa il ruolo e i dati del GestoreCampo.
  Future<GestoreCampo> completaOnboardingGestore(GestoreCampo gestore);

  /// Aggiorna i dati della Player Card di un Giocatore.
  Future<Giocatore> aggiornaPlayerCard(Giocatore giocatore);

  /// Salva le preferenze di notifica serializzate dell'account.
  Future<void> aggiornaPreferenzeNotifiche(
    String accountId,
    String preferenzeNotifiche,
  );

  /// Aggiorna lo stato applicativo dell'account.
  Future<void> aggiornaStatoAccount(String accountId, String statoAccount);

  /// Elimina i dati pubblici dell'account e le associazioni a cascata.
  Future<void> deleteAccount(String accountId);
}

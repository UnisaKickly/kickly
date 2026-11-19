/// Errore applicativo condiviso dagli strati Data, Domain e Presentation.
///
/// Nasconde le eccezioni tecniche dell'SDK e offre un messaggio leggibile
/// all'utente, mantenendo separatamente gli eventuali dettagli diagnostici.
class AppException implements Exception {
  /// Crea un errore applicativo con messaggio, codice e dettagli opzionali.
  ///
  /// Il codice e gli errori originali servono alla diagnostica senza esporre
  /// implementazioni tecniche all'interfaccia utente.
  AppException({
    required this.message,
    this.code,
    this.originalError,
    this.stackTrace,
  });

  /// Crea un errore causato da problemi di rete o connettivita'.
  ///
  /// Indica all'utente come ripristinare la connettivita' senza mostrare
  /// l'eccezione di rete proveniente dal sistema o dall'SDK.
  AppException.network({this.originalError, this.stackTrace})
    : message = 'Problema di connessione. Controlla la rete e riprova.',
      code = 'network';

  /// Crea un errore causato dalla mancanza di permessi o autenticazione.
  ///
  /// Unifica i rifiuti RLS, Auth e PostgREST in un messaggio comprensibile.
  AppException.permission({this.originalError, this.stackTrace})
    : message = 'Non hai i permessi necessari per questa operazione.',
      code = 'permission';

  /// Crea un errore relativo a vincoli o operazioni del database.
  ///
  /// Accetta un messaggio leggibile per distinguere duplicati, riferimenti
  /// assenti, campi obbligatori e altri vincoli PostgreSQL/PostgREST.
  AppException.database({
    required this.message,
    this.code,
    this.originalError,
    this.stackTrace,
  });

  /// Crea un errore causato dalla mancata configurazione del servizio.
  ///
  /// Viene usato quando Supabase non e' stato inizializzato prima dell'accesso
  /// al client condiviso.
  AppException.configuration({this.originalError, this.stackTrace})
    : message = 'Configurazione del servizio non disponibile.',
      code = 'configuration';

  /// Crea un errore applicativo per un caso tecnico imprevisto.
  ///
  /// Evita di esporre eccezioni sconosciute alla GUI e mantiene i dettagli
  /// originali disponibili per il tracciamento.
  AppException.unexpected({this.originalError, this.stackTrace})
    : message = 'Si è verificato un errore imprevisto. Riprova.',
      code = 'unexpected';

  /// Messaggio leggibile da mostrare all'utente.
  final String message;

  /// Categoria o codice tecnico stabile dell'errore.
  final String? code;

  /// Eccezione originale conservata per diagnostica e tracciamento.
  final Object? originalError;

  /// Stack trace originale, se disponibile, per la diagnostica.
  final StackTrace? stackTrace;

  /// Restituisce il messaggio applicativo senza esporre dettagli tecnici.
  @override
  String toString() => message;
}

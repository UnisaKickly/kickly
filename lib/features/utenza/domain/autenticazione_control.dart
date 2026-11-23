// Control AutenticazioneControl della tabella degli oggetti del RAD
// (§3.4.4.1.1): gestisce login e logout (RF_ACC_3).
//
// Per questo flusso non c'e' un sequence diagram; l'ordine delle chiamate e':
// FormLogin -> AutenticazioneControl.login() -> AccountRepository.accedi() ->
// AccountRepository.findById() -> Dashboard, e ImpostazioniAccount ->
// AutenticazioneControl.logout() -> AccountRepository.esci().
// La validazione dei dati sta qui, non nella GUI ne' nel repository (ticket
// KCK-208). Nessun import di Flutter o di SDK esterni (DG9).
import '../../../core/errors/app_exception.dart';
import 'account.dart';
import 'account_repository.dart';

/// Credenziali rifiutate: email non registrata o password errata.
///
/// Il messaggio e' lo stesso nei due casi, cosi' non si rivela quali email
/// sono registrate (D16, TF_ACC_11 e TF_ACC_12).
class CredenzialiNonCorretteException extends AppException {
  /// Crea l'errore con il messaggio unico di D16.
  CredenzialiNonCorretteException({super.originalError, super.stackTrace})
    : super(
        message: 'Email o password non corretti',
        code: AccountRepository.codiceCredenzialiNonValide,
      );
}

/// Campo del modulo di login lasciato vuoto (D16, TF_ACC_13).
///
/// [campo] dice alla GUI accanto a quale campo mostrare l'errore.
class CampoObbligatorioException extends AppException {
  /// Crea l'errore per il campo indicato, [email] o [password].
  CampoObbligatorioException(this.campo)
    : super(
        message: campo == email ? "Inserisci l'email" : 'Inserisci la password',
        code: 'campo_obbligatorio',
      );

  /// Nome del campo email del modulo di login.
  static const email = 'email';

  /// Nome del campo password del modulo di login.
  static const password = 'password';

  /// Campo vuoto: [email] o [password].
  final String campo;
}

/// Gestisce login e logout di un utente gia' registrato (RF_ACC_3).
///
/// Usa solo AccountRepository: il servizio di autenticazione e il Secure
/// Storage del token stanno nello strato Data e in lib/core/persistence.
class AutenticazioneControl {
  /// Crea il Control con il repository degli account.
  ///
  /// Il parametro si chiama `accountRepository` (parametro nominato privato).
  AutenticazioneControl({required this._accountRepository});

  final AccountRepository _accountRepository;

  /// Dice se c'e' una sessione aperta.
  bool get autenticato => _accountRepository.idAccountAutenticato() != null;

  /// Id dell'account con la sessione aperta, null se nessuno ha fatto
  /// l'accesso.
  ///
  /// Serve alle Boundary che devono passare l'id del Giocatore ad altri
  /// Control (es. FormLega -> GestioneLegaControl, KCK-249): i Control delle
  /// leghe non dipendono da Gestione Utenza (component diagram dell'SDD).
  String? get idAccountAutenticato => _accountRepository.idAccountAutenticato();

  /// Emette true o false a ogni cambio di sessione (login, logout o sessione
  /// chiusa dal servizio).
  ///
  /// Serve al router: l'adattatore che implementa SessioneProvider (che e' un
  /// tipo di Flutter) lo ascolta e sta fuori da domain/ (KCK-215).
  Stream<bool> get cambiamentiSessione => _accountRepository
      .cambiamentiAutenticazione()
      .map((String? idAccount) => idAccount != null);

  /// Autentica l'utente e restituisce il suo Account.
  ///
  /// La GUI usa l'Account restituito per la schermata successiva: la
  /// Dashboard se l'onboarding e' completato (TF_ACC_10), altrimenti la
  /// ripresa dell'onboarding (UC_ACC_1 E3, gestita da RegistrazioneControl).
  /// Lancia [CampoObbligatorioException] se email o password sono vuote e
  /// [CredenzialiNonCorretteException] se le credenziali sono rifiutate; gli
  /// altri errori (es. rete) arrivano come AppException del repository.
  Future<Account> login(String email, String password) async {
    // Gli spazi attorno all'email sono un errore di battitura frequente; la
    // password invece si passa com'e', perche' gli spazi possono farne parte.
    final String emailPulita = email.trim();
    if (emailPulita.isEmpty) {
      throw CampoObbligatorioException(CampoObbligatorioException.email);
    }
    if (password.isEmpty) {
      throw CampoObbligatorioException(CampoObbligatorioException.password);
    }

    final String idAccount;
    try {
      idAccount = await _accountRepository.accedi(emailPulita, password);
    } on AppException catch (error, stackTrace) {
      if (error.code == AccountRepository.codiceCredenzialiNonValide) {
        throw CredenzialiNonCorretteException(
          originalError: error,
          stackTrace: stackTrace,
        );
      }
      rethrow;
    }

    final Account? account;
    try {
      account = await _accountRepository.findById(idAccount);
    } on Object {
      // Senza i dati dell'account il login non e' riuscito: si chiude la
      // sessione appena aperta, cosi' l'app non resta autenticata.
      await _chiudiSessioneSenzaErrori();
      rethrow;
    }
    if (account == null) {
      // Utente autenticato senza riga in `account`: non dovrebbe succedere
      // (la crea il trigger della migration A). Si chiude la sessione per
      // non lasciare l'app autenticata senza dati.
      await _chiudiSessioneSenzaErrori();
      throw AppException.unexpected(
        originalError: StateError('Account $idAccount non trovato.'),
      );
    }
    return account;
  }

  /// Chiude la sessione dopo un login non completato; un errore della
  /// chiusura non deve nascondere quello del login.
  Future<void> _chiudiSessioneSenzaErrori() async {
    try {
      await _accountRepository.esci();
    } on Object {
      // Ignorato di proposito: si rilancia l'errore del login.
    }
  }

  /// Chiude la sessione: per accedere di nuovo servono le credenziali
  /// (TF_ACC_14).
  Future<void> logout() => _accountRepository.esci();
}

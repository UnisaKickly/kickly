import '../../../core/errors/app_exception.dart';
import 'account.dart';
import 'account_repository.dart';
import 'giocatore.dart';
import 'validatore_password.dart';

/// Passo dell'onboarding Giocatore da mostrare al successivo accesso.
enum PassoOnboarding { sceltaRuolo, playerCard, nessuno }

/// Gestisce registrazione, onboarding e configurazione della Player Card.
///
/// Usa AccountRepository per persistere i dati e non dipende da SDK esterni o
/// dalle Boundary della presentazione.
class RegistrazioneControl {
  /// Crea il Control con il repository degli account.
  RegistrazioneControl({required this._accountRepository});

  final AccountRepository _accountRepository;

  /// Campi raccolti da FormRegistrazione secondo UC_ACC_1.
  static const campiModulo = <String>[
    'nome',
    'cognome',
    'email',
    'password',
    'eta',
  ];

  /// Restituisce i campi necessari alla Boundary per mostrare il modulo.
  List<String> richiediModulo() => campiModulo;

  /// Valida i dati del modulo e registra il nuovo account.
  ///
  /// Restituisce l'id creato da Supabase Auth; i dati anagrafici passano al
  /// trigger tramite AccountRepository e la password non diventa un attributo
  /// di Account. Lancia errori specifici per dati mancanti o password debole.
  Future<String> registra({
    required String? nome,
    required String? cognome,
    required String? email,
    required String? password,
    required int? eta,
  }) async {
    final nomePulito = _campoObbligatorio(nome, 'nome');
    final cognomePulito = _campoObbligatorio(cognome, 'cognome');
    final emailPulita = _campoObbligatorio(email, 'email');
    final passwordPulita = _campoObbligatorio(
      password,
      'password',
      conservaSpazi: true,
    );
    if (eta == null) {
      throw AppException(
        message: "Inserisci l'età",
        code: 'campo_obbligatorio',
      );
    }

    validaPassword(passwordPulita);
    if (eta < 14 || eta > 120) {
      throw AppException(
        message: "L'età deve essere compresa tra 14 e 120 anni",
        code: 'eta_non_valida',
      );
    }

    return _accountRepository.registra(
      emailPulita,
      passwordPulita,
      nomePulito,
      cognomePulito,
      eta,
    );
  }

  /// Imposta come definitivo il ruolo Giocatore e inizializza la Player Card.
  Future<void> confermaRuolo(String accountId) {
    return _accountRepository.salvaRuolo(accountId, RuoloAccount.giocatore);
  }

  /// Valida e salva i dati della Player Card, completando l'onboarding.
  Future<Giocatore> salvaPlayerCard(
    String accountId, {
    required String? ruoloPreferitoInCampo,
    required String? piedeDominante,
  }) async {
    final ruolo = _campoPlayerCard(
      ruoloPreferitoInCampo,
      'ruoloPreferitoInCampo',
    );
    final piede = _campoPlayerCard(piedeDominante, 'piedeDominante');
    final account = await _accountRepository.findById(accountId);
    if (account is! Giocatore) {
      throw AppException.unexpected(
        originalError: StateError(
          'Giocatore $accountId non trovato per salvare la Player Card.',
        ),
      );
    }

    return _accountRepository.completaOnboardingGiocatore(
      Giocatore(
        id: account.id,
        ruoloAccount: RuoloAccount.giocatore,
        nome: account.nome,
        cognome: account.cognome,
        email: account.email,
        eta: account.eta,
        statoAccount: account.statoAccount,
        statoOnboarding: StatoOnboarding.completato,
        preferenzeNotifiche: account.preferenzeNotifiche,
        ruoloPreferitoInCampo: ruolo,
        piedeDominante: piede,
      ),
    );
  }

  /// Indica se riproporre la scelta del ruolo o la Player Card dopo un login.
  ///
  /// Un onboarding completato non si ripropone; per un Giocatore incompleto
  /// torna playerCard, mentre un account ancora senza ruolo torna sceltaRuolo.
  PassoOnboarding passoOnboardingDaRiprendere(Account account) {
    if (account.statoOnboarding == StatoOnboarding.completato) {
      return PassoOnboarding.nessuno;
    }
    if (account.ruoloAccount == null) {
      return PassoOnboarding.sceltaRuolo;
    }
    if (account.ruoloAccount == RuoloAccount.giocatore &&
        (account is! Giocatore ||
            account.ruoloPreferitoInCampo == null ||
            account.piedeDominante == null)) {
      return PassoOnboarding.playerCard;
    }
    return PassoOnboarding.nessuno;
  }

  /// Controlla che un campo testuale obbligatorio sia valorizzato.
  String _campoObbligatorio(
    String? valore,
    String campo, {
    bool conservaSpazi = false,
  }) {
    final valorePulito = conservaSpazi ? valore : valore?.trim();
    if (valorePulito == null || valorePulito.isEmpty) {
      throw AppException(
        message: switch (campo) {
          'nome' => 'Inserisci il nome',
          'cognome' => 'Inserisci il cognome',
          'email' => "Inserisci l'email",
          'password' => 'Inserisci la password',
          _ => 'Completa il campo obbligatorio',
        },
        code: 'campo_obbligatorio',
      );
    }
    return valorePulito;
  }

  /// Controlla che un dato obbligatorio della Player Card non sia vuoto.
  String _campoPlayerCard(String? valore, String campo) {
    final valorePulito = valore?.trim();
    if (valorePulito == null || valorePulito.isEmpty) {
      throw AppException(
        message: campo == 'ruoloPreferitoInCampo'
            ? 'Seleziona il ruolo preferito in campo'
            : 'Seleziona il piede dominante',
        code: 'player_card_incompleta',
      );
    }
    return valorePulito;
  }
}

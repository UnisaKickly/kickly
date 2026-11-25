import 'dart:async';

import '../../../core/errors/app_exception.dart';
import '../domain/account.dart';
import '../domain/account_repository.dart';
import '../domain/gestore_campo.dart';
import '../domain/giocatore.dart';

/// Implementazione in memoria di AccountRepository per test e sviluppo locale.
class InMemoryAccountRepository implements AccountRepository {
  /// Crea un repository vuoto con ID deterministici per gli account senza ID.
  InMemoryAccountRepository();

  final Map<String, Account> _accounts = {};
  int _nextId = 1;

  /// Password fittizie per email, al posto di Supabase Auth.
  final Map<String, String> _password = {};

  /// Id dell'account con la sessione aperta, null se nessuno e' autenticato.
  String? _idAutenticato;

  /// Avvisa gli ascoltatori a ogni login o logout simulato.
  final StreamController<String?> _cambiamenti =
      StreamController<String?>.broadcast();

  /// Registra in memoria credenziali e dati iniziali al posto di Supabase Auth.
  @override
  Future<String> registra(
    String email,
    String password,
    String nome,
    String cognome,
    int eta,
  ) async {
    final emailPulita = email.trim();
    final emailGiaPresente = _accounts.values.any(
      (Account account) =>
          account.email.toLowerCase() == emailPulita.toLowerCase(),
    );
    if (emailGiaPresente) {
      throw AppException(
        message: 'Email già registrata. Accedi o usa un altro indirizzo email.',
        code: AccountRepository.codiceEmailGiaRegistrata,
      );
    }

    final id = _generateId();
    _accounts[id] = Account(
      id: id,
      nome: nome.trim(),
      cognome: cognome.trim(),
      email: emailPulita,
      eta: eta,
      statoAccount: StatoAccount.attivo,
      statoOnboarding: StatoOnboarding.inCorso,
      preferenzeNotifiche: '{}',
    );
    _password[emailPulita] = password;
    return id;
  }

  /// Imposta il ruolo scelto e crea la specializzazione vuota del Giocatore.
  @override
  Future<void> salvaRuolo(String accountId, String ruolo) async {
    final Account? account = await findById(accountId);
    if (account == null) {
      throw AppException.unexpected(
        originalError: StateError('Account $accountId non trovato.'),
      );
    }
    if (!RuoloAccount.valori.contains(ruolo)) {
      throw AppException(
        message: 'Il ruolo selezionato non è valido.',
        code: 'ruolo_non_valido',
      );
    }
    if (account is Giocatore || account is GestoreCampo) {
      throw AppException(
        message: 'Il ruolo non può essere modificato dopo la scelta.',
        code: 'ruolo_gia_scelto',
      );
    }
    if (account.ruoloAccount != null && account.ruoloAccount != ruolo) {
      throw AppException(
        message: 'Il ruolo non può essere modificato dopo la scelta.',
        code: 'ruolo_gia_scelto',
      );
    }

    if (ruolo == RuoloAccount.giocatore) {
      _accounts[accountId] = Giocatore(
        id: account.id,
        ruoloAccount: ruolo,
        nome: account.nome,
        cognome: account.cognome,
        email: account.email,
        eta: account.eta,
        statoAccount: account.statoAccount,
        statoOnboarding: account.statoOnboarding,
        preferenzeNotifiche: account.preferenzeNotifiche,
      );
      return;
    }

    _accounts[accountId] = Account(
      id: account.id,
      ruoloAccount: ruolo,
      nome: account.nome,
      cognome: account.cognome,
      email: account.email,
      eta: account.eta,
      statoAccount: account.statoAccount,
      statoOnboarding: account.statoOnboarding,
      preferenzeNotifiche: account.preferenzeNotifiche,
    );
  }

  /// Registra la password di un'email per i test di login.
  ///
  /// Non fa parte di AccountRepository: nel sistema vero le credenziali le
  /// crea Supabase Auth in registrazione (KCK-250).
  void impostaPassword(String email, String password) {
    _password[email] = password;
  }

  @override
  Future<String> accedi(String email, String password) async {
    final Account? account = await findByEmail(email);
    // Email non registrata e password errata danno lo stesso errore, come
    // Supabase Auth (D16).
    if (account == null || _password[email] != password) {
      throw AppException(
        message: 'Email o password non corretti',
        code: AccountRepository.codiceCredenzialiNonValide,
      );
    }
    _idAutenticato = account.id;
    _cambiamenti.add(account.id);
    return account.id;
  }

  @override
  Future<void> esci() async {
    _idAutenticato = null;
    _cambiamenti.add(null);
  }

  @override
  String? idAccountAutenticato() => _idAutenticato;

  @override
  Stream<String?> cambiamentiAutenticazione() => _cambiamenti.stream;

  /// Genera un UUID fittizio stabile senza dipendenze esterne.
  String _generateId() {
    final id = _nextId++;
    return '00000000-0000-4000-8000-${id.toString().padLeft(12, '0')}';
  }

  /// Restituisce una copia dell'account con le preferenze aggiornate.
  Account _withPreferences(Account account, String preferences) {
    if (account is Giocatore) {
      return Giocatore(
        id: account.id,
        ruoloAccount: account.ruoloAccount,
        nome: account.nome,
        cognome: account.cognome,
        email: account.email,
        eta: account.eta,
        statoAccount: account.statoAccount,
        statoOnboarding: account.statoOnboarding,
        preferenzeNotifiche: preferences,
        ruoloPreferitoInCampo: account.ruoloPreferitoInCampo,
        piedeDominante: account.piedeDominante,
      );
    }
    if (account is GestoreCampo) {
      return GestoreCampo(
        id: account.id,
        ruoloAccount: account.ruoloAccount,
        nome: account.nome,
        cognome: account.cognome,
        email: account.email,
        eta: account.eta,
        statoAccount: account.statoAccount,
        statoOnboarding: account.statoOnboarding,
        preferenzeNotifiche: preferences,
        idAccountPagamenti: account.idAccountPagamenti,
      );
    }
    return Account(
      id: account.id,
      ruoloAccount: account.ruoloAccount,
      nome: account.nome,
      cognome: account.cognome,
      email: account.email,
      eta: account.eta,
      statoAccount: account.statoAccount,
      statoOnboarding: account.statoOnboarding,
      preferenzeNotifiche: preferences,
    );
  }

  /// Restituisce una copia dell'account con lo stato aggiornato.
  Account _withStatus(Account account, String status) {
    return _withPreferences(
      account is Giocatore
          ? Giocatore(
              id: account.id,
              ruoloAccount: account.ruoloAccount,
              nome: account.nome,
              cognome: account.cognome,
              email: account.email,
              eta: account.eta,
              statoAccount: status,
              statoOnboarding: account.statoOnboarding,
              preferenzeNotifiche: account.preferenzeNotifiche,
              ruoloPreferitoInCampo: account.ruoloPreferitoInCampo,
              piedeDominante: account.piedeDominante,
            )
          : account is GestoreCampo
          ? GestoreCampo(
              id: account.id,
              ruoloAccount: account.ruoloAccount,
              nome: account.nome,
              cognome: account.cognome,
              email: account.email,
              eta: account.eta,
              statoAccount: status,
              statoOnboarding: account.statoOnboarding,
              preferenzeNotifiche: account.preferenzeNotifiche,
              idAccountPagamenti: account.idAccountPagamenti,
            )
          : Account(
              id: account.id,
              ruoloAccount: account.ruoloAccount,
              nome: account.nome,
              cognome: account.cognome,
              email: account.email,
              eta: account.eta,
              statoAccount: status,
              statoOnboarding: account.statoOnboarding,
              preferenzeNotifiche: account.preferenzeNotifiche,
            ),
      account.preferenzeNotifiche,
    );
  }

  /// Salva un account e assegna un ID deterministico se necessario.
  @override
  Future<Account> createAccount(Account account) async {
    final id = account.id.isEmpty ? _generateId() : account.id;
    final saved = id == account.id
        ? account
        : Account(
            id: id,
            ruoloAccount: account.ruoloAccount,
            nome: account.nome,
            cognome: account.cognome,
            email: account.email,
            eta: account.eta,
            statoAccount: account.statoAccount,
            statoOnboarding: account.statoOnboarding,
            preferenzeNotifiche: account.preferenzeNotifiche,
          );
    _accounts[id] = saved;
    return saved;
  }

  @override
  Future<Account?> findById(String id) async => _accounts[id];

  @override
  Future<Account?> findByEmail(String email) async {
    for (final account in _accounts.values) {
      if (account.email == email) {
        return account;
      }
    }
    return null;
  }

  @override
  Future<Giocatore> completaOnboardingGiocatore(Giocatore giocatore) async {
    _accounts[giocatore.id] = giocatore;
    return giocatore;
  }

  @override
  Future<GestoreCampo> completaOnboardingGestore(GestoreCampo gestore) async {
    _accounts[gestore.id] = gestore;
    return gestore;
  }

  @override
  Future<Giocatore> aggiornaPlayerCard(Giocatore giocatore) async {
    _accounts[giocatore.id] = giocatore;
    return giocatore;
  }

  @override
  Future<void> aggiornaPreferenzeNotifiche(
    String accountId,
    String preferenzeNotifiche,
  ) async {
    final account = _accounts[accountId];
    if (account != null) {
      _accounts[accountId] = _withPreferences(account, preferenzeNotifiche);
    }
  }

  @override
  Future<void> aggiornaStatoAccount(
    String accountId,
    String statoAccount,
  ) async {
    final account = _accounts[accountId];
    if (account != null) {
      _accounts[accountId] = _withStatus(account, statoAccount);
    }
  }

  @override
  Future<void> deleteAccount(String accountId) async {
    _accounts.remove(accountId);
  }
}

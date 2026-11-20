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

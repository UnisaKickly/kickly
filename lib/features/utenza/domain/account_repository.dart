import 'account.dart';
import 'gestore_campo.dart';
import 'giocatore.dart';

/// Contratto di persistenza per Account e per le sue specializzazioni.
///
/// L'interfaccia appartiene al Domain Layer e non dipende da Supabase o da
/// altri SDK, così il Control può usare implementazioni diverse.
abstract interface class AccountRepository {
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

// Control GestioneLegaControl della tabella degli oggetti del RAD
// (§3.4.4.1.2): realizza UC_LEG_1 passi 1-4 (RF_LEG_1), cioe' validazione,
// controllo dei nomi duplicati, registrazione della lega e nomina
// dell'Amministratore.
//
// Per questo flusso non c'e' un sequence diagram; l'ordine delle chiamate e':
// FormLega -> GestioneLegaControl.creaLega() -> LegaRepository.existsByNome()
// -> LegaRepository.findByCodiceInvito() -> LegaRepository.createLega() ->
// DashboardLega. Se createLega rifiuta un duplicato, il Control richiama
// existsByNome() per capire se il duplicato e' il nome o il codice d'invito.
// La validazione dei dati sta qui, non nella GUI ne' nel repository (ticket
// KCK-242). Nessun import di Flutter o di SDK esterni (DG9).
import 'dart:math';

import '../../../core/errors/app_exception.dart';
import 'lega.dart';
import 'lega_repository.dart';

/// Dati del modulo di creazione non validi (UC_LEG_1 E1, "dati non validi").
///
/// [campo] dice alla GUI quale campo evidenziare, come chiede E1.
class DatiLegaNonValidiException extends AppException {
  /// Crea l'errore per il campo indicato: [nome], [tipologiaMatch] o
  /// [privacy].
  DatiLegaNonValidiException(this.campo)
    : super(message: _messaggioPer(campo), code: 'dati_lega_non_validi');

  /// Nome del campo nome della lega.
  static const nome = 'nome';

  /// Nome del campo tipologia di match.
  static const tipologiaMatch = 'tipologiaMatch';

  /// Nome del campo livello di privacy.
  static const privacy = 'privacy';

  /// Campo da correggere: [nome], [tipologiaMatch] o [privacy].
  final String campo;

  /// Sceglie il messaggio per l'utente in base al campo da correggere.
  static String _messaggioPer(String campo) {
    switch (campo) {
      case nome:
        return 'Inserisci il nome della lega';
      case tipologiaMatch:
        return 'Scegli una tipologia di match valida';
      default:
        return 'Scegli se la lega e\' Pubblica o Privata';
    }
  }
}

/// Nome della lega gia' usato da un'altra lega (UC_LEG_1 E1, D21).
///
/// Il confronto non distingue maiuscole e spazi iniziali/finali (D21).
class NomeLegaGiaInUsoException extends AppException {
  /// Crea l'errore con il messaggio di E1.
  NomeLegaGiaInUsoException({super.originalError, super.stackTrace})
    : super(message: 'Nome lega gia\' in uso', code: 'nome_lega_in_uso');

  /// Campo del modulo da evidenziare (sempre il nome).
  String get campo => DatiLegaNonValidiException.nome;
}

/// Gestisce la creazione di una lega (UC_LEG_1 passi 1-4, RF_LEG_1).
///
/// Legge e scrive i dati solo tramite LegaRepository. L'id del Giocatore lo
/// passa la GUI: nel component diagram dell'SDD il Control delle leghe non
/// dipende da Gestione Utenza.
class GestioneLegaControl {
  /// Crea il Control con il repository delle leghe.
  ///
  /// [orologio] restituisce l'ora attuale; si puo' sostituire nei test per
  /// avere una scadenza del codice d'invito prevedibile.
  GestioneLegaControl({
    required this._legaRepository,
    DateTime Function()? orologio,
  }) : _orologio = orologio ?? DateTime.now;

  /// Durata del codice d'invito generato alla creazione.
  ///
  /// Valore provvisorio: il RAD non dice la durata (domanda ai PM nel
  /// commento Jira di KCK-242).
  static const durataCodiceInvito = Duration(days: 7);

  /// Lunghezza del codice d'invito (provvisoria, come [durataCodiceInvito]).
  static const lunghezzaCodiceInvito = 8;

  /// Caratteri del codice d'invito: lettere maiuscole e cifre senza quelli
  /// facili da confondere (0/O, 1/I), perche' il codice si digita a mano
  /// (UC_LEG_1 passo 6).
  static const _caratteriCodice = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// Tentativi massimi per trovare un codice non ancora usato.
  static const _tentativiCodice = 5;

  /// Codice PostgreSQL di violazione di unicita' (nome o codice duplicato).
  static const _codiceDuplicato = '23505';

  final LegaRepository _legaRepository;
  final DateTime Function() _orologio;
  final Random _casuale = Random.secure();

  /// Registra una nuova lega e ne nomina amministratore chi la crea.
  ///
  /// [tipologiaMatch] e' uno dei valori di [TipologiaMatch] e [privacy] uno
  /// dei valori di [PrivacyLega]. Restituisce la lega salvata, con il codice
  /// d'invito univoco e la sua scadenza, che la GUI mostra nella
  /// DashboardLega (passo 4). Una lega pubblica (A1) e' visibile nella ricerca
  /// globale tramite LegaRepository.findPubbliche().
  /// Lancia [DatiLegaNonValidiException] se un dato non e' valido e
  /// [NomeLegaGiaInUsoException] se il nome e' gia' usato (E1); gli altri
  /// errori (es. rete) arrivano come AppException del repository.
  Future<Lega> creaLega({
    required String nome,
    required String tipologiaMatch,
    required String privacy,
    required String idGiocatore,
  }) async {
    final String nomePulito = nome.trim();
    _validaDati(nomePulito, tipologiaMatch, privacy);

    if (await _legaRepository.existsByNome(nomePulito)) {
      throw NomeLegaGiaInUsoException();
    }

    // Si riprova se il database rifiuta il codice d'invito perche' gia' usato
    // da una lega creata nel frattempo (passo 4: codice "univoco").
    for (var tentativo = 1; ; tentativo++) {
      final String codiceInvito = await _generaCodiceInvito();
      // L'id lo genera il database (D23): la stringa vuota indica una lega
      // non ancora salvata.
      final Lega nuovaLega = Lega(
        id: '',
        nome: nomePulito,
        tipologiaMatch: tipologiaMatch,
        privacy: privacy,
        codiceInvito: codiceInvito,
        scadenzaCodiceInvito: _orologio().add(durataCodiceInvito),
      );

      try {
        // Lega, membro e amministratore in un'unica transazione (D23).
        return await _legaRepository.createLega(nuovaLega, idGiocatore);
      } on AppException catch (error, stackTrace) {
        if (error.code != _codiceDuplicato) {
          rethrow;
        }
        // Due creazioni contemporanee con lo stesso nome: il controllo
        // precedente passa per entrambe, ma l'indice UNIQUE del database ne
        // rifiuta una (D21).
        if (await _legaRepository.existsByNome(nomePulito)) {
          throw NomeLegaGiaInUsoException(
            originalError: error,
            stackTrace: stackTrace,
          );
        }
        // Altrimenti il duplicato e' il codice d'invito: se ne genera un altro.
        if (tentativo >= _tentativiCodice) {
          rethrow;
        }
      }
    }
  }

  /// Controlla i dati del modulo nell'ordine dei campi di FormLega.
  ///
  /// Si ferma al primo campo non valido, cosi' la GUI evidenzia quello.
  void _validaDati(String nome, String tipologiaMatch, String privacy) {
    if (nome.isEmpty) {
      throw DatiLegaNonValidiException(DatiLegaNonValidiException.nome);
    }
    if (!TipologiaMatch.valori.contains(tipologiaMatch)) {
      throw DatiLegaNonValidiException(
        DatiLegaNonValidiException.tipologiaMatch,
      );
    }
    if (!PrivacyLega.valori.contains(privacy)) {
      throw DatiLegaNonValidiException(DatiLegaNonValidiException.privacy);
    }
  }

  /// Genera un codice d'invito che nessun'altra lega usa (passo 4: "codice
  /// d'invito univoco").
  ///
  /// Le combinazioni sono molte (32^8), quindi una collisione e' rarissima;
  /// si riprova comunque qualche volta prima di rinunciare.
  Future<String> _generaCodiceInvito() async {
    for (var tentativo = 0; tentativo < _tentativiCodice; tentativo++) {
      final String codice = String.fromCharCodes(
        List<int>.generate(
          lunghezzaCodiceInvito,
          (_) => _caratteriCodice.codeUnitAt(
            _casuale.nextInt(_caratteriCodice.length),
          ),
        ),
      );
      if (await _legaRepository.findByCodiceInvito(codice) == null) {
        return codice;
      }
    }
    throw AppException.unexpected(
      originalError: StateError('Nessun codice d\'invito libero trovato.'),
    );
  }
}

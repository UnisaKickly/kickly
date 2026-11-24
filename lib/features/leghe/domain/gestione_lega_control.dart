// Control GestioneLegaControl della tabella degli oggetti del RAD
// (§3.4.4.1.2): realizza UC_LEG_1 passi 1-4 (RF_LEG_1), cioe' validazione,
// controllo dei nomi duplicati, registrazione della lega e nomina
// dell'Amministratore, ed e' esteso alla modifica dei dettagli della lega
// (RF_LEG_1).
//
// Per questo flusso non c'e' un sequence diagram; l'ordine delle chiamate e':
// FormLega -> GestioneLegaControl.creaLega() -> LegaRepository.existsByNome()
// -> LegaRepository.findByCodiceInvito() -> LegaRepository.createLega() ->
// DashboardLega. Se createLega rifiuta un duplicato, il Control richiama
// existsByNome() per capire se il duplicato e' il nome o il codice d'invito.
// Modifica: FormLega -> GestioneLegaControl.modificaDettagliLega() ->
// LegaRepository.findById() -> LegaRepository.isAmministratore() ->
// LegaRepository.existsByNome() (solo se il nome cambia) ->
// LegaRepository.updateLega() -> DashboardLega.
// Elenco (VistaLeghe, KCK-249): VistaLeghe ->
// GestioneLegaControl.visualizzaLeghe() -> LegaRepository.findByGiocatore()
// -> LegaRepository.isAmministratore() per ogni lega.
// La validazione dei dati sta qui, non nella GUI ne' nel repository (ticket
// KCK-242). Nessun import di Flutter o di SDK esterni (DG9).
import 'dart:math';

import '../../../core/errors/app_exception.dart';
import 'gestione_adesione_control.dart';
import 'lega.dart';
import 'lega_repository.dart';

/// Indirizzo base condiviso dei link d'invito alle leghe.
///
/// Mantiene un unico punto di configurazione per il canale web degli inviti,
/// cosi' i Control non dipendono da una configurazione duplicata.
const indirizzoBaseInvito = 'https://unisakickly.github.io/kickly/';

/// Dati del modulo di creazione non validi (UC_LEG_1 E1, "dati non validi").
///
/// [campo] dice alla GUI quale campo evidenziare, come chiede E1.
class DatiLegaNonValidiException extends AppException {
  /// Crea l'errore per il campo indicato: [nome], [tipologiaMatch] o
  /// [privacy].
  ///
  /// [messaggio] sostituisce il messaggio predefinito del campo quando lo
  /// stesso campo puo' essere sbagliato in piu' modi (es. nome troppo lungo).
  DatiLegaNonValidiException(this.campo, {String? messaggio})
    : super(
        message: messaggio ?? _messaggioPer(campo),
        code: 'dati_lega_non_validi',
      );

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

/// Operazione riservata agli amministratori chiesta da chi non lo e' (D13).
///
/// La GUI non mostra il comando a chi non e' amministratore; questo errore
/// copre una richiesta arrivata comunque (TF_LEG_07).
class OperazioneNonPermessaException extends AppException {
  /// Crea l'errore con il messaggio per l'utente.
  OperazioneNonPermessaException()
    : super(
        message: 'Solo un amministratore puo\' modificare la lega',
        code: 'operazione_non_permessa',
      );
}

/// Invito condiviso da chi non ha il ruolo di amministratore della lega.
///
/// Protegge il canale di condivisione su richieste dirette (TF_LEG_11):
/// la GUI puo' nascondere il comando, ma il Control rifiuta ugualmente.
class CondivisioneInvitoNonPermessaException extends AppException {
  /// Crea l'errore con il messaggio leggibile per l'utente.
  CondivisioneInvitoNonPermessaException()
    : super(
        message: 'Solo un amministratore puo\' condividere l\'invito',
        code: 'condivisione_invito_non_permessa',
      );
}

/// Gestisce creazione e modifica di una lega (UC_LEG_1 passi 1-4, RF_LEG_1).
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
  /// Il RAD non dice la durata: 7 giorni dalla creazione (D29).
  static const durataCodiceInvito = Duration(days: 7);

  /// Lunghezza massima del nome della lega, in caratteri.
  ///
  /// Il limite e' nel mock-up UI_LEG_2 ("Massimo 30 caratteri"), che fa parte
  /// del RAD (§3.4.6); richiesto dai PM nel commento 11246 di KCK-249. Vale in
  /// creazione e in modifica; FormLega lo usa anche come `maxLength`.
  static const lunghezzaMassimaNome = 30;

  /// Lunghezza del codice d'invito (D29).
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

  /// Aggiorna nome, tipologia e privacy di una lega esistente (RF_LEG_1).
  ///
  /// Solo un amministratore della lega puo' modificarla (D13). Il nome deve
  /// restare unico come in creazione (D17, D21): tenere lo stesso nome, anche
  /// cambiando solo maiuscole o spazi, e' permesso. Codice d'invito e
  /// scadenza restano invariati. Restituisce la lega aggiornata, che la GUI
  /// mostra nella DashboardLega.
  /// Lancia [DatiLegaNonValidiException], [NomeLegaGiaInUsoException] o
  /// [OperazioneNonPermessaException]; se la lega non esiste lancia
  /// un'AppException.
  Future<Lega> modificaDettagliLega({
    required String idLega,
    required String nome,
    required String tipologiaMatch,
    required String privacy,
    required String idGiocatore,
  }) async {
    final String nomePulito = nome.trim();
    _validaDati(nomePulito, tipologiaMatch, privacy);

    final Lega? legaAttuale = await _legaRepository.findById(idLega);
    if (legaAttuale == null) {
      throw AppException.database(
        message: 'Lega non trovata',
        code: 'lega_non_trovata',
      );
    }
    if (!await _legaRepository.isAmministratore(idLega, idGiocatore)) {
      throw OperazioneNonPermessaException();
    }

    // Il proprio nome non conta come duplicato: existsByNome lo troverebbe.
    final bool nomeCambiato =
        _normalizzaNome(nomePulito) != _normalizzaNome(legaAttuale.nome);
    if (nomeCambiato && await _legaRepository.existsByNome(nomePulito)) {
      throw NomeLegaGiaInUsoException();
    }

    final Lega legaModificata = Lega(
      id: legaAttuale.id,
      nome: nomePulito,
      tipologiaMatch: tipologiaMatch,
      privacy: privacy,
      codiceInvito: legaAttuale.codiceInvito,
      scadenzaCodiceInvito: legaAttuale.scadenzaCodiceInvito,
    );
    try {
      return await _legaRepository.updateLega(legaModificata);
    } on AppException catch (error, stackTrace) {
      // Un'altra lega ha preso lo stesso nome nel frattempo (indice UNIQUE).
      if (error.code == _codiceDuplicato) {
        throw NomeLegaGiaInUsoException(
          originalError: error,
          stackTrace: stackTrace,
        );
      }
      rethrow;
    }
  }

  /// Genera o restituisce il codice d'invito valido di una lega.
  ///
  /// Solo l'amministratore puo' gestire la condivisione. Il metodo recupera
  /// la lega, riusa un codice non scaduto e ne crea uno nuovo tramite il
  /// generatore univoco quando il codice manca o e' scaduto. Se il database
  /// rifiuta il nuovo codice per collisione con un invito gia' usato (23505),
  /// riprova fino al limite previsto da D29 con un altro codice generato;
  /// al superamento del limite restituisce l'errore del repository.
  Future<String> generaCodiceInvito({
    required String idLega,
    required String idGiocatore,
  }) async {
    if (!await _legaRepository.isAmministratore(idLega, idGiocatore)) {
      throw CondivisioneInvitoNonPermessaException();
    }

    final Lega? lega = await _legaRepository.findById(idLega);
    if (lega == null) {
      throw LegaNonTrovataException();
    }

    final String? codiceEsistente = lega.codiceInvito;
    final DateTime? scadenzaEsistente = lega.scadenzaCodiceInvito;
    final bool codiceValido =
        codiceEsistente != null &&
        codiceEsistente.isNotEmpty &&
        scadenzaEsistente != null &&
        _orologio().isBefore(scadenzaEsistente);
    if (codiceValido) {
      return codiceEsistente;
    }

    for (var tentativo = 1; tentativo <= _tentativiCodice; tentativo++) {
      final String nuovoCodice = await _generaCodiceInvito();
      final Lega legaAggiornata = Lega(
        id: lega.id,
        nome: lega.nome,
        tipologiaMatch: lega.tipologiaMatch,
        privacy: lega.privacy,
        codiceInvito: nuovoCodice,
        scadenzaCodiceInvito: _orologio().add(durataCodiceInvito),
      );
      try {
        await _legaRepository.updateLega(legaAggiornata);
        return nuovoCodice;
      } on AppException catch (error) {
        if (error.code != _codiceDuplicato) {
          rethrow;
        }
        if (tentativo >= _tentativiCodice) {
          rethrow;
        }
      }
    }
    throw AppException.unexpected(
      originalError: StateError('Nessun codice d\'invito libero trovato.'),
    );
  }

  /// Genera il link d'invito valido per una lega amministrata dal Giocatore.
  ///
  /// Riutilizza [generaCodiceInvito] per preservare autorizzazione, scadenza
  /// e rigenerazione del codice, e costruisce il nuovo canale web come link
  /// senza modificare router o gestione dei membri.
  Future<String> generaLinkInvito({
    required String idLega,
    required String idGiocatore,
  }) async {
    final String codice = await generaCodiceInvito(
      idLega: idLega,
      idGiocatore: idGiocatore,
    );
    return '$indirizzoBaseInvito#/lega/invito/$codice';
  }

  /// Restituisce le leghe di cui il Giocatore e' membro, ciascuna con il suo
  /// ruolo (VistaLeghe, UI_LEG_1: badge ADMIN o MEMBRO).
  ///
  /// [amministratore] e' true se il Giocatore e' amministratore della lega
  /// (D13): la GUI lo usa solo per il badge, i permessi li ricontrolla il
  /// Control a ogni operazione riservata. Gli errori (es. rete) arrivano come
  /// AppException del repository.
  Future<List<({Lega lega, bool amministratore})>> visualizzaLeghe(
    String idGiocatore,
  ) async {
    final List<Lega> leghe = await _legaRepository.findByGiocatore(idGiocatore);
    final List<bool> ruoli = await Future.wait(
      leghe.map(
        (Lega lega) => _legaRepository.isAmministratore(lega.id, idGiocatore),
      ),
    );
    return [
      for (var i = 0; i < leghe.length; i++)
        (lega: leghe[i], amministratore: ruoli[i]),
    ];
  }

  /// Normalizza un nome come l'indice univoco del database (D21).
  String _normalizzaNome(String nome) => nome.trim().toLowerCase();

  /// Controlla i dati del modulo nell'ordine dei campi di FormLega.
  ///
  /// Si ferma al primo campo non valido, cosi' la GUI evidenzia quello.
  void _validaDati(String nome, String tipologiaMatch, String privacy) {
    if (nome.isEmpty) {
      throw DatiLegaNonValidiException(DatiLegaNonValidiException.nome);
    }
    // Si contano i caratteri (rune), non le unita' UTF-16: una lettera
    // accentata o un'emoji valgono un carattere.
    if (nome.runes.length > lunghezzaMassimaNome) {
      throw DatiLegaNonValidiException(
        DatiLegaNonValidiException.nome,
        messaggio:
            'Il nome puo\' avere al massimo $lunghezzaMassimaNome caratteri',
      );
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

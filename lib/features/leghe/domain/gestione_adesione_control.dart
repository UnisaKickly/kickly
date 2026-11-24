import '../../../core/errors/app_exception.dart';
import 'gestione_lega_control.dart';
import 'lega.dart';
import 'lega_repository.dart';

/// Invito espresso con un codice non associato ad alcuna lega.
///
/// Segnala l'E2 di UC_LEG_1 e permette alla GUI di richiedere un nuovo codice.
class CodiceInvitoNonValidoException extends AppException {
  /// Crea l'errore leggibile mostrato quando il codice non e' valido.
  CodiceInvitoNonValidoException()
    : super(
        message: 'Codice invito non valido',
        code: 'codice_invito_non_valido',
      );
}

/// Invito espresso con un codice esistente ma oltre la scadenza.
///
/// Segnala l'E2 di UC_LEG_1 e impedisce l'adesione del Giocatore alla lega.
class CodiceInvitoScadutoException extends AppException {
  /// Crea l'errore leggibile mostrato quando il codice e' scaduto.
  CodiceInvitoScadutoException()
    : super(message: 'Codice invito scaduto', code: 'codice_invito_scaduto');
}

/// Link d'invito privo del formato, della base o del codice concordati.
///
/// Consente alla GUI di distinguere un link non utilizzabile da un invito
/// valido ma errato o scaduto.
class LinkInvitoNonValidoException extends AppException {
  /// Crea l'errore leggibile mostrato quando il link non e' valido.
  LinkInvitoNonValidoException()
    : super(message: 'Link invito non valido', code: 'link_invito_non_valido');
}

/// Giocatore che tenta di aderire a una lega di cui e' gia' membro.
///
/// Evita una nuova adesione mantenendo invariato l'elenco dei membri.
class GiocatoreGiaMembroException extends AppException {
  /// Crea l'errore leggibile mostrato per una doppia adesione.
  GiocatoreGiaMembroException()
    : super(
        message: 'Sei gia\' membro di questa lega',
        code: 'giocatore_gia_membro',
      );
}

/// Accesso diretto richiesto a una lega privata senza invito.
///
/// Impedisce l'adesione alle leghe private tramite il solo identificativo,
/// rispettando l'alternativa A1 prevista per le sole leghe pubbliche.
class LegaPrivataInvitoRichiestoException extends AppException {
  /// Crea l'errore leggibile per l'accesso diretto a una lega privata.
  LegaPrivataInvitoRichiestoException()
    : super(
        message: 'Lega privata: serve un invito',
        code: 'lega_privata_invito_richiesto',
      );
}

/// Lega richiesta tramite identificativo o invito ma non presente.
///
/// Distingue un invito che non trova una lega da altri errori applicativi.
class LegaNonTrovataException extends AppException {
  /// Crea l'errore leggibile mostrato quando la lega non esiste.
  LegaNonTrovataException()
    : super(message: 'Lega non trovata', code: 'lega_non_trovata');
}

/// Gestisce l'ingresso dei Giocatori nelle leghe tramite inviti o accesso diretto.
///
/// Questa parte applicativa sara' estesa con i metodi previsti dal ticket
/// RF_LEG_2; per ora espone esclusivamente gli errori applicativi dell'adesione.
class GestioneAdesioneControl {
  /// Crea il Control con il repository delle leghe.
  // Il parametro pubblico mantiene privato il nome del campo interno.
  GestioneAdesioneControl({required LegaRepository legaRepository})
    // ignore: prefer_initializing_formals
    : _legaRepository = legaRepository;

  final LegaRepository _legaRepository;

  /// Caratteri ammessi nel codice, uguali a quelli usati dalla generazione.
  static const _caratteriCodice = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// Unisce il Giocatore a una lega tramite un codice d'invito valido.
  ///
  /// Valida la forma del codice; il repository verifica esistenza, scadenza e
  /// appartenenza e registra l'adesione in un'unica operazione.
  Future<Lega> uniscitiConCodice({
    required String codiceInvito,
    required String idGiocatore,
  }) async {
    final String codiceNormalizzato = codiceInvito.trim().toUpperCase();
    if (codiceNormalizzato.length !=
            GestioneLegaControl.lunghezzaCodiceInvito ||
        codiceNormalizzato.runes.any(
          (int carattere) =>
              !_caratteriCodice.contains(String.fromCharCode(carattere)),
        )) {
      throw CodiceInvitoNonValidoException();
    }

    return _legaRepository.uniscitiConCodice(codiceNormalizzato, idGiocatore);
  }

  /// Unisce il Giocatore a una lega aperta dal link d'invito canonico.
  ///
  /// Estrae il codice dal formato condiviso con [GestioneLegaControl], quindi
  /// riusa la stessa validazione applicativa dell'ingresso tramite codice.
  Future<Lega> uniscitiConLink({
    required String linkInvito,
    required String idGiocatore,
  }) async {
    final String codice = _estraiCodiceDaLink(linkInvito);
    return uniscitiConCodice(codiceInvito: codice, idGiocatore: idGiocatore);
  }

  /// Unisce il Giocatore direttamente a una lega pubblica trovata in ricerca.
  ///
  /// Una lega privata richiede un invito valido; questa operazione evita
  /// qualsiasi adesione basata solo sulla conoscenza dell'identificativo.
  Future<Lega> accediDirettamente({
    required String idLega,
    required String idGiocatore,
  }) async {
    final Lega? lega = await _legaRepository.findById(idLega);
    if (lega == null) {
      throw LegaNonTrovataException();
    }
    if (lega.privacy != PrivacyLega.pubblica) {
      throw LegaPrivataInvitoRichiestoException();
    }

    await _verificaNonMembro(lega.id, idGiocatore);
    return _aggiungiMembroLega(lega, idGiocatore);
  }

  /// Estrae e valida il codice dal formato canonico del link d'invito.
  ///
  /// Il prefisso condiviso evita interpretazioni diverse del canale web e il
  /// residuo deve essere un codice di 8 caratteri senza dati aggiuntivi.
  String _estraiCodiceDaLink(String linkInvito) {
    final String prefisso = '$indirizzoBaseInvito#/lega/invito/';
    if (!linkInvito.startsWith(prefisso)) {
      throw LinkInvitoNonValidoException();
    }

    final String codice = linkInvito.substring(prefisso.length);
    if (codice.length != GestioneLegaControl.lunghezzaCodiceInvito) {
      throw LinkInvitoNonValidoException();
    }
    final bool formatoValido = codice.runes.every(
      (int carattere) =>
          _caratteriCodice.contains(String.fromCharCode(carattere)),
    );
    if (!formatoValido) {
      throw LinkInvitoNonValidoException();
    }
    return codice;
  }

  /// Verifica che il Giocatore non sia gia' membro della lega.
  ///
  /// L'elenco dei membri ottenuto dal repository rende l'idempotenza visibile
  /// al Control e impedisce l'aggiunta duplicata dell'associazione.
  Future<void> _verificaNonMembro(String idLega, String idGiocatore) async {
    final List<Lega> leghe = await _legaRepository.findByGiocatore(idGiocatore);
    if (leghe.any((Lega lega) => lega.id == idLega)) {
      throw GiocatoreGiaMembroException();
    }
  }

  /// Aggiunge il Giocatore all'associazione membri della lega.
  ///
  /// Mantiene la logica DG12 in un unico punto applicativo, delegando al
  /// repository la persistenza senza introdurre nuove entita' o dipendenze.
  Future<Lega> _aggiungiMembroLega(Lega lega, String idGiocatore) async {
    await _legaRepository.aggiungiMembro(lega.id, idGiocatore);
    return lega;
  }
}

// Test di GestioneLegaControl.visualizzaLeghe (KCK-249, VistaLeghe UI_LEG_1):
// elenco delle leghe del Giocatore con il suo ruolo. Esiti attesi dalla
// tabella degli oggetti (VistaLeghe: "elenco delle proprie leghe a cui si e'
// iscritti") e da D13 (amministratori). Repository in memoria.
import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/features/leghe/data/in_memory_lega_repository.dart';
import 'package:kickly/features/leghe/domain/gestione_lega_control.dart';
import 'package:kickly/features/leghe/domain/lega.dart';

void main() {
  const idGiocatore = '00000000-0000-4000-8000-000000000201';
  const idAltro = '00000000-0000-4000-8000-000000000202';

  late InMemoryLegaRepository repository;
  late GestioneLegaControl control;

  setUp(() {
    repository = InMemoryLegaRepository();
    control = GestioneLegaControl(legaRepository: repository);
  });

  /// Crea una lega fittizia amministrata da [admin].
  Future<Lega> creaLega(String nome, String admin) => repository.createLega(
    Lega(
      id: '',
      nome: nome,
      tipologiaMatch: TipologiaMatch.cinqueVsCinque,
      privacy: PrivacyLega.privata,
    ),
    admin,
  );

  // Preparazione: il Giocatore amministra una lega, e' membro di una seconda
  // e non appartiene a una terza.
  // Esito atteso: solo le prime due, con il ruolo giusto.
  test('restituisce solo le leghe del giocatore con il suo ruolo', () async {
    final Lega propria = await creaLega('Derby del Quartiere', idGiocatore);
    final Lega altrui = await creaLega('Torneo Universitario', idAltro);
    await repository.aggiungiMembro(altrui.id, idGiocatore);
    await creaLega('Lega Estranea', idAltro);

    final leghe = await control.visualizzaLeghe(idGiocatore);

    expect(leghe, hasLength(2));
    expect(
      leghe.singleWhere((v) => v.lega.id == propria.id).amministratore,
      isTrue,
    );
    expect(
      leghe.singleWhere((v) => v.lega.id == altrui.id).amministratore,
      isFalse,
    );
  });

  // Preparazione: Giocatore senza leghe.
  // Esito atteso: elenco vuoto.
  test('giocatore senza leghe riceve un elenco vuoto', () async {
    await creaLega('Lega Estranea', idAltro);

    expect(await control.visualizzaLeghe(idGiocatore), isEmpty);
  });
}

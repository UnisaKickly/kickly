// Test del limite di 30 caratteri sul nome della lega (KCK-249, richiesto
// dai PM nel commento 11246): il limite viene dal mock-up UI_LEG_2 ("Massimo
// 30 caratteri"). Nessun test frame associato. Esito atteso come UC_LEG_1 E1:
// dati non validi -> errore sul campo nome, la lega non e' creata ne'
// modificata. Repository in memoria, dati fittizi.
import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/features/leghe/data/in_memory_lega_repository.dart';
import 'package:kickly/features/leghe/domain/gestione_lega_control.dart';
import 'package:kickly/features/leghe/domain/lega.dart';

void main() {
  const idGiocatore = '00000000-0000-4000-8000-000000000201';
  final String nome30 = 'A' * 30;
  final String nome31 = 'A' * 31;

  late InMemoryLegaRepository repository;
  late GestioneLegaControl control;

  setUp(() {
    repository = InMemoryLegaRepository();
    control = GestioneLegaControl(legaRepository: repository);
  });

  /// Verifica che l'errore sia sul nome con il messaggio del limite.
  final Matcher erroreLunghezza = isA<DatiLegaNonValidiException>()
      .having((e) => e.campo, 'campo', DatiLegaNonValidiException.nome)
      .having(
        (e) => e.message,
        'message',
        'Il nome puo\' avere al massimo 30 caratteri',
      );

  test('creazione: nome di 30 caratteri accettato', () async {
    final Lega lega = await control.creaLega(
      nome: nome30,
      tipologiaMatch: TipologiaMatch.cinqueVsCinque,
      privacy: PrivacyLega.privata,
      idGiocatore: idGiocatore,
    );

    expect(lega.nome, nome30);
  });

  test('creazione: nome di 31 caratteri rifiutato, lega non creata', () async {
    await expectLater(
      control.creaLega(
        nome: nome31,
        tipologiaMatch: TipologiaMatch.cinqueVsCinque,
        privacy: PrivacyLega.privata,
        idGiocatore: idGiocatore,
      ),
      throwsA(erroreLunghezza),
    );
    expect(await repository.findByGiocatore(idGiocatore), isEmpty);
  });

  test('creazione: gli spazi attorno al nome non contano', () async {
    final Lega lega = await control.creaLega(
      nome: '  $nome30  ',
      tipologiaMatch: TipologiaMatch.cinqueVsCinque,
      privacy: PrivacyLega.privata,
      idGiocatore: idGiocatore,
    );

    expect(lega.nome, nome30);
  });

  test('modifica: 30 caratteri accettati, 31 rifiutati', () async {
    final Lega lega = await control.creaLega(
      nome: 'Derby del Quartiere',
      tipologiaMatch: TipologiaMatch.cinqueVsCinque,
      privacy: PrivacyLega.privata,
      idGiocatore: idGiocatore,
    );

    await expectLater(
      control.modificaDettagliLega(
        idLega: lega.id,
        nome: nome31,
        tipologiaMatch: TipologiaMatch.cinqueVsCinque,
        privacy: PrivacyLega.privata,
        idGiocatore: idGiocatore,
      ),
      throwsA(erroreLunghezza),
    );
    expect((await repository.findById(lega.id))!.nome, 'Derby del Quartiere');

    final Lega modificata = await control.modificaDettagliLega(
      idLega: lega.id,
      nome: nome30,
      tipologiaMatch: TipologiaMatch.cinqueVsCinque,
      privacy: PrivacyLega.privata,
      idGiocatore: idGiocatore,
    );
    expect(modificata.nome, nome30);
  });
}

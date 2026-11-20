// Test di serializzazione dell'entity Giocatore.
//
// Verifica la mappa piatta (colonne di `account` piu' quelle di `giocatore`),
// l'id ereditato senza account_id (class_diagram_sdd.md §3, regola 9), la
// Player Card facoltativa (SD_UC_ACC_1) e l'assenza della password.
import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/features/utenza/domain/account.dart';
import 'package:kickly/features/utenza/domain/giocatore.dart';

void main() {
  // Mappa piatta fittizia come la prepara AccountRepository.
  Map<String, dynamic> mappaPiatta() => {
    'id': '0b6f1c2e-0000-4000-8000-000000000001',
    'ruolo_account': 'Giocatore',
    'nome': 'Mario',
    'cognome': 'Rossi',
    'email': 'mario.rossi@example.com',
    'eta': 25,
    'stato_account': 'attivo',
    'stato_onboarding': 'completato',
    'preferenze_notifiche': '{}',
    'ruolo_preferito_in_campo': 'Centrocampista',
    'piede_dominante': 'Destro',
  };

  group('Giocatore fromJson/toJson', () {
    test('andata e ritorno partendo da un oggetto', () {
      const giocatore = Giocatore(
        id: '0b6f1c2e-0000-4000-8000-000000000001',
        ruoloAccount: RuoloAccount.giocatore,
        nome: 'Mario',
        cognome: 'Rossi',
        email: 'mario.rossi@example.com',
        eta: 25,
        statoAccount: StatoAccount.attivo,
        statoOnboarding: StatoOnboarding.completato,
        preferenzeNotifiche: '{}',
        ruoloPreferitoInCampo: 'Centrocampista',
        piedeDominante: 'Destro',
      );

      expect(
        Giocatore.fromJson(giocatore.toJson()).toJson(),
        giocatore.toJson(),
      );
    });

    test('legge la mappa piatta campo per campo', () {
      final giocatore = Giocatore.fromJson(mappaPiatta());

      expect(giocatore, isA<Account>());
      expect(giocatore.id, '0b6f1c2e-0000-4000-8000-000000000001');
      expect(giocatore.ruoloAccount, 'Giocatore');
      expect(giocatore.nome, 'Mario');
      expect(giocatore.cognome, 'Rossi');
      expect(giocatore.email, 'mario.rossi@example.com');
      expect(giocatore.eta, 25);
      expect(giocatore.statoAccount, 'attivo');
      expect(giocatore.statoOnboarding, 'completato');
      expect(giocatore.preferenzeNotifiche, '{}');
      expect(giocatore.ruoloPreferitoInCampo, 'Centrocampista');
      expect(giocatore.piedeDominante, 'Destro');
    });

    test('Player Card non ancora salvata: campi null letti e riscritti', () {
      // Preparazione: riga nata alla scelta del ruolo, prima della Player Card.
      final mappa = mappaPiatta()
        ..['ruolo_preferito_in_campo'] = null
        ..['piede_dominante'] = null
        ..['stato_onboarding'] = 'in_corso';

      final giocatore = Giocatore.fromJson(mappa);

      expect(giocatore.ruoloPreferitoInCampo, isNull);
      expect(giocatore.piedeDominante, isNull);
      expect(giocatore.toJson()['ruolo_preferito_in_campo'], isNull);
      expect(giocatore.toJson()['piede_dominante'], isNull);
    });

    test('toJson produce esattamente la mappa piatta, senza account_id ne\' password', () {
      final json = Giocatore.fromJson(mappaPiatta()).toJson();

      expect(json, mappaPiatta());
      expect(json.containsKey('account_id'), isFalse);
      expect(json.containsKey('password'), isFalse);
    });
  });
}

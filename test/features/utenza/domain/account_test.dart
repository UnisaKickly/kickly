// Test di serializzazione dell'entity Account e delle sue costanti.
//
// Verifica andata e ritorno fromJson/toJson, la lettura di una riga come la
// restituisce Supabase, il ruolo facoltativo (D11), l'assenza della password
// (class_diagram_sdd.md §3, regola 2) e i valori ammessi (D9, migration A).
import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/features/utenza/domain/account.dart';

void main() {
  // Riga fittizia di `account` come la restituisce Supabase.
  Map<String, dynamic> rigaSupabase() => {
    'id': '0b6f1c2e-0000-4000-8000-000000000001',
    'ruolo_account': 'Giocatore',
    'nome': 'Mario',
    'cognome': 'Rossi',
    'email': 'mario.rossi@example.com',
    'eta': 25,
    'stato_account': 'attivo',
    'stato_onboarding': 'completato',
    'preferenze_notifiche': '{"partite":true}',
  };

  group('Account fromJson/toJson', () {
    test('andata e ritorno partendo da un oggetto', () {
      // Esito atteso: rileggere il JSON prodotto da toJson restituisce lo stesso JSON.
      const account = Account(
        id: '0b6f1c2e-0000-4000-8000-000000000001',
        ruoloAccount: RuoloAccount.giocatore,
        nome: 'Mario',
        cognome: 'Rossi',
        email: 'mario.rossi@example.com',
        eta: 25,
        statoAccount: StatoAccount.attivo,
        statoOnboarding: StatoOnboarding.completato,
        preferenzeNotifiche: '{}',
      );

      expect(Account.fromJson(account.toJson()).toJson(), account.toJson());
    });

    test('legge una riga di Supabase campo per campo', () {
      final account = Account.fromJson(rigaSupabase());

      expect(account.id, '0b6f1c2e-0000-4000-8000-000000000001');
      expect(account.ruoloAccount, 'Giocatore');
      expect(account.nome, 'Mario');
      expect(account.cognome, 'Rossi');
      expect(account.email, 'mario.rossi@example.com');
      expect(account.eta, 25);
      expect(account.statoAccount, 'attivo');
      expect(account.statoOnboarding, 'completato');
      expect(account.preferenzeNotifiche, '{"partite":true}');
    });

    test(
      'ruolo_account null prima dell\'onboarding viene letto e riscritto',
      () {
        // Preparazione: account appena creato dal trigger, senza ruolo (D11).
        final riga = rigaSupabase()
          ..['ruolo_account'] = null
          ..['stato_onboarding'] = 'in_corso';

        final account = Account.fromJson(riga);

        expect(account.ruoloAccount, isNull);
        expect(account.toJson().containsKey('ruolo_account'), isTrue);
        expect(account.toJson()['ruolo_account'], isNull);
      },
    );

    test('toJson produce le colonne della migration A senza password', () {
      final json = Account.fromJson(rigaSupabase()).toJson();

      expect(json.containsKey('password'), isFalse);
      expect(json.keys.toSet(), {
        'id',
        'ruolo_account',
        'nome',
        'cognome',
        'email',
        'eta',
        'stato_account',
        'stato_onboarding',
        'preferenze_notifiche',
      });
    });
  });

  group('valori ammessi', () {
    test('RuoloAccount coincide con la CHECK account_ruolo_account_check', () {
      expect(RuoloAccount.valori, {'Giocatore', 'GestoreCampo'});
      expect(RuoloAccount.giocatore, 'Giocatore');
      expect(RuoloAccount.gestoreCampo, 'GestoreCampo');
    });

    test('StatoAccount coincide con D9', () {
      expect(StatoAccount.valori, {'attivo', 'in_cancellazione'});
      expect(StatoAccount.attivo, 'attivo');
      expect(StatoAccount.inCancellazione, 'in_cancellazione');
    });

    test('StatoOnboarding coincide con D9', () {
      expect(StatoOnboarding.valori, {'in_corso', 'completato'});
      expect(StatoOnboarding.inCorso, 'in_corso');
      expect(StatoOnboarding.completato, 'completato');
    });
  });
}

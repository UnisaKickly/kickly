// Test di serializzazione dell'entity GestoreCampo.
//
// Verifica la mappa piatta (colonne di `account` piu' quelle di
// `gestore_campo`), l'id ereditato senza account_id (class_diagram_sdd.md §3,
// regola 9), l'account pagamenti facoltativo (D3) e l'assenza della password.
import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/features/utenza/domain/account.dart';
import 'package:kickly/features/utenza/domain/gestore_campo.dart';

void main() {
  // Mappa piatta fittizia come la prepara AccountRepository.
  Map<String, dynamic> mappaPiatta() => {
    'id': '0b6f1c2e-0000-4000-8000-000000000002',
    'ruolo_account': 'GestoreCampo',
    'nome': 'Luca',
    'cognome': 'Bianchi',
    'email': 'luca.bianchi@example.com',
    'eta': 40,
    'stato_account': 'attivo',
    'stato_onboarding': 'completato',
    'preferenze_notifiche': '{}',
    'id_account_pagamenti': 'acct_test_fittizio',
  };

  group('GestoreCampo fromJson/toJson', () {
    test('andata e ritorno partendo da un oggetto', () {
      const gestore = GestoreCampo(
        id: '0b6f1c2e-0000-4000-8000-000000000002',
        ruoloAccount: RuoloAccount.gestoreCampo,
        nome: 'Luca',
        cognome: 'Bianchi',
        email: 'luca.bianchi@example.com',
        eta: 40,
        statoAccount: StatoAccount.attivo,
        statoOnboarding: StatoOnboarding.completato,
        preferenzeNotifiche: '{}',
        idAccountPagamenti: 'acct_test_fittizio',
      );

      expect(
        GestoreCampo.fromJson(gestore.toJson()).toJson(),
        gestore.toJson(),
      );
    });

    test('legge la mappa piatta campo per campo', () {
      final gestore = GestoreCampo.fromJson(mappaPiatta());

      expect(gestore, isA<Account>());
      expect(gestore.id, '0b6f1c2e-0000-4000-8000-000000000002');
      expect(gestore.ruoloAccount, 'GestoreCampo');
      expect(gestore.nome, 'Luca');
      expect(gestore.cognome, 'Bianchi');
      expect(gestore.email, 'luca.bianchi@example.com');
      expect(gestore.eta, 40);
      expect(gestore.statoAccount, 'attivo');
      expect(gestore.statoOnboarding, 'completato');
      expect(gestore.preferenzeNotifiche, '{}');
      expect(gestore.idAccountPagamenti, 'acct_test_fittizio');
    });

    test('account pagamenti non collegato: null letto e riscritto', () {
      final mappa = mappaPiatta()..['id_account_pagamenti'] = null;

      final gestore = GestoreCampo.fromJson(mappa);

      expect(gestore.idAccountPagamenti, isNull);
      expect(gestore.toJson().containsKey('id_account_pagamenti'), isTrue);
      expect(gestore.toJson()['id_account_pagamenti'], isNull);
    });

    test('toJson produce esattamente la mappa piatta, senza account_id ne\' password', () {
      final json = GestoreCampo.fromJson(mappaPiatta()).toJson();

      expect(json, mappaPiatta());
      expect(json.containsKey('account_id'), isFalse);
      expect(json.containsKey('password'), isFalse);
    });
  });
}

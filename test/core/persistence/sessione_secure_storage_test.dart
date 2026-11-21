// Test di SessioneSecureStorage (KCK-208): la sessione di Supabase Auth si
// salva, si legge e si cancella nel Secure Storage, con la chiave di
// supabase_flutter. Il Secure Storage e' simulato con i valori iniziali di
// flutter_secure_storage per i test.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kickly/core/persistence/sessione_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues(<String, String>{}));

  test('usa la chiave di sessione di supabase_flutter', () {
    expect(SessioneSecureStorage.chiaveSessione, supabasePersistSessionKey);
  });

  test('salva, legge e cancella la sessione nel Secure Storage', () async {
    // Preparazione: Secure Storage vuoto.
    // Esito atteso: dopo persistSession la sessione c'e' ed e' leggibile;
    // dopo removePersistedSession non c'e' piu'.
    const storage = FlutterSecureStorage();
    final sessioneStorage = SessioneSecureStorage(storage: storage);
    await sessioneStorage.initialize();
    expect(await sessioneStorage.hasAccessToken(), isFalse);
    expect(await sessioneStorage.accessToken(), isNull);

    await sessioneStorage.persistSession('{"access_token":"token-fittizio"}');

    expect(await sessioneStorage.hasAccessToken(), isTrue);
    expect(
      await sessioneStorage.accessToken(),
      '{"access_token":"token-fittizio"}',
    );
    expect(
      await storage.read(key: supabasePersistSessionKey),
      '{"access_token":"token-fittizio"}',
    );

    await sessioneStorage.removePersistedSession();

    expect(await sessioneStorage.hasAccessToken(), isFalse);
    expect(await sessioneStorage.accessToken(), isNull);
  });

  test('riprende una sessione gia\' salvata', () async {
    // Preparazione: il Secure Storage contiene una sessione di un avvio
    // precedente.
    // Esito atteso: hasAccessToken e accessToken la restituiscono, cosi'
    // Supabase Auth riapre la sessione senza nuovo login.
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      supabasePersistSessionKey: '{"access_token":"salvato"}',
    });
    final sessioneStorage = SessioneSecureStorage();

    expect(await sessioneStorage.hasAccessToken(), isTrue);
    expect(await sessioneStorage.accessToken(), '{"access_token":"salvato"}');
  });
}

import '../../../core/errors/app_exception.dart';

/// Errore mostrato quando una password non rispetta i requisiti minimi D28.
class PasswordDeboleException extends AppException {
  /// Crea l'errore con il messaggio previsto per la registrazione e il reset.
  PasswordDeboleException()
    : super(
        message: 'La password deve avere almeno 8 caratteri, una lettera e un numero',
        code: 'password_debole',
      );
}

/// Valida i requisiti minimi della password condivisi da registrazione e reset.
///
/// Lancia [PasswordDeboleException] se manca la lunghezza, una lettera o un
/// numero, così i Control di registrazione e recupero applicano la stessa
/// regola di dominio.
void validaPassword(String password) {
  if (password.length < 8 ||
      !RegExp(r'[A-Za-z]').hasMatch(password) ||
      !RegExp(r'[0-9]').hasMatch(password)) {
    throw PasswordDeboleException();
  }
}

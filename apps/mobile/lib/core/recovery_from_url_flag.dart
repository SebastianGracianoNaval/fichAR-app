// In-memory flag set by main() after getSessionFromUrl(recovery URL) succeeds.
// app.dart reads it to show ResetPasswordScreen even if the auth stream already emitted.

bool _recoveryFromUrl = false;

bool get recoveryFromUrl => _recoveryFromUrl;

void setRecoveryFromUrl(bool value) {
  _recoveryFromUrl = value;
}

// Invite params from URL (web): /register?inviteToken=...&email=...
// Set by main() at startup so the app can show RegisterScreen.

String? _inviteToken;
String? _inviteEmail;

String? get inviteTokenFromUrl => _inviteToken;
String? get inviteEmailFromUrl => _inviteEmail;
bool get hasInviteFromUrl => _inviteToken != null && _inviteToken!.isNotEmpty;

void setInviteFromUrl({String? token, String? email}) {
  _inviteToken = token;
  _inviteEmail = email;
}

void clearInviteFromUrl() {
  _inviteToken = null;
  _inviteEmail = null;
}

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignOutService {
  /// Signs out from Supabase with fallback to local-only signout
  /// when the server call fails (e.g. no connectivity).
  /// Returns `true` if signout was performed (remote or local fallback).
  static Future<bool> signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
      return true;
    } catch (e) {
      debugPrint('signOut remote failed: $e');
      try {
        await Supabase.instance.client.auth.signOut(
          scope: SignOutScope.local,
        );
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  /// Whether the signout used a local-only fallback (useful for showing
  /// a warning SnackBar to the user).
  static Future<({bool signedOut, bool wasLocal})> signOutDetailed() async {
    try {
      await Supabase.instance.client.auth.signOut();
      return (signedOut: true, wasLocal: false);
    } catch (e) {
      debugPrint('signOut remote failed: $e');
      try {
        await Supabase.instance.client.auth.signOut(
          scope: SignOutScope.local,
        );
        return (signedOut: true, wasLocal: true);
      } catch (_) {
        return (signedOut: false, wasLocal: false);
      }
    }
  }
}

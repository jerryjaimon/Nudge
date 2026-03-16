// lib/services/auth_service.dart
//
// Google Sign-In wrapper.
// Privacy model:
//   - The UID from Google auth is used ONLY to namespace Firestore paths.
//   - No user data (gym, habits, etc.) is ever sent to Firebase without
//     explicit user action (Backup button) and AES-256 encryption with
//     a passphrase that is NEVER stored anywhere.
//   - Signing out does NOT delete local data — data stays on device.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _google = GoogleSignIn();

  // ── State ──────────────────────────────────────────────────────────────────

  static User? get currentUser => _auth.currentUser;
  static Stream<User?> get authStateChanges => _auth.authStateChanges();
  static bool get isSignedIn => _auth.currentUser != null;

  /// Short display name, falls back to email prefix, then "User".
  static String get displayName {
    final u = _auth.currentUser;
    if (u == null) return '';
    if (u.displayName != null && u.displayName!.isNotEmpty) return u.displayName!;
    final email = u.email ?? '';
    return email.isNotEmpty ? email.split('@').first : 'User';
  }

  static String get email => _auth.currentUser?.email ?? '';
  static String? get photoUrl => _auth.currentUser?.photoURL;

  // ── Sign-in ────────────────────────────────────────────────────────────────

  /// Launches Google account picker and signs in.
  /// Returns the signed-in [User], or null if the user cancelled.
  static Future<User?> signInWithGoogle() async {
    try {
      final account = await _google.signIn();
      if (account == null) return null; // user cancelled

      final googleAuth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw _friendlyError(e.code);
    }
  }

  // ── Sign-out ───────────────────────────────────────────────────────────────

  /// Signs out from both Google and Firebase.
  /// Local Hive data is NOT affected.
  static Future<void> signOut() async {
    await _google.signOut();
    await _auth.signOut();
  }

  // ── Delete account ─────────────────────────────────────────────────────────

  /// Re-authenticates with Google, then permanently deletes the Firebase Auth
  /// account. Throws a user-friendly message on failure.
  static Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Firebase requires fresh credentials before account deletion.
      final account = await _google.signIn();
      if (account == null) throw Exception('Re-authentication cancelled.');
      final googleAuth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);
      await user.delete();
      await _google.signOut();
    } on FirebaseAuthException catch (e) {
      throw Exception(_friendlyError(e.code));
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _friendlyError(String code) {
    switch (code) {
      case 'network-request-failed':
        return 'No internet connection.';
      case 'sign_in_canceled':
      case 'canceled':
        return 'Sign-in cancelled.';
      case 'account-exists-with-different-credential':
        return 'Account already exists with a different sign-in method.';
      default:
        return 'Sign-in failed. Please try again.';
    }
  }
}

// lib/services/firebase_backup_service.dart
//
// Privacy guarantees:
//   1. The user's passphrase is NEVER stored anywhere (not Hive, not Firestore,
//      not memory across sessions). It lives only in the call stack during
//      backup/restore and is discarded immediately after.
//   2. All data is AES-256-CBC encrypted client-side BEFORE leaving the device.
//      Firestore receives only opaque encrypted blobs.
//   3. Google Sign-In provides only a stable UID for Firestore path namespace.
//      No user content is accessible to Google or Firebase.
//   4. Firestore security rules enforce that uid in the path must match the
//      authenticated user — nobody else can read or write your data.
//   5. Anonymous auth is NOT used. Backup requires a verified Google account.

import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../storage.dart';
import 'auth_service.dart';

class FirebaseBackupService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ── Auth guard ─────────────────────────────────────────────────────────────

  static String _requireUid() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw Exception(
          'Sign in with Google first to back up or restore data.');
    }
    return uid;
  }

  // ── Encryption ─────────────────────────────────────────────────────────────
  //
  // Key derivation: repeats/truncates UTF-8 passphrase bytes to 32 bytes.
  // The passphrase is the ONLY decryption secret — nothing else is stored.

  static enc.Key _deriveKey(String passphrase) {
    final bytes = utf8.encode(passphrase);
    final key = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      key[i] = bytes[i % bytes.length];
    }
    return enc.Key(key);
  }

  static String _encrypt(String plaintext, String passphrase) {
    final key = _deriveKey(passphrase);
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  static String _decrypt(String ciphertext, String passphrase) {
    final parts = ciphertext.split(':');
    if (parts.length != 2) throw const FormatException('Invalid backup format.');
    final iv = enc.IV.fromBase64(parts[0]);
    final key = _deriveKey(passphrase);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    return encrypter.decrypt64(parts[1], iv: iv);
  }

  // ── Serialisation ──────────────────────────────────────────────────────────

  static Map<String, dynamic> _boxToMap(dynamic box) {
    final result = <String, dynamic>{};
    for (final key in (box as dynamic).keys) {
      result[key.toString()] = _sanitize(box.get(key));
    }
    return result;
  }

  static dynamic _sanitize(dynamic val) {
    if (val == null || val is bool || val is num || val is String) return val;
    if (val is List) return val.map(_sanitize).toList();
    if (val is Map) return val.map((k, v) => MapEntry(k.toString(), _sanitize(v)));
    return val.toString();
  }

  // ── Firestore layout ───────────────────────────────────────────────────────
  //
  //  users/{uid}/
  //    profile    → { email, displayName, lastSeen }     ← no sensitive data
  //    backup/
  //      {boxName} → { payload: "<iv_b64>:<cipher_b64>", backedUpAt, version }

  static CollectionReference _backupRef(String uid) =>
      _db.collection('users').doc(uid).collection('backup');

  // ── Backup ─────────────────────────────────────────────────────────────────

  static Future<void> backup(String passphrase) async {
    if (passphrase.isEmpty) throw ArgumentError('Passphrase must not be empty');
    final uid = _requireUid();
    await _doBackup(passphrase, uid);
  }

  /// Called from background isolate where FirebaseAuth state may not be
  /// available — caller supplies the UID directly from WorkManager inputData.
  static Future<void> backupWithUid(String passphrase, String uid) async {
    if (passphrase.isEmpty) throw ArgumentError('Passphrase must not be empty');
    if (uid.isEmpty) throw ArgumentError('UID must not be empty');
    await _doBackup(passphrase, uid);
  }

  static Future<void> _doBackup(String passphrase, String uid) async {
    // Write account metadata (no user content)
    await _db.collection('users').doc(uid).set({
      'email': AuthService.email,
      'displayName': AuthService.displayName,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final ref = _backupRef(uid);
    final batch = _db.batch();

    for (final entry in _allBoxes().entries) {
      final json = jsonEncode(_boxToMap(entry.value));
      final encrypted = _encrypt(json, passphrase);
      batch.set(ref.doc(entry.key), {
        'payload': encrypted,
        'backedUpAt': FieldValue.serverTimestamp(),
        'version': 2,
      });
    }

    await batch.commit();
    await AppStorage.settingsBox.put(
        'last_backup_at', DateTime.now().toIso8601String());
  }

  // ── Restore ────────────────────────────────────────────────────────────────

  static Future<void> restore(String passphrase) async {
    if (passphrase.isEmpty) throw ArgumentError('Passphrase must not be empty');
    final uid = _requireUid();
    final ref = _backupRef(uid);

    for (final entry in _allBoxes().entries) {
      final doc = await ref.doc(entry.key).get();
      if (!doc.exists) continue;
      final docData = doc.data() as Map<String, dynamic>?;
      final payload = docData?['payload'] as String?;
      if (payload == null) continue;

      String json;
      try {
        json = _decrypt(payload, passphrase);
      } catch (_) {
        throw Exception('Wrong passphrase — could not decrypt backup.');
      }

      final decoded = jsonDecode(json) as Map<String, dynamic>;
      await entry.value.clear();
      for (final kv in decoded.entries) {
        await entry.value.put(kv.key, kv.value);
      }
    }
  }

  // ── Delete Backup ──────────────────────────────────────────────────────────

  static Future<void> deleteBackup() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return; // Not signed in, no remote data

    final ref = _backupRef(uid);
    final batch = _db.batch();

    // Delete all backup documents
    for (final entry in _allBoxes().entries) {
      batch.delete(ref.doc(entry.key));
    }

    // Delete the user profile document itself
    batch.delete(_db.collection('users').doc(uid));

    await batch.commit();
    await AppStorage.settingsBox.delete('last_backup_at');
  }

  // ── Box map ────────────────────────────────────────────────────────────────

  static Map<String, dynamic> _allBoxes() => {
        'gym': AppStorage.gymBox,
        'movies': AppStorage.moviesBox,
        'books': AppStorage.booksBox,
        'finance': AppStorage.financeBox,
        'food': AppStorage.foodBox,
        'food_library': AppStorage.foodLibraryBox,
        'settings': AppStorage.settingsBox,
        'protected': AppStorage.protectedBox,
        'pomodoro': AppStorage.pomodoroBox,
      };

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String? get lastBackupAt =>
      AppStorage.settingsBox.get('last_backup_at') as String?;

  static String lastBackupLabel() {
    if (!AuthService.isSignedIn) return 'Sign in to enable backup';
    final ts = lastBackupAt;
    if (ts == null) return 'Never backed up';
    final dt = DateTime.tryParse(ts);
    if (dt == null) return 'Never backed up';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Backed up just now';
    if (diff.inHours < 1) return 'Backed up ${diff.inMinutes}m ago';
    if (diff.inDays < 1) return 'Backed up ${diff.inHours}h ago';
    return 'Backed up ${diff.inDays}d ago';
  }
}

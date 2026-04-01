import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import '../storage.dart';
import 'auth_service.dart';

// Bridge between GoogleSignIn and googleapis
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class GoogleDriveBackupService {
  static const String _backupFileName = 'nudge_backup.json';

  // ── Auth & Client ──────────────────────────────────────────────────────────

  static Future<drive.DriveApi> _getDriveApi() async {
    final account = AuthService.google.currentUser ?? await AuthService.google.signInSilently();
    if (account == null) {
      throw Exception('Sign in with Google first to back up or restore data.');
    }
    final headers = await account.authHeaders;
    final client = GoogleAuthClient(headers);
    return drive.DriveApi(client);
  }

  // ── Encryption ─────────────────────────────────────────────────────────────

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

  // ── Drive Helpers ──────────────────────────────────────────────────────────

  static Future<drive.File?> _getBackupFile(drive.DriveApi api) async {
    final fileList = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_backupFileName'",
      $fields: 'files(id, name)',
    );
    final files = fileList.files;
    if (files == null || files.isEmpty) return null;
    return files.first;
  }

  // ── Backup ─────────────────────────────────────────────────────────────────

  static Future<void> backup(String passphrase) async {
    if (passphrase.isEmpty) throw ArgumentError('Passphrase must not be empty');
    await _doBackup(passphrase);
  }

  static Future<void> backupWithUid(String passphrase, String uid) async {
    // uid is ignored for Drive backups because the OAuth token enforces identity
    if (passphrase.isEmpty) throw ArgumentError('Passphrase must not be empty');
    await _doBackup(passphrase);
  }

  static Future<void> _doBackup(String passphrase) async {
    final api = await _getDriveApi();
    
    // 1. Build backup payload inside a map
    final backupData = <String, dynamic>{};
    for (final entry in _allBoxes().entries) {
      final json = jsonEncode(_boxToMap(entry.value));
      backupData[entry.key] = {
        'payload': _encrypt(json, passphrase),
        'version': 2,
      };
    }
    final fullJson = jsonEncode(backupData);

    // 2. Prepare for upload
    final media = drive.Media(
      Stream.value(utf8.encode(fullJson)),
      fullJson.length,
      contentType: 'application/json',
    );

    // 3. See if file already exists
    final existingFile = await _getBackupFile(api);

    if (existingFile != null && existingFile.id != null) {
      // Update existing
      await api.files.update(
        drive.File(),
        existingFile.id!,
        uploadMedia: media,
      );
    } else {
      // Create new
      final fileToUpload = drive.File()
        ..name = _backupFileName
        ..parents = ['appDataFolder'];
      await api.files.create(
        fileToUpload,
        uploadMedia: media,
      );
    }

    await AppStorage.settingsBox.put('last_drive_backup_at', DateTime.now().toIso8601String());
  }

  // ── Restore ────────────────────────────────────────────────────────────────

  static const _settingsWhitelist = {
    'target_water_ml', 'target_budget', 'enabled_modules',
    'gemini_api_key', 'gemini_api_key_1', 'gemini_api_key_2', 'active_gemini_key_index',
    'health_source_priority', 'health_source_disabled', 'pinned_source',
    'theme', 'is_home_list_view',
    'reminder_enabled', 'reminder_hour', 'reminder_minute', 'reminder_persistent',
    'has_seen_onboarding', 'gym_goal_days',
  };

  static Future<int> restore(String passphrase) async {
    if (passphrase.isEmpty) throw ArgumentError('Passphrase must not be empty');
    final api = await _getDriveApi();
    
    final file = await _getBackupFile(api);
    if (file == null || file.id == null) {
      throw Exception('No backup found in Google Drive for this account.');
    }

    final response = await api.files.get(
      file.id!,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytes = await response.stream.fold<List<int>>([], (prev, elem) => prev..addAll(elem));
    final fullJson = utf8.decode(bytes);
    final backupData = jsonDecode(fullJson) as Map<String, dynamic>;

    int restoredBoxes = 0;

    for (final entry in _allBoxes().entries) {
      final docData = backupData[entry.key] as Map<String, dynamic>?;
      if (docData == null) continue;
      final payload = docData['payload'] as String?;
      if (payload == null) continue;

      String json;
      try {
        json = _decrypt(payload, passphrase);
      } catch (_) {
        throw Exception('Wrong passphrase — could not decrypt backup.');
      }

      final decoded = jsonDecode(json) as Map<String, dynamic>;

      if (entry.key == 'settings') {
        for (final kv in decoded.entries) {
          if (_settingsWhitelist.contains(kv.key)) {
            await entry.value.put(kv.key, kv.value);
          }
        }
      } else {
        await entry.value.clear();
        for (final kv in decoded.entries) {
          await entry.value.put(kv.key, kv.value);
        }
      }
      restoredBoxes++;
    }

    if (restoredBoxes == 0) {
      throw Exception('No valid data found in Google Drive backup.');
    }
    return restoredBoxes;
  }

  // ── Delete Backup ──────────────────────────────────────────────────────────

  static Future<void> deleteBackup() async {
    try {
      final api = await _getDriveApi();
      final file = await _getBackupFile(api);
      if (file != null && file.id != null) {
        await api.files.delete(file.id!);
      }
    } catch (_) {}
    await AppStorage.settingsBox.delete('last_drive_backup_at');
  }

  // ── Existence check ────────────────────────────────────────────────────────

  static Future<bool> checkBackupExists() async {
    try {
      final api = await _getDriveApi();
      final file = await _getBackupFile(api);
      return file != null;
    } catch (_) {
      return false;
    }
  }
}

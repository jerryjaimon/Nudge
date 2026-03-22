// lib/services/update_service.dart
//
// Checks GitHub releases for a newer version and installs it via MethodChannel.
// Set _kGitHubOwner and _kGitHubRepo to your repository before use.

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

// ── Configure these ───────────────────────────────────────────────────────────
const _kGitHubOwner    = 'jerryjaimon'; // TODO: replace with your GitHub username
const _kGitHubRepo     = 'Nudge';  // TODO: replace with your repo name
const _kCurrentVersion = '1.0.0';        // Keep in sync with pubspec.yaml version
// ─────────────────────────────────────────────────────────────────────────────

class ReleaseInfo {
  final String version;
  final String name;
  final String changelog;
  final String? apkUrl;
  final bool isNewer;

  const ReleaseInfo({
    required this.version,
    required this.name,
    required this.changelog,
    this.apkUrl,
    required this.isNewer,
  });
}

class UpdateService {
  static const _channel = MethodChannel('com.example.nudge/update');

  static String get currentVersion => _kCurrentVersion;

  /// Fetches the latest GitHub release. Returns null if unreachable or error.
  static Future<ReleaseInfo?> checkForUpdate() async {
    try {
      final resp = await http.get(
        Uri.parse(
            'https://api.github.com/repos/$_kGitHubOwner/$_kGitHubRepo/releases/latest'),
        headers: {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 12));

      if (resp.statusCode == 404) return null; // no releases yet
      if (resp.statusCode != 200) return null;

      final body = resp.body;

      // Parse tag_name, name, body from raw JSON (no dart:convert needed for
      // simple string fields — avoids an extra import of jsonDecode which is
      // already available but this keeps the parsing explicit)
      final tagMatch =
          RegExp(r'"tag_name"\s*:\s*"([^"]+)"').firstMatch(body);
      final nameMatch =
          RegExp(r'"name"\s*:\s*"([^"]+)"').firstMatch(body);
      final bodyMatch =
          RegExp(r'"body"\s*:\s*"((?:[^"\\]|\\.)*)"').firstMatch(body);

      if (tagMatch == null) return null;

      final rawTag = tagMatch.group(1)!;
      final version = rawTag.startsWith('v') ? rawTag.substring(1) : rawTag;
      final releaseName = nameMatch?.group(1) ?? rawTag;
      final changelog = (bodyMatch?.group(1) ?? 'No changelog provided.')
          .replaceAll(r'\n', '\n')
          .replaceAll(r'\r', '')
          .replaceAll(r'\"', '"')
          .trim();

      // Find the first .apk asset download URL
      String? apkUrl;
      final assetsMatch =
          RegExp(r'"assets"\s*:\s*\[(.*?)\]', dotAll: true).firstMatch(body);
      if (assetsMatch != null) {
        final assetsJson = assetsMatch.group(1)!;
        final apkBlock = RegExp(
                r'\{[^}]*"name"\s*:\s*"[^"]*\.apk"[^}]*\}',
                dotAll: true)
            .firstMatch(assetsJson);
        if (apkBlock != null) {
          final urlMatch = RegExp(
                  r'"browser_download_url"\s*:\s*"([^"]+)"')
              .firstMatch(apkBlock.group(0)!);
          apkUrl = urlMatch?.group(1);
        }
      }

      return ReleaseInfo(
        version: version,
        name: releaseName,
        changelog: changelog,
        apkUrl: apkUrl,
        isNewer: _isNewer(version, _kCurrentVersion),
      );
    } catch (_) {
      return null;
    }
  }

  /// Downloads the APK to the cache directory, calling [onProgress] (0.0–1.0).
  static Future<File?> downloadApk(
      String url, void Function(double) onProgress) async {
    try {
      final dir = await getTemporaryDirectory();
      final apkDir = Directory('${dir.path}/apk_downloads');
      await apkDir.create(recursive: true);
      final file = File('${apkDir.path}/nudge_update.apk');

      final request = http.Request('GET', Uri.parse(url));
      final response =
          await request.send().timeout(const Duration(minutes: 10));
      final total = response.contentLength ?? 0;
      int received = 0;

      final sink = file.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress(received / total);
      }
      await sink.close();
      return file;
    } catch (_) {
      return null;
    }
  }

  /// Asks Android to install the APK at [filePath] via FileProvider.
  static Future<bool> installApk(String filePath) async {
    try {
      await _channel.invokeMethod('installApk', {'path': filePath});
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Version comparison ─────────────────────────────────────────────────────

  static bool _isNewer(String remote, String current) {
    try {
      final r = remote.split('.').map(int.parse).toList();
      final c = current.split('.').map(int.parse).toList();
      for (int i = 0; i < r.length && i < c.length; i++) {
        if (r[i] > c[i]) return true;
        if (r[i] < c[i]) return false;
      }
      return r.length > c.length;
    } catch (_) {
      return false;
    }
  }
}

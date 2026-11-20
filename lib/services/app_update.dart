import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

const githubLatestRelease =
    'https://api.github.com/repos/KodzghlyCZ/wheelshot/releases/latest';

const _versionLine = r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$';

class AppUpdateOffer {
  const AppUpdateOffer({
    required this.versionName,
    required this.versionCode,
    required this.apkUrl,
  });

  final String versionName;
  final int versionCode;
  final String apkUrl;

  String get label => '$versionName+$versionCode';
}

class InstallPermissionNeeded implements Exception {}

/// Null when the body has no `version:` line or no wheelshot.apk asset.
AppUpdateOffer? parseLatestRelease(
    String body, List<Map<String, dynamic>> assets) {
  final match = RegExp(_versionLine, multiLine: true).firstMatch(body);
  if (match == null) return null;
  String? url;
  for (final asset in assets) {
    if (asset['name'] == 'wheelshot.apk') {
      final raw = asset['browser_download_url'];
      if (raw is String && raw.isNotEmpty) url = raw;
    }
  }
  if (url == null) return null;
  return AppUpdateOffer(
    versionName: match.group(1)!,
    versionCode: int.parse(match.group(2)!),
    apkUrl: url,
  );
}

bool isNewerRelease(int remoteCode, int localCode) => remoteCode > localCode;

class AppUpdate {
  static const _channel = MethodChannel('com.wheelshot.app/update');

  /// Newer GitHub release, or null when this install is current or the
  /// check cannot be made.
  static Future<AppUpdateOffer?> check() async {
    final info = await PackageInfo.fromPlatform();
    final local = int.tryParse(info.buildNumber) ?? 0;
    final offer = await fetchLatest();
    if (offer == null || !isNewerRelease(offer.versionCode, local)) {
      return null;
    }
    return offer;
  }

  static Future<AppUpdateOffer?> fetchLatest() async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(githubLatestRelease));
      request.headers.set(HttpHeaders.userAgentHeader, 'wheelshot');
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/vnd.github+json',
      );
      final response =
          await request.close().timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        await response.drain<void>();
        return null;
      }
      final raw = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final body = '${decoded['body'] ?? ''}';
      final assets = <Map<String, dynamic>>[];
      final rawAssets = decoded['assets'];
      if (rawAssets is List) {
        for (final asset in rawAssets) {
          if (asset is Map) {
            assets.add(Map<String, dynamic>.from(asset));
          }
        }
      }
      return parseLatestRelease(body, assets);
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static Future<File> download(
    AppUpdateOffer offer,
    void Function(double? progress) onProgress,
  ) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(offer.apkUrl));
      request.headers.set(HttpHeaders.userAgentHeader, 'wheelshot');
      request.followRedirects = true;
      final response =
          await request.close().timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        await response.drain<void>();
        throw HttpException('download failed ${response.statusCode}');
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/wheelshot-update.apk');
      final sink = file.openWrite();
      var received = 0;
      final total = response.contentLength;
      try {
        await for (final chunk in response) {
          received += chunk.length;
          sink.add(chunk);
          if (total > 0) {
            onProgress(received / total);
          } else {
            onProgress(null);
          }
        }
      } finally {
        await sink.close();
      }
      return file;
    } finally {
      client.close(force: true);
    }
  }

  /// Opens the system installer. Throws [InstallPermissionNeeded] when
  /// Android sent the user to the unknown-sources setting instead.
  static Future<void> install(File apk) async {
    final status = await _channel.invokeMethod<String>('install', {
      'path': apk.path,
    });
    if (status == 'need-permission') throw InstallPermissionNeeded();
  }
}

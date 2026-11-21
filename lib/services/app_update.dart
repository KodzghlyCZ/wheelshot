import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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

/// Survives sheet dispose and brief background pauses. Retries with Range.
class AppUpdateDownload extends ChangeNotifier {
  AppUpdateDownload._(this.offer);

  final AppUpdateOffer offer;
  var busy = false;
  double? progress;
  String? note;
  File? file;
  Object? error;

  Future<void>? _job;

  Future<void> start() {
    return _job ??= _run();
  }

  Future<void> _run() async {
    busy = true;
    progress = 0;
    note = null;
    error = null;
    file = null;
    notifyListeners();
    try {
      await AppUpdate._holdWake(true);
      final apk = await AppUpdate._downloadResilient(offer, (p) {
        progress = p;
        notifyListeners();
      });
      file = apk;
      note = 'Opening installer…';
      notifyListeners();
      await AppUpdate.install(apk);
      note = 'Confirm the install on the next screen.';
    } on InstallPermissionNeeded {
      error = InstallPermissionNeeded();
      note = 'Allow WheelShot to install apps, then tap Download again.';
    } catch (e) {
      error = e;
      note = 'Update failed. $e';
    } finally {
      await AppUpdate._holdWake(false);
      busy = false;
      _job = null;
      notifyListeners();
    }
  }
}

class AppUpdate {
  static const _channel = MethodChannel('com.wheelshot.app/update');
  static AppUpdateDownload? _active;

  static AppUpdateDownload? get activeDownload => _active;

  /// Same job if a download for this offer is already running.
  static AppUpdateDownload beginDownload(AppUpdateOffer offer) {
    final current = _active;
    if (current != null &&
        current.busy &&
        current.offer.versionCode == offer.versionCode &&
        current.offer.apkUrl == offer.apkUrl) {
      return current;
    }
    final job = AppUpdateDownload._(offer);
    _active = job;
    unawaited(job.start());
    return job;
  }

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

  static Future<void> _holdWake(bool on) async {
    try {
      await _channel.invokeMethod<void>(on ? 'wakeLock' : 'wakeUnlock');
    } catch (_) {}
  }

  static Future<File> _downloadResilient(
    AppUpdateOffer offer,
    void Function(double? progress) onProgress,
  ) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/wheelshot-update.apk');
    Object? lastError;
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        await _downloadOnce(offer, file, onProgress);
        return file;
      } catch (e) {
        lastError = e;
        if (attempt == 4) break;
        await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }
    throw lastError ?? const HttpException('download failed');
  }

  static Future<void> _downloadOnce(
    AppUpdateOffer offer,
    File file,
    void Function(double? progress) onProgress,
  ) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 30);
    client.idleTimeout = const Duration(seconds: 60);
    try {
      var have = 0;
      if (await file.exists()) {
        have = await file.length();
      }
      final request = await client.getUrl(Uri.parse(offer.apkUrl));
      request.headers.set(HttpHeaders.userAgentHeader, 'wheelshot');
      request.followRedirects = true;
      if (have > 0) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$have-');
      }
      final response =
          await request.close().timeout(const Duration(seconds: 45));
      if (response.statusCode == 200) {
        if (have > 0) {
          await file.writeAsBytes(const [], flush: true);
          have = 0;
        }
      } else if (response.statusCode == 206) {
        // Resume.
      } else {
        await response.drain<void>();
        throw HttpException('download failed ${response.statusCode}');
      }

      final sink = file.openWrite(
        mode: have > 0 ? FileMode.append : FileMode.write,
      );
      var received = have;
      final contentLen = response.contentLength;
      final total = contentLen < 0
          ? -1
          : (response.statusCode == 206 ? have + contentLen : contentLen);
      try {
        await for (final chunk in response.timeout(
          const Duration(seconds: 45),
          onTimeout: (sink) {
            sink.addError(TimeoutException('download stalled'));
            sink.close();
          },
        )) {
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
      if (total > 0 && received < total) {
        throw HttpException('download incomplete $received/$total');
      }
      if (received < 1024) {
        throw HttpException('download too small ($received bytes)');
      }
      onProgress(1);
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

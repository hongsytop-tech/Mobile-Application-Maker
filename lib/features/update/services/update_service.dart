import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../models/update_info.dart';

class UpdateUnavailable implements Exception {
  final String message;
  const UpdateUnavailable(this.message);
  @override
  String toString() => message;
}

/// 앱 내 자동 업데이트 매니저.
/// GitHub Releases에서 arm64-v8a APK를 받아서 시스템 인스톨러를 호출한다.
/// (안드로이드 전용. iOS/웹은 no-op)
class UpdateService {
  static const _owner = 'hongsytop-tech';
  static const _repo = 'Mobile-Application-Maker';

  /// 안드로이드 외 플랫폼은 항상 null 반환.
  Future<UpdateInfo?> checkForUpdate() async {
    if (kIsWeb || !Platform.isAndroid) return null;

    final pkg = await PackageInfo.fromPlatform();
    final currentBuild = int.tryParse(pkg.buildNumber) ?? 0;

    final res = await http.get(
      Uri.parse(
          'https://api.github.com/repos/$_owner/$_repo/releases/latest'),
      headers: {'Accept': 'application/vnd.github+json'},
    );
    if (res.statusCode != 200) {
      throw UpdateUnavailable(
          '업데이트 정보 조회 실패 (${res.statusCode})');
    }

    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final tagName = (body['tag_name'] as String?) ?? '';
    final tagMatch = RegExp(r'apk-build-(\d+)').firstMatch(tagName);
    if (tagMatch == null) return null;
    final latestBuild = int.parse(tagMatch.group(1)!);

    if (latestBuild <= currentBuild) {
      return UpdateInfo(
        latestBuild: latestBuild,
        currentBuild: currentBuild,
        name: (body['name'] as String?) ?? 'Build $latestBuild',
        apkUrl: '',
        releaseUrl: (body['html_url'] as String?) ?? '',
        releaseNotes: (body['body'] as String?) ?? '',
      );
    }

    final assets =
        (body['assets'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    // 우선순위: arm64-v8a > universal > 첫 번째
    Map<String, dynamic>? pick;
    for (final a in assets) {
      final name = (a['name'] as String?) ?? '';
      if (name.contains('arm64-v8a')) {
        pick = a;
        break;
      }
    }
    if (pick == null) {
      for (final a in assets) {
        if (((a['name'] as String?) ?? '').contains('universal')) {
          pick = a;
          break;
        }
      }
    }
    pick ??= assets.isNotEmpty ? assets.first : null;
    if (pick == null) {
      throw const UpdateUnavailable('Release에 APK가 없습니다');
    }

    return UpdateInfo(
      latestBuild: latestBuild,
      currentBuild: currentBuild,
      name: (body['name'] as String?) ?? 'Build $latestBuild',
      apkUrl: pick['browser_download_url'] as String,
      apkSizeBytes: pick['size'] as int?,
      releaseUrl: (body['html_url'] as String?) ?? '',
      releaseNotes: (body['body'] as String?) ?? '',
    );
  }

  /// APK 다운로드. onProgress는 0.0~1.0.
  Future<File> downloadApk(
    String url, {
    void Function(double progress, int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/self-dev-app-update.apk');
    if (await file.exists()) await file.delete();

    final dio = Dio();
    await dio.download(
      url,
      file.path,
      onReceiveProgress: (received, total) {
        if (total > 0 && onProgress != null) {
          onProgress(received / total, received, total);
        }
      },
      cancelToken: cancelToken,
    );
    return file;
  }

  /// 다운로드한 APK를 시스템 인스톨러로 연다.
  /// 사용자 동의가 필요한 단계 (출처 알 수 없는 앱 설치 허용).
  Future<void> installApk(File apk) async {
    final result = await OpenFilex.open(apk.path, type: 'application/vnd.android.package-archive');
    if (result.type != ResultType.done) {
      throw UpdateUnavailable('인스톨러 열기 실패: ${result.message}');
    }
  }
}

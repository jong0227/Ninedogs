import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// 새 버전 APK 를 내려받아 안드로이드 설치 화면을 띄운다.
///
/// 저장소가 공개라 GitHub Releases 의 APK 를 인증 없이 바로 받을 수 있다.
/// 받은 파일은 앱 캐시에 두고, 네이티브(MainActivity)의 FileProvider 로
/// 설치기에 넘긴다. 설치 자체는 사용자가 "설치"를 눌러야 진행된다.
class ApkInstaller {
  const ApkInstaller();

  static const _channel = MethodChannel('ninedogs/install');

  /// [url] 의 APK 를 받아 설치기를 연다. [onProgress] 는 0~1 사이 진행률.
  ///
  /// 다운로드나 설치 호출이 실패하면 예외를 던진다. 화면에서 받아 안내한다.
  Future<void> downloadAndInstall(
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    // 이전에 받다 만 파일이 남아 있을 수 있으니 늘 새로 쓴다.
    final file = File('${dir.path}/ninedogs-update.apk');

    final client = http.Client();
    try {
      final response = await client.send(http.Request('GET', Uri.parse(url)));
      if (response.statusCode != 200) {
        throw Exception('내려받지 못했어요 (${response.statusCode})');
      }

      final total = response.contentLength ?? 0;
      var received = 0;
      final sink = file.openWrite();
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) onProgress?.call(received / total);
        }
      } finally {
        await sink.close();
      }
    } finally {
      client.close();
    }

    await _channel.invokeMethod('installApk', {'path': file.path});
  }
}

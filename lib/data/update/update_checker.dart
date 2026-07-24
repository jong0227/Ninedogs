import 'dart:convert';

import 'package:http/http.dart' as http;

/// 배포된 최신 버전 정보.
class AppRelease {
  const AppRelease({
    required this.version,
    required this.pageUrl,
    this.apkUrl,
    this.notes,
  });

  /// 'v' 를 뗀 버전 문자열. 예: '1.1.0'
  final String version;

  /// 릴리즈 페이지 주소. 앱에서 브라우저로 열어준다.
  final String pageUrl;

  /// APK 자산 직접 내려받기 주소. 없을 수도 있다.
  final String? apkUrl;

  final String? notes;
}

sealed class UpdateResult {
  const UpdateResult();
}

class UpdateAvailable extends UpdateResult {
  const UpdateAvailable(this.release);
  final AppRelease release;
}

class UpToDate extends UpdateResult {
  const UpToDate();
}

/// 확인 자체를 못 했을 때. 최신인지 아닌지 알 수 없다는 뜻이라
/// [UpToDate] 와 구분해서 다룬다.
class UpdateCheckFailed extends UpdateResult {
  const UpdateCheckFailed(this.reason);
  final String reason;
}

/// 새 버전이 나왔는지 확인한다.
///
/// GitHub Releases 를 본다. 저장소가 비공개면 인증 없이는 읽을 수 없어서
/// [UpdateCheckFailed] 가 돌아온다. 토큰을 앱에 심는 건 위험하므로 하지 않는다.
/// 자세한 내용은 RELEASE.md 참고.
class UpdateChecker {
  UpdateChecker({http.Client? client, this.releasesUrl = defaultReleasesUrl})
    : _client = client ?? http.Client();

  final http.Client _client;
  final String releasesUrl;

  static const defaultReleasesUrl =
      'https://api.github.com/repos/jong0227/Ninedogs/releases/latest';

  Future<UpdateResult> check(String currentVersion) async {
    final http.Response response;
    try {
      response = await _client
          .get(
            Uri.parse(releasesUrl),
            headers: const {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      return const UpdateCheckFailed('네트워크에 연결할 수 없어요');
    }

    if (response.statusCode == 404) {
      return const UpdateCheckFailed('아직 공개된 릴리즈가 없어요');
    }
    if (response.statusCode != 200) {
      return UpdateCheckFailed('업데이트 정보를 가져오지 못했어요 (${response.statusCode})');
    }

    final AppRelease release;
    try {
      release = _parse(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, Object?>,
      );
    } catch (_) {
      return const UpdateCheckFailed('업데이트 정보를 읽지 못했어요');
    }

    return isNewer(release.version, currentVersion)
        ? UpdateAvailable(release)
        : const UpToDate();
  }

  AppRelease _parse(Map<String, Object?> json) {
    final assets = (json['assets'] as List?) ?? const [];
    final apk = assets.cast<Map<String, Object?>>().where(
      (a) => (a['name'] as String? ?? '').endsWith('.apk'),
    );

    return AppRelease(
      version: normalizeVersion(json['tag_name'] as String? ?? ''),
      pageUrl: json['html_url'] as String? ?? '',
      apkUrl: apk.isEmpty
          ? null
          : apk.first['browser_download_url'] as String?,
      notes: json['body'] as String?,
    );
  }

  /// 'v1.2.0' -> '1.2.0', '1.2.0+5' -> '1.2.0'
  static String normalizeVersion(String raw) {
    var value = raw.trim();
    if (value.startsWith('v') || value.startsWith('V')) {
      value = value.substring(1);
    }
    return value.split('+').first;
  }

  /// [candidate] 가 [current] 보다 새 버전인지.
  ///
  /// 숫자 단위로 앞에서부터 비교한다. 자릿수가 달라도('1.2' vs '1.2.0')
  /// 없는 자리는 0 으로 본다.
  static bool isNewer(String candidate, String current) {
    final a = _parts(normalizeVersion(candidate));
    final b = _parts(normalizeVersion(current));
    if (a.isEmpty) return false;

    for (var i = 0; i < (a.length > b.length ? a.length : b.length); i++) {
      final left = i < a.length ? a[i] : 0;
      final right = i < b.length ? b[i] : 0;
      if (left != right) return left > right;
    }
    return false;
  }

  static List<int> _parts(String version) => version
      .split('.')
      .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
      .toList();
}

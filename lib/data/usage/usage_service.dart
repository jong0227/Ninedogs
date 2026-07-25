import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 폰에서 구독 서비스 앱을 마지막으로 언제 썼는지 읽어온다.
///
/// **선택 기능이고 기본은 꺼져 있다.** 켜려면 사용자가 안드로이드 설정에서
/// '사용 정보 접근'을 직접 허용해야 한다. 켜지 않아도 앱은 그대로 동작한다.
///
/// ### 한계를 분명히 해둔다
/// TV·PC·태블릿으로 본 것은 잡히지 않는다. 넷플릭스를 TV 로만 보는 사람은
/// 폰 기록이 비어 있다. 그래서 기록이 없을 때 "안 쓴다"고 단정하면 안 된다.
/// 기록이 **있을 때만** 마지막 사용 시점을 알려주고, 없으면 아무 말도 하지 않는다.
class UsageService {
  const UsageService();

  static const _channel = MethodChannel('ninedogs/usage');

  bool get _supported => defaultTargetPlatform == TargetPlatform.android;

  /// 사용 정보 접근이 허용돼 있는지.
  Future<bool> hasPermission() async {
    if (!_supported) return false;
    try {
      return await _channel.invokeMethod<bool>('hasPermission') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// 안드로이드 설정의 '사용 정보 접근' 화면을 연다.
  ///
  /// 이 권한은 일반 권한 창으로 받을 수 없어서 데려다주는 것까지만 한다.
  Future<void> openSettings() async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<bool>('openSettings');
    } on PlatformException {
      // 설정 화면을 못 열어도 앱이 죽을 일은 아니다
    } on MissingPluginException {
      // 채널이 없는 환경(테스트 등)
    }
  }

  /// 각 패키지를 마지막으로 쓴 시각.
  ///
  /// 기록이 없는 패키지는 **결과에 들어 있지 않다.** 없는 것과 안 쓴 것을
  /// 구분해야 하므로 0 이나 기본값으로 채우지 않는다.
  Future<Map<String, DateTime>> lastUsed(List<String> packages) async {
    if (!_supported || packages.isEmpty) return const {};

    try {
      final raw = await _channel.invokeMapMethod<String, Object?>('lastUsed', {
        'packages': packages,
      });
      if (raw == null) return const {};

      return {
        for (final entry in raw.entries)
          if (entry.value is num && (entry.value as num) > 0)
            entry.key: DateTime.fromMillisecondsSinceEpoch(
              (entry.value as num).toInt(),
            ),
      };
    } on PlatformException {
      return const {};
    } on MissingPluginException {
      return const {};
    }
  }
}

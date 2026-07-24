import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 다른 앱(카톡 등)에서 백업 파일을 열어 넘겨준 내용을 받아온다.
///
/// 네이티브 쪽에서 한 번 가져가면 비우기 때문에, 같은 파일을 두 번 묻지 않는다.
class ImportChannel {
  const ImportChannel();

  static const _channel = MethodChannel('ninedogs/import');

  /// 대기 중인 백업 내용. 없으면 null.
  Future<String?> takePending() async {
    if (defaultTargetPlatform != TargetPlatform.android) return null;

    try {
      return await _channel.invokeMethod<String>('takePendingImport');
    } on MissingPluginException {
      // 채널이 없는 환경(테스트 등)에서는 조용히 넘어간다.
      return null;
    } on PlatformException {
      return null;
    }
  }
}

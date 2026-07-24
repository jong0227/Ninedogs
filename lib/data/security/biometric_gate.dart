import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// 지문·얼굴로 금고를 여는 통로.
///
/// 마스터 암호로 한 번 연 뒤, 그때 만들어진 키를 기기 보안 저장소
/// (Android Keystore / iOS Keychain)에 넣어둔다. 다음부터는 생체인증만
/// 통과하면 그 키를 꺼내 쓰므로 암호를 다시 입력할 필요가 없다.
///
/// **키는 기기 밖으로 나가지 않는다.** 백업 파일에도 들어가지 않고,
/// 나중에 붙일 서버 동기화에도 올리지 않는다. 기기를 바꾸면 마스터 암호로
/// 다시 열어야 한다 — 그게 맞는 동작이다.
///
/// 절충점: 이 방식은 "기기 잠금을 뚫은 사람"까지 막지는 못한다. 대신 매번
/// 긴 암호를 치는 불편이 사라져서 사람들이 실제로 잠금을 쓰게 된다.
class BiometricGate {
  BiometricGate({LocalAuthentication? auth, FlutterSecureStorage? storage})
    : _auth = auth ?? LocalAuthentication(),
      _storage = storage ?? const FlutterSecureStorage();

  final LocalAuthentication _auth;
  final FlutterSecureStorage _storage;

  static const _keyName = 'vault_key_v1';

  /// 이 기기에서 생체인증을 쓸 수 있는지. 등록된 지문이 없으면 false.
  Future<bool> isAvailable() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// 생체인증으로 열도록 설정해 뒀는지.
  Future<bool> isEnabled() async {
    try {
      return await _storage.read(key: _keyName) != null;
    } catch (_) {
      return false;
    }
  }

  /// 지금 열려 있는 금고의 키를 저장해 다음부터 생체인증으로 열게 한다.
  Future<void> enable(List<int> keyBytes) =>
      _storage.write(key: _keyName, value: base64Encode(keyBytes));

  /// 저장한 키를 지운다. 다음부터는 마스터 암호로만 열린다.
  Future<void> disable() => _storage.delete(key: _keyName);

  /// 생체인증을 거쳐 키를 꺼낸다. 실패하거나 취소하면 null.
  Future<List<int>?> unlock({String reason = '계정 정보를 보려면 인증이 필요해요'}) async {
    try {
      final stored = await _storage.read(key: _keyName);
      if (stored == null) return null;

      final passed = await _auth.authenticate(
        localizedReason: reason,
        // 기기 PIN·패턴도 허용한다. 지문만 허용하면 손이 젖었을 때처럼
        // 인식이 안 되는 상황에서 아예 못 여는 일이 생긴다.
        biometricOnly: false,
        // 인증 창이 떠 있는 동안 앱이 잠깐 뒤로 가도 흐름을 유지한다
        persistAcrossBackgrounding: true,
      );
      if (!passed) return null;

      return base64Decode(stored);
    } catch (_) {
      return null;
    }
  }
}

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// 암호화된 한 덩어리. 서버에는 이 형태로만 올라간다.
///
/// nonce 와 mac 은 비밀이 아니라 복호화에 필요한 값이라 같이 저장한다.
/// mac 덕분에 누가 암호문을 건드리면 복호화가 실패한다.
class EncryptedPayload {
  const EncryptedPayload({
    required this.nonce,
    required this.cipherText,
    required this.mac,
  });

  final List<int> nonce;
  final List<int> cipherText;
  final List<int> mac;

  Map<String, Object?> toJson() => {
    'v': 1,
    'nonce': base64Encode(nonce),
    'data': base64Encode(cipherText),
    'mac': base64Encode(mac),
  };

  factory EncryptedPayload.fromJson(Map<String, Object?> json) =>
      EncryptedPayload(
        nonce: base64Decode(json['nonce'] as String),
        cipherText: base64Decode(json['data'] as String),
        mac: base64Decode(json['mac'] as String),
      );
}

/// 마스터 암호가 틀렸거나 데이터가 손상됐을 때.
class VaultUnlockException implements Exception {
  const VaultUnlockException([this.message = '마스터 암호가 맞지 않습니다']);
  final String message;

  @override
  String toString() => message;
}

/// 계정 정보를 기기에서 암호화하고 푸는 곳.
///
/// 설계 원칙: **평문은 절대 저장하지도, 서버로 보내지도 않는다.**
/// 마스터 암호에서 뽑은 키는 메모리에만 두고, 서버(Firestore)에는
/// [EncryptedPayload] 만 올라간다. 그래서 서버를 들여다봐도 내용을 알 수 없다.
///
/// 부부가 같은 마스터 암호를 쓰면 같은 salt 로 같은 키가 나오므로
/// 서로의 기록을 열 수 있다. salt 는 비밀이 아니라서 같이 보관해도 된다.
class VaultCrypto {
  const VaultCrypto._(this._key);

  final SecretKey _key;

  static final _algorithm = AesGcm.with256bits();

  /// 마스터 암호가 맞는지 확인할 때 쓰는 고정 문구.
  /// 이걸 암호화해 두고, 풀리면 암호가 맞는 것으로 본다.
  static const _verifierPlainText = 'ninedogs-vault-v1';

  /// PBKDF2 반복 횟수. 무차별 대입을 느리게 만든다.
  ///
  /// 순수 Dart 구현이라 기기에서 1초 안팎 걸린다. 잠금 해제할 때 한 번만
  /// 도므로 감수할 만하다. 더 빠르게 하려면 cryptography_flutter 로
  /// 네이티브 구현을 붙이면 된다.
  static const iterations = 120000;

  static final _random = Random.secure();

  /// 새 금고를 만들 때 한 번 생성하는 salt. 비밀이 아니며 함께 저장한다.
  static Uint8List newSalt([int length = 16]) =>
      Uint8List.fromList(List.generate(length, (_) => _random.nextInt(256)));

  /// 마스터 암호에서 암호화 키를 뽑는다.
  static Future<VaultCrypto> fromPassword(
    String password,
    List<int> salt, {
    int iterations = VaultCrypto.iterations,
  }) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    final key = await pbkdf2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    return VaultCrypto._(key);
  }

  /// 생체인증으로 저장해 둔 키를 다시 쓸 때. 암호 유도를 건너뛴다.
  static VaultCrypto fromKeyBytes(List<int> keyBytes) {
    if (keyBytes.length != 32) {
      throw ArgumentError('키는 32바이트여야 합니다 (받은 값: ${keyBytes.length})');
    }
    return VaultCrypto._(SecretKey(keyBytes));
  }

  /// 기기 보안 저장소에 넣어둘 키 원본.
  /// flutter_secure_storage(Android Keystore / iOS Keychain) 밖으로는
  /// 절대 나가면 안 된다.
  Future<List<int>> exportKeyBytes() async => _key.extractBytes();

  Future<EncryptedPayload> encrypt(String plainText) async {
    final box = await _algorithm.encrypt(
      utf8.encode(plainText),
      secretKey: _key,
    );
    return EncryptedPayload(
      nonce: box.nonce,
      cipherText: box.cipherText,
      mac: box.mac.bytes,
    );
  }

  Future<String> decrypt(EncryptedPayload payload) async {
    try {
      final clear = await _algorithm.decrypt(
        SecretBox(
          payload.cipherText,
          nonce: payload.nonce,
          mac: Mac(payload.mac),
        ),
        secretKey: _key,
      );
      return utf8.decode(clear);
    } on SecretBoxAuthenticationError {
      // 키가 다르거나 암호문이 변조됐다. 어느 쪽인지는 구분할 수 없다.
      throw const VaultUnlockException();
    }
  }

  Future<EncryptedPayload> encryptJson(Map<String, Object?> value) =>
      encrypt(jsonEncode(value));

  Future<Map<String, Object?>> decryptJson(EncryptedPayload payload) async =>
      jsonDecode(await decrypt(payload)) as Map<String, Object?>;

  /// 금고를 처음 만들 때 저장해 둘 확인용 값.
  Future<EncryptedPayload> createVerifier() => encrypt(_verifierPlainText);

  /// 입력한 마스터 암호가 맞는지 확인한다.
  Future<bool> matchesVerifier(EncryptedPayload verifier) async {
    try {
      return await decrypt(verifier) == _verifierPlainText;
    } on VaultUnlockException {
      return false;
    }
  }
}

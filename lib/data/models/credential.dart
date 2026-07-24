import '../security/vault_crypto.dart';

/// 서비스에 어떤 방법으로 로그인하는지.
enum LoginMethod {
  email('이메일'),
  google('구글'),
  apple('애플'),
  kakao('카카오'),
  naver('네이버'),
  phone('휴대폰'),
  other('기타');

  const LoginMethod(this.label);
  final String label;
}

/// 잠금이 풀린 상태의 계정 정보. **메모리에만 존재한다.**
///
/// 이 객체를 그대로 저장하거나 로그로 남기면 안 된다. 저장할 때는 반드시
/// [encrypt] 를 거쳐 [StoredCredential] 로 바꾼다.
class Credential {
  const Credential({
    required this.id,
    required this.subscriptionId,
    this.loginId = '',
    this.password = '',
    this.loginMethod = LoginMethod.email,
    this.memo,
  });

  final String id;
  final String subscriptionId;
  final String loginId;
  final String password;
  final LoginMethod loginMethod;
  final String? memo;

  bool get isEmpty => loginId.isEmpty && password.isEmpty;

  Credential copyWith({
    String? loginId,
    String? password,
    LoginMethod? loginMethod,
    String? memo,
  }) => Credential(
    id: id,
    subscriptionId: subscriptionId,
    loginId: loginId ?? this.loginId,
    password: password ?? this.password,
    loginMethod: loginMethod ?? this.loginMethod,
    memo: memo ?? this.memo,
  );

  /// 비밀 값들만 담는다. 이 map 이 통째로 암호화된다.
  Map<String, Object?> _secretJson() => {
    'loginId': loginId,
    'password': password,
    'loginMethod': loginMethod.name,
    'memo': memo,
  };

  Future<StoredCredential> encrypt(VaultCrypto crypto) async =>
      StoredCredential(
        id: id,
        subscriptionId: subscriptionId,
        payload: await crypto.encryptJson(_secretJson()),
        updatedAt: DateTime.now(),
      );

  /// 실수로 로그에 찍혀도 비밀번호가 새지 않게 한다.
  @override
  String toString() => 'Credential($id, subscription: $subscriptionId, 비공개)';
}

/// 저장·동기화되는 형태. 아이디와 비밀번호는 [payload] 안에 암호화돼 있어
/// 서버나 백업 파일을 들여다봐도 내용을 알 수 없다.
class StoredCredential {
  const StoredCredential({
    required this.id,
    required this.subscriptionId,
    required this.payload,
    required this.updatedAt,
  });

  final String id;

  /// 어떤 구독의 것인지. 이 값만 평문이다.
  final String subscriptionId;

  final EncryptedPayload payload;
  final DateTime updatedAt;

  Future<Credential> decrypt(VaultCrypto crypto) async {
    final json = await crypto.decryptJson(payload);
    return Credential(
      id: id,
      subscriptionId: subscriptionId,
      loginId: json['loginId'] as String? ?? '',
      password: json['password'] as String? ?? '',
      loginMethod: LoginMethod.values.byName(
        json['loginMethod'] as String? ?? LoginMethod.email.name,
      ),
      memo: json['memo'] as String?,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'subscriptionId': subscriptionId,
    'payload': payload.toJson(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory StoredCredential.fromJson(Map<String, Object?> json) =>
      StoredCredential(
        id: json['id'] as String,
        subscriptionId: json['subscriptionId'] as String,
        payload: EncryptedPayload.fromJson(
          json['payload'] as Map<String, Object?>,
        ),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

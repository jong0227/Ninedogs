import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/credential.dart';
import '../security/vault_crypto.dart';

/// 금고를 열기 위해 필요한 공개 정보. 비밀이 아니라 그대로 저장·동기화한다.
///
/// [salt] 가 같아야 부부가 같은 마스터 암호로 같은 키를 얻는다.
/// [verifier] 는 입력한 암호가 맞는지 확인하는 용도다.
class VaultMetadata {
  const VaultMetadata({
    required this.salt,
    required this.verifier,
    required this.createdAt,
  });

  final List<int> salt;
  final EncryptedPayload verifier;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'salt': base64Encode(salt),
    'verifier': verifier.toJson(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory VaultMetadata.fromJson(Map<String, Object?> json) => VaultMetadata(
    salt: base64Decode(json['salt'] as String),
    verifier: EncryptedPayload.fromJson(
      json['verifier'] as Map<String, Object?>,
    ),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

/// 암호화된 계정 정보와 금고 메타데이터의 저장소.
///
/// 구독 저장소와 마찬가지로 나중에 Firestore 구현으로 갈아끼운다.
/// 어느 구현이든 [StoredCredential] 만 다루므로 평문이 흘러갈 일은 없다.
abstract interface class CredentialRepository {
  Future<VaultMetadata?> loadMetadata();
  Future<void> saveMetadata(VaultMetadata metadata);
  Future<List<StoredCredential>> load();
  Future<void> save(List<StoredCredential> credentials);

  /// 다른 기기에서 바뀐 내용을 실시간으로 받는다. 로컬 구현은 null.
  Stream<List<StoredCredential>>? watch();
}

class LocalCredentialRepository implements CredentialRepository {
  LocalCredentialRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _metadataKey = 'vault_metadata_v1';
  static const _credentialsKey = 'vault_credentials_v1';

  @override
  Future<VaultMetadata?> loadMetadata() async {
    final raw = _prefs.getString(_metadataKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      return VaultMetadata.fromJson(
        jsonDecode(raw) as Map<String, Object?>,
      );
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> saveMetadata(VaultMetadata metadata) =>
      _prefs.setString(_metadataKey, jsonEncode(metadata.toJson()));

  @override
  Future<List<StoredCredential>> load() async {
    final raw = _prefs.getString(_credentialsKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      return (jsonDecode(raw) as List)
          .map((e) => StoredCredential.fromJson(e as Map<String, Object?>))
          .toList();
    } on FormatException {
      // 형식이 깨졌다고 덮어쓰면 복구 불가능한 손실이 된다. 읽기만 포기한다.
      return [];
    }
  }

  @override
  Future<void> save(List<StoredCredential> credentials) => _prefs.setString(
    _credentialsKey,
    jsonEncode(credentials.map((c) => c.toJson()).toList()),
  );

  @override
  Stream<List<StoredCredential>>? watch() => null;
}

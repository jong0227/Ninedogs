import 'dart:convert';

import '../models/credential.dart';
import '../models/subscription.dart';
import '../repository/credential_repository.dart';

/// 백업 파일이 망가졌거나 이 앱이 만든 게 아닐 때.
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// 내보내기·가져오기에 쓰는 파일 형식.
///
/// 계정 정보는 **암호문 그대로** 담는다. 파일을 열어봐도 아이디와 비밀번호는
/// 보이지 않고, 복원한 뒤 마스터 암호를 입력해야 열린다.
/// 이때 [vaultMetadata] 의 salt 가 함께 있어야 같은 키를 다시 만들 수 있으므로
/// 계정 정보를 담을 때는 메타데이터도 반드시 같이 담는다.
class BackupFile {
  const BackupFile({
    required this.exportedAt,
    required this.subscriptions,
    this.vaultMetadata,
    this.credentials = const [],
  });

  /// 형식이 바뀌면 올린다. 가져올 때 확인한다.
  static const currentVersion = 1;

  /// 이 앱이 만든 파일인지 구별하는 표시.
  static const _magic = 'ninedogs.backup';

  final DateTime exportedAt;
  final List<Subscription> subscriptions;

  /// 계정 정보를 포함하지 않은 백업이면 null.
  final VaultMetadata? vaultMetadata;
  final List<StoredCredential> credentials;

  bool get includesCredentials => credentials.isNotEmpty;

  Map<String, Object?> toJson() => {
    'format': _magic,
    'version': currentVersion,
    'exportedAt': exportedAt.toIso8601String(),
    'subscriptions': subscriptions.map((s) => s.toJson()).toList(),
    if (vaultMetadata != null) 'vault': vaultMetadata!.toJson(),
    if (credentials.isNotEmpty)
      'credentials': credentials.map((c) => c.toJson()).toList(),
  };

  /// 사람이 열어봐도 알아볼 수 있게 들여쓰기해서 쓴다.
  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  factory BackupFile.decode(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw const BackupFormatException('백업 파일이 아니거나 내용이 깨졌어요');
    }

    if (decoded is! Map<String, Object?>) {
      throw const BackupFormatException('백업 파일이 아니거나 내용이 깨졌어요');
    }
    if (decoded['format'] != _magic) {
      throw const BackupFormatException('Ninedogs 백업 파일이 아니에요');
    }

    final version = (decoded['version'] as num?)?.toInt() ?? 0;
    if (version > currentVersion) {
      throw const BackupFormatException(
        '더 새로운 버전에서 만든 백업이에요. 앱을 업데이트해주세요',
      );
    }

    try {
      final vault = decoded['vault'] as Map<String, Object?>?;
      return BackupFile(
        exportedAt: DateTime.parse(decoded['exportedAt'] as String),
        subscriptions: ((decoded['subscriptions'] as List?) ?? const [])
            .map((e) => Subscription.fromJson(e as Map<String, Object?>))
            .toList(),
        vaultMetadata: vault == null ? null : VaultMetadata.fromJson(vault),
        credentials: ((decoded['credentials'] as List?) ?? const [])
            .map((e) => StoredCredential.fromJson(e as Map<String, Object?>))
            .toList(),
      );
    } catch (_) {
      throw const BackupFormatException('백업 내용을 읽지 못했어요');
    }
  }

  /// 카톡 같은 데서 알아보기 쉬운 파일 이름.
  String get suggestedFileName {
    final d = exportedAt;
    final stamp =
        '${d.year}${_two(d.month)}${_two(d.day)}-${_two(d.hour)}${_two(d.minute)}';
    return 'ninedogs-backup-$stamp.json';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/backup/backup_file.dart';
import '../data/models/credential.dart';
import '../data/models/subscription.dart';
import '../data/repository/credential_repository.dart';
import '../data/repository/subscription_repository.dart';
import 'subscription_providers.dart';
import 'vault_providers.dart';

/// 가져오기 결과. 사용자에게 무엇이 어떻게 됐는지 그대로 보여준다.
class ImportResult {
  const ImportResult({
    required this.added,
    required this.replaced,
    required this.credentialsRestored,
    this.credentialsSkippedReason,
  });

  final int added;
  final int replaced;
  final int credentialsRestored;

  /// 계정 정보를 못 가져왔다면 그 이유. 없으면 null.
  final String? credentialsSkippedReason;

  String get summary {
    final parts = <String>[
      if (added > 0) '구독 $added개 추가',
      if (replaced > 0) '$replaced개 갱신',
      if (credentialsRestored > 0) '계정 정보 $credentialsRestored개 복원',
    ];
    return parts.isEmpty ? '새로 가져온 내용이 없어요' : parts.join(' · ');
  }
}

class BackupService {
  const BackupService(this._ref);

  final Ref _ref;

  SubscriptionRepository get _subscriptions =>
      _ref.read(subscriptionRepositoryProvider);
  CredentialRepository get _credentials =>
      _ref.read(credentialRepositoryProvider);

  /// 지금 상태를 백업 파일로 만든다.
  ///
  /// [includeCredentials] 를 켜면 계정 정보를 **암호문 그대로** 담는다.
  /// 함께 담기는 금고 메타데이터(salt)가 있어야 복원한 기기에서
  /// 같은 마스터 암호로 열 수 있다.
  Future<BackupFile> export({required bool includeCredentials}) async {
    final subscriptions = await _subscriptions.load();
    if (!includeCredentials) {
      return BackupFile(
        exportedAt: DateTime.now(),
        subscriptions: subscriptions,
      );
    }

    final metadata = await _credentials.loadMetadata();
    final stored = await _credentials.load();

    return BackupFile(
      exportedAt: DateTime.now(),
      subscriptions: subscriptions,
      // 금고가 아직 없으면 담을 계정 정보도 없다
      vaultMetadata: metadata,
      credentials: metadata == null ? const [] : stored,
    );
  }

  /// 백업을 현재 데이터에 합친다. **기존 것을 지우지 않는다.**
  /// 같은 id 가 있으면 백업 쪽으로 갱신하고, 없으면 새로 추가한다.
  Future<ImportResult> import(BackupFile backup) async {
    final current = await _subscriptions.load();
    final byId = {for (final s in current) s.id: s};

    var added = 0;
    var replaced = 0;
    for (final incoming in backup.subscriptions) {
      if (byId.containsKey(incoming.id)) {
        replaced++;
      } else {
        added++;
      }
      byId[incoming.id] = incoming;
    }

    await _subscriptions.save(byId.values.toList());

    final credentials = await _importCredentials(backup);

    _ref.invalidate(subscriptionsProvider);
    _ref.invalidate(storedCredentialsProvider);
    _ref.invalidate(vaultProvider);

    return ImportResult(
      added: added,
      replaced: replaced,
      credentialsRestored: credentials.$1,
      credentialsSkippedReason: credentials.$2,
    );
  }

  /// (복원한 개수, 못 한 이유)
  Future<(int, String?)> _importCredentials(BackupFile backup) async {
    if (!backup.includesCredentials) return (0, null);

    final incomingMetadata = backup.vaultMetadata;
    if (incomingMetadata == null) {
      return (0, '백업에 금고 정보가 빠져 있어 계정 정보를 복원하지 못했어요');
    }

    final currentMetadata = await _credentials.loadMetadata();

    // 이 기기에 금고가 없으면 백업의 금고를 그대로 가져온다.
    // 백업을 만든 기기의 마스터 암호로 열게 된다.
    if (currentMetadata == null) {
      await _credentials.saveMetadata(incomingMetadata);
      await _credentials.save(backup.credentials);
      return (backup.credentials.length, null);
    }

    // salt 가 다르면 마스터 암호가 같아도 키가 달라서 복호화되지 않는다.
    // 섞어놓으면 열리지 않는 항목이 생기므로 아예 건너뛴다.
    if (!_sameSalt(currentMetadata.salt, incomingMetadata.salt)) {
      return (
        0,
        '이 기기의 마스터 암호가 백업과 달라서 계정 정보는 가져오지 않았어요. '
            '먼저 설정에서 데이터를 초기화한 뒤 복원하면 함께 가져올 수 있어요',
      );
    }

    final current = await _credentials.load();
    final bySubscription = {for (final c in current) c.subscriptionId: c};
    for (final incoming in backup.credentials) {
      bySubscription[incoming.subscriptionId] = incoming;
    }
    await _credentials.save(bySubscription.values.toList());

    return (backup.credentials.length, null);
  }

  static bool _sameSalt(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

final backupServiceProvider = Provider<BackupService>(BackupService.new);

/// 화면에서 쓰기 편하게 타입을 다시 내보낸다.
typedef BackupSubscription = Subscription;
typedef BackupCredential = StoredCredential;

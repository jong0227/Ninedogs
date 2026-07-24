import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repository/credential_repository.dart';
import '../data/repository/firestore_repositories.dart';
import '../data/repository/subscription_repository.dart';
import '../data/sync/household.dart';
import '../data/sync/sync_service.dart';
import 'app_providers.dart';

final syncServiceProvider = Provider<SyncService>((ref) => SyncService());

/// 연결된 household id. null 이면 이 기기에만 저장한다(기본값).
///
/// 앱을 처음 깔면 항상 null 이다. 사용자가 설정에서 직접 연결해야만 값이
/// 생긴다. 같은 앱을 쓰는 다른 사람과 저절로 묶이는 경로는 없다.
class HouseholdNotifier extends Notifier<String?> {
  static const _key = 'household_id_v1';

  @override
  String? build() => ref.watch(sharedPreferencesProvider).getString(_key);

  Future<void> set(String? id) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (id == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, id);
    }
    state = id;
  }
}

final householdIdProvider = NotifierProvider<HouseholdNotifier, String?>(
  HouseholdNotifier.new,
);

/// 지금 동기화 중인지. 화면에서 상태를 보여줄 때 쓴다.
final syncEnabledProvider = Provider<bool>(
  (ref) => ref.watch(householdIdProvider) != null,
);

/// 연결을 시작하고 끊는 일. 기존 데이터를 옮기는 책임까지 진다.
class SyncCoordinator {
  const SyncCoordinator(this._ref);

  final Ref _ref;

  SyncService get _service => _ref.read(syncServiceProvider);

  /// 새 household 를 만들고 이 기기 데이터를 올린다.
  Future<Household> startSharing() async {
    final household = await _service.createHousehold();
    await _migrateLocalInto(household.id);
    await _ref.read(householdIdProvider.notifier).set(household.id);
    return household;
  }

  /// 초대 코드로 상대의 household 에 들어간다.
  Future<Household> joinSharing(String code) async {
    final household = await _service.joinHousehold(code);
    await _migrateLocalInto(household.id);
    await _ref.read(householdIdProvider.notifier).set(household.id);
    return household;
  }

  /// 연결을 끊는다. 이 기기에는 지금까지 내용을 남겨둔다.
  ///
  /// 끊었더니 목록이 텅 비어 있으면 데이터가 사라진 줄 알고 놀란다.
  Future<void> stopSharing() async {
    final householdId = _ref.read(householdIdProvider);
    if (householdId == null) return;

    final remote = FirestoreSubscriptionRepository(householdId: householdId);
    final remoteCredentials = FirestoreCredentialRepository(
      householdId: householdId,
    );
    final prefs = _ref.read(sharedPreferencesProvider);

    // 서버에서 못 읽더라도 연결은 끊어준다. 갇히면 안 된다.
    try {
      await LocalSubscriptionRepository(prefs).save(await remote.load());

      final metadata = await remoteCredentials.loadMetadata();
      final local = LocalCredentialRepository(prefs);
      if (metadata != null) {
        await local.saveMetadata(metadata);
        await local.save(await remoteCredentials.load());
      }
    } catch (_) {
      // 무시하고 연결만 끊는다
    }

    await _service.leaveHousehold(householdId);
    await _ref.read(householdIdProvider.notifier).set(null);
  }

  /// 이 기기에 있던 것을 household 로 합친다.
  ///
  /// **덮어쓰지 않고 합친다.** 그냥 연결하면 비어 있는 서버 목록이 내려와
  /// 로컬 데이터를 지워버린다. id 가 UUID 라 겹치지 않으므로 양쪽을 더하면
  /// 둘 다 살아남는다.
  Future<void> _migrateLocalInto(String householdId) async {
    final prefs = _ref.read(sharedPreferencesProvider);

    final localSubscriptions = await LocalSubscriptionRepository(prefs).load();
    final remoteSubscriptions = FirestoreSubscriptionRepository(
      householdId: householdId,
    );

    if (localSubscriptions.isNotEmpty) {
      final remote = await remoteSubscriptions.load();
      final merged = {
        for (final subscription in remote) subscription.id: subscription,
      };
      for (final subscription in localSubscriptions) {
        merged.putIfAbsent(subscription.id, () => subscription);
      }
      await remoteSubscriptions.save(merged.values.toList());
    }

    await _migrateVault(householdId, prefs);
  }

  /// 계정 정보는 금고가 같을 때만 합칠 수 있다.
  ///
  /// salt 가 다르면 같은 마스터 암호를 써도 키가 달라 열리지 않는다.
  /// 열 수 없는 항목을 섞어두면 나중에 원인을 찾기 어려우므로 건너뛴다.
  Future<void> _migrateVault(String householdId, prefs) async {
    final local = LocalCredentialRepository(prefs);
    final localMetadata = await local.loadMetadata();
    if (localMetadata == null) return;

    final remote = FirestoreCredentialRepository(householdId: householdId);
    final remoteMetadata = await remote.loadMetadata();

    if (remoteMetadata == null) {
      // 상대가 아직 금고를 만들지 않았으면 내 것을 기준으로 삼는다
      await remote.saveMetadata(localMetadata);
      await remote.save(await local.load());
      return;
    }

    if (!_sameSalt(localMetadata.salt, remoteMetadata.salt)) return;

    final merged = {
      for (final credential in await remote.load())
        credential.subscriptionId: credential,
    };
    for (final credential in await local.load()) {
      merged.putIfAbsent(credential.subscriptionId, () => credential);
    }
    await remote.save(merged.values.toList());
  }

  static bool _sameSalt(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

final syncCoordinatorProvider = Provider<SyncCoordinator>(SyncCoordinator.new);

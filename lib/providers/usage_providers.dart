import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/catalog/service_catalog.dart';
import '../data/models/subscription.dart';
import '../data/usage/usage_service.dart';
import 'app_providers.dart';
import 'subscription_providers.dart';

final usageServiceProvider = Provider<UsageService>((ref) => const UsageService());

/// '안 쓰는 구독 찾기'를 켰는지. 기본은 꺼짐.
///
/// 권한이 있어도 이 스위치를 켜지 않았으면 사용 기록을 읽지 않는다.
/// 권한과 기능을 나눠둬야 "권한은 줬지만 지금은 보고 싶지 않다"가 가능하다.
class UsageTrackingNotifier extends Notifier<bool> {
  static const _key = 'usage_tracking_v1';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? false;

  Future<void> set(bool enabled) async {
    await ref.read(sharedPreferencesProvider).setBool(_key, enabled);
    state = enabled;
  }
}

final usageTrackingProvider =
    NotifierProvider<UsageTrackingNotifier, bool>(UsageTrackingNotifier.new);

/// 사용 정보 접근 권한이 켜져 있는지.
final usagePermissionProvider = FutureProvider<bool>(
  (ref) => ref.watch(usageServiceProvider).hasPermission(),
);

/// 구독별 마지막 사용 시각. 기록이 없는 구독은 아예 담기지 않는다.
///
/// 기능을 껐거나 권한이 없으면 빈 값이다.
final lastUsedProvider = FutureProvider<Map<String, DateTime>>((ref) async {
  if (!ref.watch(usageTrackingProvider)) return const {};

  final subscriptions = ref.watch(activeSubscriptionsProvider);

  // 구독 id -> 패키지명. 패키지를 모르는 서비스는 처음부터 빼고 묻는다.
  final packageBySubscription = <String, String>{};
  for (final subscription in subscriptions) {
    final package = ServiceCatalog.packageOf(subscription.serviceId);
    if (package != null) packageBySubscription[subscription.id] = package;
  }
  if (packageBySubscription.isEmpty) return const {};

  final usage = await ref
      .watch(usageServiceProvider)
      .lastUsed(packageBySubscription.values.toSet().toList());

  return {
    for (final entry in packageBySubscription.entries)
      if (usage[entry.value] != null) entry.key: usage[entry.value]!,
  };
});

/// 한동안 안 연 구독. 오래 안 쓴 것부터.
///
/// **기록이 있는데 오래된 경우만** 담는다. 기록 자체가 없으면 TV·PC 로만
/// 보는 것일 수 있어 판단하지 않는다.
final unusedSubscriptionsProvider = Provider<List<({Subscription subscription, int days})>>((
  ref,
) {
  final lastUsed = ref.watch(lastUsedProvider).value ?? const {};
  if (lastUsed.isEmpty) return const [];

  final now = DateTime.now();
  final result = <({Subscription subscription, int days})>[];

  for (final subscription in ref.watch(activeSubscriptionsProvider)) {
    final used = lastUsed[subscription.id];
    if (used == null) continue;

    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(used.year, used.month, used.day))
        .inDays;
    if (days < _staleDays) continue;

    result.add((subscription: subscription, days: days));
  }

  result.sort((a, b) => b.days.compareTo(a.days));
  return result;
});

/// 이만큼 안 열었으면 한 번 짚어줄 만하다.
const _staleDays = 30;

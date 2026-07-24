import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notifications/notification_service.dart';
import 'app_providers.dart';

/// 전체 기본 알림 시점. 구독별로 따로 정하지 않았으면 이 값을 쓴다.
///
/// 빈 목록이면 알림을 아예 끈 것이다. 한 번도 정한 적이 없는 상태와
/// 구분해야 해서, 저장된 값이 없을 때만 기본값을 돌려준다.
class ReminderDaysNotifier extends Notifier<List<int>> {
  static const _key = 'reminder_days_v1';

  @override
  List<int> build() {
    final saved = ref.watch(sharedPreferencesProvider).getStringList(_key);
    if (saved == null) return ReminderOptions.defaults;

    return _normalize(saved.map(int.parse));
  }

  Future<void> set(Iterable<int> days) async {
    final next = _normalize(days);
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(_key, next.map((d) => '$d').toList());
    state = next;
  }

  Future<void> toggle(int day) {
    final next = state.contains(day)
        ? state.where((d) => d != day)
        : [...state, day];
    return set(next);
  }

  /// 고를 수 있는 값만 남기고 먼 것부터 정렬한다.
  static List<int> _normalize(Iterable<int> days) {
    final kept = days.where(ReminderOptions.choices.contains).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    return kept;
  }
}

final reminderDaysProvider = NotifierProvider<ReminderDaysNotifier, List<int>>(
  ReminderDaysNotifier.new,
);

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/diagnostics.dart';
import '../models/subscription.dart';

/// 바뀌기 직전의 구독 목록 한 벌.
class SubscriptionSnapshot {
  const SubscriptionSnapshot({
    required this.savedAt,
    required this.subscriptions,
  });

  final DateTime savedAt;
  final List<Subscription> subscriptions;

  int get count => subscriptions.length;

  Map<String, Object?> toJson() => {
    'savedAt': savedAt.toIso8601String(),
    'subscriptions': subscriptions.map((s) => s.toJson()).toList(),
  };

  factory SubscriptionSnapshot.fromJson(Map<String, Object?> json) =>
      SubscriptionSnapshot(
        savedAt: DateTime.parse(json['savedAt'] as String),
        subscriptions: (json['subscriptions'] as List)
            .map((e) => Subscription.fromJson(e as Map<String, Object?>))
            .toList(),
      );
}

/// 구독 목록을 바꾸기 직전 상태로 되돌릴 수 있게 몇 벌 남겨둔다.
///
/// 이 앱의 데이터는 손으로 넣은 것이라 날아가면 재입력 말고는 방법이 없다.
/// 실제로 편집 화면 버그로 구독 이력이 통째로 사라진 적이 있는데, 저장소가
/// 키 하나를 덮어쓰는 구조라 **복구 경로가 아예 없었다.**
///
/// 코드 버그는 고쳤지만 사용자 실수(잘못 지움, 잘못 초기화)는 여전히 남는다.
/// 그래서 쓰기 직전마다 이전 상태를 남겨둔다.
class SnapshotStore {
  const SnapshotStore();

  static const _key = 'subscription_snapshots_v1';

  /// 남겨둘 개수. 많이 쌓아둘수록 되돌릴 여지는 넓지만 저장 용량과 쓰기
  /// 시간이 함께 늘어난다. 최근 몇 번이면 실수를 되짚기에 충분하다.
  static const maxSnapshots = 5;

  /// 직전 스냅샷이 이보다 최근이면 새로 남기지 않는다.
  ///
  /// 스위치 하나 켤 때마다 목록 전체를 다시 쓰면 느리고, 되돌릴 지점이
  /// 의미 없이 잘게 쪼개진다. 몰아서 고친 편집은 한 지점으로 묶는 게
  /// 되돌릴 때도 자연스럽다.
  static const minGap = Duration(minutes: 1);

  Future<List<SubscriptionSnapshot>> load(SharedPreferences prefs) async {
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map((e) => SubscriptionSnapshot.fromJson(e as Map<String, Object?>))
          .toList();
    } catch (error) {
      // 형식이 깨졌으면 없는 셈 친다. 지우지는 않는다 — 손으로 꺼내볼
      // 여지는 남겨둔다.
      logIgnored('스냅샷을 읽지 못했다', error);
      return const [];
    }
  }

  /// [before] 를 되돌릴 지점으로 남긴다. 실제로 남겼으면 true.
  ///
  /// 저장에 실패해도 예외를 던지지 않는다. 스냅샷은 곁다리라, 이것 때문에
  /// 정작 사용자의 편집이 막히면 안 된다.
  Future<bool> push(
    SharedPreferences prefs,
    List<Subscription> before, {
    DateTime? now,
  }) async {
    // 아무것도 없는 상태는 되돌릴 가치가 없다. 첫 구독을 넣기 전 상태로
    // 돌아가는 건 '전부 지우기'와 같다.
    if (before.isEmpty) return false;

    final at = now ?? DateTime.now();
    final existing = await load(prefs);

    if (existing.isNotEmpty &&
        at.difference(existing.first.savedAt).abs() < minGap) {
      return false;
    }

    final next = [
      SubscriptionSnapshot(savedAt: at, subscriptions: before),
      ...existing,
    ].take(maxSnapshots).toList();

    try {
      await prefs.setString(
        _key,
        jsonEncode(next.map((s) => s.toJson()).toList()),
      );
      return true;
    } catch (error) {
      logIgnored('스냅샷을 남기지 못했다', error);
      return false;
    }
  }

  /// 되돌린 뒤에는 그 지점을 목록에서 뺀다. 같은 곳으로 계속 되돌아가면
  /// 그 앞의 기록에 닿을 수 없다.
  Future<List<SubscriptionSnapshot>> drop(
    SharedPreferences prefs,
    DateTime savedAt,
  ) async {
    final next = (await load(
      prefs,
    )).where((s) => s.savedAt != savedAt).toList();

    await prefs.setString(
      _key,
      jsonEncode(next.map((s) => s.toJson()).toList()),
    );
    return next;
  }

  Future<void> clear(SharedPreferences prefs) => prefs.remove(_key);
}

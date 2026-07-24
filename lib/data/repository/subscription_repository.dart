import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/subscription.dart';

/// 구독 목록 저장소.
///
/// 지금은 기기 안에만 저장한다. 나중에 Firestore 구현으로 갈아끼울 수 있게
/// 인터페이스로 분리해 둔다. (부부 계정 공유 = 같은 인터페이스의 다른 구현)
abstract interface class SubscriptionRepository {
  Future<List<Subscription>> load();
  Future<void> save(List<Subscription> subscriptions);
}

class LocalSubscriptionRepository implements SubscriptionRepository {
  LocalSubscriptionRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'subscriptions_v1';

  @override
  Future<List<Subscription>> load() async {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map((e) => Subscription.fromJson(e as Map<String, Object?>))
          .toList();
    } on FormatException {
      // 저장 형식이 깨졌으면 빈 목록으로 시작한다. 덮어쓰지는 않는다.
      return [];
    }
  }

  @override
  Future<void> save(List<Subscription> subscriptions) async {
    final raw = jsonEncode(subscriptions.map((s) => s.toJson()).toList());
    await _prefs.setString(_key, raw);
  }
}

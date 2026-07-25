import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 달러로 등록한 구독을 원화로 환산해 보여줄 때 쓰는 환율(USD -> KRW).
///
/// 통계·합계는 통화가 하나로 통일돼 있어야 의미가 있다. 실시간 정확도보다
/// "항상 어떤 값이든 있는 것"이 중요하다 — 구독료 통계는 참고용이라 환율이
/// 몇 시간 묵어도 문제없지만, 아예 없으면 달러 구독이 통계에서 통째로
/// 빠지게 된다. 그래서 실패해도 마지막으로 받아둔 값, 그마저 없으면
/// 대략값으로 대체해서 **null을 돌려주지 않는다.**
class ExchangeRateService {
  ExchangeRateService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _rateKey = 'usd_krw_rate_v1';
  static const _fetchedAtKey = 'usd_krw_rate_fetched_at_v1';
  static const _maxAge = Duration(hours: 12);

  /// 인터넷이 한 번도 연결되지 않았을 때 쓰는 대략값.
  /// 실제 환율과 다를 수 있다 — 0으로 두는 것보다 나은 최후의 수단이다.
  static const fallbackRate = 1450.0;

  static const _endpoint = 'https://open.er-api.com/v6/latest/USD';

  /// 지금 쓸 환율. 캐시가 [_maxAge] 이내면 그대로 쓰고, 오래됐거나 없으면
  /// 새로 받아본다. 새로 받기 실패하면 오래된 캐시라도 쓰고, 캐시조차
  /// 없으면 [fallbackRate].
  Future<double> rate(SharedPreferences prefs) async {
    final cached = prefs.getDouble(_rateKey);
    final fetchedAt = prefs.getInt(_fetchedAtKey);
    final isFresh =
        fetchedAt != null &&
        DateTime.now()
                .difference(DateTime.fromMillisecondsSinceEpoch(fetchedAt))
                .abs() <
            _maxAge;

    if (isFresh && cached != null) return cached;

    final fetched = await _fetch();
    if (fetched != null) {
      await prefs.setDouble(_rateKey, fetched);
      await prefs.setInt(_fetchedAtKey, DateTime.now().millisecondsSinceEpoch);
      return fetched;
    }

    return cached ?? fallbackRate;
  }

  Future<double?> _fetch() async {
    try {
      final response = await _client
          .get(Uri.parse(_endpoint))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, Object?>;
      final rates = json['rates'] as Map<String, Object?>?;
      final krw = rates?['KRW'];
      return krw is num ? krw.toDouble() : null;
    } catch (_) {
      return null;
    }
  }
}

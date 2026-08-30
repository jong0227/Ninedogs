import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/diagnostics.dart';
import '../models/money.dart';

/// 날짜별 USD→KRW 환율 표.
///
/// 누적 지출은 "그때 그 환율로" 계산해야 맞다. 2024년에 낸 $9.99 를 오늘
/// 환율로 환산하면 실제로 빠져나간 원화와 다르다. 환율이 1,300원에서
/// 1,450원으로 움직인 구간이 있으면 몇 년치가 통째로 어긋난다.
class RateTable {
  RateTable(Map<String, double> byDate, {this.fallback = _defaultFallback})
    : _byDate = byDate,
      _sortedDates = byDate.keys.toList()..sort();

  /// 'yyyy-MM-dd' → 1달러당 원화
  final Map<String, double> _byDate;

  /// 이분 탐색으로 "그 날 이전의 가장 가까운 고시일"을 찾기 위한 정렬 키.
  final List<String> _sortedDates;

  /// 표가 비었을 때 쓰는 최후의 값.
  final double fallback;

  static const _defaultFallback = 1450.0;

  bool get isEmpty => _byDate.isEmpty;
  int get length => _byDate.length;

  /// 가장 오래된 고시일. 표가 비었으면 null.
  DateTime? get earliest =>
      _sortedDates.isEmpty ? null : DateTime.parse(_sortedDates.first);

  /// 가장 최근 고시일. 표가 비었으면 null.
  DateTime? get latest =>
      _sortedDates.isEmpty ? null : DateTime.parse(_sortedDates.last);

  /// [date] 에 적용할 환율.
  ///
  /// ECB 는 주말·공휴일에 환율을 고시하지 않는다. 그래서 그 날짜 **이전의
  /// 가장 가까운 고시일** 값을 쓴다 — 토요일에 결제됐으면 금요일 환율이다.
  /// 표에 있는 어떤 날짜보다도 이르면 가장 오래된 값으로, 표가 아예 비어
  /// 있으면 [fallback] 으로 대신한다.
  double rateOn(DateTime date) {
    if (_sortedDates.isEmpty) return fallback;

    final key = formatKey(date);

    // 이분 탐색: key 보다 크지 않은 마지막 항목을 찾는다.
    var low = 0;
    var high = _sortedDates.length - 1;
    var found = -1;
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if (_sortedDates[mid].compareTo(key) <= 0) {
        found = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    // 표보다 이른 날짜면 가장 오래된 값을 쓴다. 그 시절 환율을 모르는 건
    // 맞지만, 0 으로 두거나 빼버리는 것보다는 낫다.
    final index = found >= 0 ? found : 0;
    return _byDate[_sortedDates[index]] ?? fallback;
  }

  /// [amount] 를 [date] 시점 환율로 원화 환산한다. 이미 원화면 그대로.
  Money toKrwOn(Money amount, DateTime date) {
    if (amount.currency == Money.krw) return amount;
    if (amount.currency != 'USD') return amount;
    return Money((amount.major * rateOn(date)).round(), currency: Money.krw);
  }

  static String formatKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Map<String, double> toMap() => Map.unmodifiable(_byDate);
}

/// 과거 USD→KRW 환율을 받아 캐시해 두는 곳.
///
/// 유럽중앙은행(ECB) 고시 환율을 쓰는 frankfurter.dev 를 호출한다. 인증키가
/// 필요 없고, 휴장일을 물으면 직전 영업일 값을 돌려준다.
///
/// 지난 날짜의 환율은 다시 바뀌지 않으므로 한 번 받아두면 계속 쓴다. 새로
/// 받아야 하는 건 마지막으로 받은 날 이후의 꼬리 부분뿐이다.
class ExchangeRateHistoryService {
  ExchangeRateHistoryService({http.Client? client, Random? random})
    : _client = client ?? http.Client(),
      _random = random ?? Random();

  final http.Client _client;
  final Random _random;

  static const _historyKey = 'usd_krw_history_v1';
  static const _syncedAtKey = 'usd_krw_history_synced_at_v1';

  static const _host = 'api.frankfurter.dev';

  /// ECB 가 환율을 고시하기 시작한 해. 이보다 이르게 요청해봐야 소용없다.
  static final _ecbEpoch = DateTime(1999);

  /// 최신 구간을 다시 받아볼 간격의 하한·상한.
  ///
  /// 정확히 12시간처럼 고정하지 않고 매번 이 사이에서 무작위로 고른다.
  /// 초 단위까지 일정한 주기는 자동화 패턴이 그대로 드러나서 상대 서버의
  /// 봇 탐지나 레이트리밋에 걸리기 쉽다.
  static const _minRefresh = Duration(hours: 11);
  static const _maxRefresh = Duration(hours: 13);

  /// 이번 회차에 쓸 새로고침 간격. 매번 다시 뽑는다.
  Duration nextRefreshGap() {
    final spread = _maxRefresh.inMinutes - _minRefresh.inMinutes;
    return Duration(
      minutes: _minRefresh.inMinutes + _random.nextInt(spread + 1),
    );
  }

  /// [earliest] 부터 오늘까지를 덮는 환율 표.
  ///
  /// 캐시가 그 범위를 이미 덮고 있고 꼬리도 최근이면 네트워크를 타지 않는다.
  /// 받아오기에 실패해도 예외를 던지지 않는다 — 있는 캐시로, 그마저 없으면
  /// 빈 표(=fallback)로 돌려준다. 환율 때문에 화면이 비면 안 된다.
  Future<RateTable> load(
    SharedPreferences prefs, {
    required DateTime earliest,
  }) async {
    final cached = _readCache(prefs);
    final from = _clampToEcbEpoch(earliest);
    final today = DateTime.now();

    final missingStart =
        cached.earliest == null || from.isBefore(cached.earliest!);
    final syncedAt = prefs.getInt(_syncedAtKey);
    final staleTail =
        syncedAt == null ||
        DateTime.now()
                .difference(DateTime.fromMillisecondsSinceEpoch(syncedAt))
                .abs() >
            nextRefreshGap();

    if (!missingStart && !staleTail) return cached;

    // 앞이 비면 처음부터, 꼬리만 낡았으면 마지막 고시일부터 다시 받는다.
    final fetchFrom = missingStart ? from : (cached.latest ?? from);
    final fetched = await _fetchRange(fetchFrom, today);
    if (fetched == null) return cached;

    final merged = {...cached.toMap(), ...fetched};
    await prefs.setString(_historyKey, jsonEncode(merged));
    await prefs.setInt(_syncedAtKey, DateTime.now().millisecondsSinceEpoch);
    return RateTable(merged);
  }

  RateTable _readCache(SharedPreferences prefs) {
    final raw = prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) return RateTable(const {});

    try {
      final decoded = jsonDecode(raw) as Map<String, Object?>;
      return RateTable({
        for (final entry in decoded.entries)
          if (entry.value is num) entry.key: (entry.value as num).toDouble(),
      });
    } on FormatException {
      // 저장 형식이 깨졌으면 빈 표로 시작한다. 지우지는 않는다.
      return RateTable(const {});
    }
  }

  static DateTime _clampToEcbEpoch(DateTime date) =>
      date.isBefore(_ecbEpoch) ? _ecbEpoch : date;

  Future<Map<String, double>?> _fetchRange(DateTime from, DateTime to) async {
    final uri = Uri.https(
      _host,
      '/v1/${RateTable.formatKey(from)}..${RateTable.formatKey(to)}',
      {'base': 'USD', 'symbols': 'KRW'},
    );

    try {
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, Object?>;
      final rates = json['rates'] as Map<String, Object?>?;
      if (rates == null) return null;

      return {
        for (final entry in rates.entries)
          if ((entry.value as Map<String, Object?>?)?['KRW'] case final num v)
            entry.key: v.toDouble(),
      };
    } catch (error) {
      logIgnored('과거 환율을 받지 못했다', error);
      return null;
    }
  }
}

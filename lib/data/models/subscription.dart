import 'billing_cycle.dart';
import 'money.dart';

/// 특정 시점부터 적용된 구독료. 가격이 오르면 새 항목을 덧붙인다.
class PricePoint {
  const PricePoint({required this.effectiveFrom, required this.amount});

  final DateTime effectiveFrom;
  final Money amount;

  Map<String, Object?> toJson() => {
    'effectiveFrom': effectiveFrom.toIso8601String(),
    'amount': amount.toJson(),
  };

  factory PricePoint.fromJson(Map<String, Object?> json) => PricePoint(
    effectiveFrom: DateTime.parse(json['effectiveFrom'] as String),
    amount: Money.fromJson(json['amount'] as Map<String, Object?>),
  );
}

/// 구독했다가 끊은 한 구간.
///
/// 볼 게 있을 때만 켜고 끄는 서비스가 흔하다. 그런 이력을 한 줄로 뭉개면
/// "언제부터 언제까지 봤는지"도, 그 사이 안 낸 돈도 알 수 없다.
class SubscriptionPeriod {
  const SubscriptionPeriod({required this.startedAt, required this.endedAt});

  final DateTime startedAt;

  /// 이 구간을 끊은 날.
  final DateTime endedAt;

  Map<String, Object?> toJson() => {
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
  };

  factory SubscriptionPeriod.fromJson(Map<String, Object?> json) =>
      SubscriptionPeriod(
        startedAt: DateTime.parse(json['startedAt'] as String),
        endedAt: DateTime.parse(json['endedAt'] as String),
      );
}

class Subscription {
  Subscription({
    required this.id,
    required this.name,
    required this.cycle,
    required this.startedAt,
    required List<PricePoint> priceHistory,
    this.serviceId,
    this.iconUrl,
    this.brandColorValue,
    this.billingAnchor,
    this.canceledAt,
    this.accessEndsAt,
    this.trialEndsAt,
    this.paymentMethod,
    this.credentialId,
    this.memo,
    this.reminderDaysBefore,
    List<SubscriptionPeriod> pastPeriods = const [],
  }) : assert(priceHistory.isNotEmpty, '구독은 최소 한 개의 가격 정보가 필요합니다'),
       priceHistory = List.unmodifiable(
         [...priceHistory]
           ..sort((a, b) => a.effectiveFrom.compareTo(b.effectiveFrom)),
       ),
       pastPeriods = List.unmodifiable(
         [...pastPeriods]..sort((a, b) => a.startedAt.compareTo(b.startedAt)),
       );

  final String id;

  /// 카탈로그 서비스 키. 직접 입력한 구독이면 null.
  final String? serviceId;
  final String name;
  final String? iconUrl;

  /// 아이콘을 못 불러왔을 때 쓰는 대체 타일 색.
  final int? brandColorValue;

  final BillingCycle cycle;

  /// 시간순으로 정렬된 가격 이력. 최소 1개.
  final List<PricePoint> priceHistory;

  /// **지금 구간**을 시작한 날. 끊었다가 다시 구독했다면 마지막으로 다시
  /// 시작한 날이다. 맨 처음 구독한 날은 [firstStartedAt].
  final DateTime startedAt;

  /// 지금 구간 이전에 구독했다 끊은 구간들. 오래된 것부터.
  ///
  /// 여기 담긴 기간에도 결제가 있었으므로 누적 지출에 함께 센다. 그 기간의
  /// 금액은 [priceHistory] 의 시점별 가격에서 가져온다 — 구간마다 값을 따로
  /// 들고 있지 않아도 "그때는 얼마였다"가 그대로 반영된다.
  final List<SubscriptionPeriod> pastPeriods;

  /// 실제 카드 결제일 기준. 시작일과 청구일이 다를 때만 채운다.
  final DateTime? billingAnchor;

  /// 해지한 날. null 이면 구독 중.
  final DateTime? canceledAt;

  /// 해지 후에도 이용 가능한 마지막 날.
  final DateTime? accessEndsAt;

  /// 무료 체험이 끝나는 날. 곧 **첫 결제일**이다.
  ///
  /// 체험 기간에는 돈이 나가지 않으므로 이 날짜가 청구 기준일이 된다
  /// ([_anchor] 참고). 무료 체험 없이 바로 결제하면 null.
  final DateTime? trialEndsAt;

  /// 결제 수단 메모. 예: "신한카드 1234"
  final String? paymentMethod;

  /// 암호화 보관된 계정 정보 참조. 평문은 여기 담지 않는다.
  final String? credentialId;

  final String? memo;

  /// 결제 며칠 전에 알림을 받을지. 예: [7, 1]
  ///
  /// null 이면 전체 설정을 따른다. 빈 목록이면 이 구독만 알림을 끈 것이다.
  /// 이 둘을 구분해야 "전체는 켜져 있지만 이건 끔"이 가능하다.
  final List<int>? reminderDaysBefore;

  String get currency => priceHistory.last.amount.currency;

  /// 전체 설정을 감안한 실제 알림 시점.
  List<int> effectiveReminderDays(List<int> fallback) =>
      reminderDaysBefore ?? fallback;

  bool get isActive => canceledAt == null;

  /// 청구 주기의 기준일.
  ///
  /// 무료 체험이 있으면 체험이 끝나는 날이 첫 결제일이다. 시작일을 기준으로
  /// 삼으면 체험 기간에도 돈이 나간 것으로 계산돼 누적 지출이 부풀려진다.
  /// 사용자가 실제 결제일을 직접 지정했다면 그게 가장 정확하므로 먼저 본다.
  DateTime get _anchor => billingAnchor ?? trialEndsAt ?? startedAt;

  /// 아직 무료 체험 중인지.
  bool get isInTrial {
    final end = trialEndsAt;
    if (end == null || !isActive) return false;
    return !_dateOnly(DateTime.now()).isAfter(_dateOnly(end));
  }

  /// 무료 체험이 끝나기까지 남은 일수. 체험 중이 아니면 null.
  int? get daysUntilTrialEnds {
    final end = trialEndsAt;
    if (end == null || !isInTrial) return null;
    return _dateOnly(end).difference(_dateOnly(DateTime.now())).inDays;
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// 현재 구독료.
  Money get currentPrice => priceAt(DateTime.now());

  /// [date] 시점에 적용되던 구독료.
  Money priceAt(DateTime date) {
    var result = priceHistory.first;
    for (final point in priceHistory) {
      if (point.effectiveFrom.isAfter(date)) break;
      result = point;
    }
    return result.amount;
  }

  /// 월 환산 구독료. 서로 다른 주기의 구독을 나란히 비교할 때 쓴다.
  Money get monthlyCost => cycle.monthlyEquivalent(currentPrice);

  /// 가격이 바뀐 지점만. (첫 등록 가격은 변동이 아니므로 제외)
  List<PricePoint> get priceChanges => priceHistory.skip(1).toList();

  /// 맨 처음 구독을 시작한 날. 끊었다 다시 시작했어도 가장 이른 날이다.
  DateTime get firstStartedAt =>
      pastPeriods.isEmpty ? startedAt : pastPeriods.first.startedAt;

  /// 지금까지의 모든 구독 구간. 오래된 것부터, 마지막이 지금 구간이다.
  /// 지금 구간의 [SubscriptionPeriod.endedAt] 은 아직 구독 중이면 null 이 될
  /// 수 없으므로, 진행 중인 구간은 [currentPeriodEnd] 로 따로 본다.
  List<({DateTime startedAt, DateTime? endedAt})> get allPeriods => [
    for (final period in pastPeriods)
      (startedAt: period.startedAt, endedAt: period.endedAt),
    (startedAt: startedAt, endedAt: canceledAt),
  ];

  /// 몇 번 구독했다 끊었는지. 지금 구간까지 센다.
  int get periodCount => pastPeriods.length + 1;

  DateTime? get currentPeriodEnd => canceledAt;

  /// 결제가 실제로 일어난 날들. [asOf] 까지 포함한다.
  ///
  /// 끊었다 다시 구독한 구간이 있으면 각 구간마다 따로 센다. 안 쓰던 기간에
  /// 결제가 이어진 것으로 잡히면 누적 지출이 실제보다 커진다.
  List<DateTime> billingDatesUntil(DateTime asOf) {
    final dates = <DateTime>[];

    for (final period in pastPeriods) {
      dates.addAll(
        _datesFrom(period.startedAt, _earliest(asOf, period.endedAt)),
      );
    }
    // 지금 구간만 카드 결제일·무료 체험 기준(_anchor)을 따른다.
    dates.addAll(_datesFrom(_anchor, _earliest(asOf, canceledAt)));

    return dates;
  }

  /// [from] 부터 [until] 까지 주기대로 짚은 날들.
  /// 잘못된 데이터로 무한 루프에 빠지지 않도록 상한을 둔다.
  List<DateTime> _datesFrom(DateTime from, DateTime until) {
    final dates = <DateTime>[];
    var date = from;
    const maxCharges = 2000;
    while (!date.isAfter(until) && dates.length < maxCharges) {
      dates.add(date);
      date = cycle.next(date);
    }
    return dates;
  }

  /// [start] 부터 [end] 까지(양 끝 포함) 사이에 걸린 결제일들.
  /// 캘린더에서 한 달치를 그릴 때 쓴다.
  ///
  /// 끊었다 다시 구독한 구간이 있으면 각 구간을 따로 훑는다. 지난 달을
  /// 넘겨볼 때 그때 실제로 구독 중이었는지가 그대로 드러난다.
  List<DateTime> billingDatesBetween(DateTime start, DateTime end) {
    final dates = <DateTime>[];

    for (final period in pastPeriods) {
      dates.addAll(
        _datesBetween(period.startedAt, period.endedAt, start, end),
      );
    }
    dates.addAll(_datesBetween(_anchor, canceledAt, start, end));

    dates.sort();
    return dates;
  }

  /// 한 구간([from] ~ [periodEnd])의 결제일 중 [start]~[end] 에 걸린 것들.
  List<DateTime> _datesBetween(
    DateTime from,
    DateTime? periodEnd,
    DateTime start,
    DateTime end,
  ) {
    final dates = <DateTime>[];
    var date = from;
    var guard = 0;
    const maxSteps = 4000;

    // 구간 앞쪽은 건너뛴다
    while (date.isBefore(start) && guard++ < maxSteps) {
      date = cycle.next(date);
    }

    while (!date.isAfter(end) && guard++ < maxSteps) {
      // 끊은 뒤로는 청구되지 않는다
      if (periodEnd != null && date.isAfter(periodEnd)) break;
      dates.add(date);
      date = cycle.next(date);
    }

    return dates;
  }

  /// 이 구독에 지금까지 쓴 누적 금액. 가격 변동 이력을 반영한다.
  Money totalSpentUntil(DateTime asOf) {
    var total = Money.zero(currency);
    for (final date in billingDatesUntil(asOf)) {
      total += priceAt(date);
    }
    return total;
  }

  Money get totalSpent => totalSpentUntil(DateTime.now());

  /// 다음 결제 예정일. 해지했으면 null.
  DateTime? nextBillingDate([DateTime? from]) {
    if (!isActive) return null;
    final now = from ?? DateTime.now();
    var date = _anchor;
    var guard = 0;
    while (!date.isAfter(now) && guard++ < 2000) {
      date = cycle.next(date);
    }
    return date;
  }

  /// 다음 결제까지 남은 일수. 해지했으면 null.
  int? get daysUntilNextBilling {
    final next = nextBillingDate();
    if (next == null) return null;
    final now = DateTime.now();
    return DateTime(
      next.year,
      next.month,
      next.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  /// 이용 권한이 남은 마지막 날. 해지했으면 [accessEndsAt],
  /// 구독 중이면 다음 결제일 전날.
  DateTime? get accessValidUntil {
    if (!isActive) return accessEndsAt;
    final next = nextBillingDate();
    return next?.subtract(const Duration(days: 1));
  }

  static DateTime _earliest(DateTime a, DateTime? b) =>
      b == null || a.isBefore(b) ? a : b;

  Subscription copyWith({
    String? name,
    String? iconUrl,
    int? brandColorValue,
    BillingCycle? cycle,
    List<PricePoint>? priceHistory,
    DateTime? startedAt,
    DateTime? billingAnchor,
    DateTime? canceledAt,
    DateTime? accessEndsAt,
    DateTime? trialEndsAt,
    String? paymentMethod,
    String? credentialId,
    String? memo,
    List<int>? reminderDaysBefore,
    List<SubscriptionPeriod>? pastPeriods,
    bool clearCanceledAt = false,

    /// 무료 체험 정보를 지운다. (체험이 끝났거나 잘못 넣은 경우)
    bool clearTrial = false,

    /// 이 구독만의 알림 설정을 지우고 전체 설정을 따르게 한다.
    bool clearReminders = false,
  }) {
    return Subscription(
      id: id,
      serviceId: serviceId,
      name: name ?? this.name,
      iconUrl: iconUrl ?? this.iconUrl,
      brandColorValue: brandColorValue ?? this.brandColorValue,
      cycle: cycle ?? this.cycle,
      priceHistory: priceHistory ?? this.priceHistory,
      startedAt: startedAt ?? this.startedAt,
      billingAnchor: billingAnchor ?? this.billingAnchor,
      canceledAt: clearCanceledAt ? null : (canceledAt ?? this.canceledAt),
      accessEndsAt: accessEndsAt ?? this.accessEndsAt,
      trialEndsAt: clearTrial ? null : (trialEndsAt ?? this.trialEndsAt),
      paymentMethod: paymentMethod ?? this.paymentMethod,
      credentialId: credentialId ?? this.credentialId,
      memo: memo ?? this.memo,
      reminderDaysBefore: clearReminders
          ? null
          : (reminderDaysBefore ?? this.reminderDaysBefore),
      pastPeriods: pastPeriods ?? this.pastPeriods,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'serviceId': serviceId,
    'name': name,
    'iconUrl': iconUrl,
    'brandColorValue': brandColorValue,
    'cycle': cycle.name,
    'priceHistory': priceHistory.map((p) => p.toJson()).toList(),
    'startedAt': startedAt.toIso8601String(),
    'billingAnchor': billingAnchor?.toIso8601String(),
    'canceledAt': canceledAt?.toIso8601String(),
    'accessEndsAt': accessEndsAt?.toIso8601String(),
    'trialEndsAt': trialEndsAt?.toIso8601String(),
    'paymentMethod': paymentMethod,
    'credentialId': credentialId,
    'memo': memo,
    'reminderDaysBefore': reminderDaysBefore,
    'pastPeriods': pastPeriods.map((p) => p.toJson()).toList(),
  };

  factory Subscription.fromJson(Map<String, Object?> json) => Subscription(
    id: json['id'] as String,
    serviceId: json['serviceId'] as String?,
    name: json['name'] as String,
    iconUrl: json['iconUrl'] as String?,
    brandColorValue: (json['brandColorValue'] as num?)?.toInt(),
    cycle: BillingCycle.values.byName(json['cycle'] as String),
    priceHistory: (json['priceHistory'] as List)
        .map((e) => PricePoint.fromJson(e as Map<String, Object?>))
        .toList(),
    startedAt: DateTime.parse(json['startedAt'] as String),
    billingAnchor: _parseOrNull(json['billingAnchor']),
    canceledAt: _parseOrNull(json['canceledAt']),
    accessEndsAt: _parseOrNull(json['accessEndsAt']),
    trialEndsAt: _parseOrNull(json['trialEndsAt']),
    paymentMethod: json['paymentMethod'] as String?,
    credentialId: json['credentialId'] as String?,
    memo: json['memo'] as String?,
    reminderDaysBefore: (json['reminderDaysBefore'] as List?)
        ?.map((e) => (e as num).toInt())
        .toList(),
    // 이 필드가 생기기 전에 저장된 데이터에는 없다. 없으면 구간이 하나뿐인
    // 구독으로 읽혀서 예전과 똑같이 동작한다.
    pastPeriods:
        (json['pastPeriods'] as List?)
            ?.map((e) => SubscriptionPeriod.fromJson(e as Map<String, Object?>))
            .toList() ??
        const [],
  );

  static DateTime? _parseOrNull(Object? value) =>
      value == null ? null : DateTime.parse(value as String);
}

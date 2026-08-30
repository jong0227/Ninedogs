import 'package:flutter_test/flutter_test.dart';
import 'package:ninedogs/data/backup/snapshot_store.dart';
import 'package:ninedogs/data/models/billing_cycle.dart';
import 'package:ninedogs/data/models/money.dart';
import 'package:ninedogs/data/models/subscription.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 되돌릴 지점을 남겨두는 곳.
///
/// 편집 화면 버그로 구독 이력이 통째로 날아갔을 때 복구 경로가 아예 없었다.
/// 코드 버그는 고쳤지만 잘못 지우거나 잘못 초기화하는 실수는 여전히 남는다.
void main() {
  const store = SnapshotStore();
  late SharedPreferences prefs;

  Subscription sub(String id) => Subscription.create(
    id: id,
    name: id,
    cycle: BillingCycle.monthly,
    startedAt: DateTime(2026, 1, 1),
    priceHistory: [
      PricePoint(
        effectiveFrom: DateTime(2026, 1, 1),
        amount: const Money(10000),
        cycle: BillingCycle.monthly,
      ),
    ],
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('되돌릴 지점 남기기', () {
    test('처음에는 아무것도 없다', () async {
      expect(await store.load(prefs), isEmpty);
    });

    test('남긴 목록을 그대로 읽어온다', () async {
      await store.push(prefs, [sub('netflix'), sub('spotify')]);

      final saved = await store.load(prefs);
      expect(saved, hasLength(1));
      expect(saved.single.count, 2);
      expect(
        saved.single.subscriptions.map((s) => s.id),
        ['netflix', 'spotify'],
      );
    });

    test('최근 것이 앞에 온다', () async {
      final base = DateTime(2026, 3, 1, 12);
      await store.push(prefs, [sub('a')], now: base);
      await store.push(prefs, [sub('b')], now: base.add(const Duration(hours: 1)));

      final saved = await store.load(prefs);
      expect(saved.first.subscriptions.single.id, 'b');
    });

    test('빈 목록은 남기지 않는다', () async {
      // 첫 구독을 넣기 전으로 돌아가는 건 '전부 지우기'와 같다.
      expect(await store.push(prefs, const []), isFalse);
      expect(await store.load(prefs), isEmpty);
    });

    test('짧은 간격으로 이어서 고치면 한 지점으로 묶는다', () async {
      // 스위치 하나 켤 때마다 지점이 생기면 되돌릴 자리가 의미 없이 잘게
      // 쪼개지고, 목록 전체를 다시 쓰느라 느려진다.
      final base = DateTime(2026, 3, 1, 12);
      await store.push(prefs, [sub('a')], now: base);
      final pushed = await store.push(
        prefs,
        [sub('b')],
        now: base.add(const Duration(seconds: 30)),
      );

      expect(pushed, isFalse);
      expect(await store.load(prefs), hasLength(1));
    });

    test('시간이 지나면 새 지점을 만든다', () async {
      final base = DateTime(2026, 3, 1, 12);
      await store.push(prefs, [sub('a')], now: base);
      final pushed = await store.push(
        prefs,
        [sub('b')],
        now: base.add(const Duration(minutes: 5)),
      );

      expect(pushed, isTrue);
      expect(await store.load(prefs), hasLength(2));
    });

    test('정해둔 개수만 남기고 오래된 건 버린다', () async {
      var at = DateTime(2026, 3, 1, 12);
      for (var i = 0; i < SnapshotStore.maxSnapshots + 3; i++) {
        await store.push(prefs, [sub('s$i')], now: at);
        at = at.add(const Duration(minutes: 5));
      }

      final saved = await store.load(prefs);
      expect(saved, hasLength(SnapshotStore.maxSnapshots));
      // 가장 최근 것이 살아 있어야 한다
      expect(saved.first.subscriptions.single.id, 's7');
    });
  });

  group('되돌린 지점 빼기', () {
    test('고른 지점만 빠진다', () async {
      final base = DateTime(2026, 3, 1, 12);
      await store.push(prefs, [sub('a')], now: base);
      await store.push(
        prefs,
        [sub('b')],
        now: base.add(const Duration(minutes: 5)),
      );

      final left = await store.drop(prefs, base);

      expect(left, hasLength(1));
      expect(left.single.subscriptions.single.id, 'b');
    });
  });

  group('저장된 내용이 깨졌을 때', () {
    test('없는 셈 치고 넘어간다', () async {
      SharedPreferences.setMockInitialValues({
        'subscription_snapshots_v1': '{이건 JSON 이 아니다',
      });
      prefs = await SharedPreferences.getInstance();

      expect(await store.load(prefs), isEmpty);
    });
  });

  group('구독 내용이 온전히 보존된다', () {
    test('이력과 해지일까지 그대로 돌아온다', () async {
      final rich = Subscription.create(
        id: 'netflix',
        name: '넷플릭스',
        cycle: BillingCycle.monthly,
        startedAt: DateTime(2025, 6, 1),
        canceledAt: DateTime(2026, 3, 20),
        memo: '프리미엄',
        priceHistory: [
          PricePoint(
            effectiveFrom: DateTime(2025, 6, 1),
            amount: const Money(17000),
            cycle: BillingCycle.monthly,
          ),
        ],
        pastPeriods: [
          SubscriptionPeriod(
            startedAt: DateTime(2023, 1, 1),
            endedAt: DateTime(2023, 8, 31),
          ),
        ],
      );

      await store.push(prefs, [rich]);
      final restored = (await store.load(prefs)).single.subscriptions.single;

      expect(restored.toJson(), rich.toJson());
    });
  });
}

import 'dart:convert';

import 'package:ninedogs_core/ninedogs_core.dart';
import 'package:test/test.dart';

/// 공유 계약 픽스처. family_finance 도 같은 JSON 으로 왕복 테스트를 돌린다.
/// 이 JSON 의 모양이 바뀌면 두 앱의 저장 데이터가 어긋난다는 뜻이다(가짜 값).
const fixture = '''
{"cv":1,"id":"00000000-0000-4000-8000-000000000001","serviceId":"ott_a","name":"OTT-A",
 "iconUrl":null,"brandColorValue":4292441943,"cycle":"monthly",
 "priceHistory":[{"effectiveFrom":"2026-01-01T00:00:00.000","amount":{"minor":10000,"currency":"KRW"},"cycle":null}],
 "startedAt":"2026-01-01T00:00:00.000","billingAnchor":null,"canceledAt":null,"accessEndsAt":null,
 "trialEndsAt":null,"paymentMethod":"가나다카드","credentialId":null,"memo":"기본","owner":"b",
 "reminderDaysBefore":null,"pastPeriods":[]}
''';

void main() {
  test('계약 픽스처를 읽고 다시 쓰면 같은 JSON 이 된다', () {
    final json = jsonDecode(fixture) as Map<String, Object?>;
    final back = Subscription.fromJson(json).toJson();
    expect(jsonEncode(back), jsonEncode(json));
  });

  test('계약 버전은 1', () => expect(kContractVersion, 1));

  test('사람 이름 기본값', () {
    expect(People.fromJson(null).nameOf('a'), '나');
  });
}

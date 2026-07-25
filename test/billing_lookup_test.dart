import 'package:flutter_test/flutter_test.dart';
import 'package:ninedogs/data/catalog/billing_lookup.dart';
import 'package:ninedogs/data/catalog/service_catalog.dart';

void main() {
  group('가입일 찾기 안내', () {
    test('모든 안내가 실제 카탈로그 서비스에 붙어 있다', () {
      for (final id in billingLookups.keys) {
        expect(
          ServiceCatalog.byId(id),
          isNotNull,
          reason: '$id 는 카탈로그에 없다 — 이름이 바뀌었거나 오타다',
        );
      }
    });

    test('URL 은 https 로만 넣는다', () {
      for (final entry in billingLookups.entries) {
        final url = entry.value.url;
        if (url == null) continue;
        expect(
          Uri.tryParse(url)?.scheme,
          'https',
          reason: '${entry.key} 의 주소가 https 가 아니다',
        );
      }
    });

    test('경로 설명은 비어 있지 않다', () {
      for (final entry in billingLookups.entries) {
        expect(entry.value.path, isNotEmpty, reason: entry.key);
        expect(entry.value.historyRange, isNotEmpty, reason: entry.key);
      }
    });

    test('스토어 구독 주소도 https 다', () {
      for (final url in [appStoreSubscriptionsUrl, playStoreSubscriptionsUrl]) {
        expect(Uri.tryParse(url)?.scheme, 'https');
      }
    });

    test('모르는 서비스는 null 을 준다', () {
      expect(billingLookupOf('없는_서비스'), isNull);
      expect(billingLookupOf(null), isNull);
    });
  });
}

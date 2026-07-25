import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ninedogs/data/exchange/exchange_rate_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('정상 응답이면 환율을 읽어 캐시에 남긴다', () async {
    final client = MockClient((request) async {
      return http.Response(
        '{"result":"success","rates":{"KRW":1400.5}}',
        200,
      );
    });
    final service = ExchangeRateService(client: client);
    final prefs = await SharedPreferences.getInstance();

    final rate = await service.rate(prefs);

    expect(rate, 1400.5);
    expect(prefs.getDouble('usd_krw_rate_v1'), 1400.5);
  });

  test('요청이 실패하면 대략값으로 대신한다', () async {
    final client = MockClient((request) async => http.Response('', 500));
    final service = ExchangeRateService(client: client);
    final prefs = await SharedPreferences.getInstance();

    final rate = await service.rate(prefs);

    expect(rate, ExchangeRateService.fallbackRate);
  });

  test('요청이 실패해도 예전 캐시가 있으면 그걸 쓴다', () async {
    SharedPreferences.setMockInitialValues({
      'usd_krw_rate_v1': 1234.0,
      // 아주 오래전이라 캐시로는 신선하지 않음
      'usd_krw_rate_fetched_at_v1': 0,
    });
    final client = MockClient((request) async => http.Response('', 500));
    final service = ExchangeRateService(client: client);
    final prefs = await SharedPreferences.getInstance();

    final rate = await service.rate(prefs);

    expect(rate, 1234.0);
  });

  test('캐시가 신선하면 다시 받아오지 않는다', () async {
    SharedPreferences.setMockInitialValues({
      'usd_krw_rate_v1': 1111.0,
      'usd_krw_rate_fetched_at_v1': DateTime.now().millisecondsSinceEpoch,
    });
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response('{"result":"success","rates":{"KRW":9999}}', 200);
    });
    final service = ExchangeRateService(client: client);
    final prefs = await SharedPreferences.getInstance();

    final rate = await service.rate(prefs);

    expect(rate, 1111.0);
    expect(calls, 0);
  });

  test('응답 형식이 이상해도 죽지 않고 대략값을 쓴다', () async {
    final client = MockClient(
      (request) async => http.Response('이상한 응답', 200),
    );
    final service = ExchangeRateService(client: client);
    final prefs = await SharedPreferences.getInstance();

    final rate = await service.rate(prefs);

    expect(rate, ExchangeRateService.fallbackRate);
  });
}

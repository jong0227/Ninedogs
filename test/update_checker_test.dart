import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ninedogs/data/update/update_checker.dart';

UpdateChecker checkerReturning(
  Object? body, {
  int statusCode = 200,
  bool throwError = false,
}) {
  final client = MockClient((request) async {
    if (throwError) throw const SocketExceptionStub();
    return http.Response(
      jsonEncode(body),
      statusCode,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
  return UpdateChecker(client: client);
}

class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}

Map<String, Object?> release(String tag, {String? apkName}) => {
  'tag_name': tag,
  'html_url': 'https://github.com/jong0227/Ninedogs/releases/tag/$tag',
  'body': '버그 수정',
  'assets': [
    if (apkName != null)
      {
        'name': apkName,
        'browser_download_url': 'https://example.test/$apkName',
      },
  ],
};

void main() {
  group('버전 비교', () {
    test('앞자리부터 숫자로 비교한다', () {
      expect(UpdateChecker.isNewer('1.1.0', '1.0.0'), isTrue);
      expect(UpdateChecker.isNewer('2.0.0', '1.9.9'), isTrue);
      expect(UpdateChecker.isNewer('1.0.1', '1.0.0'), isTrue);
    });

    test('같거나 낮으면 새 버전이 아니다', () {
      expect(UpdateChecker.isNewer('1.0.0', '1.0.0'), isFalse);
      expect(UpdateChecker.isNewer('1.0.0', '1.0.1'), isFalse);
      expect(UpdateChecker.isNewer('1.9.9', '2.0.0'), isFalse);
    });

    test('문자열 비교가 아니라 숫자 비교다', () {
      // 문자열로 비교하면 '10' < '9' 가 되어버린다
      expect(UpdateChecker.isNewer('1.10.0', '1.9.0'), isTrue);
      expect(UpdateChecker.isNewer('1.9.0', '1.10.0'), isFalse);
    });

    test('자릿수가 달라도 빈 자리는 0 으로 본다', () {
      expect(UpdateChecker.isNewer('1.2', '1.2.0'), isFalse);
      expect(UpdateChecker.isNewer('1.2.1', '1.2'), isTrue);
    });

    test('v 접두사와 빌드 번호를 떼고 비교한다', () {
      expect(UpdateChecker.normalizeVersion('v1.2.0'), '1.2.0');
      expect(UpdateChecker.normalizeVersion('1.2.0+5'), '1.2.0');
      expect(UpdateChecker.isNewer('v1.1.0', '1.0.0+3'), isTrue);
    });

    test('버전을 못 읽으면 새 버전으로 보지 않는다', () {
      expect(UpdateChecker.isNewer('', '1.0.0'), isFalse);
    });
  });

  group('업데이트 확인', () {
    test('더 높은 버전이 있으면 알려준다', () async {
      final result = await checkerReturning(
        release('v1.1.0', apkName: 'app-arm64-v8a-release.apk'),
      ).check('1.0.0');

      expect(result, isA<UpdateAvailable>());
      final available = result as UpdateAvailable;
      expect(available.release.version, '1.1.0');
      expect(
        available.release.apkUrl,
        'https://example.test/app-arm64-v8a-release.apk',
      );
    });

    test('같은 버전이면 최신이라고 한다', () async {
      final result = await checkerReturning(release('v1.0.0')).check('1.0.0');
      expect(result, isA<UpToDate>());
    });

    test('APK 자산이 없으면 릴리즈 페이지로 보낸다', () async {
      final result = await checkerReturning(release('v1.1.0')).check('1.0.0');

      final available = result as UpdateAvailable;
      expect(available.release.apkUrl, isNull);
      expect(available.release.pageUrl, contains('releases/tag/v1.1.0'));
    });

    test('릴리즈가 없으면(404) 확인 실패로 다룬다', () async {
      final result = await checkerReturning(
        {'message': 'Not Found'},
        statusCode: 404,
      ).check('1.0.0');

      expect(result, isA<UpdateCheckFailed>());
      expect((result as UpdateCheckFailed).reason, contains('릴리즈'));
    });

    test('네트워크가 안 되면 최신이라고 우기지 않는다', () async {
      final result = await checkerReturning(null, throwError: true)
          .check('1.0.0');

      // UpToDate 로 처리하면 사용자가 최신인 줄 오해한다
      expect(result, isA<UpdateCheckFailed>());
    });

    test('응답 형식이 이상해도 죽지 않는다', () async {
      final result = await checkerReturning('그냥 문자열').check('1.0.0');
      expect(result, isA<UpdateCheckFailed>());
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ninedogs/widgets/app_date_picker.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko_KR'));

  /// 날짜 선택기를 띄우고, 고른 값을 받아볼 수 있게 한다.
  Future<DateTime?> open(
    WidgetTester tester, {
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) async {
    DateTime? result;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko', 'KR'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ko', 'KR')],
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await pickDate(
                  context,
                  initialDate: initialDate,
                  firstDate: firstDate,
                  lastDate: lastDate,
                  helpText: '구독을 시작한 날',
                );
              },
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    return result;
  }

  group('날짜 선택기', () {
    testWidgets('헤더를 누르면 연도만이 아니라 달도 고를 수 있다', (tester) async {
      // 원래 불편했던 지점: 기본 피커는 헤더를 눌러도 연도만 골라졌다.
      await open(
        tester,
        initialDate: DateTime(2026, 7, 10),
        firstDate: DateTime(2010),
        lastDate: DateTime(2026, 7, 26),
      );

      expect(find.text('2026년 7월'), findsOneWidget);

      await tester.tap(find.text('2026년 7월'));
      await tester.pumpAndSettle();

      // 연·월 격자에는 열두 달이 다 있다.
      expect(find.text('2026년'), findsOneWidget);
      expect(find.text('3월'), findsOneWidget);
      expect(find.text('12월'), findsOneWidget);
    });

    testWidgets('먼 과거로 몇 번만에 간다', (tester) async {
      await open(
        tester,
        initialDate: DateTime(2026, 7, 10),
        firstDate: DateTime(2010),
        lastDate: DateTime(2026, 7, 26),
      );

      // 헤더 → 이전 해 → 달 선택. 화살표로 달을 하나씩 넘기지 않는다.
      await tester.tap(find.text('2026년 7월'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('이전 해'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3월'));
      await tester.pumpAndSettle();

      expect(find.text('2025년 3월'), findsOneWidget);
    });

    testWidgets('직접 입력으로 바꿔 칠 수 있다', (tester) async {
      await open(
        tester,
        initialDate: DateTime(2026, 7, 10),
        firstDate: DateTime(2010),
        lastDate: DateTime(2026, 7, 26),
      );

      await tester.tap(find.byTooltip('직접 입력'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '20190315');
      await tester.pumpAndSettle();

      // 헤더가 친 날짜를 그대로 따라간다.
      expect(find.textContaining('2019년 3월 15일'), findsOneWidget);
    });

    testWidgets('범위 밖 날짜를 치면 저장을 막는다', (tester) async {
      await open(
        tester,
        initialDate: DateTime(2026, 7, 10),
        firstDate: DateTime(2010),
        lastDate: DateTime(2026, 7, 26),
      );

      await tester.tap(find.byTooltip('직접 입력'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '20301231');
      await tester.pumpAndSettle();

      expect(find.text('고를 수 없는 날짜예요'), findsOneWidget);

      final confirm = tester.widget<TextButton>(
        find.widgetWithText(TextButton, '선택'),
      );
      expect(confirm.onPressed, isNull);
    });

    testWidgets('고른 날짜를 돌려준다', (tester) async {
      DateTime? picked;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ko', 'KR'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ko', 'KR')],
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  picked = await pickDate(
                    context,
                    initialDate: DateTime(2026, 7, 10),
                    firstDate: DateTime(2010),
                    lastDate: DateTime(2026, 7, 26),
                    helpText: '구독을 시작한 날',
                  );
                },
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('선택'));
      await tester.pumpAndSettle();

      expect(picked, DateTime(2026, 7, 15));
    });
  });
}

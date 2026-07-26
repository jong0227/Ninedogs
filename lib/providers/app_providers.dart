import 'package:flutter/material.dart' show Color, ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/exchange/exchange_rate_service.dart';
import '../data/icons/icon_palette.dart';
import '../data/icons/icon_resolver.dart';
import '../data/update/apk_installer.dart';
import '../data/update/update_checker.dart';

/// main() 에서 실제 인스턴스로 override 한다.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('main() 에서 override 해야 합니다'),
);

final iconResolverProvider = Provider<IconResolver>(
  (ref) => IconResolver(prefs: ref.watch(sharedPreferencesProvider)),
);

/// 온보딩(첫 구독 고르기)을 마쳤는지. 앱을 다시 켜도 유지된다.
class OnboardingCompleteNotifier extends Notifier<bool> {
  static const _key = 'onboarding_complete_v1';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? false;

  Future<void> complete() async {
    await ref.read(sharedPreferencesProvider).setBool(_key, true);
    state = true;
  }
}

final onboardingCompleteProvider =
    NotifierProvider<OnboardingCompleteNotifier, bool>(
      OnboardingCompleteNotifier.new,
    );

/// 밝게/어둡게 설정. 기본은 어둡게 — 검정 바탕이 이 앱의 기본 모습이다.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'theme_mode_v1';

  @override
  ThemeMode build() {
    final saved = ref.watch(sharedPreferencesProvider).getString(_key);
    return ThemeMode.values
        .where((mode) => mode.name == saved)
        .firstOrNull ??
        ThemeMode.dark;
  }

  Future<void> set(ThemeMode mode) async {
    await ref.read(sharedPreferencesProvider).setString(_key, mode.name);
    state = mode;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

/// 하단 탭의 현재 선택 인덱스 (0=구독, 1=캘린더, 2=통계).
///
/// 홈 화면의 요약 카드처럼, 다른 화면에서 탭을 직접 전환하고 싶을 때 쓴다.
/// 저장하지 않는다 — 앱을 다시 켜면 구독 탭에서 시작한다.
class SelectedShellTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}

final selectedShellTabProvider =
    NotifierProvider<SelectedShellTabNotifier, int>(
      SelectedShellTabNotifier.new,
    );

/// 캘린더 탭에서 고른 날짜. 날짜를 고르면 그날 결제만 보여주는 화면으로
/// 바뀐다.
///
/// 화면 State 가 아니라 provider 로 둔 이유: 뒤로가기를 눌렀을 때 날짜
/// 선택부터 풀어줘야 하는데, 그 판단은 [AppShell] 이 하기 때문에 탭 바깥에서도
/// 지금 날짜가 선택돼 있는지 알아야 한다.
class CalendarSelectedDayNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void select(DateTime? day) => state = day;
}

final calendarSelectedDayProvider =
    NotifierProvider<CalendarSelectedDayNotifier, DateTime?>(
      CalendarSelectedDayNotifier.new,
    );

/// 설치된 앱의 버전. 예: '1.0.0'
final appVersionProvider = FutureProvider<String>(
  (ref) async => (await PackageInfo.fromPlatform()).version,
);

final updateCheckerProvider = Provider<UpdateChecker>((ref) => UpdateChecker());

final apkInstallerProvider = Provider<ApkInstaller>((ref) => const ApkInstaller());

final exchangeRateServiceProvider = Provider<ExchangeRateService>(
  (ref) => ExchangeRateService(),
);

/// 지금 쓸 USD -> KRW 환율. 실패해도 캐시나 대략값으로 대체하므로
/// (ExchangeRateService 참고) 이 provider 는 null 을 주지 않는다.
final exchangeRateProvider = FutureProvider<double>(
  (ref) => ref
      .watch(exchangeRateServiceProvider)
      .rate(ref.watch(sharedPreferencesProvider)),
);

typedef IconRequest = ({String serviceId, String searchTerm, String? domain});

/// 서비스별 아이콘 URL. 실패하면 null 이고 화면에서는 첫 글자를 그린다.
final iconUrlProvider = FutureProvider.family<String?, IconRequest>((
  ref,
  request,
) {
  return ref
      .watch(iconResolverProvider)
      .resolve(
        request.serviceId,
        request.searchTerm,
        domain: request.domain,
      );
});

/// 아이콘 가장자리 색. 원으로 자를 때 바깥을 이 색으로 채워
/// 아이콘이 잘리지 않으면서도 이음매가 안 보이게 한다.
final iconEdgeColorProvider = FutureProvider.family<Color?, String>(
  (ref, url) => IconPalette.edgeColor(url),
);

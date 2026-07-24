import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/icons/icon_resolver.dart';

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

typedef IconRequest = ({String serviceId, String searchTerm});

/// 서비스별 아이콘 URL. 실패하면 null 이고 화면에서는 대체 타일을 그린다.
final iconUrlProvider = FutureProvider.family<String?, IconRequest>((
  ref,
  request,
) {
  return ref
      .watch(iconResolverProvider)
      .resolve(request.serviceId, request.searchTerm);
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';
import 'subscription_providers.dart';
import 'vault_providers.dart';

/// 앱에 쌓인 모든 것을 지운다. 되돌릴 수 없다.
///
/// 화면에서 부르기 전에 반드시 사용자에게 확인을 받는다.
/// (설정 화면은 확인 문구를 직접 입력하게 한다)
class AppReset {
  const AppReset(this._ref);

  final Ref _ref;

  Future<void> everything() async {
    // 구독, 계정 정보, 금고 메타데이터, 온보딩 여부, 아이콘 캐시까지 전부.
    await _ref.read(sharedPreferencesProvider).clear();

    // 저장소를 비운 뒤 상태를 다시 읽게 만든다. 순서가 바뀌면
    // 지우기 전 값이 메모리에 남는다.
    _ref.invalidate(subscriptionsProvider);
    _ref.invalidate(storedCredentialsProvider);
    _ref.invalidate(vaultProvider);
    _ref.invalidate(onboardingCompleteProvider);
  }
}

final appResetProvider = Provider<AppReset>(AppReset.new);

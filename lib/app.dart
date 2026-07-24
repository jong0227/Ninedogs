import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'providers/app_providers.dart';
import 'providers/vault_providers.dart';

class NinedogsApp extends ConsumerStatefulWidget {
  const NinedogsApp({super.key});

  @override
  ConsumerState<NinedogsApp> createState() => _NinedogsAppState();
}

class _NinedogsAppState extends ConsumerState<NinedogsApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 앱이 화면에서 내려가면 금고를 잠근다.
  ///
  /// 폰을 잠깐 빌려주거나 앱 전환 화면을 띄웠을 때 계정 정보가 그대로
  /// 보이면 안 된다. 키를 메모리에서 버리므로 다시 보려면 마스터 암호가 필요하다.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      ref.read(vaultProvider.notifier).lock();
    }
  }

  @override
  Widget build(BuildContext context) {
    final onboarded = ref.watch(onboardingCompleteProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Ninedogs',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: onboarded ? const HomeScreen() : const OnboardingScreen(),
    );
  }
}

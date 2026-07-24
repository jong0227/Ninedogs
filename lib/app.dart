import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'data/backup/import_channel.dart';
import 'features/backup/backup_actions.dart';
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
  /// 화면 어디에 있든 백업 가져오기 확인창을 띄우기 위해 필요하다.
  final _navigatorKey = GlobalKey<NavigatorState>();

  static const _importChannel = ImportChannel();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 앱이 꺼져 있다가 백업 파일로 열린 경우
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPendingImport());
  }

  /// 카톡 등에서 백업 파일을 눌러 들어왔는지 확인한다.
  Future<void> _checkPendingImport() async {
    final raw = await _importChannel.takePending();
    if (raw == null || raw.isEmpty) return;

    final context = _navigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    await confirmAndImport(context, ref, raw);
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

    // 앱이 떠 있는 상태에서 백업 파일이 열리면 여기로 돌아온다
    if (state == AppLifecycleState.resumed) {
      _checkPendingImport();
    }
  }

  @override
  Widget build(BuildContext context) {
    final onboarded = ref.watch(onboardingCompleteProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Ninedogs',
      navigatorKey: _navigatorKey,
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

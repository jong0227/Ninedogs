import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'providers/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR');

  // Firebase 는 부부 공유를 켰을 때만 쓴다. 설정이 없거나 초기화가 실패해도
  // 앱은 이 기기 저장소만으로 온전히 동작해야 한다.
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // 동기화 없이 계속 간다
  }

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const NinedogsApp(),
    ),
  );
}

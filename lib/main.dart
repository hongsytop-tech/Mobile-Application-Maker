import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'features/auth/services/supabase_service.dart';
import 'features/auth/services/sync_web_stub.dart'
    if (dart.library.html) 'features/auth/services/sync_web.dart';
import 'features/kakao/services/kakao_oauth_stub.dart'
    if (dart.library.html) 'features/kakao/services/kakao_oauth_web.dart';
import 'features/quotes/services/notification_service.dart';
import 'features/update/services/web_update_detector_stub.dart'
    if (dart.library.html) 'features/update/services/web_update_detector_web.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Supabase 초기화 전에 카카오 OAuth 콜백 파라미터(?code/?state)를 가로채서
  // Supabase auth 가 자기 PKCE 콜백으로 오인하는 것을 방지.
  captureKakaoCallback();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env 파일이 없어도 앱은 실행 (검색·로그인 비활성)
  }
  await initializeDateFormatting('ko_KR');
  await NotificationService.init();
  await SupabaseService.init();
  setupSyncTabCloseFlush();
  WebUpdateDetector.init();
  runApp(const ProviderScope(child: SelfDevApp()));
}

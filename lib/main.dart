import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'features/auth/services/supabase_service.dart';
import 'features/quotes/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env 파일이 없어도 앱은 실행 (검색·로그인 비활성)
  }
  await initializeDateFormatting('ko_KR');
  await NotificationService.init();
  await SupabaseService.init();
  runApp(const ProviderScope(child: SelfDevApp()));
}

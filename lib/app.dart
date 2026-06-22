import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'features/auth/widgets/sync_gate.dart';
import 'shell/main_shell.dart';

class SelfDevApp extends StatelessWidget {
  const SelfDevApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '자기계발 앱',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko'), Locale('en')],
      locale: const Locale('ko'),
      theme: ThemeData(
        // surface 색을 흰색으로 명시 — 기본은 seed 에서 파생된 옅은 색조라
        // 일부 모니터에서 분홍/붉은 기가 도는 흰색으로 보일 수 있다.
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5),
        ).copyWith(
          surface: Colors.white,
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: Colors.white,
          surfaceContainer: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.white,
        canvasColor: Colors.white,
        useMaterial3: true,
        fontFamily: 'Pretendard',
      ),
      home: const SyncGate(child: MainShell()),
    );
  }
}

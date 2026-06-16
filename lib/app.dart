import 'package:flutter/material.dart';

import 'features/auth/widgets/sync_gate.dart';
import 'shell/main_shell.dart';

class SelfDevApp extends StatelessWidget {
  const SelfDevApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '자기계발 앱',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
        useMaterial3: true,
        fontFamily: 'Pretendard',
      ),
      home: const SyncGate(child: MainShell()),
    );
  }
}

import 'package:flutter/material.dart';

import '../features/auth/screens/profile_screen.dart';
import '../features/diary/screens/diary_calendar_screen.dart';
import '../features/kakao/services/kakao_link_service.dart';
import '../features/quotes/screens/quotes_screen.dart';
import '../features/reading/screens/home_screen.dart';
import '../features/todo/screens/todo_home_screen.dart';
import '../features/update/widgets/update_banner.dart';
import '../features/update/widgets/web_update_banner.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 1; // 할일/목표(To do) 가 첫 화면

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleKakaoCallback());
  }

  Future<void> _handleKakaoCallback() async {
    final result = await KakaoLinkService.handleRedirectIfAny();
    if (result == null || !mounted) return;
    final msg = result.ok
        ? (result.hasTalkMessage
            ? '✅ 카카오톡 알림 연동 완료!'
            : '⚠️ 연동됐지만 "메시지 전송" 동의가 빠졌어요. 마이페이지에서 다시 연동해주세요.')
        : '❌ 카카오 연동 실패: ${result.error}';
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 5),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const UpdateBanner(),
            const WebUpdateBanner(),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: const [
                  HomeScreen(),
                  TodoHomeScreen(),
                  DiaryCalendarScreen(),
                  QuotesScreen(),
                  ProfileScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          // 다른 탭으로 이동 시 진행 중인 스낵바(예: 즉시 할일 완료 Undo) 닫기
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          setState(() => _index = i);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: '독서',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'To do',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: '일기',
          ),
          NavigationDestination(
            icon: Icon(Icons.format_quote_outlined),
            selectedIcon: Icon(Icons.format_quote),
            label: '문구',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '마이',
          ),
        ],
      ),
    );
  }
}

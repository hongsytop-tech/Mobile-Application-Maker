import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/screens/profile_screen.dart';
import '../features/diary/screens/diary_calendar_screen.dart';
import '../features/kakao/services/kakao_link_service.dart';
import '../features/memo/providers/memo_providers.dart';
import '../features/memo/screens/memo_edit_screen.dart';
import '../features/memo/screens/memo_list_screen.dart';
import '../features/memo/services/memo_url_helper.dart'
    if (dart.library.html) '../features/memo/services/memo_url_helper_web.dart';
import '../features/quotes/screens/quotes_screen.dart';
import '../features/reading/screens/home_screen.dart';
import '../features/todo/screens/todo_home_screen.dart';
import '../features/update/widgets/update_banner.dart';
import '../features/update/widgets/web_update_banner.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0; // To do 가 첫 화면 (첫 번째 탭)
  late final PageController _pageCtrl = PageController(initialPage: _index);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleKakaoCallback();
      _handleMemoDeepLink();
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _goToTab(int i) {
    if (i == _index) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() => _index = i);
    // 빠르고 부드럽게 전환
    _pageCtrl.animateToPage(
      i,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
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

  Future<void> _handleMemoDeepLink() async {
    final memoId = readMemoIdFromUrl();
    if (memoId == null) return;

    // 새로고침 시 같은 메모가 재진입되지 않도록 쿼리 파라미터 제거
    clearMemoQueryParam();

    // 메모 탭으로 전환
    const memoTabIndex = 4;
    setState(() => _index = memoTabIndex);
    _pageCtrl.jumpToPage(memoTabIndex);

    // 메모 데이터 로드를 대기 (최대 5초)
    final start = DateTime.now();
    while (mounted) {
      final asyncMemos = ref.read(memosProvider);
      if (asyncMemos.hasValue) {
        final memos = asyncMemos.value!;
        final idx = memos.indexWhere((m) => m.id == memoId);
        if (idx >= 0) {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => MemoEditScreen(memo: memos[idx])),
          );
        }
        return;
      }
      if (DateTime.now().difference(start) > const Duration(seconds: 5)) return;
      await Future.delayed(const Duration(milliseconds: 100));
    }
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
              child: PageView(
                controller: _pageCtrl,
                onPageChanged: (i) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  setState(() => _index = i);
                },
                children: const [
                  TodoHomeScreen(),
                  HomeScreen(),
                  DiaryCalendarScreen(),
                  QuotesScreen(),
                  MemoListScreen(),
                  ProfileScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goToTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'To do',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: '독서',
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
            icon: Icon(Icons.sticky_note_2_outlined),
            selectedIcon: Icon(Icons.sticky_note_2),
            label: '메모',
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

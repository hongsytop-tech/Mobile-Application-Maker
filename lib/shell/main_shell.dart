import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/kakao/services/kakao_link_service.dart';
import '../features/memo/providers/memo_providers.dart';
import '../features/memo/screens/memo_edit_screen.dart';
import '../features/memo/services/memo_url_helper.dart'
    if (dart.library.html) '../features/memo/services/memo_url_helper_web.dart';
import '../features/tasks/services/google_tasks_service.dart';
import '../features/tasks/services/tasks_importer.dart';
import '../features/update/widgets/update_banner.dart';
import '../features/update/widgets/web_update_banner.dart';
import 'app_tabs.dart';
import 'menu_settings.dart';
import 'menu_settings_provider.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncMenu = ref.watch(menuSettingsProvider);
    final menu = asyncMenu.value ?? const MenuSettings();
    // 설정 로딩 전이라도 기본 순서로 즉시 렌더 (깜빡임 방지)
    var visibleIds = menu.visibleOrder;
    // 안전장치: NavigationBar 는 최소 2개를 요구 → 손상된 설정이면 전체 표시
    if (visibleIds.length < 2) visibleIds = menu.normalizedOrder;
    final tabs = [for (final id in visibleIds) kAppTabs[id]!];
    return _ShellScaffold(tabs: tabs);
  }
}

class _ShellScaffold extends ConsumerStatefulWidget {
  final List<AppTab> tabs;
  const _ShellScaffold({required this.tabs});

  @override
  ConsumerState<_ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends ConsumerState<_ShellScaffold> {
  int _index = 0;
  late PageController _pageCtrl = PageController(initialPage: _index);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleKakaoCallback();
      _handleMemoDeepLink();
      _autoImportTasks();
    });
  }

  @override
  void didUpdateWidget(_ShellScaffold old) {
    super.didUpdateWidget(old);
    // 탭 구성이 바뀌면 현재 인덱스를 범위 내로 보정
    if (widget.tabs.length != old.tabs.length) {
      if (_index >= widget.tabs.length) {
        _index = widget.tabs.length - 1;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pageCtrl.hasClients) _pageCtrl.jumpToPage(_index);
        });
      }
    }
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

  /// 앱 시작 시 구글 Tasks 를 조용히(팝업 없이) 메모로 가져온다.
  /// 동의가 살아있으면 자동, 필요 시엔 조용히 실패(마이페이지 버튼으로 재허용).
  Future<void> _autoImportTasks() async {
    if (!kIsWeb) return;
    if (!GoogleTasksService.isConfigured) return;
    try {
      // 메모 로드 완료를 먼저 보장 (미로드 상태 add → 기존 메모 유실 방지)
      await ref.read(memosProvider.future);
      final r = await TasksImporter.importNew(
        ref.read(memosProvider.notifier),
        silent: true,
      );
      if (r.imported > 0 && mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text('🗒️ 구글 Tasks에서 ${r.imported}건을 메모로 가져왔어요'),
            duration: const Duration(seconds: 3),
          ));
      }
    } catch (_) {
      // 조용히 무시 — 앱 시작을 방해하지 않는다.
    }
  }

  Future<void> _handleMemoDeepLink() async {
    final memoId = readMemoIdFromUrl();
    if (memoId == null) return;
    clearMemoQueryParam();

    // 메모 탭이 보이면 그 탭으로 전환
    final memoTabIndex = widget.tabs.indexWhere((t) => t.id == 'memo');
    if (memoTabIndex >= 0) {
      setState(() => _index = memoTabIndex);
      if (_pageCtrl.hasClients) _pageCtrl.jumpToPage(memoTabIndex);
    }

    // 메모 데이터 로드를 대기 (최대 5초) 후 편집 화면을 push
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
    final tabs = widget.tabs;
    final safeIndex = _index.clamp(0, tabs.length - 1);
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
                children: [for (final t in tabs) t.builder(context)],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: _goToTab,
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.selectedIcon),
              label: t.label,
            ),
        ],
      ),
    );
  }
}

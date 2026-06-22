import 'package:flutter/material.dart';

import '../features/auth/screens/profile_screen.dart';
import '../features/diary/screens/diary_calendar_screen.dart';
import '../features/memo/screens/memo_list_screen.dart';
import '../features/quotes/screens/quotes_screen.dart';
import '../features/reading/screens/home_screen.dart';
import '../features/todo/screens/todo_home_screen.dart';

/// 하단 탭 하나의 정의 (화면 + 아이콘 + 라벨).
class AppTab {
  final String id;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final WidgetBuilder builder;

  /// true 면 사용자가 숨길 수 없다 (마이페이지 = 설정 진입점이라 항상 표시).
  final bool lockedVisible;

  const AppTab({
    required this.id,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
    this.lockedVisible = false,
  });
}

/// 전체 탭 레지스트리 (id → 정의).
final Map<String, AppTab> kAppTabs = {
  'todo': AppTab(
    id: 'todo',
    label: 'To do',
    icon: Icons.checklist_outlined,
    selectedIcon: Icons.checklist,
    builder: (_) => const TodoHomeScreen(),
  ),
  'reading': AppTab(
    id: 'reading',
    label: '독서',
    icon: Icons.menu_book_outlined,
    selectedIcon: Icons.menu_book,
    builder: (_) => const HomeScreen(),
  ),
  'diary': AppTab(
    id: 'diary',
    label: '일기',
    icon: Icons.calendar_month_outlined,
    selectedIcon: Icons.calendar_month,
    builder: (_) => const DiaryCalendarScreen(),
  ),
  'quotes': AppTab(
    id: 'quotes',
    label: '문구',
    icon: Icons.format_quote_outlined,
    selectedIcon: Icons.format_quote,
    builder: (_) => const QuotesScreen(),
  ),
  'memo': AppTab(
    id: 'memo',
    label: '메모',
    icon: Icons.sticky_note_2_outlined,
    selectedIcon: Icons.sticky_note_2,
    builder: (_) => const MemoListScreen(),
  ),
  'profile': AppTab(
    id: 'profile',
    label: '마이',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    builder: (_) => const ProfileScreen(),
    lockedVisible: true,
  ),
};

/// 기본 탭 순서.
const kDefaultTabOrder = <String>[
  'todo',
  'reading',
  'diary',
  'quotes',
  'memo',
  'profile',
];

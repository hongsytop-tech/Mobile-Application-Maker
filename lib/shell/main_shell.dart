import 'package:flutter/material.dart';

import '../features/auth/screens/profile_screen.dart';
import '../features/diary/screens/diary_calendar_screen.dart';
import '../features/quotes/screens/quotes_screen.dart';
import '../features/reading/screens/home_screen.dart';
import '../features/todo/screens/todo_home_screen.dart';
import '../features/update/widgets/update_banner.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const UpdateBanner(),
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
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: '독서',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: '할 일',
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

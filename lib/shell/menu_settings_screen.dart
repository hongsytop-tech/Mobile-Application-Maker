import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_tabs.dart';
import 'menu_settings.dart';
import 'menu_settings_provider.dart';

/// 하단 탭 표시 여부 + 순서를 편집하는 화면.
class MenuSettingsScreen extends ConsumerWidget {
  const MenuSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncMenu = ref.watch(menuSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('메뉴 편집')),
      body: asyncMenu.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (menu) => _Body(menu: menu),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final MenuSettings menu;
  const _Body({required this.menu});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = menu.normalizedOrder;
    final notifier = ref.read(menuSettingsProvider.notifier);
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '오른쪽 손잡이를 끌어 순서를 바꾸고, 스위치로 표시 여부를 정하세요.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            itemCount: ids.length,
            onReorder: (oldIndex, newIndex) {
              final next = [...ids];
              if (newIndex > oldIndex) newIndex -= 1;
              final moved = next.removeAt(oldIndex);
              next.insert(newIndex, moved);
              notifier.reorder(next);
            },
            itemBuilder: (context, i) {
              final id = ids[i];
              final tab = kAppTabs[id]!;
              final visible = menu.isVisible(id);
              return Container(
                key: ValueKey(id),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: visible
                        ? primary.withOpacity(0.3)
                        : Colors.grey.shade300,
                  ),
                ),
                child: ListTile(
                  leading: Icon(
                    visible ? tab.selectedIcon : tab.icon,
                    color: visible ? primary : Colors.grey,
                  ),
                  title: Text(
                    tab.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: visible ? null : Colors.grey,
                    ),
                  ),
                  subtitle: tab.lockedVisible
                      ? const Text('항상 표시 (설정 진입점)',
                          style: TextStyle(fontSize: 11))
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (tab.lockedVisible)
                        Icon(Icons.lock_outline,
                            size: 18, color: Colors.grey.shade400)
                      else
                        Switch(
                          value: visible,
                          onChanged: (on) async {
                            final ok =
                                await notifier.setHidden(id, !on);
                            if (!ok && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('최소 2개의 메뉴는 표시해야 해요.'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        ),
                      const SizedBox(width: 4),
                      ReorderableDragStartListener(
                        index: i,
                        child: Icon(Icons.drag_handle,
                            color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

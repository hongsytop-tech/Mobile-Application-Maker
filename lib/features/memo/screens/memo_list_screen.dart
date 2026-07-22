import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/services/sync_manager.dart';
import '../../../shared/widgets/scroll_to_top.dart';
import '../models/memo_folder.dart';
import '../providers/memo_folder_providers.dart';
import '../providers/memo_providers.dart';
import '../widgets/memo_list_widgets.dart';
import 'memo_edit_screen.dart';
import 'memo_folder_screen.dart';
import 'memo_search_screen.dart';

class MemoListScreen extends ConsumerStatefulWidget {
  const MemoListScreen({super.key});

  @override
  ConsumerState<MemoListScreen> createState() => _MemoListScreenState();
}

class _MemoListScreenState extends ConsumerState<MemoListScreen> {
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _newFolder() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('새 폴더'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '폴더 이름'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('만들기')),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      await ref.read(memoFoldersProvider.notifier).add(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncMemos = ref.watch(memosProvider);
    final rootMemos = ref.watch(sortedMemosProvider(null));
    final folders = ref.watch(sortedMemoFoldersProvider);
    final counts = ref.watch(memoCountByFolderProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('메모'),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: '새 폴더',
            onPressed: _newFolder,
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '검색',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MemoSearchScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MemoEditScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('새 메모'),
      ),
      body: ScrollToTop(
        child: RefreshIndicator(
          onRefresh: () => SyncManager.instance.pullOnLogin(),
          child: asyncMemos.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('오류: $e')),
            data: (_) {
              final empty = rootMemos.isEmpty && folders.isEmpty;
              if (empty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.sticky_note_2_outlined,
                                  size: 56, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                '아직 메모가 없어요.\n오른쪽 아래에서 새 메모를 추가해 보세요.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }
              return MemoAutoScrollOnDrag(
                controller: _scrollCtrl,
                child: ListView(
                  controller: _scrollCtrl,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                  children: [
                    if (folders.isNotEmpty) ...[
                      const MemoSectionLabel(
                          icon: Icons.folder, text: '폴더'),
                      const SizedBox(height: 8),
                      ...folders.map((f) => _FolderTile(
                            folder: f,
                            count: counts[f.id] ?? 0,
                          )),
                      const SizedBox(height: 12),
                    ],
                    if (rootMemos.pinned.isNotEmpty) ...[
                      MemoSectionLabel(
                          icon: Icons.push_pin,
                          text: '고정됨 (${rootMemos.pinned.length})'),
                      const SizedBox(height: 8),
                      DraggableMemoList(memos: rootMemos.pinned),
                    ],
                    if (rootMemos.pinned.isNotEmpty &&
                        rootMemos.others.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      MemoSectionLabel(
                          icon: Icons.notes,
                          text: '메모 (${rootMemos.others.length})'),
                      const SizedBox(height: 8),
                    ],
                    if (rootMemos.others.isNotEmpty)
                      DraggableMemoList(memos: rootMemos.others),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 폴더 한 칸 — 메모를 끌어다 놓으면 그 폴더로 이동. 탭하면 폴더 열기.
class _FolderTile extends ConsumerWidget {
  final MemoFolder folder;
  final int count;
  const _FolderTile({required this.folder, required this.count});

  Future<void> _menu(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('이름 변경'),
              onTap: () {
                Navigator.pop(ctx);
                _rename(context, ref);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: Colors.red.shade400),
              title: const Text('폴더 삭제'),
              subtitle: const Text('안의 메모는 삭제되지 않고 밖으로 나옵니다'),
              onTap: () {
                Navigator.pop(ctx);
                _delete(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController(text: folder.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('폴더 이름 변경'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('저장')),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      await ref.read(memoFoldersProvider.notifier).rename(folder.id, name);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('"${folder.name}" 폴더를 삭제할까요?'),
        content: const Text('폴더 안의 메모는 삭제되지 않고 목록으로 나옵니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(memosProvider.notifier).unfileFolder(folder.id);
      await ref.read(memoFoldersProvider.notifier).remove(folder.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = Theme.of(context).colorScheme.primary;
    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (d) =>
          ref.read(memosProvider.notifier).setFolder(d.data, folder.id),
      builder: (context, candidate, _) {
        final hovering = candidate.isNotEmpty;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: hovering ? primary.withOpacity(0.12) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => MemoFolderScreen(folderId: folder.id)),
              ),
              onLongPress: () => _menu(context, ref),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hovering ? primary : Colors.grey.shade300,
                    width: hovering ? 2 : 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Icon(Icons.folder, color: primary, size: 26),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        folder.name,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text('$count',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600)),
                    // 이름 변경/삭제 메뉴 버튼
                    IconButton(
                      icon: Icon(Icons.more_vert,
                          size: 20, color: Colors.grey.shade500),
                      tooltip: '폴더 메뉴',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _menu(context, ref),
                    ),
                    Icon(Icons.chevron_right,
                        size: 20, color: Colors.grey.shade400),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

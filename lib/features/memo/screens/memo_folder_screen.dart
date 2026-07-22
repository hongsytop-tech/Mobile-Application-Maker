import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/services/sync_manager.dart';
import '../../../shared/widgets/scroll_to_top.dart';
import '../providers/memo_folder_providers.dart';
import '../providers/memo_providers.dart';
import '../widgets/memo_list_widgets.dart';
import 'memo_edit_screen.dart';

/// 한 폴더 안의 메모 목록. 새 메모는 이 폴더에 생성되고,
/// 카드의 "폴더에서 빼기" 아이콘으로 루트로 내보낼 수 있다.
class MemoFolderScreen extends ConsumerStatefulWidget {
  final String folderId;
  const MemoFolderScreen({super.key, required this.folderId});

  @override
  ConsumerState<MemoFolderScreen> createState() => _MemoFolderScreenState();
}

class _MemoFolderScreenState extends ConsumerState<MemoFolderScreen> {
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _newMemoInFolder() {
    // 이 폴더 소속으로 새 메모 (편집 화면에서 처음 저장 시 생성).
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => MemoEditScreen(folderId: widget.folderId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final folders = ref.watch(sortedMemoFoldersProvider);
    final matches = folders.where((f) => f.id == widget.folderId);
    final folder = matches.isEmpty ? null : matches.first;
    final memos = ref.watch(sortedMemosProvider(widget.folderId));

    // 폴더가 삭제됐으면 뒤로.
    if (folder == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.folder, size: 20),
            const SizedBox(width: 8),
            Expanded(
                child: Text(folder.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newMemoInFolder,
        icon: const Icon(Icons.add),
        label: const Text('이 폴더에 새 메모'),
      ),
      body: ScrollToTop(
        child: RefreshIndicator(
          onRefresh: () => SyncManager.instance.pullOnLogin(),
          child: memos.isEmpty
              ? ListView(
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
                              Icon(Icons.folder_open,
                                  size: 56, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                '이 폴더에 메모가 없어요.\n메모 목록에서 끌어다 넣거나\n아래에서 새로 만들어 보세요.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : MemoAutoScrollOnDrag(
                  controller: _scrollCtrl,
                  child: ListView(
                    controller: _scrollCtrl,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                    children: [
                      if (memos.pinned.isNotEmpty) ...[
                        MemoSectionLabel(
                            icon: Icons.push_pin,
                            text: '고정됨 (${memos.pinned.length})'),
                        const SizedBox(height: 8),
                        DraggableMemoList(
                            memos: memos.pinned, showUnfile: true),
                      ],
                      if (memos.pinned.isNotEmpty &&
                          memos.others.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        MemoSectionLabel(
                            icon: Icons.notes,
                            text: '메모 (${memos.others.length})'),
                        const SizedBox(height: 8),
                      ],
                      if (memos.others.isNotEmpty)
                        DraggableMemoList(
                            memos: memos.others, showUnfile: true),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

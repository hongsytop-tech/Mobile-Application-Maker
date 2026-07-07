import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../auth/services/sync_manager.dart';
import '../../../shared/widgets/scroll_to_top.dart';
import '../models/memo.dart';
import '../providers/memo_providers.dart';
import '../services/memo_markup.dart';
import '../services/memo_url_helper.dart'
    if (dart.library.html) '../services/memo_url_helper_web.dart';
import 'memo_edit_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    final asyncMemos = ref.watch(memosProvider);
    final sorted = ref.watch(sortedMemosProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('메모'),
        actions: [
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
              if (sorted.isEmpty) {
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
              return _AutoScrollOnDrag(
                controller: _scrollCtrl,
                child: ListView(
                  controller: _scrollCtrl,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                  children: [
                    if (sorted.pinned.isNotEmpty) ...[
                      _SectionLabel(
                        icon: Icons.push_pin,
                        text: '고정됨 (${sorted.pinned.length})',
                      ),
                      const SizedBox(height: 8),
                      _DraggableMemoList(memos: sorted.pinned),
                    ],
                    if (sorted.pinned.isNotEmpty &&
                        sorted.others.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _SectionLabel(
                        icon: Icons.notes,
                        text: '전체 (${sorted.others.length})',
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (sorted.others.isNotEmpty)
                      _DraggableMemoList(memos: sorted.others),
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

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  const _SectionLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

/// 같은 섹션(pinned 또는 others) 내 드래그-드롭 순서 변경.
class _DraggableMemoList extends ConsumerWidget {
  final List<Memo> memos;
  const _DraggableMemoList({required this.memos});

  void _dropBefore(WidgetRef ref, String sourceId, String targetId) {
    if (sourceId == targetId) return;
    final ids = memos.map((m) => m.id).toList();
    if (!ids.contains(sourceId) || !ids.contains(targetId)) return;
    ids.remove(sourceId);
    final tgt = ids.indexOf(targetId);
    if (tgt < 0) return;
    ids.insert(tgt, sourceId);
    ref.read(memosProvider.notifier).reorder(ids);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        for (final m in memos)
          DragTarget<String>(
            onWillAcceptWithDetails: (d) =>
                d.data != m.id && memos.any((x) => x.id == d.data),
            onAcceptWithDetails: (d) => _dropBefore(ref, d.data, m.id),
            builder: (context, candidate, _) {
              final hovering = candidate.isNotEmpty;
              return Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: hovering
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      width: hovering ? 2 : 0,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _MemoCard(memo: m),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _MemoCard extends ConsumerStatefulWidget {
  final Memo memo;
  const _MemoCard({required this.memo});

  @override
  ConsumerState<_MemoCard> createState() => _MemoCardState();
}

class _MemoCardState extends ConsumerState<_MemoCard> {
  bool _dragging = false;

  Memo get memo => widget.memo;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('이 메모를 삭제할까요?'),
        content: Text(memo.title.isEmpty ? '(제목 없음)' : memo.title,
            style: const TextStyle(fontSize: 13, color: Colors.grey)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(memosProvider.notifier).remove(memo.id);
    }
  }

  Future<void> _showShortcut(BuildContext context) async {
    final url = buildMemoShareUrl(memo.id);
    final title = memo.title.trim().isEmpty ? '(제목 없음)' : memo.title;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('홈 화면 바로가기'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('"$title" 메모를 바로 열 수 있는 URL입니다.',
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SelectableText(
                url,
                style:
                    const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 12),
            const Text('홈 화면에 추가하는 방법',
                style:
                    TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text(
              '1. 아래 "URL 복사" 버튼을 누르세요\n'
              '2. 모바일 브라우저(Safari/Chrome)에서 새 탭을 열고 주소창에 붙여넣기\n'
              '3. 브라우저 메뉴 → "홈 화면에 추가" 선택\n'
              '4. 홈 화면 아이콘을 누르면 이 메모가 바로 열립니다',
              style: TextStyle(fontSize: 12, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('닫기')),
          FilledButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('URL 복사'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('URL이 복사되었어요'),
                      duration: Duration(seconds: 2)),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy.MM.dd HH:mm');
    final primary = Theme.of(context).colorScheme.primary;
    final isPinned = memo.isPinned;

    final preview = memo.content
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trimRight())
        .join('\n')
        .trim();
    final title = memo.title.trim().isEmpty ? '(제목 없음)' : memo.title;

    final card = Material(
      color: isPinned ? primary.withOpacity(0.06) : Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MemoEditScreen(memo: memo)),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPinned ? primary.withOpacity(0.4) : Colors.grey.shade300,
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: memo.title.trim().isEmpty ? Colors.grey : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () =>
                        ref.read(memosProvider.notifier).togglePin(memo.id),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                        size: 20,
                        color: isPinned ? primary : Colors.grey.shade400,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => _showShortcut(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.add_to_home_screen_outlined,
                          size: 20, color: Colors.blue.shade400),
                    ),
                  ),
                  InkWell(
                    onTap: () => _confirmDelete(context, ref),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.delete_outline,
                          size: 20, color: Colors.red.shade400),
                    ),
                  ),
                  // 드래그 핸들 — 길게 눌러 위아래로 끌기
                  LongPressDraggable<String>(
                    data: memo.id,
                    axis: Axis.vertical,
                    dragAnchorStrategy: (d, ctx, pos) =>
                        Offset(pos.dx - 12, 25),
                    onDragStarted: () => setState(() => _dragging = true),
                    onDragEnd: (_) => setState(() => _dragging = false),
                    onDraggableCanceled: (_, __) =>
                        setState(() => _dragging = false),
                    feedback: SizedBox(
                      width: MediaQuery.of(context).size.width - 24,
                      child: Material(
                        color: Colors.transparent,
                        elevation: 6,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: primary.withOpacity(0.4), width: 1),
                          ),
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    childWhenDragging: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.drag_handle,
                          size: 22, color: Colors.grey),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.drag_handle,
                          size: 22, color: Colors.grey),
                    ),
                  ),
                ],
              ),
              if (preview.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    children: memoSpans(
                      preview,
                      TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          height: 1.4),
                    ),
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time,
                      size: 12, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    df.format(memo.updatedAt),
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 120),
      opacity: _dragging ? 0.35 : 1.0,
      child: card,
    );
  }
}

/// 드래그 중 화면 상/하 가장자리에 손가락이 들어오면 자동 스크롤.
class _AutoScrollOnDrag extends StatefulWidget {
  final Widget child;
  final ScrollController controller;
  final double edgeSize;

  const _AutoScrollOnDrag({
    required this.child,
    required this.controller,
    this.edgeSize = 90,
  });

  @override
  State<_AutoScrollOnDrag> createState() => _AutoScrollOnDragState();
}

class _AutoScrollOnDragState extends State<_AutoScrollOnDrag> {
  Timer? _timer;
  double _direction = 0;
  DateTime _lastMove = DateTime.fromMillisecondsSinceEpoch(0);

  void _ensureScrolling(double dir) {
    _direction = dir;
    _lastMove = DateTime.now();
    if (_timer != null) return;
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (DateTime.now().difference(_lastMove) >
          const Duration(milliseconds: 100)) {
        _stop();
        return;
      }
      final ctrl = widget.controller;
      if (!ctrl.hasClients) return;
      final pos = ctrl.position;
      final next = (ctrl.offset + _direction * 10)
          .clamp(pos.minScrollExtent, pos.maxScrollExtent);
      if (next == ctrl.offset) {
        _stop();
        return;
      }
      ctrl.jumpTo(next);
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: widget.edgeSize,
          child: DragTarget<Object>(
            onWillAcceptWithDetails: (_) => true,
            onMove: (_) => _ensureScrolling(-1),
            onLeave: (_) => _stop(),
            onAcceptWithDetails: (_) {},
            builder: (_, __, ___) =>
                const IgnorePointer(child: SizedBox.expand()),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: widget.edgeSize,
          child: DragTarget<Object>(
            onWillAcceptWithDetails: (_) => true,
            onMove: (_) => _ensureScrolling(1),
            onLeave: (_) => _stop(),
            onAcceptWithDetails: (_) {},
            builder: (_, __, ___) =>
                const IgnorePointer(child: SizedBox.expand()),
          ),
        ),
      ],
    );
  }
}

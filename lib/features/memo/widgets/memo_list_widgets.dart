import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/memo.dart';
import '../providers/memo_providers.dart';
import '../services/memo_markup.dart';
import '../services/memo_url_helper.dart'
    if (dart.library.html) '../services/memo_url_helper_web.dart';
import '../screens/memo_edit_screen.dart';

class MemoSectionLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  const MemoSectionLabel({super.key, required this.icon, required this.text});

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

/// 같은 섹션 내 드래그-드롭 순서 변경.
class DraggableMemoList extends ConsumerWidget {
  final List<Memo> memos;
  final bool showUnfile;
  const DraggableMemoList(
      {super.key, required this.memos, this.showUnfile = false});

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
                  child: MemoCard(memo: m, showUnfile: showUnfile),
                ),
              );
            },
          ),
      ],
    );
  }
}

class MemoCard extends ConsumerStatefulWidget {
  final Memo memo;

  /// 폴더 화면 안에서 "폴더에서 빼기" 아이콘을 표시할지.
  final bool showUnfile;
  const MemoCard({super.key, required this.memo, this.showUnfile = false});

  @override
  ConsumerState<MemoCard> createState() => _MemoCardState();
}

class _MemoCardState extends ConsumerState<MemoCard> {
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
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
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
                  if (widget.showUnfile)
                    InkWell(
                      onTap: () => ref
                          .read(memosProvider.notifier)
                          .setFolder(memo.id, null),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.folder_off_outlined,
                            size: 20, color: Colors.orange.shade400),
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
                  LongPressDraggable<String>(
                    data: memo.id,
                    axis: null,
                    dragAnchorStrategy: (d, ctx, pos) => Offset(pos.dx - 12, 25),
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
                      child:
                          Icon(Icons.drag_handle, size: 22, color: Colors.grey),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child:
                          Icon(Icons.drag_handle, size: 22, color: Colors.grey),
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
                  Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    df.format(memo.updatedAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
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
class MemoAutoScrollOnDrag extends StatefulWidget {
  final Widget child;
  final ScrollController controller;
  final double edgeSize;

  const MemoAutoScrollOnDrag({
    super.key,
    required this.child,
    required this.controller,
    this.edgeSize = 90,
  });

  @override
  State<MemoAutoScrollOnDrag> createState() => _MemoAutoScrollOnDragState();
}

class _MemoAutoScrollOnDragState extends State<MemoAutoScrollOnDrag> {
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

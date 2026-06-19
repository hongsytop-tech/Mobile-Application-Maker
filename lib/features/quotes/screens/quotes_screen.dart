import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/quote.dart';
import '../providers/quote_providers.dart';
import 'quote_edit_screen.dart';
import 'quote_rotation_settings_screen.dart';

class QuotesScreen extends ConsumerStatefulWidget {
  const QuotesScreen({super.key});

  @override
  ConsumerState<QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends ConsumerState<QuotesScreen> {
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncQuotes = ref.watch(quotesProvider);
    final sorted = ref.watch(sortedQuotesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('기억하고 싶은 문구'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: FilledButton.tonalIcon(
              icon: const Icon(Icons.campaign, size: 18),
              label: const Text('순차 알림'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const QuoteRotationSettingsScreen(),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const QuoteEditScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('문구 추가'),
      ),
      body: asyncQuotes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (_) {
          if (sorted.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  '아직 저장된 문구가 없어요.\n오른쪽 아래에서 새 문구를 추가해 보세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }
          return _AutoScrollOnDrag(
            controller: _scrollCtrl,
            child: ListView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (sorted.pinned.isNotEmpty) ...[
                  _SectionLabel(
                    icon: Icons.push_pin,
                    text: '고정됨 (${sorted.pinned.length})',
                  ),
                  const SizedBox(height: 8),
                  _DraggableQuoteList(quotes: sorted.pinned),
                ],
                if (sorted.pinned.isNotEmpty &&
                    sorted.others.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _SectionLabel(
                    icon: Icons.history,
                    text: '전체 (${sorted.others.length})',
                  ),
                  const SizedBox(height: 8),
                ],
                if (sorted.others.isNotEmpty)
                  _DraggableQuoteList(quotes: sorted.others),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 같은 섹션(pinned 또는 others) 내 드래그-드롭 순서 변경.
/// 각 카드 핸들을 길게 눌러 들고 다른 카드 위에 놓으면 그 위치 앞에 삽입.
class _DraggableQuoteList extends ConsumerWidget {
  final List<Quote> quotes;
  const _DraggableQuoteList({required this.quotes});

  void _dropBefore(WidgetRef ref, String sourceId, String targetId) {
    if (sourceId == targetId) return;
    final ids = quotes.map((q) => q.id).toList();
    if (!ids.contains(sourceId) || !ids.contains(targetId)) return; // 다른 섹션은 무시
    ids.remove(sourceId);
    final tgt = ids.indexOf(targetId);
    if (tgt < 0) return;
    ids.insert(tgt, sourceId);
    ref.read(quotesProvider.notifier).reorder(ids);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        for (final q in quotes)
          DragTarget<String>(
            onWillAcceptWithDetails: (d) =>
                d.data != q.id && quotes.any((x) => x.id == d.data),
            onAcceptWithDetails: (d) => _dropBefore(ref, d.data, q.id),
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
                  child: _QuoteCard(quote: q),
                ),
              );
            },
          ),
      ],
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

class _QuoteCard extends ConsumerStatefulWidget {
  final Quote quote;
  const _QuoteCard({required this.quote});

  @override
  ConsumerState<_QuoteCard> createState() => _QuoteCardState();
}

class _QuoteCardState extends ConsumerState<_QuoteCard> {
  bool _dragging = false;

  Quote get quote => widget.quote;

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Quote q) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('이 문구를 삭제할까요?'),
        content: Text(q.text,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
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
      await ref.read(quotesProvider.notifier).remove(q.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy.MM.dd');
    final primary = Theme.of(context).colorScheme.primary;
    final isPinned = quote.isPinned;

    final card = Dismissible(
      key: ValueKey('dismiss_${quote.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async => await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('이 문구를 삭제할까요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('삭제'),
            ),
          ],
        ),
      ),
      onDismissed: (_) => ref.read(quotesProvider.notifier).remove(quote.id),
      child: Material(
        color: isPinned ? primary.withOpacity(0.06) : Colors.white,
        elevation: 0,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => QuoteEditScreen(quote: quote),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isPinned
                    ? primary.withOpacity(0.4)
                    : Colors.grey.shade300,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        quote.text,
                        style: const TextStyle(fontSize: 15, height: 1.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => ref
                          .read(quotesProvider.notifier)
                          .togglePin(quote.id),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          isPinned
                              ? Icons.push_pin
                              : Icons.push_pin_outlined,
                          size: 20,
                          color: isPinned ? primary : Colors.grey.shade400,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => _confirmDelete(context, ref, quote),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: Colors.red.shade400,
                        ),
                      ),
                    ),
                    // 드래그 핸들 — 길게 눌러 위아래로 끌기
                    LongPressDraggable<String>(
                      data: quote.id,
                      axis: Axis.vertical,
                      dragAnchorStrategy: (d, ctx, pos) =>
                          Offset(pos.dx - 12, 25),
                      onDragStarted: () =>
                          setState(() => _dragging = true),
                      onDragEnd: (_) =>
                          setState(() => _dragging = false),
                      onDraggableCanceled: (_, __) =>
                          setState(() => _dragging = false),
                      feedback: SizedBox(
                        width: MediaQuery.of(context).size.width - 24,
                        child: Material(
                          color: Colors.transparent,
                          elevation: 6,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: primary.withOpacity(0.4),
                                  width: 1),
                            ),
                            child: Text(
                              quote.text,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 15, height: 1.5),
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.event_note,
                        size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      df.format(quote.createdAt),
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                    if (quote.hasSchedule) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.notifications_active,
                          size: 14, color: primary),
                      const SizedBox(width: 4),
                      Text(
                        quote.scheduleLabel(null) ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
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

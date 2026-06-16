import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/quote.dart';
import '../providers/quote_providers.dart';
import 'quote_edit_screen.dart';
import 'quote_rotation_settings_screen.dart';

class QuotesScreen extends ConsumerWidget {
  const QuotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            children: [
              if (sorted.pinned.isNotEmpty) ...[
                _SectionLabel(
                  icon: Icons.push_pin,
                  text: '고정됨 (${sorted.pinned.length})',
                ),
                const SizedBox(height: 8),
                _ReorderableQuotes(
                  quotes: sorted.pinned,
                  onReorder: (oldIdx, newIdx) {
                    if (newIdx > oldIdx) newIdx -= 1;
                    final ids = sorted.pinned.map((q) => q.id).toList();
                    final moved = ids.removeAt(oldIdx);
                    ids.insert(newIdx, moved);
                    ref.read(quotesProvider.notifier).reorder(ids);
                  },
                ),
                if (sorted.others.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _SectionLabel(
                    icon: Icons.history,
                    text: '전체 (${sorted.others.length})',
                  ),
                  const SizedBox(height: 8),
                ],
              ],
              if (sorted.others.isNotEmpty)
                _ReorderableQuotes(
                  quotes: sorted.others,
                  onReorder: (oldIdx, newIdx) {
                    if (newIdx > oldIdx) newIdx -= 1;
                    final ids = sorted.others.map((q) => q.id).toList();
                    final moved = ids.removeAt(oldIdx);
                    ids.insert(newIdx, moved);
                    ref.read(quotesProvider.notifier).reorder(ids);
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ReorderableQuotes extends ConsumerWidget {
  final List<Quote> quotes;
  final void Function(int oldIdx, int newIdx) onReorder;

  const _ReorderableQuotes({required this.quotes, required this.onReorder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: quotes.length,
      onReorder: onReorder,
      proxyDecorator: (child, index, animation) => Material(
        color: Colors.transparent,
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        child: child,
      ),
      itemBuilder: (context, i) {
        final q = quotes[i];
        return Padding(
          key: ValueKey(q.id),
          padding: const EdgeInsets.only(bottom: 8),
          child: _QuoteCard(quote: q, index: i),
        );
      },
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

class _QuoteCard extends ConsumerWidget {
  final Quote quote;
  final int index;
  const _QuoteCard({required this.quote, required this.index});

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Quote q) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('이 문구를 삭제할까요?'),
        content: Text(q.text,
            maxLines: 4, overflow: TextOverflow.ellipsis,
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
  Widget build(BuildContext context, WidgetRef ref) {
    final df = DateFormat('yyyy.MM.dd');
    final primary = Theme.of(context).colorScheme.primary;
    final isPinned = quote.isPinned;

    return Dismissible(
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
                    ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.drag_handle,
                          size: 22,
                          color: Colors.grey,
                        ),
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
  }
}

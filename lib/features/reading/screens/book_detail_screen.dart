import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/book.dart';
import '../providers/book_providers.dart';
import '../services/book_toc_service.dart';
import '../widgets/book_cover.dart';

class BookDetailScreen extends ConsumerStatefulWidget {
  final String bookId;
  const BookDetailScreen({super.key, required this.bookId});

  @override
  ConsumerState<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends ConsumerState<BookDetailScreen> {
  bool _fetching = false;
  bool _autoFetchAttempted = false;

  /// 체크박스 드래프트 — 저장 전까지의 임시 상태 (인덱스 → 읽음 여부)
  /// null이면 드래프트 없음(저장된 상태와 동일).
  Map<int, bool>? _draftToc;
  bool _savingToc = false;

  static final _won = NumberFormat('#,###');

  bool _draftIsRead(Book book, int i) {
    return _draftToc?[i] ?? book.toc[i].isRead;
  }

  bool get _hasDraftChanges => _draftToc != null && _draftToc!.isNotEmpty;

  void _toggleDraft(Book book, int i) {
    setState(() {
      _draftToc ??= {};
      final newValue = !_draftIsRead(book, i);
      // 원래 값과 같아지면 드래프트에서 제거 (변경 없음 처리)
      if (newValue == book.toc[i].isRead) {
        _draftToc!.remove(i);
      } else {
        _draftToc![i] = newValue;
      }
      if (_draftToc!.isEmpty) _draftToc = null;
    });
  }

  void _discardDraft() {
    setState(() => _draftToc = null);
  }

  Future<void> _saveDraft(Book book) async {
    if (_draftToc == null || _draftToc!.isEmpty) return;
    setState(() => _savingToc = true);
    try {
      final newToc = [
        for (int i = 0; i < book.toc.length; i++)
          book.toc[i].copyWith(isRead: _draftIsRead(book, i)),
      ];
      await ref.read(booksProvider.notifier).setToc(book.id, newToc);
      if (mounted) {
        setState(() => _draftToc = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('진행도 저장 완료')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingToc = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(booksProvider).value ?? const <Book>[];
    final book = books.where((b) => b.id == widget.bookId).firstOrNull;

    if (book == null) {
      return const Scaffold(body: Center(child: Text('책을 찾을 수 없어요')));
    }

    // 최초 진입 시 메타데이터(가격·링크·TOC) 자동 시도
    if (!_autoFetchAttempted &&
        book.isbn.isNotEmpty &&
        book.priceStandard == null &&
        book.aladinLink == null) {
      _autoFetchAttempted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchMetadata(book, showErrorSnack: false);
      });
    }

    final isReading = book.status == BookStatus.reading;

    return PopScope(
      canPop: !_hasDraftChanges,
      onPopInvoked: (didPop) async {
        if (didPop || !_hasDraftChanges) return;
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('저장하지 않은 변경이 있어요'),
            content: const Text('지금까지의 체크 변경을 버리고 나갈까요?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('계속 편집'),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('버리고 나가기'),
              ),
            ],
          ),
        );
        if (ok == true && mounted) {
          setState(() => _draftToc = null);
          Navigator.of(context).pop();
        }
      },
      child: _buildScaffold(book, isReading),
    );
  }

  Widget _buildScaffold(Book book, bool isReading) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('책 상세'),
        actions: [
          IconButton(
            tooltip: '삭제',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(book.id),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _BookHeader(book: book),
          const SizedBox(height: 20),
          _PriceAndLinks(
            book: book,
            fetching: _fetching,
            onRefresh: () => _fetchMetadata(book, forceRefresh: true),
          ),
          if (book.description.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('소개', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(book.description),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Text('목차', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('편집'),
                onPressed: () => _editToc(book),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (book.toc.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                '목차를 직접 추가해 진행도를 관리할 수 있어요.\n"편집"을 눌러 한 줄에 하나씩 챕터를 입력하세요.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            )
          else
            ...List.generate(book.toc.length, (i) {
              final item = book.toc[i];
              final isRead = _draftIsRead(book, i);
              final changed =
                  _draftToc != null && _draftToc!.containsKey(i);
              return CheckboxListTile(
                value: isRead,
                onChanged: (_) => _toggleDraft(book, i),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          decoration:
                              isRead ? TextDecoration.lineThrough : null,
                          color: isRead ? Colors.grey : null,
                        ),
                      ),
                    ),
                    if (changed) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              );
            }),
          if (_hasDraftChanges) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.edit_note,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_draftToc!.length}개 항목 변경됨',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _savingToc ? null : _discardDraft,
                          child: const Text('취소'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed:
                              _savingToc ? null : () => _saveDraft(book),
                          icon: _savingToc
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white),
                                )
                              : const Icon(Icons.save, size: 18),
                          label: const Text('진행도 저장'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          if (book.status == BookStatus.wishlist)
            FilledButton.icon(
              icon: const Icon(Icons.menu_book),
              label: const Text('읽기 시작'),
              onPressed: () async {
                await ref.read(booksProvider.notifier).markReading(book.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('"읽고 있는 책"으로 옮겼어요')),
                  );
                }
              },
            )
          else if (isReading)
            FilledButton.icon(
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('다 읽었어요'),
              onPressed: () async {
                await ref.read(booksProvider.notifier).markFinished(book.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('완독한 책에 저장했어요 🎉')),
                  );
                }
              },
            )
          else
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('다시 읽는 중으로 변경'),
              onPressed: () =>
                  ref.read(booksProvider.notifier).markReading(book.id),
            ),
        ],
      ),
    );
  }

  Future<void> _fetchMetadata(
    Book book, {
    bool showErrorSnack = true,
    bool forceRefresh = false,
  }) async {
    setState(() => _fetching = true);
    try {
      final svc = ref.read(bookTocServiceProvider);
      final meta = await svc.fetch(
        isbn: book.isbn,
        title: book.title,
        forceRefresh: forceRefresh,
      );
      await ref.read(booksProvider.notifier).applyMetadata(book.id, meta);
      if (mounted && meta.hasAnything) {
        final msgs = <String>[];
        if (meta.toc.isNotEmpty) msgs.add('목차 ${meta.toc.length}개');
        if (meta.priceSales != null) msgs.add('가격');
        if (meta.aladinLink != null || meta.kyoboLink != null) msgs.add('구매 링크');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${msgs.join(' · ')} 가져왔어요')),
        );
      }
    } on TocServiceUnavailable catch (e) {
      if (showErrorSnack && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (showErrorSnack && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('정보 가져오기 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  Future<void> _editToc(Book book) async {
    final controller = TextEditingController(
      text: book.toc.map((e) => e.title).join('\n'),
    );
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('목차 편집'),
        content: SizedBox(
          width: 480,
          child: TextField(
            controller: controller,
            maxLines: 12,
            minLines: 6,
            decoration: const InputDecoration(
              hintText: '한 줄에 하나씩 챕터를 입력하세요\n예)\n1장. 시작\n2장. 핵심 원리\n...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (result == null) return;
    final existingMap = {for (final e in book.toc) e.title: e.isRead};
    final newToc = result
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map((s) => TocItem(title: s, isRead: existingMap[s] ?? false))
        .toList();
    await ref.read(booksProvider.notifier).setToc(widget.bookId, newToc);
  }

  Future<void> _confirmDelete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('정말 삭제할까요?'),
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
    );
    if (confirm == true && mounted) {
      await ref.read(booksProvider.notifier).remove(id);
      if (mounted) Navigator.of(context).pop();
    }
  }
}

class _BookHeader extends StatelessWidget {
  final Book book;
  const _BookHeader({required this.book});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BookCover(url: book.thumbnail, width: 96, height: 140),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(book.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(book.authors.join(', '),
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 4),
              Text(book.publisher,
                  style:
                      const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: book.progress,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
              ),
              const SizedBox(height: 4),
              Text(
                '진행도 ${(book.progress * 100).round()}%'
                '${book.toc.isEmpty ? "" : " (${book.toc.where((e) => e.isRead).length}/${book.toc.length})"}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PriceAndLinks extends StatelessWidget {
  final Book book;
  final bool fetching;
  final VoidCallback onRefresh;

  const _PriceAndLinks({
    required this.book,
    required this.fetching,
    required this.onRefresh,
  });

  static final _won = NumberFormat('#,###');

  @override
  Widget build(BuildContext context) {
    final hasPrice = book.priceStandard != null || book.priceSales != null;
    final links = <_LinkSpec>[
      if (book.aladinLink != null)
        _LinkSpec(label: '알라딘에서 구매', url: book.aladinLink!, isPrimary: true),
      if (book.kyoboLink != null)
        _LinkSpec(label: '교보문고 정보', url: book.kyoboLink!),
      if (book.coupangLink != null)
        _LinkSpec(label: '쿠팡에서 구매', url: book.coupangLink!),
    ];

    if (!hasPrice && links.isEmpty) {
      return OutlinedButton.icon(
        onPressed: fetching ? null : onRefresh,
        icon: fetching
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.cloud_download_outlined, size: 18),
        label: const Text('가격·구매 링크 가져오기'),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (hasPrice) ...[
                if (book.priceSales != null) ...[
                  Text(
                    '${_won.format(book.priceSales)}원',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (book.priceStandard != null &&
                    book.priceStandard != book.priceSales)
                  Text(
                    '${_won.format(book.priceStandard)}원',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
              ] else
                const Text('가격 정보 없음',
                    style: TextStyle(color: Colors.grey)),
              const Spacer(),
              IconButton(
                tooltip: '다시 불러오기',
                onPressed: fetching ? null : onRefresh,
                icon: fetching
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 18),
              ),
            ],
          ),
          if (links.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: links.map((l) => _linkButton(l)).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _linkButton(_LinkSpec l) {
    final onTap = () async {
      final uri = Uri.parse(l.url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    };
    return l.isPrimary
        ? FilledButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(l.label),
          )
        : OutlinedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(l.label),
          );
  }
}

class _LinkSpec {
  final String label;
  final String url;
  final bool isPrimary;
  const _LinkSpec({
    required this.label,
    required this.url,
    this.isPrimary = false,
  });
}

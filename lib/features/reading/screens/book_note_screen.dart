import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/book.dart';
import '../models/book_note.dart';
import '../providers/book_providers.dart';

/// 독서 노트 한 건 편집 (위치 + 내용).
/// [existing] 이 null 이면 신규 추가, 있으면 기존 노트 수정.
class BookNoteEditScreen extends ConsumerStatefulWidget {
  final String bookId;
  final BookNote? existing;
  const BookNoteEditScreen({super.key, required this.bookId, this.existing});

  @override
  ConsumerState<BookNoteEditScreen> createState() =>
      _BookNoteEditScreenState();
}

class _BookNoteEditScreenState extends ConsumerState<BookNoteEditScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _locationCtrl;
  late final TextEditingController _contentCtrl;
  final FocusNode _contentFocus = FocusNode();
  bool _dirty = false;
  bool _saving = false;

  /// 처음 저장 시 생성된 노트 — 이후 자동저장은 이 ID 에 update.
  BookNote? _createdNote;

  bool get _isNew => widget.existing == null && _createdNote == null;
  BookNote? get _currentExisting => widget.existing ?? _createdNote;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locationCtrl = TextEditingController(text: widget.existing?.location ?? '');
    _contentCtrl = TextEditingController(text: widget.existing?.content ?? '');
    _locationCtrl.addListener(_markDirty);
    _contentCtrl.addListener(_markDirty);
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _contentFocus.dispose();
    _locationCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      if (_dirty) _save(silent: true);
    }
  }

  Future<void> _save({bool silent = false}) async {
    if (_saving) return;
    _saving = true;
    try {
      final location = _locationCtrl.text.trim();
      final content = _contentCtrl.text.trim();
      final notifier = ref.read(booksProvider.notifier);
      final existing = _currentExisting;
      if (existing == null) {
        // 둘 다 비어있으면 저장 생략 (빈 노트 방지)
        if (location.isEmpty && content.isEmpty) return;
        final created = await notifier.addNoteEntry(
          widget.bookId,
          content: content,
          location: location,
        );
        _createdNote = created;
      } else {
        await notifier.updateNoteEntry(
          widget.bookId,
          existing.copyWith(
            content: content,
            location: location,
            updatedAt: DateTime.now(),
          ),
        );
      }
      if (mounted) {
        setState(() => _dirty = false);
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('저장됨'),
                duration: Duration(milliseconds: 800)),
          );
        }
      }
    } finally {
      _saving = false;
    }
  }

  void _padToTapAndFocus(Offset localPosition) {
    const topPadding = 16.0;
    const lineHeight = 24.0;
    final relativeY = localPosition.dy - topPadding;
    if (relativeY > 0) {
      final tappedLine = (relativeY / lineHeight).floor();
      final currentLines = _contentCtrl.text.split('\n').length;
      if (tappedLine >= currentLines) {
        final extra = tappedLine - currentLines + 1;
        final newText = _contentCtrl.text + ('\n' * extra);
        _contentCtrl.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newText.length),
        );
      }
    }
    if (!_contentFocus.hasFocus) _contentFocus.requestFocus();
  }

  Book? _findBook() {
    final list = ref.read(booksProvider).value ?? const <Book>[];
    return list.where((b) => b.id == widget.bookId).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final bookTitle = _findBook()?.title ?? '독서노트';
    return PopScope(
      canPop: !_dirty,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (_dirty) await _save(silent: true);
        if (mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? '새 노트 — $bookTitle' : '노트 — $bookTitle',
              maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: '저장',
              onPressed: _dirty ? _save : null,
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 위치 입력
              TextField(
                controller: _locationCtrl,
                decoration: const InputDecoration(
                  labelText: '위치',
                  hintText: '예: p.42 / 3장 도입부 / ch.5 §2',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.place_outlined),
                ),
                maxLines: 1,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                enableSuggestions: false,
                enableIMEPersonalizedLearning: false,
                magnifierConfiguration: TextMagnifierConfiguration.disabled,
              ),
              const SizedBox(height: 12),
              // 내용 입력 (남은 공간 전체)
              Expanded(
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (event) =>
                      _padToTapAndFocus(event.localPosition),
                  child: TextField(
                    controller: _contentCtrl,
                    focusNode: _contentFocus,
                    maxLines: null,
                    expands: true,
                    decoration: const InputDecoration(
                      labelText: '내용',
                      hintText: '인상 깊은 문구나 떠오른 생각을 적어보세요...',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    textAlignVertical: TextAlignVertical.top,
                    autocorrect: false,
                    enableSuggestions: false,
                    enableIMEPersonalizedLearning: false,
                    magnifierConfiguration:
                        TextMagnifierConfiguration.disabled,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

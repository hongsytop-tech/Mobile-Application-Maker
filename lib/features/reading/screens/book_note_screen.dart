import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/book.dart';
import '../providers/book_providers.dart';

/// 책 한 권의 독서 노트 편집 화면 (메모 편집과 동일한 패턴).
class BookNoteScreen extends ConsumerStatefulWidget {
  final String bookId;
  const BookNoteScreen({super.key, required this.bookId});

  @override
  ConsumerState<BookNoteScreen> createState() => _BookNoteScreenState();
}

class _BookNoteScreenState extends ConsumerState<BookNoteScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _ctrl;
  final FocusNode _focus = FocusNode();
  bool _dirty = false;
  bool _saving = false;
  String _initial = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final book = _findBook();
    _initial = book?.notes ?? '';
    _ctrl = TextEditingController(text: _initial);
    _ctrl.addListener(_onChanged);
  }

  Book? _findBook() {
    final list = ref.read(booksProvider).value ?? const <Book>[];
    return list.where((b) => b.id == widget.bookId).firstOrNull;
  }

  void _onChanged() {
    final changed = _ctrl.text != _initial;
    if (changed != _dirty) setState(() => _dirty = changed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focus.dispose();
    _ctrl.dispose();
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
      final text = _ctrl.text;
      await ref.read(booksProvider.notifier).setNotes(widget.bookId, text);
      if (mounted) {
        setState(() {
          _initial = text;
          _dirty = false;
        });
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
      final currentLines = _ctrl.text.split('\n').length;
      if (tappedLine >= currentLines) {
        final extra = tappedLine - currentLines + 1;
        final newText = _ctrl.text + ('\n' * extra);
        _ctrl.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newText.length),
        );
      }
    }
    if (!_focus.hasFocus) _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final book = _findBook();
    final title = book?.title ?? '독서노트';
    return PopScope(
      canPop: !_dirty,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (_dirty) await _save(silent: true);
        if (mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
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
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (event) => _padToTapAndFocus(event.localPosition),
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              maxLines: null,
              expands: true,
              decoration: const InputDecoration(
                hintText: '책에 대한 메모를 자유롭게 남겨보세요...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              textAlignVertical: TextAlignVertical.top,
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              magnifierConfiguration: TextMagnifierConfiguration.disabled,
            ),
          ),
        ),
      ),
    );
  }
}

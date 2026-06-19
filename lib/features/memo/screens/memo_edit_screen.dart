import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/memo.dart';
import '../providers/memo_providers.dart';

class MemoEditScreen extends ConsumerStatefulWidget {
  final Memo? memo;
  const MemoEditScreen({super.key, this.memo});

  @override
  ConsumerState<MemoEditScreen> createState() => _MemoEditScreenState();
}

class _MemoEditScreenState extends ConsumerState<MemoEditScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  final FocusNode _contentFocus = FocusNode();
  bool _dirty = false;
  bool _saving = false;

  bool get _isNew => widget.memo == null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _titleCtrl = TextEditingController(text: widget.memo?.title ?? '');
    _contentCtrl = TextEditingController(text: widget.memo?.content ?? '');
    _titleCtrl.addListener(_markDirty);
    _contentCtrl.addListener(_markDirty);
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _contentFocus.dispose();
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 백그라운드 진입 시 자동 저장
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
      final title = _titleCtrl.text.trim();
      final content = _contentCtrl.text;
      final notifier = ref.read(memosProvider.notifier);
      if (_isNew) {
        if (title.isEmpty && content.isEmpty) return;
        await notifier.add(title: title, content: content);
      } else {
        await notifier.save(widget.memo!.copyWith(
          title: title,
          content: content,
          updatedAt: DateTime.now(),
        ));
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

  void _focusContentAtEnd() {
    if (!_contentFocus.hasFocus) {
      _contentFocus.requestFocus();
    }
    // 빈 영역 탭 시 마지막 위치로 커서 이동
    final len = _contentCtrl.text.length;
    _contentCtrl.selection = TextSelection.collapsed(offset: len);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        // 뒤로가기 시 자동 저장
        if (_dirty) await _save(silent: true);
        if (mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? '새 메모' : '메모 편집'),
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
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  hintText: '제목 (선택)',
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
                maxLines: 1,
              ),
              const Divider(height: 16),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _focusContentAtEnd,
                  child: TextField(
                    controller: _contentCtrl,
                    focusNode: _contentFocus,
                    decoration: const InputDecoration(
                      hintText: '내용을 입력하세요...',
                      border: InputBorder.none,
                      isCollapsed: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    maxLines: null,
                    expands: true,
                    keyboardType: TextInputType.multiline,
                    textAlignVertical: TextAlignVertical.top,
                    scrollPadding: const EdgeInsets.only(bottom: 120),
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

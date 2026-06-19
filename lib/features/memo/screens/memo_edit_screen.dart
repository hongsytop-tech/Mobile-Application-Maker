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

class _MemoEditScreenState extends ConsumerState<MemoEditScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  bool _dirty = false;

  bool get _isNew => widget.memo == null;

  @override
  void initState() {
    super.initState();
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
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('저장됨'),
            duration: Duration(milliseconds: 800)),
      );
    }
  }

  Future<bool> _confirmExit() async {
    if (!_dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('저장하지 않은 변경이 있어요'),
        content: const Text('변경 사항을 저장할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('버리기'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _save();
      return true;
    }
    return ok == false; // 'false' means discard
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmExit() && mounted) {
          Navigator.of(context).pop();
        }
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
                ),
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
                maxLines: 1,
              ),
              const Divider(height: 16),
              Expanded(
                child: TextField(
                  controller: _contentCtrl,
                  decoration: const InputDecoration(
                    hintText: '내용을 입력하세요...',
                    border: InputBorder.none,
                  ),
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  keyboardType: TextInputType.multiline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

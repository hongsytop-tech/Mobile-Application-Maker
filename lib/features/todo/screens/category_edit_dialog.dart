import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/todo_category.dart';
import '../providers/todo_providers.dart';

Future<void> showCategoryEditDialog(
  BuildContext context,
  WidgetRef ref, {
  TodoCategory? category,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _CategoryEditDialog(category: category),
  );
}

class _CategoryEditDialog extends ConsumerStatefulWidget {
  final TodoCategory? category;
  const _CategoryEditDialog({this.category});

  @override
  ConsumerState<_CategoryEditDialog> createState() =>
      _CategoryEditDialogState();
}

class _CategoryEditDialogState extends ConsumerState<_CategoryEditDialog> {
  late final TextEditingController _ctrl;
  late int _colorIndex;

  bool get _isNew => widget.category == null;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.category?.name ?? '');
    _colorIndex = widget.category?.colorIndex ?? 0;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    final notifier = ref.read(todoCategoriesProvider.notifier);
    if (_isNew) {
      await notifier.add(name, _colorIndex);
    } else {
      await notifier.save(widget.category!.copyWith(
        name: name,
        colorIndex: _colorIndex,
      ));
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmDelete() async {
    Navigator.of(context).pop();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('"${widget.category!.name}" 카테고리를 삭제할까요?'),
        content: const Text('카테고리 안의 모든 할 일도 함께 삭제됩니다.'),
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
    if (ok == true) {
      await ref
          .read(todoCategoriesProvider.notifier)
          .remove(widget.category!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isNew ? '카테고리 추가' : '카테고리 편집'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '카테고리 이름 (예: 운동, 학습)',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          const Text('색상',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: List.generate(todoCategoryColors.length, (i) {
              final c = Color(todoCategoryColors[i]);
              final selected = i == _colorIndex;
              return GestureDetector(
                onTap: () => setState(() => _colorIndex = i),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? Colors.black : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check,
                          color: Colors.white, size: 18)
                      : null,
                ),
              );
            }),
          ),
        ],
      ),
      actions: [
        if (!_isNew)
          TextButton(
            onPressed: _confirmDelete,
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _save, child: const Text('저장')),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/diary.dart';
import '../providers/diary_providers.dart';

class DiaryEditScreen extends ConsumerStatefulWidget {
  final DateTime date;
  const DiaryEditScreen({super.key, required this.date});

  @override
  ConsumerState<DiaryEditScreen> createState() => _DiaryEditScreenState();
}

class _DiaryEditScreenState extends ConsumerState<DiaryEditScreen> {
  late DiaryMode _mode;
  late List<TextEditingController> _sentenceCtrls;
  late List<TextEditingController> _gratitudeCtrls;
  bool _saving = false;

  static const _newItemCount = 3;

  @override
  void initState() {
    super.initState();
    final existing =
        ref.read(diaryByDateProvider(Diary.normalize(widget.date)));
    _mode = existing?.mode ?? DiaryMode.sentences;
    // 옛 freeform 데이터는 모델 fromJson 에서 이미 sentences 로 옮겨졌으니
    // 여기서는 sentences 만 보면 된다.
    _sentenceCtrls = _initControllers(existing?.sentences ?? const []);
    _gratitudeCtrls = _initControllers(existing?.gratitudes ?? const []);
  }

  List<TextEditingController> _initControllers(List<String> source) {
    if (source.isEmpty) {
      return List.generate(_newItemCount, (_) => TextEditingController());
    }
    return source.map((s) => TextEditingController(text: s)).toList();
  }

  @override
  void dispose() {
    for (final c in _sentenceCtrls) {
      c.dispose();
    }
    for (final c in _gratitudeCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  List<TextEditingController> get _activeCtrls =>
      _mode == DiaryMode.gratitude ? _gratitudeCtrls : _sentenceCtrls;

  void _addItem() {
    setState(() => _activeCtrls.add(TextEditingController()));
  }

  void _removeItem(int i) {
    setState(() {
      _activeCtrls[i].dispose();
      _activeCtrls.removeAt(i);
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final sentences =
          _sentenceCtrls.map((c) => c.text.trim()).toList();
      final gratitudes =
          _gratitudeCtrls.map((c) => c.text.trim()).toList();
      final diary = Diary(
        date: Diary.normalize(widget.date),
        mode: _mode,
        sentences: sentences,
        gratitudes: gratitudes,
        updatedAt: DateTime.now(),
      );

      if (diary.isEmpty) {
        await ref
            .read(diariesProvider.notifier)
            .removeByDate(diary.date);
      } else {
        await ref.read(diariesProvider.notifier).upsert(diary);
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('이 일기를 삭제할까요?'),
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
          .read(diariesProvider.notifier)
          .removeByDate(Diary.normalize(widget.date));
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy년 M월 d일 (E)', 'ko_KR');
    final hasExisting =
        ref.watch(diaryByDateProvider(Diary.normalize(widget.date))) != null;
    final isGratitude = _mode == DiaryMode.gratitude;

    return Scaffold(
      appBar: AppBar(
        title: Text(df.format(widget.date)),
        actions: [
          if (hasExisting)
            IconButton(
              tooltip: '삭제',
              icon: const Icon(Icons.delete_outline),
              onPressed: _confirmDelete,
            ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('저장'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<DiaryMode>(
            segments: const [
              ButtonSegment(
                value: DiaryMode.sentences,
                label: Text('일상'),
                icon: Icon(Icons.format_list_bulleted),
              ),
              ButtonSegment(
                value: DiaryMode.gratitude,
                label: Text('감사 일기'),
                icon: Icon(Icons.favorite_outline),
              ),
            ],
            selected: {_mode},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: 16),
          _ItemList(
            controllers: _activeCtrls,
            hint: isGratitude ? '감사한 일 ' : '문장 ',
            addLabel: isGratitude ? '감사한 일 추가' : '문장 추가',
            onAdd: _addItem,
            onRemove: _removeItem,
          ),
        ],
      ),
    );
  }
}

class _ItemList extends StatelessWidget {
  final List<TextEditingController> controllers;
  final String hint;
  final String addLabel;
  final VoidCallback onAdd;
  final void Function(int) onRemove;

  const _ItemList({
    required this.controllers,
    required this.hint,
    required this.addLabel,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...List.generate(controllers.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 40,
                  alignment: Alignment.center,
                  child: Text(
                    '${i + 1}.',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: controllers[i],
                    minLines: 1,
                    maxLines: 4,
                    autofocus: i == 0 && controllers[i].text.isEmpty,
                    decoration: InputDecoration(
                      hintText: '$hint${i + 1}',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: '이 항목 제거',
                  onPressed:
                      controllers.length > 1 ? () => onRemove(i) : null,
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: Text(addLabel),
        ),
      ],
    );
  }
}

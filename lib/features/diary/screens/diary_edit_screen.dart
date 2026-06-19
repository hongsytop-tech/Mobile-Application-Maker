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
  late final TextEditingController _freeCtrl;
  late List<TextEditingController> _sentenceCtrls;
  bool _saving = false;

  static const _newSentenceCount = 3;

  @override
  void initState() {
    super.initState();
    final existing =
        ref.read(diaryByDateProvider(Diary.normalize(widget.date)));
    _mode = existing?.mode ?? DiaryMode.freeform;
    _freeCtrl = TextEditingController(text: existing?.freeText ?? '');
    final initSentences = existing?.sentences ?? const <String>[];
    _sentenceCtrls = initSentences.isEmpty
        ? List.generate(
            _newSentenceCount, (_) => TextEditingController())
        : initSentences
            .map((s) => TextEditingController(text: s))
            .toList();
  }

  @override
  void dispose() {
    _freeCtrl.dispose();
    for (final c in _sentenceCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _addSentence() {
    setState(() => _sentenceCtrls.add(TextEditingController()));
  }

  void _removeSentence(int i) {
    setState(() {
      _sentenceCtrls[i].dispose();
      _sentenceCtrls.removeAt(i);
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final sentences =
          _sentenceCtrls.map((c) => c.text.trim()).toList();
      final diary = Diary(
        date: Diary.normalize(widget.date),
        mode: _mode,
        freeText: _freeCtrl.text,
        sentences: sentences,
        updatedAt: DateTime.now(),
      );

      if (diary.isEmpty) {
        // 비어있으면 저장하지 않고 삭제 (있던 경우)
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
                value: DiaryMode.freeform,
                label: Text('서술형'),
                icon: Icon(Icons.notes),
              ),
              ButtonSegment(
                value: DiaryMode.sentences,
                label: Text('문장별'),
                icon: Icon(Icons.format_list_bulleted),
              ),
            ],
            selected: {_mode},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: 16),
          if (_mode == DiaryMode.freeform)
            TextField(
              controller: _freeCtrl,
              minLines: 16,
              maxLines: null,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '오늘 하루를 자유롭게 기록하세요...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              // 한글 IME 가 커서를 다음 줄로 밀어내는 안드로이드 문제 회피.
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              // CanvasKit 렌더러에서 선택 돋보기가 사라지지 않는 버그 회피.
              magnifierConfiguration: TextMagnifierConfiguration.disabled,
            )
          else
            _SentenceList(
              controllers: _sentenceCtrls,
              onAdd: _addSentence,
              onRemove: _removeSentence,
            ),
        ],
      ),
    );
  }
}

class _SentenceList extends StatelessWidget {
  final List<TextEditingController> controllers;
  final VoidCallback onAdd;
  final void Function(int) onRemove;

  const _SentenceList({
    required this.controllers,
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
                      hintText: '문장 ${i + 1}',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: '이 문장 제거',
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
          label: const Text('문장 추가'),
        ),
      ],
    );
  }
}

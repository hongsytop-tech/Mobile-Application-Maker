import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/exercise_log.dart';

/// 운동 기록 다이얼로그 결과.
class ExerciseLogInput {
  final String type;
  final List<int> reps; // 세트별 횟수
  const ExerciseLogInput({required this.type, required this.reps});
}

/// 운동 종류 선택 + 세트별 횟수 입력 다이얼로그.
/// 저장 시 [ExerciseLogInput] 반환, 취소 시 null.
Future<ExerciseLogInput?> showExerciseLogDialog(BuildContext context) {
  return showDialog<ExerciseLogInput>(
    context: context,
    builder: (_) => const _ExerciseLogDialog(),
  );
}

class _ExerciseLogDialog extends StatefulWidget {
  const _ExerciseLogDialog();

  @override
  State<_ExerciseLogDialog> createState() => _ExerciseLogDialogState();
}

class _ExerciseLogDialogState extends State<_ExerciseLogDialog> {
  String _type = kExerciseTypes.first;
  // 세트별 횟수 입력 컨트롤러 (기본 1세트)
  final List<TextEditingController> _setCtrls = [TextEditingController()];
  String? _error;

  @override
  void dispose() {
    for (final c in _setCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _addSet() {
    setState(() => _setCtrls.add(TextEditingController()));
  }

  void _removeSet(int i) {
    if (_setCtrls.length <= 1) return;
    setState(() {
      _setCtrls.removeAt(i).dispose();
    });
  }

  void _save() {
    final reps = <int>[];
    for (final c in _setCtrls) {
      final t = c.text.trim();
      if (t.isEmpty) continue;
      final n = int.tryParse(t);
      if (n == null || n <= 0) {
        setState(() => _error = '횟수는 1 이상의 숫자로 입력하세요.');
        return;
      }
      reps.add(n);
    }
    if (reps.isEmpty) {
      setState(() => _error = '세트 횟수를 하나 이상 입력하세요.');
      return;
    }
    Navigator.of(context).pop(ExerciseLogInput(type: _type, reps: reps));
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return AlertDialog(
      title: const Text('운동 기록'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('운동 종류', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final t in kExerciseTypes)
                  ChoiceChip(
                    label: Text(t),
                    selected: _type == t,
                    onSelected: (_) => setState(() => _type = t),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('세트별 횟수', style: TextStyle(fontSize: 13)),
                const Spacer(),
                Text('${_setCtrls.length}세트',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 6),
            for (int i = 0; i < _setCtrls.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      child: Text('${i + 1}세트',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade700)),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _setCtrls[i],
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: const InputDecoration(
                          hintText: '횟수',
                          isDense: true,
                          border: OutlineInputBorder(),
                          suffixText: '회',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.remove_circle_outline,
                          size: 20,
                          color: _setCtrls.length <= 1
                              ? Colors.grey.shade300
                              : Colors.red.shade300),
                      onPressed:
                          _setCtrls.length <= 1 ? null : () => _removeSet(i),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('세트 추가'),
                onPressed: _addSet,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(_error!,
                  style: TextStyle(fontSize: 12, color: Colors.red.shade600)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: primary),
          onPressed: _save,
          child: const Text('저장'),
        ),
      ],
    );
  }
}

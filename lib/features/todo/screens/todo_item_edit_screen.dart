import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../quotes/services/notification_service.dart';
import '../models/todo_item.dart';
import '../providers/todo_providers.dart';

class TodoItemEditScreen extends ConsumerStatefulWidget {
  final String categoryId;
  final TodoItem? item;
  const TodoItemEditScreen({super.key, required this.categoryId, this.item});

  @override
  ConsumerState<TodoItemEditScreen> createState() =>
      _TodoItemEditScreenState();
}

class _TodoItemEditScreenState extends ConsumerState<TodoItemEditScreen> {
  late final TextEditingController _textCtrl;
  late TodoRepeat _repeat;
  late Set<int> _weekDays;
  late int _monthDay;
  late int _notifyHour;
  late int _notifyMinute;
  bool _saving = false;

  bool get _isNew => widget.item == null;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    _textCtrl = TextEditingController(text: it?.text ?? '');
    _repeat = it?.repeat ?? TodoRepeat.once;
    _weekDays = {...(it?.weekDays ?? const <int>{})};
    _monthDay = it?.monthDay ?? 1;
    _notifyHour = it?.notifyHour ?? 9;
    _notifyMinute = it?.notifyMinute ?? 0;
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _notifyHour, minute: _notifyMinute),
    );
    if (picked != null) {
      setState(() {
        _notifyHour = picked.hour;
        _notifyMinute = picked.minute;
      });
    }
  }

  Future<void> _save() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('할 일 내용을 입력해 주세요')),
      );
      return;
    }
    if (_repeat == TodoRepeat.weekly && _weekDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('주간 반복 — 요일을 1개 이상 선택해 주세요')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      if (_repeat != TodoRepeat.once && NotificationService.supported) {
        await NotificationService.requestPermission();
      }

      final draft = TodoItem(
        id: widget.item?.id ?? 'draft',
        categoryId: widget.categoryId,
        text: text,
        repeat: _repeat,
        weekDays:
            _repeat == TodoRepeat.weekly ? _weekDays : const <int>{},
        monthDay: _repeat == TodoRepeat.monthly ? _monthDay : null,
        notifyHour: _notifyHour,
        notifyMinute: _notifyMinute,
        createdAt: widget.item?.createdAt ?? DateTime.now(),
        completions: widget.item?.completions ?? const [],
      );

      final notifier = ref.read(todoItemsProvider.notifier);
      if (_isNew) {
        await notifier.add(draft);
      } else {
        await notifier.save(widget.item!.copyWith(
          text: text,
          repeat: _repeat,
          weekDays: draft.weekDays,
          monthDay: draft.monthDay,
          notifyHour: _notifyHour,
          notifyMinute: _notifyMinute,
          clearMonthDay: _repeat != TodoRepeat.monthly,
        ));
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
        title: const Text('이 할 일을 삭제할까요?'),
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
      await ref.read(todoItemsProvider.notifier).remove(widget.item!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy.MM.dd HH:mm');
    final item = widget.item;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? '할 일 추가' : '할 일 편집'),
        actions: [
          if (!_isNew)
            IconButton(
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
          TextField(
            controller: _textCtrl,
            maxLines: 3,
            minLines: 1,
            autofocus: _isNew,
            decoration: const InputDecoration(
              hintText: '할 일을 입력하세요',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Text('반복 주기',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<TodoRepeat>(
            segments: TodoRepeat.values
                .map((r) => ButtonSegment(value: r, label: Text(r.label)))
                .toList(),
            selected: {_repeat},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _repeat = s.first),
          ),
          const SizedBox(height: 20),
          if (_repeat == TodoRepeat.weekly) ...[
            Text('요일 선택',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: List.generate(7, (i) {
                final day = i + 1; // 1..7
                final selected = _weekDays.contains(day);
                return FilterChip(
                  label: Text(weekDayLabel(day)),
                  selected: selected,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _weekDays.add(day);
                      } else {
                        _weekDays.remove(day);
                      }
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 20),
          ],
          if (_repeat == TodoRepeat.monthly) ...[
            Text('매월 며칠',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _monthDay.toDouble(),
                    min: 1,
                    max: 31,
                    divisions: 30,
                    label: '${_monthDay}일',
                    onChanged: (v) =>
                        setState(() => _monthDay = v.round()),
                  ),
                ),
                Container(
                  width: 60,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$_monthDay일',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '💡 해당 일이 없는 달(예: 2월 31일)은 자동으로 건너뜁니다.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
          ],
          if (_repeat != TodoRepeat.once) ...[
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('알림 시각'),
                subtitle: const Text('이 시간에 푸시 알림 (기본 09:00)'),
                trailing: Text(
                  '${_notifyHour.toString().padLeft(2, '0')}:${_notifyMinute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onTap: _pickTime,
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (item != null && item.completions.isNotEmpty) ...[
            Text('완료 이력',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: item.completions.reversed
                    .take(20)
                    .map((d) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle,
                                  size: 14, color: Colors.green.shade600),
                              const SizedBox(width: 6),
                              Text(df.format(d),
                                  style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
            if (item.completions.length > 20) ...[
              const SizedBox(height: 4),
              Text(
                '… 외 ${item.completions.length - 20}회',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

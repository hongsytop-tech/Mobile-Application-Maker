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

  DateTime? _deadline;
  bool _notifyEnabled = false;
  late DateTime _notifyDate;
  late int _notifyHour;
  late int _notifyMinute;

  bool _saving = false;

  bool get _isNew => widget.item == null;

  /// 마감/알림 섹션을 보여줄지 (장기목표는 제외)
  bool get _showScheduling => _repeat != TodoRepeat.longterm;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _textCtrl = TextEditingController(text: it?.text ?? '');
    _repeat = it?.repeat ?? TodoRepeat.once;
    _weekDays = {...(it?.weekDays ?? const <int>{})};
    _monthDay = it?.monthDay ?? 1;
    _deadline = it?.deadline;
    _notifyEnabled = it?.notifyEnabled ?? false;
    _notifyDate = it?.notifyDate ?? today;
    _notifyHour = it?.notifyHour ?? 9;
    _notifyMinute = it?.notifyMinute ?? 0;
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
      locale: const Locale('ko'),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _pickNotifyDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _notifyDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
      locale: const Locale('ko'),
    );
    if (picked != null) setState(() => _notifyDate = picked);
  }

  Future<void> _pickNotifyTime() async {
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
      final notify = _showScheduling && _notifyEnabled;
      if (notify && NotificationService.supported) {
        await NotificationService.requestPermission();
      }

      final draft = TodoItem(
        id: widget.item?.id ?? 'draft',
        categoryId: widget.categoryId,
        text: text,
        repeat: _repeat,
        weekDays: _repeat == TodoRepeat.weekly ? _weekDays : const <int>{},
        monthDay: _repeat == TodoRepeat.monthly ? _monthDay : null,
        deadline: _showScheduling ? _deadline : null,
        notifyEnabled: notify,
        notifyDate: _repeat == TodoRepeat.once ? _notifyDate : null,
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
          deadline: _showScheduling ? _deadline : null,
          clearDeadline: !_showScheduling || _deadline == null,
          notifyEnabled: notify,
          notifyDate: _repeat == TodoRepeat.once ? _notifyDate : null,
          clearNotifyDate: _repeat != TodoRepeat.once,
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
        title: const Text('이 항목을 삭제할까요?'),
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
    final dfDate = DateFormat('yyyy.MM.dd (E)', 'ko_KR');
    final dfFull = DateFormat('yyyy.MM.dd HH:mm');
    final item = widget.item;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? '항목 추가' : '항목 편집'),
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
          SizedBox(
            height: 56,
            child: TextField(
              controller: _textCtrl,
              maxLines: 1,
              autofocus: _isNew,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              textAlignVertical: TextAlignVertical.center,
              autocorrect: false,
              enableSuggestions: false,
              onSubmitted: (_) => _save(),
              decoration: const InputDecoration(
                hintText: '할 일 / 목표를 입력하세요',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 12, vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 반복 주기
          Text('유형 / 반복 주기',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: TodoRepeat.values.map((r) {
              return ChoiceChip(
                label: Text(r.label),
                selected: _repeat == r,
                onSelected: (_) => setState(() => _repeat = r),
              );
            }).toList(),
          ),
          if (_repeat == TodoRepeat.longterm) ...[
            const SizedBox(height: 8),
            Text(
              '💡 장기 목표는 마감일·알림 없이 꾸준히 관리하는 목표입니다.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 20),

          // 주간: 요일 선택
          if (_repeat == TodoRepeat.weekly) ...[
            Text('요일 선택',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: List.generate(7, (i) {
                final day = i + 1;
                final selected = _weekDays.contains(day);
                return FilterChip(
                  label: Text(weekDayLabel(day)),
                  selected: selected,
                  onSelected: (v) => setState(() {
                    if (v) {
                      _weekDays.add(day);
                    } else {
                      _weekDays.remove(day);
                    }
                  }),
                );
              }),
            ),
            const SizedBox(height: 20),
          ],

          // 월간: 일자 선택
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
                      style:
                          const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],

          // 마감시한 (장기목표 제외)
          if (_showScheduling) ...[
            Text('마감시한 (선택)',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const Icon(Icons.event),
                title: const Text('마감 날짜'),
                subtitle: _deadline == null
                    ? const Text('설정 안 함')
                    : Text(item?.deadlineLabel ?? dfDate.format(_deadline!)),
                trailing: _deadline == null
                    ? const Icon(Icons.chevron_right)
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _deadline = null),
                      ),
                onTap: _pickDeadline,
              ),
            ),
            const SizedBox(height: 20),

            // 알림 (날짜 + 시간)
            Text('알림',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('알림 받기'),
                    subtitle: const Text('지정한 날짜·시각에 푸시 알림'),
                    value: _notifyEnabled,
                    onChanged: (v) => setState(() => _notifyEnabled = v),
                  ),
                  if (_notifyEnabled) ...[
                    const Divider(height: 1),
                    // 즉시형만 날짜 선택 (반복형은 주기로 결정)
                    if (_repeat == TodoRepeat.once)
                      ListTile(
                        leading: const Icon(Icons.calendar_today),
                        title: const Text('알림 날짜'),
                        trailing: Text(
                          dfDate.format(_notifyDate),
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        onTap: _pickNotifyDate,
                      ),
                    ListTile(
                      leading: const Icon(Icons.access_time),
                      title: const Text('알림 시각'),
                      trailing: Text(
                        '${_notifyHour.toString().padLeft(2, '0')}:${_notifyMinute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      onTap: _pickNotifyTime,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // 완료 이력
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
                          padding:
                              const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle,
                                  size: 14,
                                  color: Colors.green.shade600),
                              const SizedBox(width: 6),
                              Text(dfFull.format(d),
                                  style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
            if (item.completions.length > 20) ...[
              const SizedBox(height: 4),
              Text('… 외 ${item.completions.length - 20}회',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ],

          if (!NotificationService.supported && _showScheduling) ...[
            const SizedBox(height: 8),
            Text(
              'ℹ️ 웹에서는 알림이 동작하지 않습니다. 모바일 앱에서 사용해 주세요.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }
}

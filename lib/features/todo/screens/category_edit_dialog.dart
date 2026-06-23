import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../quotes/services/notification_service.dart';
import '../models/todo_category.dart';
import '../providers/todo_providers.dart';
import '../widgets/wheel_time_picker.dart';

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
  late bool _notifyEnabled;
  late String _notifyMode; // 'daily' | 'interval'
  late int _notifyHour;
  late int _notifyMinute;
  late int _intervalHours;
  late int _intervalMinutes;

  bool get _isNew => widget.category == null;
  bool get _isInterval => _notifyMode == 'interval';

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.category?.name ?? '');
    _colorIndex = widget.category?.colorIndex ?? 0;
    _notifyEnabled = widget.category?.notifyEnabled ?? false;
    _notifyMode = widget.category?.notifyMode ?? 'daily';
    _notifyHour = widget.category?.notifyHour ?? 9;
    _notifyMinute = widget.category?.notifyMinute ?? 0;
    _intervalHours = widget.category?.notifyIntervalHours ?? 3;
    _intervalMinutes = widget.category?.notifyIntervalMinutes ?? 0;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    if (_notifyEnabled && NotificationService.supported) {
      await NotificationService.requestPermission();
    }
    final notifier = ref.read(todoCategoriesProvider.notifier);
    final now = DateTime.now();
    if (_isNew) {
      final c = await notifier.add(name, _colorIndex);
      await notifier.save(c.copyWith(
        notifyEnabled: _notifyEnabled,
        notifyMode: _notifyMode,
        notifyHour: _notifyHour,
        notifyMinute: _notifyMinute,
        notifyIntervalHours: _intervalHours,
        notifyIntervalMinutes: _intervalMinutes,
        updatedAt: now,
      ));
    } else {
      await notifier.save(widget.category!.copyWith(
        name: name,
        colorIndex: _colorIndex,
        notifyEnabled: _notifyEnabled,
        notifyMode: _notifyMode,
        notifyHour: _notifyHour,
        notifyMinute: _notifyMinute,
        notifyIntervalHours: _intervalHours,
        notifyIntervalMinutes: _intervalMinutes,
        updatedAt: now,
      ));
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickTime() async {
    final picked = await pickWheelTime(
      context,
      initialHour: _notifyHour,
      initialMinute: _notifyMinute,
    );
    if (picked != null) {
      setState(() {
        _notifyHour = picked.hour;
        _notifyMinute = picked.minute;
      });
    }
  }

  Future<void> _pickInterval() async {
    final picked = await pickWheelDuration(
      context,
      initialHours: _intervalHours,
      initialMinutes: _intervalMinutes,
    );
    if (picked != null) {
      setState(() {
        _intervalHours = picked.hour;
        _intervalMinutes = picked.minute;
      });
    }
  }

  Future<void> _confirmDelete() async {
    final cat = widget.category!;
    final notifier = ref.read(todoCategoriesProvider.notifier);
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    // 편집 다이얼로그부터 닫기
    Navigator.of(context).pop();
    // 새 확인 다이얼로그 (root context 사용 → 위에서 닫힌 다이얼로그의 영향 없음)
    final ok = await showDialog<bool>(
      context: rootContext,
      builder: (ctx) => AlertDialog(
        title: Text('"${cat.name}" 카테고리를 삭제할까요?'),
        content: const Text('카테고리 안의 모든 할 일도 함께 삭제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await notifier.remove(cat.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isNew ? '카테고리 추가' : '카테고리 편집'),
      content: SingleChildScrollView(
        child: Column(
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
          const SizedBox(height: 8),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('카테고리 알림', style: TextStyle(fontSize: 14)),
            subtitle: const Text('미완료 항목을 모아서 푸시',
                style: TextStyle(fontSize: 12)),
            value: _notifyEnabled,
            onChanged: (v) => setState(() => _notifyEnabled = v),
          ),
          if (_notifyEnabled) ...[
            const SizedBox(height: 4),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'daily',
                  label: Text('매일 시각'),
                  icon: Icon(Icons.schedule),
                ),
                ButtonSegment(
                  value: 'interval',
                  label: Text('반복 간격'),
                  icon: Icon(Icons.repeat),
                ),
              ],
              selected: {_notifyMode},
              showSelectedIcon: false,
              onSelectionChanged: (s) =>
                  setState(() => _notifyMode = s.first),
            ),
            if (_isInterval)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.timelapse),
                title: const Text('반복 간격'),
                trailing: Text(
                  '${_intervalHours}시간 ${_intervalMinutes}분',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onTap: _pickInterval,
              )
            else
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time),
                title: const Text('알림 시각'),
                trailing: Text(
                  '${_notifyHour.toString().padLeft(2, '0')}:${_notifyMinute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                onTap: _pickTime,
              ),
          ],
        ],
      ),
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

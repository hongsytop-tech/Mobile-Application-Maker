import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../todo/widgets/wheel_time_picker.dart';
import '../models/quote.dart';
import '../providers/quote_providers.dart';
import '../services/notification_service.dart';

class QuoteEditScreen extends ConsumerStatefulWidget {
  /// null이면 신규 작성
  final Quote? quote;
  const QuoteEditScreen({super.key, this.quote});

  @override
  ConsumerState<QuoteEditScreen> createState() => _QuoteEditScreenState();
}

class _QuoteEditScreenState extends ConsumerState<QuoteEditScreen> {
  late final TextEditingController _textCtrl;
  late bool _notifyEnabled;
  late NotifyMode _mode;
  TimeOfDay? _time;
  int _intervalHours = 0;
  int _intervalMinutes = 30;
  bool _saving = false;

  bool get _isNew => widget.quote == null;

  @override
  void initState() {
    super.initState();
    final q = widget.quote;
    _textCtrl = TextEditingController(text: q?.text ?? '');
    _notifyEnabled = q?.notifyEnabled ?? false;
    _mode = q?.notifyMode ?? NotifyMode.daily;
    _time = q?.notifyTime ?? const TimeOfDay(hour: 9, minute: 0);
    _intervalHours = q?.intervalHours ?? 0;
    _intervalMinutes = q?.intervalMinutes ?? 30;
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final cur = _time ?? const TimeOfDay(hour: 9, minute: 0);
    final picked = await pickWheelTime(
      context,
      initialHour: cur.hour,
      initialMinute: cur.minute,
    );
    if (picked != null) {
      setState(() => _time = TimeOfDay(hour: picked.hour, minute: picked.minute));
    }
  }

  Future<void> _save() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('문구를 입력해 주세요')),
      );
      return;
    }

    if (_notifyEnabled && _mode == NotifyMode.interval) {
      final total = _intervalHours * 60 + _intervalMinutes;
      if (total < 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('알림 간격을 1분 이상으로 설정해 주세요')),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      if (_notifyEnabled && NotificationService.supported) {
        final granted = await NotificationService.requestPermission();
        if (!granted && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('알림 권한이 거부되었습니다. 설정에서 허용해주세요.'),
            ),
          );
        }
      }

      final notifier = ref.read(quotesProvider.notifier);
      final isDaily = _mode == NotifyMode.daily;

      final now = DateTime.now();
      final draft = Quote(
        id: widget.quote?.id ?? 'draft',
        text: text,
        createdAt: widget.quote?.createdAt ?? now,
        updatedAt: now,
        notifyEnabled: _notifyEnabled,
        notifyMode: _mode,
        notifyHour: _notifyEnabled && isDaily ? _time!.hour : null,
        notifyMinute: _notifyEnabled && isDaily ? _time!.minute : null,
        intervalHours: _notifyEnabled && !isDaily ? _intervalHours : null,
        intervalMinutes: _notifyEnabled && !isDaily ? _intervalMinutes : null,
      );

      if (_isNew) {
        await notifier.add(draft);
      } else {
        await notifier.save(
          widget.quote!.copyWith(
            text: text,
            updatedAt: now,
            notifyEnabled: _notifyEnabled,
            notifyMode: _mode,
            notifyHour: draft.notifyHour,
            notifyMinute: draft.notifyMinute,
            intervalHours: draft.intervalHours,
            intervalMinutes: draft.intervalMinutes,
            clearDailyTime: !isDaily || !_notifyEnabled,
            clearInterval: isDaily || !_notifyEnabled,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? '문구 추가' : '문구 편집'),
        actions: [
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
            maxLines: 8,
            minLines: 4,
            autofocus: _isNew,
            decoration: const InputDecoration(
              hintText: '기억하고 싶은 문구를 입력하세요',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('알림 받기'),
                  subtitle: const Text('지정한 방식으로 이 문구를 알려드려요'),
                  value: _notifyEnabled,
                  onChanged: (v) => setState(() => _notifyEnabled = v),
                ),
                if (_notifyEnabled) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: SegmentedButton<NotifyMode>(
                      segments: const [
                        ButtonSegment(
                          value: NotifyMode.daily,
                          label: Text('매일 지정 시간'),
                          icon: Icon(Icons.schedule),
                        ),
                        ButtonSegment(
                          value: NotifyMode.interval,
                          label: Text('반복 간격'),
                          icon: Icon(Icons.repeat),
                        ),
                      ],
                      selected: {_mode},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) =>
                          setState(() => _mode = s.first),
                    ),
                  ),
                  if (_mode == NotifyMode.daily) ...[
                    ListTile(
                      leading: const Icon(Icons.access_time),
                      title: const Text('알림 시간'),
                      trailing: Text(
                        _time != null
                            ? _time!.format(context)
                            : '시간 선택',
                        style: const TextStyle(fontSize: 16),
                      ),
                      onTap: _pickTime,
                    ),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '반복 간격',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () async {
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
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.timelapse, size: 20),
                                  const SizedBox(width: 10),
                                  Text(
                                    '${_intervalHours}시간 ${_intervalMinutes}분마다',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const Spacer(),
                                  Icon(Icons.expand_more,
                                      color: Colors.grey.shade500),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _intervalSummary(),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '💡 너무 짧은 간격(1~5분)은 배터리 소모가 큽니다.',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          if (_notifyEnabled && !NotificationService.supported) ...[
            const SizedBox(height: 12),
            Text(
              'ℹ️ 웹에서는 알림이 동작하지 않습니다. 모바일 앱에서 사용해 주세요.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  String _intervalSummary() {
    final total = _intervalHours * 60 + _intervalMinutes;
    if (total < 1) return '간격을 설정해 주세요';
    final parts = <String>[];
    if (_intervalHours > 0) parts.add('${_intervalHours}시간');
    if (_intervalMinutes > 0) parts.add('${_intervalMinutes}분');
    return '${parts.join(' ')}마다 알림';
  }
}

class _NumberStepper extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  const _NumberStepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.step = 1,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: value > min
                    ? () => onChanged(
                        (value - step).clamp(min, max))
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
                visualDensity: VisualDensity.compact,
              ),
              Text(
                '$value',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: value < max
                    ? () => onChanged(
                        (value + step).clamp(min, max))
                    : null,
                icon: const Icon(Icons.add_circle_outline),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

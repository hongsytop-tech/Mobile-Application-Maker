import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/quote_providers.dart';
import '../services/notification_service.dart';
import '../services/quote_rotation_service.dart';

class QuoteRotationSettingsScreen extends ConsumerStatefulWidget {
  const QuoteRotationSettingsScreen({super.key});

  @override
  ConsumerState<QuoteRotationSettingsScreen> createState() =>
      _QuoteRotationSettingsScreenState();
}

class _QuoteRotationSettingsScreenState
    extends ConsumerState<QuoteRotationSettingsScreen> {
  QuoteRotationSettings _settings = const QuoteRotationSettings();
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    QuoteRotationService.load().then((s) {
      if (mounted) {
        setState(() {
          _settings = s;
          _loaded = true;
        });
      }
    });
  }

  Future<void> _apply(QuoteRotationSettings next) async {
    setState(() {
      _settings = next;
      _saving = true;
    });
    try {
      // 사용 켤 때 권한 요청
      if (next.enabled && NotificationService.supported) {
        await NotificationService.requestPermission();
      }
      await QuoteRotationService.save(next);
      final quotes = ref.read(quotesProvider).value ?? const [];
      await QuoteRotationService.reschedule(quotes);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _settings.hour, minute: _settings.minute),
    );
    if (picked != null) {
      await _apply(_settings.copyWith(hour: picked.hour, minute: picked.minute));
    }
  }

  @override
  Widget build(BuildContext context) {
    final quotes = ref.watch(quotesProvider).value ?? const [];
    if (!_loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('문구 순차 알림')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Icon(
            Icons.campaign,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 8),
          const Text(
            '저장한 문구들이 지정한 주기마다\n순환하면서 큰 알림으로 표시됩니다.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 24),

          // 사용 토글
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SwitchListTile(
              title: const Text('순차 알림 사용'),
              subtitle: Text(
                quotes.isEmpty
                    ? '먼저 문구를 1개 이상 추가해 주세요'
                    : '총 ${quotes.length}개 문구가 순환됩니다',
              ),
              value: _settings.enabled,
              onChanged: quotes.isEmpty
                  ? null
                  : (v) => _apply(_settings.copyWith(enabled: v)),
            ),
          ),

          if (_settings.enabled) ...[
            const SizedBox(height: 20),
            Text('반복 주기',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<RotationMode>(
              segments: const [
                ButtonSegment(
                  value: RotationMode.dailyAtTime,
                  label: Text('매일 지정 시각'),
                  icon: Icon(Icons.schedule),
                ),
                ButtonSegment(
                  value: RotationMode.interval,
                  label: Text('반복 간격'),
                  icon: Icon(Icons.repeat),
                ),
              ],
              selected: {_settings.mode},
              showSelectedIcon: false,
              onSelectionChanged: (s) =>
                  _apply(_settings.copyWith(mode: s.first)),
            ),
            const SizedBox(height: 16),

            if (_settings.mode == RotationMode.dailyAtTime)
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.access_time),
                  title: const Text('알림 시각'),
                  trailing: Text(
                    '${_settings.hour.toString().padLeft(2, '0')}:${_settings.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  onTap: _pickTime,
                ),
              )
            else
              _IntervalPicker(
                hours: _settings.intervalHours,
                minutes: _settings.intervalMinutes,
                onChanged: (h, m) => _apply(
                  _settings.copyWith(intervalHours: h, intervalMinutes: m),
                ),
              ),

            const SizedBox(height: 24),
            Text('다음 예정 알림',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _UpcomingList(settings: _settings, quotes: quotes),
          ],

          if (!NotificationService.supported) ...[
            const SizedBox(height: 16),
            Text(
              'ℹ️ 웹에서는 알림이 동작하지 않습니다. 모바일 앱에서 사용해 주세요.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
          ],
          if (_saving) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}

class _IntervalPicker extends StatelessWidget {
  final int hours;
  final int minutes;
  final void Function(int h, int m) onChanged;
  const _IntervalPicker({
    required this.hours,
    required this.minutes,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _StepRow(
                  label: '시간',
                  value: hours,
                  min: 0,
                  max: 23,
                  onChanged: (v) => onChanged(v, minutes),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StepRow(
                  label: '분',
                  value: minutes,
                  min: 0,
                  max: 59,
                  step: 5,
                  onChanged: (v) => onChanged(hours, v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hours * 60 + minutes < 1
                ? '간격을 1분 이상으로 설정해 주세요'
                : '${hours > 0 ? "${hours}시간 " : ""}${minutes > 0 ? "${minutes}분" : ""}마다 알림',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '💡 너무 짧은 간격은 배터리 소모가 큽니다.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;
  const _StepRow({
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
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: value > min
                    ? () => onChanged((value - step).clamp(min, max))
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$value',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: value < max
                    ? () => onChanged((value + step).clamp(min, max))
                    : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UpcomingList extends StatelessWidget {
  final QuoteRotationSettings settings;
  final List quotes;
  const _UpcomingList({required this.settings, required this.quotes});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('MM.dd (E) HH:mm', 'ko_KR');
    final upcoming = QuoteRotationService.preview(
      quotes: List.from(quotes),
      settings: settings,
      count: 6,
    );
    if (upcoming.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          '예정된 알림이 없습니다.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: upcoming.map((e) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 90,
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    df.format(e.when),
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: Text(
                    e.text,
                    style: const TextStyle(fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  TimeOfDay? _time;
  bool _saving = false;

  bool get _isNew => widget.quote == null;

  @override
  void initState() {
    super.initState();
    final q = widget.quote;
    _textCtrl = TextEditingController(text: q?.text ?? '');
    _notifyEnabled = q?.notifyEnabled ?? false;
    _time = q?.notifyTime;
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('문구를 입력해 주세요')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      // 알림 켰는데 시간 미설정이면 9시로 기본
      final hour = _notifyEnabled ? (_time?.hour ?? 9) : null;
      final minute = _notifyEnabled ? (_time?.minute ?? 0) : null;

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
      if (_isNew) {
        await notifier.add(
          text: text,
          notifyHour: hour,
          notifyMinute: minute,
          notifyEnabled: _notifyEnabled,
        );
      } else {
        await notifier.update(
          widget.quote!.copyWith(
            text: text,
            notifyHour: hour,
            notifyMinute: minute,
            notifyEnabled: _notifyEnabled,
            clearNotifyTime: !_notifyEnabled,
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
                  title: const Text('매일 알림 받기'),
                  subtitle: const Text('지정한 시간에 이 문구를 알려드려요'),
                  value: _notifyEnabled,
                  onChanged: (v) => setState(() => _notifyEnabled = v),
                ),
                if (_notifyEnabled) ...[
                  const Divider(height: 1),
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
}

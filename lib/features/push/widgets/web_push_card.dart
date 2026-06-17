import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/web_push_service.dart';

class WebPushCard extends StatefulWidget {
  const WebPushCard({super.key});

  @override
  State<WebPushCard> createState() => _WebPushCardState();
}

class _WebPushCardState extends State<WebPushCard> {
  bool _loading = true;
  bool _busy = false;
  bool _supported = false;
  bool _subscribed = false;
  String _permission = 'default';
  String? _msg;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final supported = await WebPushService.isSupported();
    final permission = await WebPushService.permission();
    final subscribed = supported ? await WebPushService.isSubscribed() : false;
    if (!mounted) return;
    setState(() {
      _supported = supported;
      _permission = permission;
      _subscribed = subscribed;
      _loading = false;
    });
  }

  Future<void> _enable() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    final result = await WebPushService.enable();
    if (!mounted) return;
    if (result.ok) {
      setState(() => _msg = '✅ 알림이 활성화되었습니다.');
    } else if (result.unsupported) {
      setState(() => _msg = '이 브라우저/플랫폼에서는 웹 푸시가 지원되지 않습니다.');
    } else {
      setState(() => _msg = '❌ ${result.error}');
    }
    await _refresh();
    setState(() => _busy = false);
  }

  Future<void> _disable() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    await WebPushService.disable();
    if (!mounted) return;
    setState(() => _msg = '알림이 비활성화되었습니다.');
    await _refresh();
    setState(() => _busy = false);
  }

  Future<void> _test() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      // 항상 enable 을 먼저 호출 → 브라우저 구독을 DB 와 동기화
      final r = await WebPushService.enable();
      if (!r.ok) {
        if (mounted) {
          setState(() {
            _msg = r.unsupported
                ? '이 브라우저/플랫폼에서는 웹 푸시가 지원되지 않습니다.'
                : '❌ ${r.error ?? "활성화 실패"}';
          });
        }
        return;
      }
      await WebPushService.sendTest();
      if (mounted) {
        setState(() => _msg = '✅ 테스트 푸시를 전송했어요. 잠시 후 알림이 옵니다.');
      }
    } catch (e, st) {
      if (mounted) {
        setState(() => _msg = '❌ 예외: $e\n${st.toString().split('\n').take(3).join('\n')}');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active, color: primary, size: 20),
              const SizedBox(width: 8),
              Text('웹 푸시 알림',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: primary)),
              const Spacer(),
              if (_loading)
                const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 6),
          Text(_statusText(),
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade800,
                  height: 1.4)),
          const SizedBox(height: 12),
          ..._buildActions(),
          if (_msg != null) ...[
            const SizedBox(height: 10),
            Text(_msg!, style: const TextStyle(fontSize: 12)),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildActions() {
    if (!kIsWeb) {
      return [
        Text('현재는 PWA(웹)에서만 동작합니다.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ];
    }
    if (!_supported) {
      return [
        Text('이 브라우저에서는 웹 푸시가 지원되지 않습니다.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ];
    }
    if (_permission == 'denied') {
      return [
        Text(
          '브라우저 설정에서 이 사이트의 알림 권한이 차단돼 있어요.\n주소창 옆 자물쇠 아이콘 → 알림 → "허용"으로 바꿔주세요.',
          style: TextStyle(fontSize: 12, color: Colors.red.shade700),
        ),
      ];
    }
    if (!_subscribed) {
      return [
        FilledButton.icon(
          onPressed: _busy ? null : _enable,
          icon: const Icon(Icons.notifications),
          label: const Text('알림 켜기'),
        ),
      ];
    }
    return [
      Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _busy ? null : _test,
              icon: const Icon(Icons.send),
              label: const Text('테스트 보내기'),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _disable,
            icon: const Icon(Icons.notifications_off),
            label: const Text('끄기'),
          ),
        ],
      ),
    ];
  }

  String _statusText() {
    if (_loading) return '상태 확인 중...';
    if (!kIsWeb) {
      return 'PWA(웹)을 홈 화면에 추가한 뒤 그 안에서 활성화하면, 휴대폰 시스템 알림으로 옵니다.';
    }
    if (!_supported) return '이 브라우저는 웹 푸시를 지원하지 않습니다.';
    if (_subscribed) return '✅ 알림 활성화됨';
    if (_permission == 'denied') return '권한 차단됨';
    return '활성화하면 휴대폰/PC 시스템 알림으로 문구·할일 알림을 받습니다.';
  }
}

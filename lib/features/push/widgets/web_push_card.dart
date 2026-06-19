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
  bool _optedOut = false;
  String _permission = 'default';
  String? _msg;

  /// 실제 알림이 켜진 상태 = 구독됨 + 사용자가 끄지 않음
  bool get _enabled => _subscribed && !_optedOut;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final supported = await WebPushService.isSupported();
    final permission = await WebPushService.permission();
    final subscribed = supported ? await WebPushService.isSubscribed() : false;
    final optedOut = await WebPushService.optedOut();
    if (!mounted) return;
    setState(() {
      _supported = supported;
      _permission = permission;
      _subscribed = subscribed;
      _optedOut = optedOut;
      _loading = false;
    });
  }

  Future<void> _toggle(bool on) async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    if (on) {
      final result = await WebPushService.enable();
      if (mounted) {
        if (result.ok) {
          _msg = '✅ 알림이 켜졌습니다.';
        } else if (result.unsupported) {
          _msg = '이 브라우저/플랫폼에서는 웹 푸시가 지원되지 않습니다.';
        } else {
          _msg = '❌ ${result.error}';
        }
      }
    } else {
      await WebPushService.disable();
      if (mounted) _msg = '알림이 꺼졌습니다.';
    }
    await _refresh();
    if (mounted) setState(() => _busy = false);
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
              if (_loading || _busy)
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
              else if (_canToggle)
                Switch(
                  value: _enabled,
                  onChanged: _busy ? null : _toggle,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(_statusText(),
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade800,
                  height: 1.4)),
          if (_msg != null) ...[
            const SizedBox(height: 10),
            Text(_msg!, style: const TextStyle(fontSize: 12)),
          ],
        ],
      ),
    );
  }

  /// 스위치를 표시할 수 있는 상태인지 (웹 + 지원 + 권한 미차단)
  bool get _canToggle => kIsWeb && _supported && _permission != 'denied';

  String _statusText() {
    if (_loading) return '상태 확인 중...';
    if (!kIsWeb) {
      return 'PWA(웹)을 홈 화면에 추가한 뒤 그 안에서 켜면, 휴대폰 시스템 알림으로 옵니다.';
    }
    if (!_supported) return '이 브라우저는 웹 푸시를 지원하지 않습니다.';
    if (_permission == 'denied') {
      return '브라우저 설정에서 이 사이트의 알림 권한이 차단돼 있어요.\n주소창 옆 자물쇠 아이콘 → 알림 → "허용"으로 바꿔주세요.';
    }
    if (_enabled) {
      return '✅ 이 기기에서 알림 켜짐 — 다른 기기의 알림 설정과 별개입니다.';
    }
    return '이 기기에서 꺼짐 — 스위치를 켜면 이 기기에서만 알림을 받습니다.\n(다른 기기의 알림은 영향 없음)';
  }
}

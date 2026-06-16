import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/kakao_link_service.dart';

class KakaoLinkCard extends StatefulWidget {
  const KakaoLinkCard({super.key});

  @override
  State<KakaoLinkCard> createState() => _KakaoLinkCardState();
}

class _KakaoLinkCardState extends State<KakaoLinkCard> {
  KakaoLinkStatus? _status;
  bool _loading = true;
  bool _busy = false;
  String? _msg;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final s = await KakaoLinkService.status();
    if (!mounted) return;
    setState(() {
      _status = s;
      _loading = false;
    });
  }

  Future<void> _link() async {
    if (!kIsWeb) {
      _toast('카카오 알림 연동은 현재 웹(PWA)에서만 지원합니다. PWA 에서 연동해 주세요.');
      return;
    }
    try {
      await KakaoLinkService.startLinkFlow();
    } catch (e) {
      _toast('연동 시작 실패: $e');
    }
  }

  Future<void> _test() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      await KakaoLinkService.sendTest();
      setState(() => _msg = '✅ 카카오톡 "나와의 채팅"으로 테스트 메시지를 보냈어요.');
    } catch (e) {
      setState(() => _msg = '❌ 전송 실패: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unlink() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('카카오 알림 연동을 해제할까요?'),
        content: const Text('해제 후엔 카카오톡으로 알림이 가지 않습니다. 언제든 다시 연동할 수 있어요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          FilledButton.tonal(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('해제')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await KakaoLinkService.unlink();
      await _refresh();
      setState(() => _msg = '연동을 해제했습니다.');
    } catch (e) {
      setState(() => _msg = '해제 실패: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final kakaoYellow = const Color(0xFFFEE500);
    final kakaoBrown = const Color(0xFF3C1E1E);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kakaoYellow.withOpacity(0.20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kakaoYellow.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.chat_bubble, color: kakaoBrown, size: 20),
              const SizedBox(width: 8),
              Text(
                '카카오톡 알림',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: kakaoBrown,
                ),
              ),
              const Spacer(),
              if (_loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _statusText(),
            style: TextStyle(
              fontSize: 12,
              color: kakaoBrown.withOpacity(0.85),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          if (_status == null || !_status!.linked) ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: kakaoYellow,
                foregroundColor: kakaoBrown,
              ),
              onPressed: _busy ? null : _link,
              icon: const Icon(Icons.link),
              label: const Text('카카오톡으로 알림 받기'),
            ),
          ] else if (!_status!.hasTalkMessage) ...[
            Text(
              '메시지 전송 권한 (talk_message) 동의가 빠져 있어요.\n아래 버튼으로 다시 연동해 주세요.',
              style: TextStyle(fontSize: 12, color: Colors.red.shade700),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: kakaoYellow,
                foregroundColor: kakaoBrown,
              ),
              onPressed: _busy ? null : _link,
              icon: const Icon(Icons.link),
              label: const Text('다시 연동하기'),
            ),
          ] else ...[
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
                  onPressed: _busy ? null : _unlink,
                  icon: const Icon(Icons.link_off),
                  label: const Text('해제'),
                ),
              ],
            ),
          ],
          if (_msg != null) ...[
            const SizedBox(height: 10),
            Text(_msg!, style: const TextStyle(fontSize: 12)),
          ],
        ],
      ),
    );
  }

  String _statusText() {
    if (_loading) return '연동 상태 확인 중...';
    final s = _status;
    if (s == null || !s.linked) {
      return '연동하면 문구·할일 알림이 카카오톡 "나와의 채팅"으로 옵니다.\nPWA 에서도 알림을 받을 수 있어요.';
    }
    if (!s.hasTalkMessage) return '연동되었지만 메시지 권한이 빠져 있습니다.';
    return '✅ 연동됨 — 알림이 카카오톡으로 옵니다.';
  }
}

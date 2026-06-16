import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/supabase_service.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLogin = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _emailSubmit() async {
    if (!SupabaseService.isConfigured) {
      setState(() => _error = 'Supabase URL/Key가 .env에 설정되지 않았습니다.');
      return;
    }
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.length < 6) {
      setState(() => _error = '이메일과 6자 이상 비밀번호를 입력해 주세요.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_isLogin) {
        await SupabaseService.signIn(email: email, password: password);
      } else {
        await SupabaseService.signUp(email: email, password: password);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _googleSubmit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SupabaseService.signInWithGoogle();
      if (mounted) Navigator.of(context).pop();
    } on AuthFailure catch (e) {
      if (e.message == '취소됨') {
        setState(() => _error = null);
      } else {
        setState(() => _error = e.message);
      }
    } catch (e) {
      setState(() => _error = '로그인 실패: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _comingSoon(String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name 로그인은 다음 업데이트에서 지원 예정입니다')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('로그인 / 회원가입')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 8),
          Icon(Icons.cloud_sync,
              size: 56, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          const Text(
            '로그인하면 데이터를 클라우드에 백업해\n다른 기기·앱 업데이트 후에도 이어서 쓸 수 있어요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 28),

          // ---- 소셜 로그인 ----
          _SocialButton(
            label: 'Google로 시작하기',
            color: Colors.white,
            textColor: Colors.black87,
            border: true,
            icon: const _GoogleIcon(),
            enabled: !_busy,
            onTap: _googleSubmit,
          ),
          const SizedBox(height: 8),
          _SocialButton(
            label: '카카오로 시작하기 (준비 중)',
            color: const Color(0xFFFEE500),
            textColor: const Color(0xFF000000),
            icon: const Icon(Icons.chat_bubble, color: Colors.black),
            enabled: false,
            onTap: () => _comingSoon('카카오'),
          ),
          const SizedBox(height: 8),
          _SocialButton(
            label: '네이버로 시작하기 (준비 중)',
            color: const Color(0xFF03C75A),
            textColor: Colors.white,
            icon: const Icon(Icons.public, color: Colors.white),
            enabled: false,
            onTap: () => _comingSoon('네이버'),
          ),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: Divider(color: Colors.grey.shade300)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('또는 이메일',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
            Expanded(child: Divider(color: Colors.grey.shade300)),
          ]),
          const SizedBox(height: 16),

          // ---- 이메일/비번 ----
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: '이메일',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordCtrl,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            decoration: const InputDecoration(
              labelText: '비밀번호 (6자 이상)',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _emailSubmit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _emailSubmit,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_isLogin ? '이메일로 로그인' : '이메일로 회원가입'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() {
              _isLogin = !_isLogin;
              _error = null;
            }),
            child: Text(_isLogin
                ? '계정이 없으신가요? 회원가입'
                : '이미 계정이 있으신가요? 로그인'),
          ),
        ],
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final Widget icon;
  final bool enabled;
  final bool border;
  final VoidCallback onTap;

  const _SocialButton({
    required this.label,
    required this.color,
    required this.textColor,
    required this.icon,
    required this.enabled,
    this.border = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Material(
        color: enabled ? color : color.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: border
                ? BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  )
                : null,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                SizedBox(width: 22, height: 22, child: icon),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();
  @override
  Widget build(BuildContext context) {
    // 텍스트로 간이 G 아이콘 (별도 에셋 없이 표시)
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [
          Color(0xFF4285F4),
          Color(0xFF34A853),
          Color(0xFFFBBC05),
          Color(0xFFEA4335),
        ]),
        borderRadius: BorderRadius.circular(11),
      ),
      alignment: Alignment.center,
      child: const Text(
        'G',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}

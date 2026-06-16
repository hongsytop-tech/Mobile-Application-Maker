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

  Future<void> _submit() async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? '로그인' : '회원가입')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 12),
          Icon(Icons.cloud_sync,
              size: 56, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          const Text(
            '데이터를 클라우드에 백업해서\n다른 기기·앱 업데이트 후에도 동일하게 사용하세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 28),
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
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_isLogin ? '로그인' : '회원가입'),
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
          const SizedBox(height: 24),
          Text(
            '※ 회원가입 후 가입 이메일로 확인 메일이 발송될 수 있습니다.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

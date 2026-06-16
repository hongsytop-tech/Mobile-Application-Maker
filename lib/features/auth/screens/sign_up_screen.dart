import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/supabase_service.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _emailCtrl = TextEditingController();
  final _pw1Ctrl = TextEditingController();
  final _pw2Ctrl = TextEditingController();
  bool _busy = false;
  bool _obscure1 = true;
  bool _obscure2 = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pw1Ctrl.dispose();
    _pw2Ctrl.dispose();
    super.dispose();
  }

  String? _validate() {
    final email = _emailCtrl.text.trim();
    final pw1 = _pw1Ctrl.text;
    final pw2 = _pw2Ctrl.text;
    if (email.isEmpty || !email.contains('@')) {
      return '올바른 이메일을 입력해 주세요.';
    }
    if (pw1.length < 6) {
      return '비밀번호는 6자 이상이어야 합니다.';
    }
    if (pw1 != pw2) {
      return '비밀번호가 일치하지 않습니다.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!SupabaseService.isConfigured) {
      setState(() => _error = 'Supabase URL/Key가 설정되지 않았습니다.');
      return;
    }
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await SupabaseService.signUp(
        email: _emailCtrl.text.trim(),
        password: _pw1Ctrl.text,
      );
      if (!mounted) return;

      // 세션이 바로 생기면 (확인 메일 OFF) → 가입+로그인 완료
      if (res.session != null) {
        Navigator.of(context).pop(); // 회원가입 화면 닫기
        Navigator.of(context).pop(); // 로그인 화면 닫기 → 로그인 상태로
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원가입 완료! 로그인되었습니다.')),
        );
      } else {
        // 확인 메일 ON → 안내 후 로그인 화면으로 복귀
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('가입 메일을 확인해 주세요'),
            content: Text(
              '${_emailCtrl.text.trim()} 으로 확인 메일을 보냈어요.\n'
              '메일의 링크를 누른 뒤 로그인해 주세요.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('확인'),
              ),
            ],
          ),
        );
        if (mounted) Navigator.of(context).pop(); // 로그인 화면으로
      }
    } catch (e) {
      setState(() => _error = _friendly(e.toString()));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendly(String raw) {
    if (raw.contains('already registered') ||
        raw.contains('User already')) {
      return '이미 가입된 이메일입니다. 로그인해 주세요.';
    }
    if (raw.contains('valid email')) {
      return '이메일 형식이 올바르지 않습니다.';
    }
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 8),
          Icon(Icons.person_add_alt_1,
              size: 52, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          const Text(
            '이메일과 비밀번호로 계정을 만들어요.',
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
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pw1Ctrl,
            obscureText: _obscure1,
            decoration: InputDecoration(
              labelText: '비밀번호 (6자 이상)',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                    _obscure1 ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure1 = !_obscure1),
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pw2Ctrl,
            obscureText: _obscure2,
            decoration: InputDecoration(
              labelText: '비밀번호 확인',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                    _obscure2 ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure2 = !_obscure2),
              ),
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('가입하기'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('이미 계정이 있으신가요? 로그인'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthFailure implements Exception {
  final String message;
  const AuthFailure(this.message);
  @override
  String toString() => message;
}

class SupabaseService {
  static bool _initialized = false;
  static GoogleSignIn? _googleSignIn;

  static SupabaseClient get client => Supabase.instance.client;

  static bool get isConfigured => _initialized;

  static Future<void> init() async {
    final url = dotenv.maybeGet('SUPABASE_URL') ?? '';
    final key = dotenv.maybeGet('SUPABASE_ANON_KEY') ?? '';
    if (url.isEmpty || key.isEmpty) {
      return;
    }
    await Supabase.initialize(url: url, anonKey: key);
    _initialized = true;
  }

  static User? get currentUser =>
      _initialized ? client.auth.currentUser : null;
  static bool get isAuthenticated => currentUser != null;

  static Stream<AuthState> get authChanges => client.auth.onAuthStateChange;

  // ---- 이메일 / 비밀번호 ----
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) {
    return client.auth.signUp(email: email, password: password);
  }

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return client.auth
        .signInWithPassword(email: email, password: password);
  }

  // ---- Google ----
  static bool get isGoogleConfigured {
    final id = dotenv.maybeGet('GOOGLE_WEB_CLIENT_ID') ?? '';
    return id.isNotEmpty && !id.startsWith('your_');
  }

  static Future<AuthResponse> signInWithGoogle() async {
    if (!_initialized) {
      throw const AuthFailure('Supabase가 초기화되지 않았습니다');
    }
    final webClientId = dotenv.maybeGet('GOOGLE_WEB_CLIENT_ID') ?? '';
    if (webClientId.isEmpty) {
      throw const AuthFailure(
          'GOOGLE_WEB_CLIENT_ID가 .env에 없습니다. docs/SUPABASE_SETUP.md 참고.');
    }

    _googleSignIn ??= GoogleSignIn(
      serverClientId: webClientId,
      scopes: const ['email', 'openid', 'profile'],
    );

    final account = await _googleSignIn!.signIn();
    if (account == null) {
      throw const AuthFailure('취소됨');
    }
    final auth = await account.authentication;
    final idToken = auth.idToken;
    final accessToken = auth.accessToken;
    if (idToken == null) {
      throw const AuthFailure('Google에서 ID 토큰을 받지 못했습니다');
    }

    return client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  static Future<void> signOut() async {
    try {
      await _googleSignIn?.signOut();
    } catch (_) {}
    await client.auth.signOut();
  }

  // ---- 데이터 ----
  static Future<Map<String, dynamic>?> pullUserData() async {
    final user = currentUser;
    if (user == null) return null;
    return await client
        .from('user_data')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();
  }

  static Future<void> pushUserData({
    required List<String> books,
    required List<String> quotes,
    required List<String> diaries,
    required List<String> todoCategories,
    required List<String> todoItems,
    Map<String, dynamic>? settings,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw StateError('로그인이 필요합니다');
    }
    await client.from('user_data').upsert({
      'user_id': user.id,
      'books': books,
      'quotes': quotes,
      'diaries': diaries,
      'todo_categories': todoCategories,
      'todo_items': todoItems,
      if (settings != null) 'settings': settings,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}

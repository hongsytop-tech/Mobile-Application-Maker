import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static bool _initialized = false;

  static SupabaseClient get client => Supabase.instance.client;

  static bool get isConfigured => _initialized;

  static Future<void> init() async {
    final url = dotenv.maybeGet('SUPABASE_URL') ?? '';
    final key = dotenv.maybeGet('SUPABASE_ANON_KEY') ?? '';
    if (url.isEmpty || key.isEmpty) {
      // .env 미설정 시에도 앱은 동작 (로그인 기능만 비활성)
      return;
    }
    await Supabase.initialize(url: url, anonKey: key);
    _initialized = true;
  }

  static User? get currentUser =>
      _initialized ? client.auth.currentUser : null;
  static bool get isAuthenticated => currentUser != null;

  static Stream<AuthState> get authChanges => client.auth.onAuthStateChange;

  // ---- 인증 ----
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

  static Future<void> signOut() => client.auth.signOut();

  // ---- 데이터 ----
  static Future<Map<String, dynamic>?> pullUserData() async {
    final user = currentUser;
    if (user == null) return null;
    final res = await client
        .from('user_data')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();
    return res;
  }

  static Future<void> pushUserData({
    required List<String> books,
    required List<String> quotes,
    required List<String> diaries,
    required List<String> todoCategories,
    required List<String> todoItems,
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
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}

import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/services/sync_manager.dart';
import '../models/quote.dart';

class QuoteStorageService {
  static const _key = 'quotes_v1';

  Future<List<Quote>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? const [];
    return list.map(Quote.fromJsonString).toList();
  }

  Future<void> saveAll(List<Quote> quotes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _key, quotes.map((e) => e.toJsonString()).toList());
    // 즉시 cloud push (debounce 우회) → PWA 가 push 전에 종료돼도 누락 없음
    await SyncManager.instance.flushNow();
  }
}

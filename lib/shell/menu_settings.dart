import 'dart:convert';

import 'app_tabs.dart';

/// 하단 탭 표시/순서 설정 (계정에 동기화).
class MenuSettings {
  /// 모든 탭 id 의 표시 순서. kAppTabs 에 없는 id 는 무시, 빠진 id 는 끝에 보충.
  final List<String> order;

  /// 숨긴 탭 id 집합 (lockedVisible 탭은 여기 있어도 강제로 표시됨).
  final Set<String> hidden;

  const MenuSettings({this.order = kDefaultTabOrder, this.hidden = const {}});

  /// 정규화된 전체 순서 (저장된 순서 + 누락분 보충 + 미존재 id 제거).
  List<String> get normalizedOrder {
    final seen = <String>{};
    final result = <String>[];
    for (final id in order) {
      if (kAppTabs.containsKey(id) && seen.add(id)) result.add(id);
    }
    // 레지스트리에 새로 추가된 탭은 끝에 보충
    for (final id in kDefaultTabOrder) {
      if (kAppTabs.containsKey(id) && seen.add(id)) result.add(id);
    }
    return result;
  }

  /// 실제 화면에 표시할 탭 id 들 (순서 적용 + 숨김 제외, locked 는 항상 포함).
  List<String> get visibleOrder {
    return normalizedOrder.where((id) {
      final t = kAppTabs[id]!;
      return t.lockedVisible || !hidden.contains(id);
    }).toList();
  }

  bool isVisible(String id) {
    final t = kAppTabs[id];
    if (t == null) return false;
    return t.lockedVisible || !hidden.contains(id);
  }

  MenuSettings copyWith({List<String>? order, Set<String>? hidden}) =>
      MenuSettings(
        order: order ?? this.order,
        hidden: hidden ?? this.hidden,
      );

  Map<String, dynamic> toJson() => {
        'order': order,
        'hidden': hidden.toList(),
      };

  factory MenuSettings.fromJson(Map<String, dynamic> j) => MenuSettings(
        order: (j['order'] as List?)?.map((e) => e as String).toList() ??
            kDefaultTabOrder,
        hidden: (j['hidden'] as List?)?.map((e) => e as String).toSet() ??
            const {},
      );

  String toJsonString() => jsonEncode(toJson());
  factory MenuSettings.fromJsonString(String s) =>
      MenuSettings.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

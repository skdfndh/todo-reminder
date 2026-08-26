// 语义版本号解析与比较的纯函数，供「应用内检查更新」判断新旧版本。

/// 语义版本号（如 1.2.3）的解析与比较。
///
/// 只比较数字段，忽略前缀 v/V 与 `+buildNumber` 后缀。
/// 逐段比较、短段按 0 补齐（1.0 == 1.0.0）。不引入第三方包。
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.parts);

  /// 各数字段，如 [major, minor, patch]。
  final List<int> parts;

  /// 从 'v1.1.0' / '1.0.0' / '1.0.0+1' 解析；无法解析返回 null。
  static AppVersion? tryParse(String s) {
    var text = s.trim();
    // 去掉常见的 v 前缀。
    if (text.length > 1 && (text[0] == 'v' || text[0] == 'V')) {
      text = text.substring(1);
    }
    // 忽略 +buildNumber 后缀。
    final plus = text.indexOf('+');
    if (plus != -1) text = text.substring(0, plus);

    final parts = <int>[];
    for (final seg in text.split('.')) {
      final n = int.tryParse(seg);
      if (n == null) return null;
      parts.add(n);
    }
    return parts.isEmpty ? null : AppVersion(parts);
  }

  @override
  int compareTo(AppVersion other) {
    final len = parts.length > other.parts.length
        ? parts.length
        : other.parts.length;
    for (var i = 0; i < len; i++) {
      final a = i < parts.length ? parts[i] : 0;
      final b = i < other.parts.length ? other.parts[i] : 0;
      if (a != b) return a < b ? -1 : 1;
    }
    return 0;
  }

  /// 是否严格新于 [other]。
  bool isNewerThan(AppVersion other) => compareTo(other) > 0;

  @override
  String toString() => parts.join('.');
}

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeveloperModeState {
  const DeveloperModeState._(this._salt, this._digest, {this.enabled = false});

  final bool enabled;
  final String _salt;
  final String _digest;
  bool get configured => _salt.isNotEmpty && _digest.isNotEmpty;
}

final developerModeProvider =
    AsyncNotifierProvider<DeveloperModeNotifier, DeveloperModeState>(
      DeveloperModeNotifier.new,
    );

class DeveloperModeNotifier extends AsyncNotifier<DeveloperModeState> {
  static const _storageKey = 'developer_mode';

  @override
  Future<DeveloperModeState> build() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_storageKey);
    if (stored == null) return const DeveloperModeState._('', '');
    try {
      final data = jsonDecode(stored);
      if (data is Map<String, dynamic> &&
          data['salt'] is String &&
          data['digest'] is String &&
          RegExp(r'^[0-9a-f]{32}$').hasMatch(data['salt'] as String) &&
          RegExp(r'^[0-9a-f]{64}$').hasMatch(data['digest'] as String)) {
        return DeveloperModeState._(
          data['salt'] as String,
          data['digest'] as String,
          enabled: data['enabled'] == true,
        );
      }
    } on FormatException {
      // 损坏的本机配置不能使开发者模式意外开启。
    }
    return const DeveloperModeState._('', '');
  }

  Future<void> setPasscode(String passcode) async {
    final current = await future;
    if (current.configured) throw StateError('已设置本机口令');
    if (passcode.length < 6 ||
        passcode.length > 64 ||
        passcode.trim().isEmpty) {
      throw const FormatException('口令需为 6 至 64 位');
    }
    final random = Random.secure();
    final salt = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await _save(
      DeveloperModeState._(salt, _digest(salt, passcode), enabled: true),
    );
  }

  Future<bool> unlock(String passcode) async {
    final current = await future;
    if (!current.configured ||
        _digest(current._salt, passcode) != current._digest) {
      return false;
    }
    await _save(
      DeveloperModeState._(current._salt, current._digest, enabled: true),
    );
    return true;
  }

  Future<void> disable() async {
    final current = await future;
    await _save(DeveloperModeState._(current._salt, current._digest));
  }

  String _digest(String salt, String passcode) =>
      sha256.convert(utf8.encode('$salt:$passcode')).toString();

  Future<void> _save(DeveloperModeState value) async {
    final prefs = await SharedPreferences.getInstance();
    // 单条写入，避免开启状态与口令配置只保存了一半。
    final saved = await prefs.setString(
      _storageKey,
      jsonEncode({
        'enabled': value.enabled,
        'salt': value._salt,
        'digest': value._digest,
      }),
    );
    if (!saved) throw StateError('无法保存开发者模式设置');
    state = AsyncData(value);
  }
}

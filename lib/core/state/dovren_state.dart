import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/rules/data/rule_repository.dart';
import '../../features/rules/domain/models/block_rule.dart';

class DovrenState extends ChangeNotifier {
  DovrenState({RuleRepository? repository})
      : repository = repository ?? const RecipeRuleRepository() {
    restore();
  }

  static const _protectionKey = 'protection';
  static const _focusKey = 'focus';
  static const _allowlistKey = 'allowlist';
  static const _enabledRulesKey = 'enabled_rules';
  static const _strictModeKey = 'strict_mode';

  final RuleRepository repository;
  final Set<String> allowlisted = {};
  final Set<String> enabledRuleDomains = {};
  bool protectionEnabled = true;
  bool strictMode = false;
  bool restored = false;
  String focusMode = 'Recipe sites';
  SharedPreferences? _prefs;

  List<BlockRule> get rules => repository.rules();

  List<BlockRule> get activeRules => rules
      .where((rule) => enabledRuleDomains.contains(rule.domain))
      .toList(growable: false);

  int get blockedToday => activeRules.fold(
        0,
        (sum, rule) => sum + rule.blockedToday,
      );

  bool isRuleEnabled(BlockRule rule) =>
      enabledRuleDomains.contains(rule.domain);

  Future<void> restore() async {
    _prefs = await SharedPreferences.getInstance();
    protectionEnabled = _prefs?.getBool(_protectionKey) ?? true;
    strictMode = _prefs?.getBool(_strictModeKey) ?? false;
    focusMode = _prefs?.getString(_focusKey) ?? 'Recipe sites';
    allowlisted
      ..clear()
      ..addAll(_prefs?.getStringList(_allowlistKey) ?? const []);
    final savedRules = _prefs?.getStringList(_enabledRulesKey);
    enabledRuleDomains
      ..clear()
      ..addAll(savedRules ?? rules.map((rule) => rule.domain));
    restored = true;
    notifyListeners();
  }

  Future<void> setProtection(bool value) async {
    protectionEnabled = value;
    await _prefs?.setBool(_protectionKey, value);
    notifyListeners();
  }

  Future<void> setFocus(String value) async {
    focusMode = value;
    await _prefs?.setString(_focusKey, value);
    notifyListeners();
  }

  Future<void> setStrictMode(bool value) async {
    strictMode = value;
    if (value) {
      enabledRuleDomains
        ..clear()
        ..addAll(rules.map((rule) => rule.domain));
      await _prefs?.setStringList(
        _enabledRulesKey,
        enabledRuleDomains.toList(growable: false),
      );
    }
    await _prefs?.setBool(_strictModeKey, value);
    notifyListeners();
  }

  Future<void> setRuleEnabled(BlockRule rule, bool enabled) async {
    if (enabled) {
      enabledRuleDomains.add(rule.domain);
    } else {
      enabledRuleDomains.remove(rule.domain);
      if (strictMode) {
        strictMode = false;
        await _prefs?.setBool(_strictModeKey, false);
      }
    }
    await _prefs?.setStringList(
      _enabledRulesKey,
      enabledRuleDomains.toList(growable: false),
    );
    notifyListeners();
  }

  Future<void> addAllowlistedSite(String domain) async {
    final normalized = domain.trim().toLowerCase();
    if (normalized.isEmpty) return;
    allowlisted.add(normalized);
    await _saveAllowlist();
    notifyListeners();
  }

  Future<void> removeAllowlistedSite(String domain) async {
    allowlisted.remove(domain);
    await _saveAllowlist();
    notifyListeners();
  }

  Future<void> toggleAllowlist(String domain) async {
    if (allowlisted.contains(domain)) {
      await removeAllowlistedSite(domain);
    } else {
      await addAllowlistedSite(domain);
    }
  }

  Future<void> _saveAllowlist() async {
    final preferences = _prefs ?? await SharedPreferences.getInstance();
    _prefs = preferences;
    await preferences.setStringList(
      _allowlistKey,
      allowlisted.toList(growable: false),
    );
  }
}

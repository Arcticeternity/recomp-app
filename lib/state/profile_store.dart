import 'package:flutter/foundation.dart';

import '../core/macro/macro_ratio.dart';
import '../core/profile/user_profile.dart';
import '../core/storage/app_repository.dart';

/// 用户配置域：档案、主题、API Key、自定义宏量配比。
class ProfileStore extends ChangeNotifier {
  ProfileStore(this._repository);

  final AppRepository _repository;

  UserProfile? _profile;
  String? _themeName;
  String? _apiKey;
  MacroRatio? _customRatio;

  UserProfile? get profile => _profile;
  String? get themeName => _themeName;
  String? get apiKey => _apiKey;

  /// 用户自定义的配比；null 表示跟随档案推荐值。
  MacroRatio? get customRatio => _customRatio;

  Future<void> load() async {
    _profile = await _repository.loadProfile();
    _themeName = await _repository.loadTheme();
    _apiKey = await _repository.loadApiKey();
    _customRatio = await _repository.loadMacroRatio();
    notifyListeners();
  }

  Future<void> saveProfile(UserProfile profile) async {
    _profile = profile;
    notifyListeners();
    await _repository.saveProfile(profile);
  }

  Future<void> saveTheme(String name) async {
    _themeName = name;
    notifyListeners();
    await _repository.saveTheme(name);
  }

  Future<void> saveApiKey(String key) async {
    _apiKey = key;
    notifyListeners();
    await _repository.saveApiKey(key);
  }

  Future<void> saveMacroRatio(MacroRatio ratio) async {
    _customRatio = ratio;
    notifyListeners();
    await _repository.saveMacroRatio(ratio);
  }

  /// 恢复推荐配比。
  Future<void> clearMacroRatio() async {
    _customRatio = null;
    notifyListeners();
    await _repository.clearMacroRatio();
  }
}

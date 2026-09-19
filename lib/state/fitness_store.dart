import 'package:flutter/foundation.dart';

import '../core/fitness/favorite.dart';
import '../core/storage/app_repository.dart';

/// 健身收藏域：收藏分组、已收藏动作。
class FitnessStore extends ChangeNotifier {
  FitnessStore(this._repository);

  final AppRepository _repository;

  List<FavoriteGroup> _favoriteGroups = [];
  Set<String> _favoriteIds = {};

  List<FavoriteGroup> get favoriteGroups => List.unmodifiable(_favoriteGroups);
  Set<String> get favoriteIds => _favoriteIds;

  Future<void> load() async {
    _favoriteGroups = await _repository.loadFavoriteGroups();
    _favoriteIds = await _repository.loadFavoriteActionIds();
    notifyListeners();
  }

  Future<int> addFavoriteGroup(String name) async {
    final id = await _repository.addFavoriteGroup(name);
    _favoriteGroups = await _repository.loadFavoriteGroups();
    notifyListeners();
    return id;
  }

  Future<void> renameFavoriteGroup(int id, String name) async {
    await _repository.renameFavoriteGroup(id, name);
    _favoriteGroups = await _repository.loadFavoriteGroups();
    notifyListeners();
  }

  Future<void> deleteFavoriteGroup(int id) async {
    await _repository.deleteFavoriteGroup(id);
    _favoriteGroups = await _repository.loadFavoriteGroups();
    _favoriteIds = await _repository.loadFavoriteActionIds();
    notifyListeners();
  }

  Future<void> addFavorite(String actionId, int groupId) async {
    await _repository.addFavorite(actionId, groupId);
    _favoriteIds = await _repository.loadFavoriteActionIds();
    notifyListeners();
  }

  Future<void> removeFavorite(String actionId) async {
    await _repository.removeFavorite(actionId);
    _favoriteIds = await _repository.loadFavoriteActionIds();
    notifyListeners();
  }

  Future<List<String>> loadFavoritesInGroup(int groupId) =>
      _repository.loadFavoritesInGroup(groupId);
}

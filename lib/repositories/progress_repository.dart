import 'package:shared_preferences/shared_preferences.dart';

import '../models/progress_store.dart';

class ProgressRepository {
  const ProgressRepository();

  static const storageKey = 'japan_driver_progress_v1';

  Future<ProgressStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ProgressStore.decode(prefs.getString(storageKey));
  }

  Future<void> save(ProgressStore store) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, store.encode());
  }
}

import '../services/fichajes_api_service.dart';

/// In-memory cache for employee's assigned places.
/// TTL: 4 hours (OPTIMIZACION-RECURSOS-RED §3.2).
class PlacesCache {
  static List<Place>? _places;
  static DateTime? _fetchedAt;
  static const _ttl = Duration(hours: 4);

  static bool get _isValid =>
      _places != null &&
      _fetchedAt != null &&
      DateTime.now().difference(_fetchedAt!) < _ttl;

  static Future<List<Place>> getPlaces({bool forceRefresh = false}) async {
    if (!forceRefresh && _isValid) return _places!;

    final result = await FichajesApiService.getPlaces();
    if (result.error == null) {
      _places = result.data;
      _fetchedAt = DateTime.now();
    }
    return _places ?? result.data;
  }

  static void invalidate() {
    _places = null;
    _fetchedAt = null;
  }
}

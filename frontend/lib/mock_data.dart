import 'models.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

// No longer hardcoded to Karachi!
// This file is now a dynamic data provider that defaults to empty states
// unless the backend provides live data (not yet implemented for bulk lists).

// Empty lists by default to force live data fetching or "Empty State" UI
List<CivicCase> caseItems = [];
List<CivicCase> feedCases = [];
List<MapIssue> mapIssues = [];

CivicCase? caseById(String id) {
  final allCases = [...caseItems, ...feedCases];
  final index = allCases.indexWhere((item) => item.id == id);
  return index != -1 ? allCases[index] : null;
}

/// Helper to calculate distance from user to a point
double calculateDistance(Position userPos, double targetLat, double targetLng) {
  return Geolocator.distanceBetween(
    userPos.latitude,
    userPos.longitude,
    targetLat,
    targetLng,
  );
}

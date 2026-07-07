enum MapLayerType {
  offlineBaseMap,
  vehicleTrack,
  missionRoute,
  geofence,
  noGoZone,
}

class GeoPoint {
  const GeoPoint({
    required this.latitude,
    required this.longitude,
    this.altitudeMeters,
  });

  final double latitude;
  final double longitude;
  final double? altitudeMeters;
}

class MapBounds {
  const MapBounds({required this.southWest, required this.northEast});

  final GeoPoint southWest;
  final GeoPoint northEast;
}

class OperationZone {
  const OperationZone({
    required this.id,
    required this.name,
    required this.points,
  });

  final String id;
  final String name;
  final List<GeoPoint> points;
}

class NoGoZone {
  const NoGoZone({required this.id, required this.name, required this.points});

  final String id;
  final String name;
  final List<GeoPoint> points;
}

class GeofencePolygon {
  const GeofencePolygon({
    required this.id,
    required this.name,
    required this.points,
  });

  final String id;
  final String name;
  final List<GeoPoint> points;
}

class VehicleTrackPoint {
  const VehicleTrackPoint({
    required this.position,
    required this.timestamp,
    this.headingDegrees,
  });

  final GeoPoint position;
  final DateTime timestamp;
  final double? headingDegrees;
}

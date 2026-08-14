import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../models/navigation_route.dart';

abstract interface class NavigationService {
  String get providerId;
  String get profileId;
  bool get providerFrozen;

  Future<List<PlaceSuggestion>> search(String query, {LatLng? near});
  Future<NavigationRoute> bicycleRoute({
    required LatLng origin,
    required PlaceSuggestion destination,
  });
}

class OpenNavigationService implements NavigationService {
  OpenNavigationService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  String get providerId => 'valhalla-public-prototype-candidate';

  @override
  String get profileId => 'bicycle/hybrid';

  @override
  bool get providerFrozen => false;

  @override
  Future<List<PlaceSuggestion>> search(String query, {LatLng? near}) async {
    if (query.trim().length < 3) return const <PlaceSuggestion>[];
    final parameters = <String, String>{
      'q': query.trim(),
      'format': 'jsonv2',
      'limit': '6',
      'addressdetails': '1',
    };
    if (near != null) {
      parameters['viewbox'] =
          '${near.longitude - 0.3},${near.latitude + 0.2},${near.longitude + 0.3},${near.latitude - 0.2}';
      parameters['bounded'] = '0';
    }
    final response = await _client.get(
      Uri.https('nominatim.openstreetmap.org', '/search', parameters),
      headers: const {'User-Agent': 'BicycleOBU/1.0 (research prototype)'},
    );
    if (response.statusCode != 200) {
      throw StateError('Place search failed (${response.statusCode}).');
    }
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((raw) {
          final item = raw as Map<String, dynamic>;
          return PlaceSuggestion(
            name: item['display_name']?.toString() ?? 'Selected destination',
            location: LatLng(
              double.parse(item['lat'].toString()),
              double.parse(item['lon'].toString()),
            ),
          );
        })
        .toList(growable: false);
  }

  @override
  Future<NavigationRoute> bicycleRoute({
    required LatLng origin,
    required PlaceSuggestion destination,
  }) async {
    final response = await _client.post(
      Uri.https('valhalla1.openstreetmap.de', '/route'),
      headers: const {
        'Content-Type': 'application/json',
        'X-Client-Id': 'com.niklasdathe.bicycle_obu',
      },
      body: jsonEncode(<String, Object>{
        'locations': <Map<String, double>>[
          <String, double>{'lat': origin.latitude, 'lon': origin.longitude},
          <String, double>{
            'lat': destination.location.latitude,
            'lon': destination.location.longitude,
          },
        ],
        'costing': 'bicycle',
        'costing_options': <String, Object>{
          'bicycle': <String, Object>{
            'bicycle_type': 'hybrid',
            'use_roads': 0.35,
            'use_hills': 0.45,
          },
        },
        'units': 'kilometers',
        'language': 'en-US',
      }),
    );
    if (response.statusCode != 200) {
      throw StateError('Route request failed (${response.statusCode}).');
    }
    final root = jsonDecode(response.body) as Map<String, dynamic>;
    final trip = root['trip'] as Map<String, dynamic>?;
    if (trip == null || trip['status'] != 0) {
      throw StateError(
        trip?['status_message']?.toString() ?? 'No route was found.',
      );
    }
    final summary = trip['summary'] as Map<String, dynamic>;
    final legs = trip['legs'] as List<dynamic>? ?? const <dynamic>[];
    final points = <LatLng>[];
    final steps = <RouteStep>[];
    for (final rawLeg in legs) {
      final leg = rawLeg as Map<String, dynamic>;
      final legPoints = _decodePolyline6(leg['shape'].toString());
      final pointOffset = points.length;
      points.addAll(legPoints);
      for (final rawManeuver
          in leg['maneuvers'] as List<dynamic>? ?? const <dynamic>[]) {
        final maneuver = rawManeuver as Map<String, dynamic>;
        final shapeIndex =
            (maneuver['begin_shape_index'] as num?)?.toInt() ?? 0;
        final pointIndex = (pointOffset + shapeIndex)
            .clamp(0, points.length - 1)
            .toInt();
        final location = points[pointIndex];
        steps.add(
          RouteStep(
            instruction: maneuver['instruction']?.toString() ?? 'Continue',
            street:
                (maneuver['street_names'] as List<dynamic>?)?.isNotEmpty ??
                    false
                ? (maneuver['street_names'] as List<dynamic>).first.toString()
                : 'Unnamed road',
            distanceMeters:
                ((maneuver['length'] as num?)?.toDouble() ?? 0) * 1000,
            location: location,
          ),
        );
      }
    }
    return NavigationRoute(
      destinationName: destination.name,
      destination: destination.location,
      geometry: points,
      steps: steps,
      distanceMeters: (summary['length'] as num).toDouble() * 1000,
      durationSeconds: (summary['time'] as num).toDouble(),
    );
  }

  List<LatLng> _decodePolyline6(String encoded) {
    final result = <LatLng>[];
    var index = 0;
    var latitude = 0;
    var longitude = 0;
    while (index < encoded.length) {
      final latDelta = _decodeComponent(encoded, () => index++);
      final lonDelta = _decodeComponent(encoded, () => index++);
      latitude += latDelta;
      longitude += lonDelta;
      result.add(LatLng(latitude / 1e6, longitude / 1e6));
    }
    return result;
  }

  int _decodeComponent(String encoded, int Function() nextIndex) {
    var result = 0;
    var shift = 0;
    int value;
    do {
      final index = nextIndex();
      if (index >= encoded.length)
        throw const FormatException('Invalid route shape.');
      value = encoded.codeUnitAt(index) - 63;
      result |= (value & 0x1f) << shift;
      shift += 5;
    } while (value >= 0x20);
    return (result & 1) != 0 ? ~(result >> 1) : result >> 1;
  }
}

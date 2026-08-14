import 'package:bicycle_obu/data/navigation/navigation_service.dart';
import 'package:bicycle_obu/models/navigation_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('requests bicycle costing and parses Valhalla route', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(_valhallaFixture, 200);
    });
    final service = OpenNavigationService(client: client);

    final route = await service.bicycleRoute(
      origin: const LatLng(38.5, -120.2),
      destination: const PlaceSuggestion(
        name: 'Destination',
        location: LatLng(43.252, -126.453),
      ),
    );

    expect(captured.method, 'POST');
    expect(captured.body, contains('"costing":"bicycle"'));
    expect(route.distanceMeters, 12500);
    expect(route.durationSeconds, 1800);
    expect(route.geometry, hasLength(3));
    expect(route.steps.single.instruction, 'Head northeast');
  });
}

const _valhallaFixture = '''
{
  "trip": {
    "status": 0,
    "status_message": "Found route between points",
    "summary": {"length": 12.5, "time": 1800},
    "legs": [{
      "shape": "_p~iF~ps|U_ulLnnqC_mqNvxq`@",
      "maneuvers": [{
        "instruction": "Head northeast",
        "street_names": ["Teststraße"],
        "length": 12.5,
        "begin_shape_index": 0
      }]
    }]
  }
}
''';

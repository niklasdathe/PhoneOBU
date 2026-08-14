import 'package:bicycle_obu/cits/cits_interpreter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('interprets all required C-ITS message sets', () {
    expect(
      CitsInterpreter.interpret(<String, Object?>{
        'messageSet': 'VAM',
        'stationId': 2,
      }),
      isA<VamRoadUser>(),
    );
    expect(
      CitsInterpreter.interpret(<String, Object?>{
        'messageSet': 'CAM',
        'stationId': 1,
        'distanceM': 32,
      }),
      isA<CamRoadUser>(),
    );
    expect(
      CitsInterpreter.interpret(<String, Object?>{
        'messageSet': 'DENM',
        'cause': 'roadWorks',
      }),
      isA<DenmEvent>(),
    );
    expect(
      CitsInterpreter.interpret(<String, Object?>{
        'messageSet': 'MAPEM',
        'intersectionId': 7,
      }),
      isA<MapemIntersection>(),
    );
    expect(
      CitsInterpreter.interpret(<String, Object?>{
        'messageSet': 'SPATEM',
        'intersectionId': 7,
        'state': 'permissiveMovementAllowed',
      }),
      isA<SpatemSignal>(),
    );
    expect(
      CitsInterpreter.interpret(<String, Object?>{
        'messageSet': 'IVIM',
        'informationCode': 'speedLimit',
      }),
      isA<IvimInformation>(),
    );
  });
}

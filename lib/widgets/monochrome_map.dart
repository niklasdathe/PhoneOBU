import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/navigation_route.dart';
import '../models/phone_sensor_snapshot.dart';
import '../theme/obu_theme.dart';

class MonochromeMap extends StatefulWidget {
  const MonochromeMap({
    required this.phoneSensors,
    required this.navigation,
    required this.onDestinationSelected,
    required this.highContrast,
    super.key,
  });

  final PhoneSensorSnapshot phoneSensors;
  final NavigationState navigation;
  final ValueChanged<PlaceSuggestion> onDestinationSelected;
  final bool highContrast;

  @override
  State<MonochromeMap> createState() => _MonochromeMapState();
}

class _MonochromeMapState extends State<MonochromeMap> {
  final _mapController = MapController();
  bool _followLocation = true;
  LatLng? _lastCentered;

  @override
  void didUpdateWidget(covariant MonochromeMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final location = widget.phoneSensors.location;
    if (!_followLocation || location == null) return;
    final point = LatLng(location.latitude, location.longitude);
    if (_lastCentered == null ||
        const Distance().as(LengthUnit.Meter, _lastCentered!, point) > 3) {
      _lastCentered = point;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mapController.move(point, 16.5);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = widget.phoneSensors.location;
    final current = location == null
        ? const LatLng(53.551086, 9.993682)
        : LatLng(location.latitude, location.longitude);
    final route = widget.navigation.route;
    return Semantics(
      label: 'Live OpenStreetMap navigation map. Long press to route to a point.',
      child: Stack(
        children: <Widget>[
          ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              0.33, 0.33, 0.33, 0, 0,
              0.33, 0.33, 0.33, 0, 0,
              0.33, 0.33, 0.33, 0, 0,
              0, 0, 0, 1, 0,
            ]),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: current,
                initialZoom: 16.5,
                onPositionChanged: (_, gesture) {
                  if (gesture) setState(() => _followLocation = false);
                },
                onLongPress: (_, point) => widget.onDestinationSelected(
                  PlaceSuggestion(name: 'Dropped pin', location: point),
                ),
              ),
              children: <Widget>[
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.niklasdathe.bicycle_obu',
                ),
                if (route != null && route.geometry.isNotEmpty)
                  PolylineLayer(
                    polylines: <Polyline>[
                      Polyline(
                        points: route.geometry,
                        color: ObuColors.ink,
                        strokeWidth: widget.highContrast ? 9 : 7,
                        borderColor: Colors.white,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: <Marker>[
                    Marker(
                      point: current,
                      width: 46,
                      height: 46,
                      child: _LocationMarker(
                        heading: location?.courseDegrees ??
                            widget.phoneSensors.compassHeadingDegrees ??
                            0,
                      ),
                    ),
                    if (route != null)
                      Marker(
                        point: route.destination,
                        width: 38,
                        height: 38,
                        child: const Icon(
                          Icons.location_on_rounded,
                          size: 38,
                          color: ObuColors.green,
                        ),
                      ),
                  ],
                ),
                RichAttributionWidget(
                  attributions: const <SourceAttribution>[
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            right: 14,
            bottom: 225,
            child: FloatingActionButton.small(
              heroTag: 'recenter-map',
              tooltip: 'Follow phone location',
              backgroundColor: Colors.white,
              foregroundColor: ObuColors.ink,
              onPressed: () {
                setState(() => _followLocation = true);
                _mapController.move(current, 16.5);
              },
              child: const Icon(Icons.my_location_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationMarker extends StatelessWidget {
  const _LocationMarker({required this.heading});

  final double heading;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: ObuColors.ink, width: 2),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x33000000), blurRadius: 8),
        ],
      ),
      child: Transform.rotate(
        angle: heading * 3.141592653589793 / 180,
        child: const Icon(Icons.navigation_rounded, color: ObuColors.ink),
      ),
    );
  }
}

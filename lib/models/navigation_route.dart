import 'package:latlong2/latlong.dart';

class PlaceSuggestion {
  const PlaceSuggestion({required this.name, required this.location});

  final String name;
  final LatLng location;
}

class RouteStep {
  const RouteStep({
    required this.instruction,
    required this.street,
    required this.distanceMeters,
    required this.location,
  });

  final String instruction;
  final String street;
  final double distanceMeters;
  final LatLng location;
}

class NavigationRoute {
  const NavigationRoute({
    required this.destinationName,
    required this.destination,
    required this.geometry,
    required this.steps,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final String destinationName;
  final LatLng destination;
  final List<LatLng> geometry;
  final List<RouteStep> steps;
  final double distanceMeters;
  final double durationSeconds;
}

enum NavigationStatus { idle, searching, routing, navigating, error }

class NavigationState {
  const NavigationState({
    required this.status,
    required this.route,
    required this.currentStepIndex,
    required this.distanceToNextStepMeters,
    required this.searchResults,
    required this.error,
  });

  factory NavigationState.initial() => const NavigationState(
    status: NavigationStatus.idle,
    route: null,
    currentStepIndex: 0,
    distanceToNextStepMeters: null,
    searchResults: <PlaceSuggestion>[],
    error: null,
  );

  final NavigationStatus status;
  final NavigationRoute? route;
  final int currentStepIndex;
  final double? distanceToNextStepMeters;
  final List<PlaceSuggestion> searchResults;
  final String? error;

  RouteStep? get currentStep {
    final value = route;
    if (value == null || value.steps.isEmpty) return null;
    final index = currentStepIndex.clamp(0, value.steps.length - 1).toInt();
    return value.steps[index];
  }

  NavigationState copyWith({
    NavigationStatus? status,
    NavigationRoute? route,
    int? currentStepIndex,
    double? distanceToNextStepMeters,
    List<PlaceSuggestion>? searchResults,
    String? error,
    bool clearRoute = false,
    bool clearDistance = false,
    bool clearError = false,
  }) => NavigationState(
    status: status ?? this.status,
    route: clearRoute ? null : route ?? this.route,
    currentStepIndex: currentStepIndex ?? this.currentStepIndex,
    distanceToNextStepMeters: clearDistance
        ? null
        : distanceToNextStepMeters ?? this.distanceToNextStepMeters,
    searchResults: searchResults ?? this.searchResults,
    error: clearError ? null : error ?? this.error,
  );
}

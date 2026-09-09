import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/design_tokens.dart';

/// Shared, reusable map view that renders store markers from a plain list.
///
/// This widget is intentionally data-source agnostic: callers already resolved
/// the store list and pass it here. It guarantees that the inline "Discover
/// Now" map and the full Map tab render markers with identical behavior.
class StoresMapView extends StatelessWidget {
  final List<Map<String, dynamic>> stores;
  final LatLng? initialCenter;
  final double initialZoom;
  final MapController? controller;
  final void Function(Map<String, dynamic> store)? onStoreTap;
  final Color markerColor;
  final InteractionOptions interactionOptions;
  final String userAgentPackageName;
  final void Function(MapPosition position, bool hasGesture)? onPositionChanged;

  const StoresMapView({
    super.key,
    required this.stores,
    this.initialCenter,
    this.initialZoom = 12.0,
    this.controller,
    this.onStoreTap,
    this.markerColor = kGold,
    this.interactionOptions = const InteractionOptions(
      flags: InteractiveFlag.all,
    ),
    this.userAgentPackageName = 'com.kupuna.coupona',
    this.onPositionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final center = _resolveCenter();
    final markers = stores.where(_hasValidLocation).map(_buildMarker).toList();

    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: initialZoom,
        interactionOptions: interactionOptions,
        onPositionChanged: onPositionChanged,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: userAgentPackageName,
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }

  LatLng _resolveCenter() {
    if (initialCenter != null) return initialCenter!;
    final firstValid = stores.where(_hasValidLocation).firstOrNull;
    if (firstValid != null) {
      final lat = readCoordinate(firstValid, ['lat', 'latitude']);
      final lng = readCoordinate(firstValid, ['lng', 'longitude']);
      if (lat != null && lng != null) {
        return LatLng(lat, lng);
      }
    }
    return const LatLng(32.8872, 13.1913);
  }

  bool _hasValidLocation(Map<String, dynamic> store) {
    final lat = readCoordinate(store, ['lat', 'latitude']);
    final lng = readCoordinate(store, ['lng', 'longitude']);
    return lat != null && lng != null && lat != 0 && lng != 0;
  }

  Marker _buildMarker(Map<String, dynamic> store) {
    final lat = readCoordinate(store, ['lat', 'latitude']);
    final lng = readCoordinate(store, ['lng', 'longitude']);
    final name = (store['name'] ?? '').toString();

    return Marker(
      width: 42,
      height: 42,
      point: LatLng(lat ?? 0, lng ?? 0),
      child: GestureDetector(
        onTap: onStoreTap == null ? null : () => onStoreTap!(store),
        child: Tooltip(
          message: name,
          child: Icon(
            Icons.location_on,
            color: markerColor,
            size: 36,
          ),
        ),
      ),
    );
  }
}

double? readCoordinate(Map<String, dynamic> store, List<String> candidateKeys) {
  for (final key in candidateKeys) {
    final value = store[key];
    if (value != null) {
      final parsed = double.tryParse(value.toString());
      if (parsed != null) return parsed;
    }
  }

  final nested = store['location'];
  if (nested is Map) {
    for (final key in candidateKeys) {
      final value = nested[key];
      if (value != null) {
        final parsed = double.tryParse(value.toString());
        if (parsed != null) return parsed;
      }
    }
    final altLat = nested['latitude'] ?? nested['lat'];
    final altLng = nested['longitude'] ?? nested['lng'];
    if (candidateKeys.contains('lat') || candidateKeys.contains('latitude')) {
      final parsed = double.tryParse((altLat ?? '').toString());
      if (parsed != null) return parsed;
    }
    if (candidateKeys.contains('lng') || candidateKeys.contains('longitude')) {
      final parsed = double.tryParse((altLng ?? '').toString());
      if (parsed != null) return parsed;
    }
  }

  return null;
}

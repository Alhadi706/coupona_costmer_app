import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class AnalyticsMapPanel extends StatelessWidget {
  final List<Map<String, dynamic>> points;
  final String emptyLabel;
  final Color markerColor;

  const AnalyticsMapPanel({
    super.key,
    required this.points,
    required this.emptyLabel,
    this.markerColor = const Color(0xFFE0B13F),
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Text(emptyLabel);
    }

    final validPoints = points
        .where((point) => point['latitude'] != null && point['longitude'] != null)
        .toList(growable: false);
    if (validPoints.isEmpty) {
      return Text(emptyLabel);
    }

    final centerLat = validPoints.fold<double>(
          0,
          (sum, point) => sum + _toDouble(point['latitude']),
        ) /
        validPoints.length;
    final centerLng = validPoints.fold<double>(
          0,
          (sum, point) => sum + _toDouble(point['longitude']),
        ) /
        validPoints.length;

    return SizedBox(
      height: 340,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: LatLng(centerLat, centerLng),
            initialZoom: _initialZoom(validPoints),
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.kupuna.coupona',
            ),
            MarkerLayer(
              markers: validPoints.map((point) {
                final label = (point['label'] ?? '').toString();
                final value = (point['value'] ?? '').toString();
                final textValue = value.isEmpty ? label : '$label • $value';
                return Marker(
                  point: LatLng(_toDouble(point['latitude']), _toDouble(point['longitude'])),
                  width: 150,
                  height: 62,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on, color: markerColor, size: 30),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 145),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        color: Colors.white.withValues(alpha: 0.92),
                        child: Text(textValue, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                );
              }).toList(growable: false),
            ),
            RichAttributionWidget(
              attributions: [TextSourceAttribution('OpenStreetMap contributors')],
            ),
          ],
        ),
      ),
    );
  }

  double _initialZoom(List<Map<String, dynamic>> points) {
    if (points.length < 2) return 12;
    final latitudes = points.map((p) => _toDouble(p['latitude']));
    final longitudes = points.map((p) => _toDouble(p['longitude']));
    final span = [latitudes.reduce((a, b) => a > b ? a : b) - latitudes.reduce((a, b) => a < b ? a : b), longitudes.reduce((a, b) => a > b ? a : b) - longitudes.reduce((a, b) => a < b ? a : b)].reduce((a, b) => a > b ? a : b);
    if (span > 20) return 3;
    if (span > 5) return 6;
    if (span > 1) return 8;
    return 11;
  }

  double _toDouble(dynamic value) {
    final parsed = double.tryParse('${value ?? 0}');
    return parsed ?? 0;
  }
}

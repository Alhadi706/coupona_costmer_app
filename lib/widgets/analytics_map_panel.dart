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
      height: 220,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: LatLng(centerLat, centerLng),
            initialZoom: 11,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.coupona_app',
            ),
            MarkerLayer(
              markers: validPoints.map((point) {
                final label = (point['label'] ?? '').toString();
                final value = (point['value'] ?? '').toString();
                return Marker(
                  point: LatLng(_toDouble(point['latitude']), _toDouble(point['longitude'])),
                  width: 110,
                  height: 54,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on, color: markerColor, size: 30),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          value.isEmpty ? label : '$label • $value',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }

  double _toDouble(dynamic value) {
    final parsed = double.tryParse('${value ?? 0}');
    return parsed ?? 0;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';

class MapPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;
  const MapPickerScreen({Key? key, this.initialLocation}) : super(key: key);

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng? _pickedLocation;

  @override
  void initState() {
    super.initState();
    _pickedLocation = widget.initialLocation ?? LatLng(32.8872, 13.1913); // طرابلس كموقع افتراضي
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تحديد الموقع على الخريطة')),
      body: FlutterMap(
        options: MapOptions(
          center: _pickedLocation,
          zoom: 13.0,
          onTap: (tapPosition, point) {
            setState(() {
              _pickedLocation = point;
            });
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: ['a', 'b', 'c'],
            tileProvider: CancellableNetworkTileProvider(),
          ),
          if (_pickedLocation != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _pickedLocation!,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                ),
              ],
            ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12.0),
        child: ElevatedButton(
          onPressed: () {
            if (_pickedLocation != null) {
              Navigator.of(context).pop(_pickedLocation);
            }
          },
          child: const Text('اختيار هذا الموقع'),
        ),
      ),
    );
  }
}

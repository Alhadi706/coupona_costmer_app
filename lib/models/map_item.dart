import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

enum MapItemType { store, offer }

class MapItem {
  final String id;
  final LatLng position;
  final String title;
  final String? subtitle;
  final String? category;
  final MapItemType type;
  final Map<String, dynamic> data;

  const MapItem({
    required this.id,
    required this.position,
    required this.title,
    required this.type,
    required this.data,
    this.subtitle,
    this.category,
  });

  static MapItem? fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc, MapItemType type) {
    final data = doc.data();
    if (data == null) {
      return null;
    }
    final position = _extractLatLng(data);
    if (position == null) {
      return null;
    }
    final normalizedData = {...data, 'id': doc.id};
    return MapItem(
      id: doc.id,
      position: position,
      title: _resolveTitle(normalizedData, type),
      subtitle: normalizedData['description']?.toString(),
      category: _resolveCategory(normalizedData),
      type: type,
      data: normalizedData,
    );
  }

  static MapItem? fromMap(Map<String, dynamic> data, MapItemType type) {
    final position = _extractLatLng(data);
    if (position == null) {
      return null;
    }
    final id = (data['id'] ?? '${type.name}-${DateTime.now().millisecondsSinceEpoch}').toString();
    final normalizedData = {...data, 'id': id};
    return MapItem(
      id: id,
      position: position,
      title: _resolveTitle(normalizedData, type),
      subtitle: normalizedData['description']?.toString(),
      category: _resolveCategory(normalizedData),
      type: type,
      data: normalizedData,
    );
  }

  static LatLng? _extractLatLng(Map<String, dynamic> data) {
    final lat = data['lat'];
    final lng = data['lng'];
    if (lat is num && lng is num) {
      return LatLng(lat.toDouble(), lng.toDouble());
    }
    final latitude = data['latitude'];
    final longitude = data['longitude'];
    if (latitude is num && longitude is num) {
      return LatLng(latitude.toDouble(), longitude.toDouble());
    }
    final location = data['location'];
    if (location is GeoPoint) {
      return LatLng(location.latitude, location.longitude);
    }
    if (location is Map) {
      final latValue = location['lat'] ?? location['latitude'];
      final lngValue = location['lng'] ?? location['longitude'];
      if (latValue is num && lngValue is num) {
        return LatLng(latValue.toDouble(), lngValue.toDouble());
      }
      if (latValue is String && lngValue is String) {
        final latNum = double.tryParse(latValue);
        final lngNum = double.tryParse(lngValue);
        if (latNum != null && lngNum != null) {
          return LatLng(latNum, lngNum);
        }
      }
    }
    if (location is List && location.length >= 2) {
      final latValue = location[0];
      final lngValue = location[1];
      if (latValue is num && lngValue is num) {
        return LatLng(latValue.toDouble(), lngValue.toDouble());
      }
    }
    if (location is String) {
      final parts = location.split(',');
      if (parts.length >= 2) {
        final latNum = double.tryParse(parts[0].trim());
        final lngNum = double.tryParse(parts[1].trim());
        if (latNum != null && lngNum != null) {
          return LatLng(latNum, lngNum);
        }
      }
    }
    return null;
  }

  static String _resolveTitle(Map<String, dynamic> data, MapItemType type) {
    if (type == MapItemType.store) {
      return (data['name'] ?? data['storeName'] ?? 'متجر').toString();
    }
    return (data['storeName'] ?? data['title'] ?? data['name'] ?? 'عرض').toString();
  }

  static String? _resolveCategory(Map<String, dynamic> data) {
    final category = data['category'] ?? data['storeCategory'];
    if (category == null) {
      return null;
    }
    return category.toString();
  }

  bool matchesSearch(String text) {
    if (text.isEmpty) {
      return true;
    }
    final lower = text.toLowerCase();
    return title.toLowerCase().contains(lower) ||
        (subtitle?.toLowerCase().contains(lower) ?? false) ||
        data.values.any((value) {
          if (value is String) {
            return value.toLowerCase().contains(lower);
          }
          return false;
        });
  }

  bool matchesCategory(String categoryKey) {
    if (categoryKey.isEmpty) {
      return true;
    }
    if (category == null) {
      return false;
    }
    return category!.toLowerCase() == categoryKey.toLowerCase();
  }
}

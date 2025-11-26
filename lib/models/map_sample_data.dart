import 'map_item.dart';

const List<Map<String, dynamic>> _sampleStoresRaw = [
  {
    'id': 'sample-store-1',
    'name': 'مطعم النخيل',
    'category': 'restaurants',
    'lat': 24.7136,
    'lng': 46.6753,
    'phone': '+966 11 123 4567',
    'location': 'الرياض، حي العليا',
    'description': 'أطباق سعودية مميزة مع عروض على الوجبات العائلية.'
  },
  {
    'id': 'sample-store-2',
    'name': 'متجر التقنية الحديثة',
    'category': 'electronics',
    'lat': 24.7600,
    'lng': 46.6800,
    'phone': '+966 11 987 6543',
    'location': 'الرياض، حي الصحافة',
    'description': 'أحدث الأجهزة الإلكترونية مع ضمان ممتد.'
  },
  {
    'id': 'sample-store-3',
    'name': 'عيادات حياة',
    'category': 'clinics',
    'lat': 24.6995,
    'lng': 46.7220,
    'phone': '+966 11 555 2233',
    'location': 'الرياض، حي غرناطة',
    'description': 'خصومات على الفحوصات الشاملة والاستشارات الطبية.'
  },
];

const List<Map<String, dynamic>> _sampleOffersRaw = [
  {
    'id': 'sample-offer-1',
    'storeName': 'مطعم النخيل',
    'storeCategory': 'restaurants',
    'lat': 24.7136,
    'lng': 46.6753,
    'description': 'خصم 20% على قائمة العشاء طوال أيام الأسبوع.',
    'percent': '20%',
    'location': 'الرياض، حي العليا'
  },
  {
    'id': 'sample-offer-2',
    'storeName': 'متجر التقنية الحديثة',
    'storeCategory': 'electronics',
    'lat': 24.7600,
    'lng': 46.6800,
    'description': 'قسيمة شرائية بقيمة 100 ريال عند الشراء بأكثر من 500 ريال.',
    'discountValue': '100 ريال',
    'location': 'الرياض، حي الصحافة'
  },
  {
    'id': 'sample-offer-3',
    'storeName': 'عيادات حياة',
    'storeCategory': 'clinics',
    'lat': 24.6995,
    'lng': 46.7220,
    'description': 'كشف مجاني للمرضى الجدد مع خصم على التحاليل.',
    'discountValue': 'كشف مجاني',
    'location': 'الرياض، حي غرناطة'
  },
];

final List<MapItem> sampleStoreItems = _sampleStoresRaw
    .map((data) => MapItem.fromMap(data, MapItemType.store))
    .whereType<MapItem>()
    .toList();

final List<MapItem> sampleOfferItems = _sampleOffersRaw
    .map((data) => MapItem.fromMap(data, MapItemType.offer))
    .whereType<MapItem>()
    .toList();

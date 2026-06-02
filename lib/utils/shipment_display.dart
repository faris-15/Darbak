import 'package:intl/intl.dart';

/// Arabic labels for shipment lifecycle (aligned with driver timeline copy).
const Map<String, String> kShipmentLifecycleStatusAr = {
  'pending': 'قيد الانتظار',
  'bidding': 'قيد المزايدة',
  'assigned': 'تم قبول العرض والتعيين',
  'at_pickup': 'وصلت لموقع التحميل',
  'en_route': 'بدأت الرحلة (في الطريق)',
  'at_dropoff': 'وصلت لموقع التسليم',
  'delivered': 'تم التسليم بنجاح',
  'cancelled': 'ملغاة',
};

String shipmentLifecycleStatusAr(String? raw) {
  final s = raw?.toString().trim() ?? '';
  if (s.isEmpty) return 'قيد المعالجة';
  return kShipmentLifecycleStatusAr[s] ?? 'حالة غير معروفة';
}

/// City-style segment from a full address (first comma-separated part).
String shipmentCitySegment(String? address) {
  if (address == null || address.trim().isEmpty) return 'غير محدد';
  return address.split(',').first.trim();
}

/// Arabic labels for pickup / dropoff (cards & headers).
const String kShipmentPickupLocationLabelAr = 'مكان التحميل';
const String kShipmentDropoffLocationLabelAr = 'مكان التسليم';
const String kShipmentDeliveryDateLabelAr = 'تاريخ التسليم';

/// Primary line for an address on cards (first segment; full string if no comma).
String shipmentAddressPrimaryLine(String? address, {int maxChars = 56}) {
  final raw = address?.trim() ?? '';
  if (raw.isEmpty) return 'غير محدد';
  final first = raw.split(',').first.trim();
  final use = first.isNotEmpty ? first : raw;
  if (use.length <= maxChars) return use;
  return '${use.substring(0, maxChars)}…';
}

/// Legacy single-line route (avoid for driver cards; prefer labeled pickup/dropoff).
String shipmentRouteTitle(Map<String, dynamic> shipment) {
  final from = shipmentCitySegment(shipment['pickup_address']?.toString());
  final to = shipmentCitySegment(shipment['dropoff_address']?.toString());
  return '$from ➔ $to';
}

/// Shipper / company display name when the API exposes it.
String shipmentShipperDisplayName(Map<String, dynamic> shipment) {
  for (final key in [
    'shipper_name',
    'shipperName',
    'shipper_full_name',
    'shipperFullName',
    'company_name',
    'companyName',
  ]) {
    final v = shipment[key]?.toString().trim();
    if (v != null && v.isNotEmpty) return v;
  }
  final shipper = shipment['shipper'];
  if (shipper is Map) {
    for (final key in ['full_name', 'fullName', 'name', 'company_name', 'companyName']) {
      final v = shipper[key]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
  }
  return '';
}

/// Short Arabic line for cards (company / shipper).
String shipmentCompanyUiLine(Map<String, dynamic> shipment) {
  final name = shipmentShipperDisplayName(shipment);
  if (name.isEmpty) return 'الشركة: غير متوفرة';
  return 'الشركة: $name';
}

/// Price for «agreed» labels: accepted bid, else suggested, else base listing.
dynamic shipmentAgreedPriceValue(Map<String, dynamic> shipment) {
  return shipment['accepted_bid_amount'] ??
      shipment['suggested_price'] ??
      shipment['base_price'];
}

String formatShipmentDateTimeForUi(dynamic value, {String locale = 'ar_SA'}) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) return 'لم يتم تحديده';
  final local = parsed.toLocal();
  try {
    return DateFormat.yMMMd(locale).add_Hm().format(local);
  } catch (_) {
    return DateFormat('yyyy-MM-dd').format(local);
  }
}

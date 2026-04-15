class BidModel {
  final int id;
  final int shipmentId;
  final int driverId;
  final double bidAmount;
  final int estimatedDays;
  final String bidStatus;
  final String driverName;
  final String? licenseNo;
  final String? phone;
  final double driverRating;
  final int ratingCount;

  BidModel({
    required this.id,
    required this.shipmentId,
    required this.driverId,
    required this.bidAmount,
    required this.estimatedDays,
    required this.bidStatus,
    required this.driverName,
    this.licenseNo,
    this.phone,
    required this.driverRating,
    required this.ratingCount,
  });

  factory BidModel.fromJson(Map<String, dynamic> json) {
    return BidModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      shipmentId: int.tryParse(json['shipment_id']?.toString() ?? '') ?? 0,
      driverId: int.tryParse(json['driver_id']?.toString() ?? '') ?? 0,
      bidAmount: double.tryParse(json['bid_amount'].toString()) ?? 0.0,
      estimatedDays: int.tryParse(json['estimated_days'].toString()) ?? 0,
      bidStatus: json['bid_status']?.toString() ?? '',
      driverName: json['driver_name']?.toString() ?? json['full_name']?.toString() ?? 'سائق',
      licenseNo: json['license_no']?.toString(),
      phone: json['phone']?.toString(),
      driverRating: double.tryParse(json['driver_rating'].toString()) ?? 0.0,
      ratingCount: int.tryParse(json['rating_count'].toString()) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shipment_id': shipmentId,
      'driver_id': driverId,
      'bid_amount': bidAmount,
      'estimated_days': estimatedDays,
      'bid_status': bidStatus,
      'driver_name': driverName,
      'license_no': licenseNo,
      'phone': phone,
      'driver_rating': driverRating,
      'rating_count': ratingCount,
    };
  }
}

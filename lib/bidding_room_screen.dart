import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'api_service.dart';
import 'app_theme.dart';
import 'app_widgets.dart';
import 'models/bid_model.dart';
import 'utils/sar_formatter.dart';
import 'widgets/sar_price.dart';

class BidDetailsScreen extends StatefulWidget {
  final int shipmentId;
  final Map<String, dynamic> shipmentData;
  final int driverId;
  final String driverName;

  const BidDetailsScreen({
    super.key,
    required this.shipmentId,
    required this.shipmentData,
    required this.driverId,
    required this.driverName,
  });

  @override
  State<BidDetailsScreen> createState() => _BidDetailsScreenState();
}

class _BidDetailsScreenState extends State<BidDetailsScreen> {
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _daysController = TextEditingController();
  bool agree = false;
  bool isSubmitting = false;
  String validationError = '';
  List<BidModel> existingBids = [];
  double? lowestBid;
  bool _licenseExpired = false;

  @override
  void initState() {
    super.initState();
    final suggestedPrice = _suggestedPrice;
    _priceController.text = suggestedPrice > 0
        ? suggestedPrice.toStringAsFixed(0)
        : '';
    _daysController.text = '5';
    _loadExistingBids();
    _checkLicenseExpiry();
  }

  double get _suggestedPrice =>
      SarFormatter.parse(
        widget.shipmentData['suggested_price'] ??
            widget.shipmentData['base_price'],
      ) ??
      0;

  Future<void> _checkLicenseExpiry() async {
    try {
      final u = await ApiService.getProfile(widget.driverId);
      final exp = u['expiry_date']?.toString();
      if (exp == null || exp.isEmpty) return;
      final d = DateTime.tryParse(exp);
      if (d == null) return;
      final today = DateTime.now();
      final end = DateTime(d.year, d.month, d.day);
      final start = DateTime(today.year, today.month, today.day);
      if (end.isBefore(start) && mounted) {
        setState(() => _licenseExpired = true);
      }
    } catch (_) {}
  }

  Future<void> _loadExistingBids() async {
    try {
      final bids = await ApiService.getBids(widget.shipmentId);
      setState(() {
        existingBids = bids;
        if (bids.isNotEmpty) {
          lowestBid = bids
              .map((bid) => bid.bidAmount)
              .reduce((value, element) => value < element ? value : element);
        }
      });
    } catch (e) {
      debugPrint('Error loading bids: $e');
    }
  }

  String _validateBid(String priceText) {
    if (priceText.isEmpty) {
      return 'الرجاء إدخال المبلغ';
    }

    final price = SarFormatter.parse(priceText);
    if (price == null || price <= 0) {
      return 'الرجاء إدخال مبلغ صحيح';
    }

    if (price > SarFormatter.maxDatabaseAmount) {
      return 'المبلغ يتجاوز الحد المسموح به';
    }

    return '';
  }

  Future<void> _submitBid() async {
    if (widget.driverId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('خطأ: لم يتم العثور على بيانات السائق'),
          backgroundColor: DarbakColors.danger,
        ),
      );
      return;
    }

    if (_licenseExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'انتهت صلاحية رخصة القيادة. لا يمكنك تقديم عروض حتى تجدد الرخصة.',
          ),
          backgroundColor: DarbakColors.danger,
        ),
      );
      return;
    }

    final error = _validateBid(_priceController.text);
    if (error.isNotEmpty) {
      setState(() {
        validationError = error;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: DarbakColors.danger,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    if (!agree) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء الموافقة على الشروط والأحكام'),
          backgroundColor: DarbakColors.danger,
        ),
      );
      return;
    }

    setState(() {
      isSubmitting = true;
      validationError = '';
    });

    try {
      final bidAmount = SarFormatter.parse(_priceController.text)!;
      final estimatedDays = int.tryParse(_daysController.text) ?? 5;
      if (estimatedDays <= 0) {
        throw DarbakException('مدة التسليم المتوقعة غير صحيحة');
      }

      await ApiService.enterBiddingRoom(
        widget.shipmentId,
        widget.driverId,
        bidAmount,
        estimatedDays,
      );

      if (mounted) {
        setState(() {
          isSubmitting = false;
        });

        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    color: DarbakColors.success,
                    size: 28,
                  ),
                  SizedBox(width: 12),
                  Text('تم إرسال العرض بنجاح'),
                ],
              ),
              content: const Text(
                'تم إرسال عرضك للشركة. سيتم إخطارك عند قبول العرض.',
                style: TextStyle(fontSize: 15, height: 1.6),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Return to previous screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DarbakColors.primary,
                  ),
                  child: const Text('العودة إلى الشحنات'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        final msg = e is DarbakException ? e.message : e.toString();
        setState(() {
          isSubmitting = false;
          validationError = msg;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $msg'),
            backgroundColor: DarbakColors.danger,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  String _getCityDisplay(String? address) {
    if (address == null || address.isEmpty) return 'Unknown';
    return address.split(',')[0].trim();
  }

  double? _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  String _calculateDistance() {
    final storedDistance = _readDouble(
      widget.shipmentData['distance_km'] ??
          widget.shipmentData['distanceKm'] ??
          widget.shipmentData['distance'],
    );
    if (storedDistance != null && storedDistance > 0) {
      return '${storedDistance.toStringAsFixed(0)} كم';
    }

    final pickupLat = _readDouble(widget.shipmentData['pickup_lat']);
    final pickupLng = _readDouble(widget.shipmentData['pickup_lng']);
    final dropoffLat = _readDouble(widget.shipmentData['dropoff_lat']);
    final dropoffLng = _readDouble(widget.shipmentData['dropoff_lng']);
    if ([pickupLat, pickupLng, dropoffLat, dropoffLng].any((v) => v == null)) {
      return 'المسافة غير متاحة';
    }

    const earthRadiusKm = 6371.0;
    final dLat = _degreesToRadians(dropoffLat! - pickupLat!);
    final dLng = _degreesToRadians(dropoffLng! - pickupLng!);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(pickupLat)) *
            math.cos(_degreesToRadians(dropoffLat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return '${(earthRadiusKm * c).round()} كم';
  }

  double _degreesToRadians(double degrees) => degrees * math.pi / 180;

  String _formatDeliveryDate(dynamic value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return 'غير محدد';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw.replaceAll('T', ' ').replaceAll(RegExp(r'\.000Z$|Z$'), '');
    }

    final local = parsed.isUtc ? parsed.toLocal() : parsed;
    final date =
        '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '$date - $time';
  }

  String _formatAmount(dynamic amount, {int decimalDigits = 2}) {
    return SarFormatter.format(amount, decimalDigits: decimalDigits);
  }

  String _comparisonLabel(double bidAmount, double suggestedPrice) {
    if (suggestedPrice <= 0) return 'لا يوجد سعر مقترح للمقارنة';
    final difference = bidAmount - suggestedPrice;
    if (difference.abs() < 0.01) return 'مطابق للسعر المقترح';

    final percent = (difference.abs() / suggestedPrice) * 100;
    final direction = difference > 0 ? 'أعلى' : 'أقل';
    return '$direction من السعر المقترح بـ ${_formatAmount(difference.abs())} (${percent.toStringAsFixed(1)}%)';
  }

  @override
  void dispose() {
    _priceController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suggestedPrice = _suggestedPrice;
    final typedBid = SarFormatter.parse(_priceController.text);
    final cityFrom = _getCityDisplay(widget.shipmentData['pickup_address']);
    final cityTo = _getCityDisplay(widget.shipmentData['dropoff_address']);
    final distance = _calculateDistance();
    final deliveryDate = _formatDeliveryDate(
      widget.shipmentData['expected_delivery_date'],
    );

    return Scaffold(
      backgroundColor: DarbakColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: DarbakColors.background,
        foregroundColor: DarbakColors.text,
        centerTitle: false,
        title: const Text('ملخص الشحنة'),
        leading: const BackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'غرفة المناقصة',
                  textAlign: TextAlign.start,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xffF7F9FB),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: DarbakColors.borderSoft),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _LocationPin(
                            icon: Icons.place_outlined,
                            color: DarbakColors.primary,
                          ),
                          const Expanded(
                            child: Divider(
                              color: Color(0xffCBD5E1),
                              thickness: 1.3,
                              indent: 10,
                              endIndent: 10,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: DarbakColors.borderSoft,
                              ),
                            ),
                            child: Text(
                              distance,
                              style: const TextStyle(
                                color: DarbakColors.primaryDark,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const Expanded(
                            child: Divider(
                              color: Color(0xffCBD5E1),
                              thickness: 1.3,
                              indent: 10,
                              endIndent: 10,
                            ),
                          ),
                          const _LocationPin(
                            icon: Icons.my_location_rounded,
                            color: DarbakColors.text,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: _RouteCityBlock(label: 'إلى', city: cityTo),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _RouteCityBlock(
                              label: 'من',
                              city: cityFrom,
                              alignEnd: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _BidMetaItem(
                              icon: Icons.inventory_2_outlined,
                              text:
                                  '${widget.shipmentData['weight_kg'] ?? 0} طن',
                            ),
                          ),
                          Expanded(
                            child: _BidMetaItem(
                              icon: Icons.calendar_today_outlined,
                              text: deliveryDate,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _BidMetaItem(
                              icon: Icons.local_shipping_outlined,
                              text:
                                  widget.shipmentData['cargo_description'] ??
                                  'بضائع عامة',
                            ),
                          ),
                          Expanded(
                            child: _BidMetaItem(
                              icon: Icons.payments_outlined,
                              text: lowestBid != null
                                  ? 'أقل عرض: ${_formatAmount(lowestBid, decimalDigits: 0)}'
                                  : 'لا توجد عروض بعد',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _sectionCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.warning_amber_rounded, color: DarbakColors.danger),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'تنبيه: يمكنك تقديم عرض واحد فقط على هذه الشحنة، وعند إرسال العرض يصبح ملزماً.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.7,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _sectionCard(
            child: Column(
              children: [
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    'أدخل قيمة عرضك النهائي',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: DarbakColors.orange,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SarIcon(size: 26, color: Colors.black87),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _priceController,
                          textAlign: TextAlign.center,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) {
                            setState(() {
                              validationError = '';
                            });
                          },
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                          ),
                          decoration: const InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'السعر المقترح من الشركة: ',
                      style: TextStyle(
                        fontSize: 15,
                        color: DarbakColors.subText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SarPrice(
                      amount: suggestedPrice,
                      decimalDigits: 0,
                      style: const TextStyle(
                        fontSize: 15,
                        color: DarbakColors.subText,
                        fontWeight: FontWeight.w600,
                      ),
                      iconSize: 15,
                    ),
                  ],
                ),
                if (lowestBid != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'أقل عرض مقدم حتى الآن: ',
                          style: TextStyle(
                            fontSize: 15,
                            color: DarbakColors.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SarPrice(
                          amount: lowestBid,
                          decimalDigits: 0,
                          style: const TextStyle(
                            fontSize: 15,
                            color: DarbakColors.danger,
                            fontWeight: FontWeight.w600,
                          ),
                          iconSize: 15,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _priceSuggestionButton(
                        (suggestedPrice * 0.90).toStringAsFixed(0),
                        'أقل 10%',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _priceSuggestionButton(
                        suggestedPrice.toStringAsFixed(0),
                        'المقترح',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _priceSuggestionButton(
                        (suggestedPrice * 1.10).toStringAsFixed(0),
                        'أعلى 10%',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (typedBid != null && typedBid > 0)
                  _BidComparisonCard(
                    label: _comparisonLabel(typedBid, suggestedPrice),
                    isHigher: typedBid > suggestedPrice,
                    isMatching: (typedBid - suggestedPrice).abs() < 0.01,
                  ),
                if (validationError.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      validationError,
                      style: const TextStyle(
                        color: DarbakColors.danger,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xffF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: agree,
                        activeColor: DarbakColors.primary,
                        onChanged: (v) {
                          setState(() => agree = v ?? false);
                        },
                      ),
                      const Expanded(
                        child: Text(
                          'أقر بأن هذا العرض نهائي وملزم، وأوافق على شروط وأحكام المنصة',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: isSubmitting ? null : _submitBid,
                    icon: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.check_circle_outline_rounded),
                    label: Text(
                      isSubmitting ? 'جاري الإرسال...' : 'تأكيد وإرسال العرض',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: DarbakColors.success,
                      disabledBackgroundColor: const Color(0xffCFE7C9),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceSuggestionButton(String value, String label) {
    return OutlinedButton(
      onPressed: () => setState(() => _priceController.text = value),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: DarbakColors.text,
        side: const BorderSide(color: DarbakColors.borderSoft),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          SarPrice(
            amount: value,
            decimalDigits: 0,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            iconSize: 14,
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return DarbakSurface(padding: const EdgeInsets.all(16), child: child);
  }
}

class _BidComparisonCard extends StatelessWidget {
  final String label;
  final bool isHigher;
  final bool isMatching;

  const _BidComparisonCard({
    required this.label,
    required this.isHigher,
    required this.isMatching,
  });

  @override
  Widget build(BuildContext context) {
    final color = isMatching
        ? DarbakColors.primary
        : isHigher
        ? DarbakColors.orange
        : DarbakColors.success;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            isMatching
                ? Icons.check_circle_outline_rounded
                : isHigher
                ? Icons.trending_up_rounded
                : Icons.trending_down_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationPin extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _LocationPin({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: 21),
    );
  }
}

class _RouteCityBlock extends StatelessWidget {
  final String label;
  final String city;
  final bool alignEnd;

  const _RouteCityBlock({
    required this.label,
    required this.city,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: DarbakColors.subText,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          city,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: DarbakColors.text,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _BidMetaItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BidMetaItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: DarbakColors.subText),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: DarbakColors.text,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

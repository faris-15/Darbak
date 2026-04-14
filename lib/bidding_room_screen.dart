import 'package:flutter/material.dart';
import 'api_service.dart';

class AppColors {
  static const primary = Color(0xff168A57);
  static const primaryDark = Color(0xff0E6D44);
  static const background = Color(0xffF5F7FA);
  static const card = Colors.white;
  static const border = Color(0xffE6E9EF);
  static const text = Color(0xff1B1F24);
  static const subText = Color(0xff6B7280);
  static const danger = Color(0xffD94C4C);
  static const orange = Color(0xffF59E0B);
  static const lightGreen = Color(0xffE9F8F0);
  static const success = Color(0xff79C96B);
}

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
  List<dynamic> existingBids = [];
  double? lowestBid;

  @override
  void initState() {
    super.initState();
    final basePrice = widget.shipmentData['base_price'] ?? 0;
    _priceController.text = basePrice.toString();
    _daysController.text = '5';
    _loadExistingBids();
  }

  Future<void> _loadExistingBids() async {
    try {
      final bids = await ApiService.getBids(widget.shipmentId);
      setState(() {
        existingBids = bids;
        if (bids.isNotEmpty) {
          // Assuming bids are sorted by bid_amount ASC, first one is lowest
          lowestBid = double.tryParse(bids[0]['bid_amount'].toString()) ?? 0;
        }
      });
    } catch (e) {
      print('Error loading bids: $e');
    }
  }

  String _validateBid(String priceText) {
    if (priceText.isEmpty) {
      return 'الرجاء إدخال المبلغ';
    }

    final price = double.tryParse(priceText);
    if (price == null || price <= 0) {
      return 'الرجاء إدخال مبلغ صحيح';
    }

    final basePrice =
        double.tryParse(widget.shipmentData['base_price'].toString()) ?? 0;

    if (price > basePrice) {
      return 'يجب أن يكون المبلغ أقل أو يساوي السعر الأساسي (${basePrice.toStringAsFixed(2)} ر.س)';
    }

    if (lowestBid != null && price >= lowestBid!) {
      return 'يجب أن يكون عرضك أقل من أفضل عرض حالي (${lowestBid!.toStringAsFixed(2)} ر.س)';
    }

    if (price < basePrice * 0.5) {
      return 'العرض يبدو منخفضاً جداً';
    }

    return '';
  }

  Future<void> _submitBid() async {
    if (widget.driverId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('خطأ: لم يتم العثور على بيانات السائق'),
          backgroundColor: AppColors.danger,
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
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    if (!agree) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء الموافقة على الشروط والأحكام'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() {
      isSubmitting = true;
      validationError = '';
    });

    try {
      final bidAmount = double.parse(_priceController.text);
      final estimatedDays = int.tryParse(_daysController.text) ?? 5;

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
                  Icon(Icons.check_circle_outline_rounded,
                      color: AppColors.success, size: 28),
                  SizedBox(width: 12),
                  Text('تم إرسال العرض بنجاح'),
                ],
              ),
              content: const Text(
                'تم قبول عرضك في نظام المناقصة العكسية. سيتم إخطارك عند قبول عرضك.',
                style: TextStyle(fontSize: 15, height: 1.6),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Return to previous screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
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
        setState(() {
          isSubmitting = false;
          validationError = e.toString();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: AppColors.danger,
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

  String _calculateDistance() {
    // Placeholder - would calculate actual distance from coordinates
    return '950 كم';
  }

  @override
  void dispose() {
    _priceController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final basePrice =
        double.tryParse(widget.shipmentData['base_price'].toString()) ?? 0;
    final cityFrom = _getCityDisplay(widget.shipmentData['pickup_address']);
    final cityTo = _getCityDisplay(widget.shipmentData['dropoff_address']);
    final distance = _calculateDistance();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.text,
          centerTitle: false,
          title: const Text(
            'ملخص الشحنة',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionCard(
              child: Column(
                children: [
                  Row(
                    children: const [
                      Icon(Icons.arrow_forward, color: AppColors.text),
                      SizedBox(width: 8),
                      Text(
                        'غرفة المناقصة',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xffF3F4F6),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                color: AppColors.subText),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Divider(color: AppColors.subText),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              distance,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.subText,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Divider(color: AppColors.subText),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.place_outlined,
                                color: AppColors.text),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              cityTo,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              cityFrom,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
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
                                text: widget.shipmentData['expected_delivery_date'] ??
                                    '15 يناير 2025',
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
                                text: widget.shipmentData['cargo_description'] ??
                                    'بضائع عامة',
                              ),
                            ),
                            Expanded(
                              child: _BidMetaItem(
                                icon: Icons.payments_outlined,
                                text:
                                    'أقل عرض حالي: ${lowestBid != null ? lowestBid!.toStringAsFixed(0) : basePrice.toStringAsFixed(0)} ر.س',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.shipmentData['cargo_description'] ??
                              'معلومات عن البضاعة',
                          style: const TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.w700,
                          ),
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
                  Icon(Icons.warning_amber_rounded, color: AppColors.danger),
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
                    alignment: Alignment.centerRight,
                    child: Text(
                      'أدخل قيمة عرضك النهائي',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.orange,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'ر.س ',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _priceController,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
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
                  Text(
                    'السعر الأساسي: ${basePrice.toStringAsFixed(0)} ر.س',
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.subText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (lowestBid != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'أقل عرض حالي: ${lowestBid!.toStringAsFixed(0)} ر.س',
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _priceSuggestionButton(
                          '${(basePrice * 0.95).toStringAsFixed(0)}',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _priceSuggestionButton(
                          '${(basePrice * 0.90).toStringAsFixed(0)}',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _priceSuggestionButton(
                          '${(basePrice * 0.85).toStringAsFixed(0)}',
                        ),
                      ),
                    ],
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
                          activeColor: AppColors.primary,
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
                                    Colors.white),
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
                        backgroundColor: AppColors.success,
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
      ),
    );
  }

  Widget _priceSuggestionButton(String value) {
    return OutlinedButton(
      onPressed: () => setState(() => _priceController.text = value),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: Text(
        '$value ر.س',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.03),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _BidMetaItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BidMetaItem({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.subText),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.text,
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


// تسجيل خروج يمسح الجلسة المحلية ويُسجّل خروج Firebase.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'app_theme.dart';
import 'app_widgets.dart';
import 'api_service.dart';
import 'contract/open_contract_pdf.dart';
import 'location_picker_screens.dart';
import 'ratings_screen.dart';
import 'shipment_bids_detail_screen.dart';
import 'trip_screens.dart';
import 'services/profile_image_flow.dart';
import 'services/profile_repository.dart';
import 'utils/sar_formatter.dart';
import 'widgets/profile_avatar.dart';
import 'widgets/sar_price.dart';
import 'truck_classification/truck_classification_models.dart';
import 'truck_classification/truck_classification_service.dart';
import 'truck_classification/widgets/truck_configuration_form.dart';
import 'widgets/shipment_path.dart';

/// Home للشاحن (الشركة/الجهة المالكة للشحنات)
class ShipperHomeScreen extends StatefulWidget {
  const ShipperHomeScreen({super.key});

  @override
  State<ShipperHomeScreen> createState() => _ShipperHomeScreenState();
}

class _ShipperHomeScreenState extends State<ShipperHomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const ShipperShipmentsScreen(), // شحناتي
      const ShipperNotificationsScreen(), // التنبيهات
      const ShipperMessagesScreen(), // الرسائل
      const ShipperProfileScreen(), // الحساب
    ];

    final titles = ['شحناتي', 'التنبيهات', 'الرسائل', 'حسابي'];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_currentIndex]),
        automaticallyImplyLeading: false,
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: DarbakColors.primaryGreen,
        unselectedItemColor: DarbakColors.textSecondary,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2_rounded),
            label: 'شحناتي',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_none_rounded),
            activeIcon: Icon(Icons.notifications_rounded),
            label: 'تنبيهات',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            activeIcon: Icon(Icons.chat_bubble_rounded),
            label: 'الرسائل',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.domain_outlined),
            activeIcon: Icon(Icons.domain_rounded),
            label: 'حسابي',
          ),
        ],
      ),
    );
  }
}

/// شاشة شحنات الشاحن (مع عرض الشحنات النشطة)
class ShipperShipmentsScreen extends StatefulWidget {
  const ShipperShipmentsScreen({super.key});

  @override
  State<ShipperShipmentsScreen> createState() => _ShipperShipmentsScreenState();
}

class _ShipperShipmentsScreenState extends State<ShipperShipmentsScreen> {
  static const int _maxActiveShipments = 5;
  static const Set<String> _activeStatuses = {
    'pending',
    'bidding',
    'assigned',
    'at_pickup',
    'en_route',
    'at_dropoff',
  };

  List<Map<String, dynamic>> _shipments = [];
  bool _loading = true;
  String? _error;
  String _verificationStatus = 'pending';

  bool get _shipperKybVerified =>
      _verificationStatus.toLowerCase() == 'verified';

  int get _activeShipmentsCount => _shipments
      .where((s) => _activeStatuses.contains((s['status'] ?? '').toString()))
      .length;

  Color get _activeProgressColor {
    if (_activeShipmentsCount >= _maxActiveShipments) return Colors.red;
    if (_activeShipmentsCount == _maxActiveShipments - 1) return Colors.orange;
    return DarbakColors.primaryGreen;
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'bidding':
        return 'في المزاد';
      case 'assigned':
        return 'مُسندة لسائق';
      case 'delivered':
        return 'تم التسليم';
      case 'pending':
        return 'قيد الانتظار';
      case 'at_pickup':
        return 'عند التحميل';
      case 'en_route':
        return 'في الطريق';
      case 'at_dropoff':
        return 'عند التسليم';
      default:
        return status;
    }
  }

  Color _statusChipColor(String status) {
    switch (status) {
      case 'bidding':
        return Colors.orange.shade100;
      case 'assigned':
        return Colors.blue.shade100;
      case 'delivered':
        return Colors.green.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  Color _statusTextColor(String status) {
    switch (status) {
      case 'bidding':
        return Colors.orange.shade900;
      case 'assigned':
        return Colors.blue.shade900;
      case 'delivered':
        return Colors.green.shade900;
      default:
        return Colors.grey.shade800;
    }
  }

  String _formatExpectedDate(dynamic rawDate) {
    if (rawDate == null) return 'غير محدد';
    try {
      final parsed = DateTime.parse(rawDate.toString());
      return DateFormat('dd-MM-yyyy').format(parsed);
    } catch (_) {
      return rawDate.toString();
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      final profile = await ProfileRepository.getMe();
      if (!mounted) return;
      setState(() {
        _verificationStatus =
            profile['verification_status']?.toString() ?? 'pending';
      });
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _verificationStatus =
            prefs.getString('verification_status') ?? 'pending';
      });
    }
    if (!mounted) return;
    await _loadShipments();
  }

  Future<void> _refreshShipmentsAndKyb() async {
    try {
      final profile = await ProfileRepository.getMe();
      if (mounted) {
        setState(() {
          _verificationStatus =
              profile['verification_status']?.toString() ?? 'pending';
        });
      }
    } catch (_) {}
    await _loadShipments();
  }

  String _kybBannerMessage() {
    switch (_verificationStatus.toLowerCase()) {
      case 'rejected':
        return 'لم تُقبل وثائق الشركة. راجع قسم «حالة التحقق» في حسابك أو تواصل مع الدعم.';
      case 'verified':
        return '';
      default:
        return 'حسابك قيد مراجعة الوثائق من الإدارة. بعد التوثيق (موثّق) يمكنك نشر الشحنات وقبول عروض السائقين.';
    }
  }

  Future<void> _loadShipments() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final shipperId = prefs.getInt('user_id');
      if (shipperId == null) {
        setState(() {
          _error = 'لم يتم العثور على بيانات المستخدم';
          _loading = false;
        });
        return;
      }

      final allShipments = await ApiService.getShipments();
      final myShipments = allShipments
          .where((s) => s['shipper_id'] == shipperId)
          .toList();
      setState(() {
        _shipments = myShipments.map((s) => s as Map<String, dynamic>).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openRateDriver(Map<String, dynamic> shipment) async {
    final shipmentId = (shipment['id'] as num?)?.toInt();
    final driverId = (shipment['driver_id'] as num?)?.toInt();
    if (shipmentId == null || driverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد بيانات سائق لهذه الشحنة')),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RatingsScreen(
          shipmentId: shipmentId,
          otherUserId: driverId,
          otherUserRole: 'driver',
          otherUserName: shipment['driver_name']?.toString() ?? 'السائق',
        ),
      ),
    );

    if (mounted) {
      _loadShipments();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text('خطأ: $_error'));
    }

    return SafeArea(
      child: Column(
        children: [
          if (!_shipperKybVerified)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
              child: Material(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        color: Colors.amber.shade900,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _kybBannerMessage(),
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: Colors.brown.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // شريط أعلى + زر شحنة جديدة
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: DarbakColors.cardBackground,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الشحنات النشطة: ($_activeShipmentsCount/$_maxActiveShipments)',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: DarbakColors.dark,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 9,
                          value: (_activeShipmentsCount / _maxActiveShipments)
                              .clamp(0.0, 1.0),
                          color: _activeProgressColor,
                          backgroundColor: Colors.grey.shade300,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    Tooltip(
                      message: !_shipperKybVerified
                          ? 'يتاح نشر الشحنات بعد موافقة الإدارة على وثائق الشركة'
                          : (_activeShipmentsCount >= _maxActiveShipments
                                ? 'بلغت الحد الأقصى للشحنات النشطة'
                                : ''),
                      child: ElevatedButton.icon(
                        onPressed: !_shipperKybVerified ||
                                _activeShipmentsCount >= _maxActiveShipments
                            ? null
                            : () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const CreateShipmentScreen(),
                                  ),
                                );
                                if (mounted) _loadShipments();
                              },
                        icon: const Icon(Icons.add_rounded),
                        label: const Text(
                          'شحنة جديدة',
                          style: TextStyle(fontSize: 13),
                        ),
                        iconAlignment: IconAlignment.end,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshShipmentsAndKyb,
              child: _shipments.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.35,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.inventory_2_outlined,
                                size: 64,
                                color: DarbakColors.textSecondary,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'لا توجد شحنات حالياً',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: DarbakColors.dark,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 32),
                                child: Text(
                                  _shipperKybVerified
                                      ? 'اضغط على "شحنة جديدة" لبدء إنشاء شحنتك الأولى'
                                      : 'بعد اعتماد الإدارة لحسابك كـ«موثّق» يمكنك نشر الشحنات من الزر أعلاه.',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: DarbakColors.textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: _shipments.length,
                      itemBuilder: (context, index) {
                        final shipment = _shipments[index];
                        final status = (shipment['status'] ?? '').toString();
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 3.5,
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _statusChipColor(status),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      _statusLabel(status),
                                      style: TextStyle(
                                        color: _statusTextColor(status),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ShipmentPath(
                                  pickupCity: shipment['pickup_address']
                                      ?.toString(),
                                  dropoffCity: shipment['dropoff_address']
                                      ?.toString(),
                                ),
                                const SizedBox(height: 14),
                                Text('الوزن: ${shipment['weight_kg']} طن'),
                                Row(
                                  children: [
                                    const Text('السعر المتفق عليه: '),
                                    SarPrice(
                                      amount:
                                          shipment['final_price'] ??
                                          shipment['accepted_bid_amount'],
                                      style: const TextStyle(fontSize: 14),
                                      iconSize: 14,
                                    ),
                                  ],
                                ),
                                Text(
                                  'الموعد النهائي: ${_formatExpectedDate(shipment['expected_delivery_date'])}',
                                ),
                                const SizedBox(height: 16),
                                if (shipment['status'] == 'bidding')
                                  SizedBox(
                                    width: double.infinity,
                                    child: Tooltip(
                                      message: !_shipperKybVerified
                                          ? 'يتاح قبول العروض بعد توثيق الحساب'
                                          : '',
                                      child: ElevatedButton.icon(
                                        onPressed: !_shipperKybVerified
                                            ? null
                                            : () {
                                                Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        ShipmentBidsDetailScreen(
                                                      shipmentId:
                                                          (shipment['id'] as num)
                                                              .toInt(),
                                                      pickupAddress:
                                                          shipment['pickup_address']
                                                              ?.toString(),
                                                      dropoffAddress:
                                                          shipment['dropoff_address']
                                                              ?.toString(),
                                                      suggestedPrice:
                                                          SarFormatter.parse(
                                                        shipment[
                                                                'suggested_price'] ??
                                                            shipment[
                                                                'base_price'],
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                        icon: const Icon(Icons.gavel_rounded),
                                        label: const Text('عرض العروض'),
                                        iconAlignment: IconAlignment.end,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              DarbakColors.primaryGreen,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if ([
                                  'assigned',
                                  'at_pickup',
                                  'en_route',
                                  'at_dropoff',
                                ].contains(status))
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => ChatScreen(
                                                shipmentId: shipment['id']
                                                    .toString(),
                                                otherUser: 'محادثة الرحلة',
                                              ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.chat_bubble_rounded,
                                        ),
                                        label: const Text('محادثة السائق'),
                                      ),
                                    ),
                                  ),
                                if (status == 'delivered')
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: Tooltip(
                                        message: !_shipperKybVerified
                                            ? 'يتاح التقييم بعد توثيق الحساب'
                                            : '',
                                        child: ElevatedButton.icon(
                                          onPressed: !_shipperKybVerified
                                              ? null
                                              : () =>
                                                  _openRateDriver(shipment),
                                          icon: const Icon(
                                              Icons.star_rate_rounded),
                                          label: const Text('تقييم السائق'),
                                          iconAlignment: IconAlignment.end,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                DarbakColors.primaryGreen,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// يقتصر حقل الوزن على أرقام ونقطة عشرية واحدة؛ يمنع المسافات والسالب والحروف والفواصل.
class _ShipmentWeightTonsInputFormatter extends TextInputFormatter {
  const _ShipmentWeightTonsInputFormatter();

  static String _toLatinDigits(String s) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    var o = s;
    for (var i = 0; i < 10; i++) {
      o = o.replaceAll(arabic[i], '$i').replaceAll(persian[i], '$i');
    }
    return o;
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }
    var t = _toLatinDigits(newValue.text);
    t = t.replaceAll(RegExp(r'[\s\-,،٬eE+]'), '');
    t = t.replaceAll(RegExp(r'[^0-9.]'), '');
    final dot = t.indexOf('.');
    if (dot != -1) {
      t = t.substring(0, dot + 1) + t.substring(dot + 1).replaceAll('.', '');
    }
    if (t == newValue.text) {
      return newValue;
    }
    var offset = newValue.selection.baseOffset;
    if (offset > t.length) {
      offset = t.length;
    } else if (offset < 0) {
      offset = 0;
    }
    return TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

/// شاشة إنشاء شحنة جديدة (مع تحديد موقع التحميل + التسليم)
class CreateShipmentScreen extends StatefulWidget {
  const CreateShipmentScreen({super.key});

  @override
  State<CreateShipmentScreen> createState() => _CreateShipmentScreenState();
}

class _CreateShipmentScreenState extends State<CreateShipmentScreen> {
  static const double _maxLegalShipmentWeightTons = 45;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _cargoTypeController = TextEditingController();
  final TextEditingController _basePriceController = TextEditingController();
  final TextEditingController _specialInstructionsController =
      TextEditingController();

  DateTime? _selectedDate;
  String _selectedPeriod = 'morning';
  int _auctionDurationHours = 24;
  bool _isSubmitting = false;
  bool _requireSpecificTruck = false;
  TruckGroup? _requiredTruckGroup;
  String? _requiredCategoryId;
  int? _requiredAxleCount;
  String? _requiredBodyTypeId;
  String? _requiredCapacityId;
  TruckConfiguration? _requiredTruckConfiguration;
  final _truckRequirementFormKey = GlobalKey<TruckConfigurationFormState>();

  // بيانات موقع التحميل
  String? pickupMapsUrl;
  double? pickupLat;
  double? pickupLng;

  // بيانات موقع التسليم
  String? dropoffMapsUrl;
  double? dropoffLat;
  double? dropoffLng;

  double? get _enteredWeightTons =>
      SarFormatter.parse(_weightController.text.trim());

  void _syncTruckRequirementFromWeight() {
    final tons = _enteredWeightTons;
    if (tons == null || tons <= 0) return;
    final service = const TruckClassificationService();
    final categoryId = service.suggestCategoryIdForWeightTons(tons);
    final category = service.categoryById(categoryId);
    if (category == null) return;
    setState(() {
      _requiredTruckGroup = category.group;
      _requiredCategoryId = category.id;
      _requiredAxleCount = category.axleCounts.first;
      _requiredBodyTypeId = category.defaultBodyTypeId;
      _requiredCapacityId = category.capacities.first.id;
      _requiredTruckConfiguration = service.resolveConfiguration(
        group: _requiredTruckGroup,
        categoryId: _requiredCategoryId,
        axleCount: _requiredAxleCount,
        bodyTypeId: _requiredBodyTypeId,
        capacityId: _requiredCapacityId,
      );
    });
  }

  bool get _isWeightOverLegalLimit {
    final weight = _enteredWeightTons;
    return weight != null && weight > _maxLegalShipmentWeightTons;
  }

  /// وزن غير صالح لزر الإرسال (حقل غير فارغ والقيمة ≤ 0 أو غير رقمية أو > 45 طن).
  bool get _isWeightBlockingSubmit {
    final raw = _weightController.text.trim();
    if (raw.isEmpty) return false;
    final weight = _enteredWeightTons;
    if (weight == null) return true;
    return weight <= 0 || weight > _maxLegalShipmentWeightTons;
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _weightController.dispose();
    _cargoTypeController.dispose();
    _basePriceController.dispose();
    _specialInstructionsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  Future<void> _pickPickupLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PickupLocationPickerScreen()),
    );

    if (result != null && mounted) {
      setState(() {
        pickupLat = result['lat'] as double;
        pickupLng = result['lng'] as double;
        pickupMapsUrl = result['mapsUrl'] as String;
      });
    }
  }

  Future<void> _pickDropoffLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DropoffLocationPickerScreen()),
    );

    if (result != null && mounted) {
      setState(() {
        dropoffLat = result['lat'] as double;
        dropoffLng = result['lng'] as double;
        dropoffMapsUrl = result['mapsUrl'] as String;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitDisabled = _isSubmitting || _isWeightBlockingSubmit;

    return Scaffold(
      appBar: AppBar(title: const Text('شحنة جديدة')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'بيانات الشحنة',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: DarbakColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // مدينة التحميل
                  _buildTextField(
                    label: 'مدينة التحميل',
                    controller: _fromController,
                    validatorMsg: 'الرجاء إدخال مدينة التحميل',
                  ),
                  const SizedBox(height: 8),

                  // زر تحديد موقع التحميل
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton.icon(
                      onPressed: _pickPickupLocation,
                      icon: const Icon(Icons.location_on_outlined, size: 18),
                      label: const Text(
                        'تحديد موقع التحميل على الخريطة',
                        style: TextStyle(fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DarbakColors.primaryGreen,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),

                  if (pickupMapsUrl != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: const [
                        Icon(Icons.check_circle, color: Colors.green, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'تم تحديد موقع التحميل',
                          style: TextStyle(color: Colors.green, fontSize: 12),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 12),

                  // مدينة التفريغ
                  _buildTextField(
                    label: 'مدينة التفريغ',
                    controller: _toController,
                    validatorMsg: 'الرجاء إدخال مدينة التفريغ',
                  ),
                  const SizedBox(height: 8),

                  // زر تحديد موقع التسليم
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton.icon(
                      onPressed: _pickDropoffLocation,
                      icon: const Icon(Icons.location_on_outlined, size: 18),
                      label: const Text(
                        'تحديد موقع التسليم على الخريطة',
                        style: TextStyle(fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),

                  if (dropoffMapsUrl != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: const [
                        Icon(
                          Icons.check_circle,
                          color: Colors.orange,
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'تم تحديد موقع التسليم',
                          style: TextStyle(color: Colors.orange, fontSize: 12),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 12),

                  // السعر المقترح
                  _buildTextField(
                    label: 'السعر المقترح للشحنة',
                    controller: _basePriceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validatorMsg: 'الرجاء إدخال السعر المقترح',
                    helperText:
                        'سيظهر للسائقين كسعر إرشادي، ويمكنهم تقديم عروض أعلى أو أقل.',
                    customValidator: (value) {
                      if (!SarFormatter.isValidAmount(value)) {
                        return 'أدخل سعراً صحيحاً أكبر من صفر';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // الوزن
                  _buildTextField(
                    label: 'وزن الشحنة (بالطن)',
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: const [_ShipmentWeightTonsInputFormatter()],
                    onChanged: (_) {
                      setState(() {});
                      if (_requireSpecificTruck) _syncTruckRequirementFromWeight();
                    },
                    validatorMsg: 'الرجاء إدخال الوزن',
                    customValidator: (value) {
                      final weight = SarFormatter.parse(value);
                      if (weight == null || weight <= 0) {
                        return 'أدخل وزناً أكبر من صفر ولا يتجاوز 45 طن (أرقام فقط، بدون مسافات)';
                      }
                      if (weight > _maxLegalShipmentWeightTons) {
                        return 'الحد الأقصى المسموح به قانونياً هو 45 طن';
                      }
                      return null;
                    },
                  ),
                  if (_isWeightOverLegalLimit) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'تنبيه: الحد الأقصى المسموح به قانونياً هو 45 طن.',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                  if (_isWeightBlockingSubmit &&
                      !_isWeightOverLegalLimit &&
                      _weightController.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'الوزن يجب أن يكون أكبر من صفر ولا يتجاوز 45 طن، وأرقاماً صحيحة فقط.',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 12),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'تحديد نوع الشاحنة المطلوبة',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'يُقترح تلقائياً من الوزن — يمكنك تعديله',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _requireSpecificTruck,
                    activeThumbColor: DarbakColors.primaryGreen,
                    onChanged: (value) {
                      setState(() {
                        _requireSpecificTruck = value;
                        if (value) _syncTruckRequirementFromWeight();
                      });
                    },
                  ),
                  if (_requireSpecificTruck) ...[
                    const SizedBox(height: 8),
                    KeyedSubtree(
                      key: ValueKey(
                        'ship-req-$_requiredCategoryId-$_requiredAxleCount',
                      ),
                      child: TruckConfigurationForm(
                        key: _truckRequirementFormKey,
                        initialGroup: _requiredTruckGroup,
                        initialCategoryId: _requiredCategoryId,
                        initialAxleCount: _requiredAxleCount,
                        initialBodyTypeId: _requiredBodyTypeId,
                        initialCapacityId: _requiredCapacityId,
                        onChanged: (config) {
                          setState(() => _requiredTruckConfiguration = config);
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // نوع الحمولة
                  _buildTextField(
                    label: 'نوع الحمولة / ملاحظات',
                    controller: _cargoTypeController,
                    maxLines: 2,
                    validatorMsg: 'الرجاء كتابة وصف مختصر للحمولة',
                  ),
                  const SizedBox(height: 12),

                  // التعليمات الخاصة (اختياري)
                  _buildTextField(
                    label: 'التعليمات الخاصة (اختياري)',
                    controller: _specialInstructionsController,
                    maxLines: 3,
                    isRequired: false,
                    validatorMsg: '',
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'موعد التسليم الأقصى (EDT)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: DarbakColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'يجب تسليم الشحنة قبل أو في هذا الموعد، وبعده يتم احتساب خصم تأخير آلياً.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),

                  // Date picker
                  InkWell(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: Color(0xff168A57),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedDate != null
                                  ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                                  : 'اختر التاريخ',
                              style: TextStyle(
                                color: _selectedDate != null
                                    ? Colors.black
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Period selection
                  DropdownButtonFormField<String>(
                    value: _selectedPeriod,
                    decoration: const InputDecoration(
                      labelText: 'فترة التسليم',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'morning',
                        child: Text('صباحي (06:00 - 12:00)'),
                      ),
                      DropdownMenuItem(
                        value: 'evening',
                        child: Text('مسائي (12:00 - 18:00)'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedPeriod = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _auctionDurationHours,
                    decoration: const InputDecoration(
                      labelText: 'مدة المزاد (بالساعات)',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 2, child: Text('2 ساعة')),
                      DropdownMenuItem(value: 6, child: Text('6 ساعات')),
                      DropdownMenuItem(value: 12, child: Text('12 ساعة')),
                      DropdownMenuItem(value: 24, child: Text('24 ساعة')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _auctionDurationHours = value;
                      });
                    },
                  ),
                  // if (_selectedDateTime == null) ...[
                  //   Padding(
                  //     padding: const EdgeInsets.only(top: 4),
                  //     child: const Text(
                  //       'تحديد EDT إلزامي وفقاً لمتطلبات النظام',
                  //       style: TextStyle(color: Colors.red, fontSize: 12),
                  //     ),
                  //   ),
                  // ],
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: isSubmitDisabled
                        ? null
                        : () async {
                            if (!(_formKey.currentState?.validate() ?? false)) {
                              return;
                            }
                            if (_selectedDate == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'يرجى تحديد موعد التسليم الأقصى',
                                  ),
                                ),
                              );
                              return;
                            }

                            setState(() => _isSubmitting = true);

                            try {
                              final suggestedPrice = SarFormatter.parse(
                                _basePriceController.text.trim(),
                              )!;
                              final weightKg = SarFormatter.parse(
                                _weightController.text.trim(),
                              )!;

                              // Format date as YYYY-MM-DD
                              final formattedDate =
                                  '${_selectedDate!.year.toString().padLeft(4, '0')}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';

                              if (pickupLat == null ||
                                  pickupLng == null ||
                                  dropoffLat == null ||
                                  dropoffLng == null) {
                                setState(() => _isSubmitting = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'يرجى تحديد موقعي التحميل والتسليم على الخريطة أولاً',
                                    ),
                                  ),
                                );
                                return;
                              }

                              if (_requireSpecificTruck) {
                                final truckOk =
                                    _truckRequirementFormKey.currentState
                                        ?.validateAll() ??
                                    false;
                                if (!truckOk || _requiredTruckConfiguration == null) {
                                  setState(() => _isSubmitting = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'يرجى إكمال متطلبات الشاحنة المطلوبة',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                              }

                              final created = await ApiService.createShipment({
                                'weightKg': weightKg,
                                if (_requireSpecificTruck &&
                                    _requiredTruckConfiguration != null)
                                  ..._requiredTruckConfiguration!.toApiPayload(),
                                'cargoDescription': _cargoTypeController.text
                                    .trim(),
                                'pickupAddress': _fromController.text.trim(),
                                'dropoffAddress': _toController.text.trim(),
                                'pickupLat': pickupLat,
                                'pickupLng': pickupLng,
                                'dropoffLat': dropoffLat,
                                'dropoffLng': dropoffLng,
                                'suggestedPrice': suggestedPrice,
                                'basePrice': suggestedPrice,
                                'expectedDeliveryDate': formattedDate,
                                'period': _selectedPeriod,
                                'auctionDurationHours': _auctionDurationHours,
                                'specialInstructions':
                                    _specialInstructionsController.text.trim(),
                              });

                              debugPrint(
                                'Shipment created successfully: $created',
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تم نشر الشحنة بنجاح'),
                                ),
                              );
                              Navigator.of(context).pop();
                            } catch (e) {
                              setState(() => _isSubmitting = false);
                              debugPrint('Shipment creation error: $e');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          },
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('حفظ ونشر الشحنة في السوق'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String validatorMsg,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool isRequired = true,
    String? helperText,
    ValueChanged<String>? onChanged,
    String? Function(String?)? customValidator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(labelText: label, helperText: helperText),
      onChanged: onChanged,
      validator: (value) {
        if (isRequired && (value == null || value.trim().isEmpty)) {
          return validatorMsg;
        }
        final customError = customValidator?.call(value);
        if (customError != null) return customError;
        return null;
      },
      textAlign: TextAlign.start,
    );
  }
}

/// شاشة صورية لقائمة العروض (احتياطية)
class ShipperBidsPlaceholderScreen extends StatelessWidget {
  const ShipperBidsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('عروض السائقين')),
      body: const Center(
        child: Text(
          'هنا سيتم عرض عروض السائقين (السعر، التقييم، الالتزام).',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// شاشة صورية للعقد الإلكتروني (تشمل EDT وشروط الخصم)
class ShipperContractScreen extends StatelessWidget {
  const ShipperContractScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('العقد الإلكتروني')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Text(
            'هنا نموذج العقد الإلكتروني بين الشاحن والسائق:\n\n'
            '- بيانات الشحنة والمدن والوزن.\n'
            '- قيمة العرض النهائي المقبول.\n'
            '- موعد التسليم الأقصى (EDT).\n'
            '- بند خصم التأخير: خصم 5% يومياً من مستحقات السائق عند التأخر عن EDT.\n\n'
            'سيتم لاحقاً ربط هذه الشاشة مع النظام الخلفي لتوليد عقد حقيقي يمكن توقيعه رقمياً.',
            style: TextStyle(fontSize: 14),
          ),
        ),
      ),
    );
  }
}

String formatNotificationTime(Object? value, {DateTime? now}) {
  final parsedDate = _parseNotificationDate(value)?.toLocal();
  if (parsedDate == null) return '';

  final currentTime = (now ?? DateTime.now()).toLocal();
  final difference = currentTime.difference(parsedDate);
  if (difference.isNegative || difference.inSeconds < 60) {
    return 'الآن';
  }

  if (_isSameDate(parsedDate, currentTime)) {
    if (difference.inMinutes < 60) {
      return 'منذ ${_formatArabicTimeUnit(difference.inMinutes, singular: 'دقيقة', dual: 'دقيقتين', plural: 'دقائق', countedSingular: 'دقيقة')}';
    }

    return 'منذ ${_formatArabicTimeUnit(difference.inHours, singular: 'ساعة', dual: 'ساعتين', plural: 'ساعات', countedSingular: 'ساعة')}';
  }

  final yesterday = DateTime(
    currentTime.year,
    currentTime.month,
    currentTime.day,
  ).subtract(const Duration(days: 1));
  if (_isSameDate(parsedDate, yesterday)) {
    return 'أمس الساعة ${formatArabicClockTime(parsedDate)}';
  }

  return DateFormat('dd/MM/yyyy', 'ar').format(parsedDate);
}

String formatArabicClockTime(DateTime value) {
  return DateFormat('h:mm a', 'ar').format(value.toLocal());
}

DateTime? _parseNotificationDate(Object? value) {
  if (value is DateTime) return value;
  final rawValue = value?.toString().trim();
  if (rawValue == null || rawValue.isEmpty) return null;
  return DateTime.tryParse(rawValue);
}

bool _isSameDate(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

String _formatArabicTimeUnit(
  int value, {
  required String singular,
  required String dual,
  required String plural,
  required String countedSingular,
}) {
  if (value <= 1) return singular;
  if (value == 2) return dual;

  final formattedValue = NumberFormat.decimalPattern('ar').format(value);
  if (value >= 3 && value <= 10) {
    return '$formattedValue $plural';
  }
  return '$formattedValue $countedSingular';
}

/// شاشة التنبيهات
class ShipperNotificationsScreen extends StatefulWidget {
  const ShipperNotificationsScreen({super.key});

  @override
  State<ShipperNotificationsScreen> createState() =>
      _ShipperNotificationsScreenState();
}

class _ShipperNotificationsScreenState
    extends State<ShipperNotificationsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getInt('user_id');
      if (uid == null) {
        setState(() {
          _error = 'لم يتم العثور على المستخدم';
          _loading = false;
        });
        return;
      }
      final res = await ApiService.getNotifications(uid);
      final list = (res['notifications'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد تنبيهات',
          style: TextStyle(color: DarbakColors.textSecondary),
        ),
      );
    }
    final now = DateTime.now();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final n = _items[i];
          return _NotificationTile(notification: n, now: now, onReload: _load);
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.now,
    required this.onReload,
  });

  final Map<String, dynamic> notification;
  final DateTime now;
  final Future<void> Function() onReload;

  @override
  Widget build(BuildContext context) {
    final read =
        notification['is_read'] == 1 || notification['is_read'] == true;
    final title = (notification['title'] ?? 'تنبيه').toString();
    final message = (notification['message'] ?? '').toString();
    final routeDescription = _readNotificationText(
      notification['route_description'],
    );
    final displayMessage = _replaceShipmentIdWithRoute(
      _normalizeContractNotificationMessage(message),
      routeDescription,
    );
    final shipmentId = _readNotificationShipmentId(notification, message);
    final isContract = title == 'عقد إلكتروني' && shipmentId != null;
    final timeLabel = formatNotificationTime(
      notification['created_at'],
      now: now,
    );

    return ListTile(
      leading: Icon(
        read
            ? Icons.notifications_none_rounded
            : Icons.notifications_active_rounded,
        color: read ? DarbakColors.textSecondary : DarbakColors.primaryGreen,
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: read ? FontWeight.w500 : FontWeight.w700),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NotificationMessage(message: displayMessage),
          if (isContract)
            TextButton(
              onPressed: () async {
                await openShipmentContractPdfInApp(context, shipmentId);
                if (context.mounted) await onReload();
              },
              child: const Text('عرض العقد'),
            ),
        ],
      ),
      isThreeLine: isContract,
      trailing: Text(
        timeLabel,
        style: const TextStyle(fontSize: 11, color: DarbakColors.textSecondary),
      ),
      onTap: () async {
        final id = (notification['id'] as num?)?.toInt();
        if (id != null) {
          try {
            await ApiService.markNotificationAsRead(id);
          } catch (_) {}
        }
        if (isContract) {
          await openShipmentContractPdfInApp(context, shipmentId);
        }
        if (context.mounted) await onReload();
      },
    );
  }
}

String? _readNotificationText(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int? _readNotificationShipmentId(
  Map<String, dynamic> notification,
  String message,
) {
  for (final key in const [
    'related_shipment_id',
    'shipment_id',
    'relatedShipmentId',
    'shipmentId',
  ]) {
    final parsed = _readNotificationInt(notification[key]);
    if (parsed != null) return parsed;
  }

  final match = RegExp(
    r'(?:للشحنة|الشحنة)\s*(?:رقم)?\s*#?(\d+)',
  ).firstMatch(message);
  return match == null ? null : int.tryParse(match.group(1)!);
}

int? _readNotificationInt(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

String _replaceShipmentIdWithRoute(String message, String? routeDescription) {
  if (routeDescription == null || routeDescription.isEmpty) return message;

  final patterns = [
    RegExp(r'للشحنة\s*#\d+'),
    RegExp(r'للشحنة\s+رقم\s*#?\d+'),
    RegExp(r'الشحنة\s*#\d+'),
    RegExp(r'الشحنة\s+رقم\s*#?\d+'),
  ];

  for (final pattern in patterns) {
    if (pattern.hasMatch(message)) {
      return message.replaceFirstMapped(pattern, (match) {
        final matchedText = match.group(0)!;
        if (matchedText.startsWith('للشحنة')) {
          return 'للشحنة $routeDescription';
        }
        return 'الشحنة $routeDescription';
      });
    }
  }

  return message;
}

String _normalizeContractNotificationMessage(String message) {
  return message.replaceFirst(
    RegExp(r'تم إنشاء عقد\s+رقم\s*#?\d+'),
    'تم إنشاء عقد',
  );
}

class _NotificationMessage extends StatelessWidget {
  const _NotificationMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style;
    final parts = message.split(SarFormatter.symbol);

    if (parts.length == 1) {
      return Text(message);
    }

    return Text.rich(
      TextSpan(
        style: style,
        children: [
          for (var i = 0; i < parts.length; i++) ...[
            TextSpan(text: parts[i]),
            if (i < parts.length - 1)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: SarIcon(
                    size: (style.fontSize ?? 14) + 1,
                    color: style.color,
                  ),
                ),
              ),
          ],
        ],
      ),
      textDirection: TextDirection.rtl,
    );
  }
}

/// شاشة الرسائل
class ShipperMessagesScreen extends StatefulWidget {
  const ShipperMessagesScreen({super.key});

  @override
  State<ShipperMessagesScreen> createState() => _ShipperMessagesScreenState();
}

class _ShipperMessagesScreenState extends State<ShipperMessagesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await ApiService.getMyChatConversations();
      final rows = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
      await ProfileRepository.preloadProfileImagesFromRows(
        rows,
        urlField: 'other_party_profile_image_url',
        keyField: 'other_party_profile_image_key',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }
    if (_rows.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد محادثات بعد',
          style: TextStyle(color: DarbakColors.textSecondary),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _rows.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final r = _rows[i];
          final sid = _intFromRowValue(r['shipment_id']);
          final otherUserId = _intFromRowValue(r['other_party_id']);
          final name = (r['other_party_name'] ?? 'محادثة').toString();
          final imageUrl = r['other_party_profile_image_url']?.toString();
          final imageKey = r['other_party_profile_image_key']?.toString();
          final role = r['other_party_role']?.toString() ?? 'driver';
          final last = (r['last_preview'] ?? r['last_message'] ?? '')
              .toString();
          final unreadCount = _intFromRowValue(r['unread_count']) ?? 0;
          return _ConversationTile(
            avatar: ProfileAvatar(
              imageUrl: imageUrl,
              imageKey: imageKey,
              role: role,
              radius: 22,
            ),
            title: name,
            subtitle: last,
            trailing: unreadCount > 0
                ? _UnreadBadge(count: unreadCount)
                : const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            onTap: () async {
              if (sid == null) return;
              await ProfileRepository.preloadProfileImage(
                imageUrl: imageUrl,
                imageKey: imageKey,
              );
              if (!context.mounted) return;
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    shipmentId: sid.toString(),
                    otherUser: name,
                    otherUserId: otherUserId,
                    otherUserProfileImageUrl: imageUrl,
                    otherUserProfileImageKey: imageKey,
                    otherUserRole: role,
                  ),
                ),
              );
              if (mounted) unawaited(_load());
            },
          );
        },
      ),
    );
  }
}

int? _intFromRowValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.avatar,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  final Widget avatar;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            avatar,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: DarbakColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(width: 40, child: Center(child: trailing)),
          ],
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// شاشة الحساب (الشاحن/الشركة)
class ShipperProfileScreen extends StatefulWidget {
  const ShipperProfileScreen({super.key});

  @override
  State<ShipperProfileScreen> createState() => _ShipperProfileScreenState();
}

class _ShipperProfileScreenState extends State<ShipperProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _isEditing = false;
  bool _isUploadingProfileImage = false;
  double? _profileImageUploadProgress;
  Map<String, dynamic>? _user;

  late final TextEditingController _fullNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لم يتم العثور على بيانات المستخدم')),
        );
      }
      setState(() => _loading = false);
      return;
    }

    try {
      final profile = await ProfileRepository.getMe();
      if (!mounted) return;
      setState(() {
        _user = profile;
        _fullNameController.text = profile['full_name']?.toString() ?? '';
        _emailController.text = profile['email']?.toString() ?? '';
        _phoneController.text = profile['phone']?.toString() ?? '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل في تحميل الملف الشخصي: $e')));
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null) return;

    setState(() => _loading = true);
    try {
      final updated = await ProfileRepository.updateProfile({
        'fullName': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'licenseNo': _user?['license_no'],
        'commercialNo': _user?['commercial_no'],
      });
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تحديث البيانات بنجاح')));
      setState(() {
        _user = updated;
        _isEditing = false;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في تحديث التفاصيل: $e')));
      setState(() => _loading = false);
    }
  }

  Future<void> _showProfileImageActions() async {
    final action = await ProfileImageFlow.showActionSheet(
      context,
      hasImage: ProfileImageFlow.hasImage(_user),
    );
    if (action == null) return;

    if (action == ProfileImageAction.remove) {
      await _applyProfileImageChange(
        () => ProfileImageFlow.remove(),
        'تم حذف صورة الشركة',
      );
    } else {
      await _applyProfileImageChange(
        () => ProfileImageFlow.uploadFromAction(
          action,
          onProgress: (value) {
            if (!mounted) return;
            setState(() => _profileImageUploadProgress = value);
          },
        ),
        'تم تحديث صورة الشركة',
      );
    }
  }

  Future<void> _applyProfileImageChange(
    Future<ProfileImageChange?> Function() action,
    String successMessage,
  ) async {
    setState(() {
      _isUploadingProfileImage = true;
      _profileImageUploadProgress = 0;
    });
    try {
      final change = await action();
      if (change == null) return;
      if (!mounted) return;
      setState(() => _user = ProfileImageFlow.applyToProfile(_user, change));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر تحديث الصورة: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingProfileImage = false;
          _profileImageUploadProgress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_user == null) {
      return const Center(child: Text('لا يوجد بيانات مستخدم'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: _isEditing ? 'حفظ التعديلات' : 'تعديل الحساب',
                  icon: Icon(_isEditing ? Icons.save_rounded : Icons.edit),
                  onPressed: _isEditing
                      ? _updateProfile
                      : () => setState(() => _isEditing = true),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: ValueListenableBuilder<ProfileImageState>(
                valueListenable: ProfileRepository.profileImageNotifier,
                builder: (context, state, _) {
                  final imageUrl =
                      _user?['profileImageUrl']?.toString() ??
                      _user?['profile_image_url']?.toString() ??
                      state.imageUrl;
                  final imageKey =
                      _user?['profileImageKey']?.toString() ?? state.imageKey;
                  return ProfileAvatar(
                    imageUrl: imageUrl,
                    imageKey: imageKey,
                    role: 'shipper',
                    radius: 52,
                    showEditButton: true,
                    onEdit: _showProfileImageActions,
                    isUploading: _isUploadingProfileImage,
                    uploadProgress: _profileImageUploadProgress,
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            _buildProfileField(
              label: 'الاسم الكامل',
              controller: _fullNameController,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.start,
            ),
            const SizedBox(height: 12),
            _buildProfileField(
              label: 'البريد الإلكتروني',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.end,
            ),
            const SizedBox(height: 12),
            _buildProfileField(
              label: 'رقم الجوال',
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.end,
            ),
            const SizedBox(height: 20),
            if (_isEditing) ...[
              DarbakPrimaryButton(
                label: 'حفظ التعديلات',
                icon: Icons.save_rounded,
                onPressed: _updateProfile,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  _fullNameController.text =
                      _user?['full_name']?.toString() ?? '';
                  _emailController.text = _user?['email']?.toString() ?? '';
                  _phoneController.text = _user?['phone']?.toString() ?? '';
                  setState(() => _isEditing = false);
                },
                child: const Text('إلغاء التعديل'),
              ),
            ] else ...[
              _buildInfoCard('الشركة', _user?['full_name'] ?? ''),
              _buildInfoCard(
                'رقم السجل التجاري',
                _user?['commercial_no'] ?? 'غير متوفر',
              ),
              _buildInfoCard(
                'حالة التحقق',
                switch (
                    (_user?['verification_status'] ?? 'pending').toString()) {
                  'verified' => 'موثّق',
                  'rejected' => 'مرفوض',
                  _ => 'قيد المراجعة',
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'إجمالي الشحنات',
                      (_user?['total_shipments'] ?? 0).toString(),
                      Icons.inventory_2_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'تم تسليمها',
                      (_user?['delivered_shipments'] ?? 0).toString(),
                      Icons.check_circle_outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'نشطة حالياً',
                      (_user?['active_shipments'] ?? 0).toString(),
                      Icons.local_shipping_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'التقييم العام',
                      _user?['average_rating']?.toString() ??
                          _user?['rating']?.toString() ??
                          '0.0',
                      Icons.star_outline_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              DarbakLogoutBarButton(onPressed: _logout),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProfileField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    TextDirection textDirection = TextDirection.rtl,
    TextAlign textAlign = TextAlign.start,
  }) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: TextFormField(
        controller: controller,
        readOnly: !_isEditing,
        enableInteractiveSelection: _isEditing,
        keyboardType: keyboardType,
        textAlign: textAlign,
        textDirection: textDirection,
        style: Theme.of(context).textTheme.bodyLarge,
        decoration: InputDecoration(labelText: label),
        validator: (value) =>
            (value == null || value.trim().isEmpty) ? 'مطلوب' : null,
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DarbakColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: DarbakColors.primaryGreen, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: DarbakColors.dark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: DarbakColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text(
                'تأكيد تسجيل الخروج',
                textAlign: TextAlign.center,
              ),
              content: const Text(
                'هل تريد فعلاً تسجيل الخروج؟',
                textAlign: TextAlign.center,
              ),
              actionsAlignment: MainAxisAlignment.center,
              actionsOverflowAlignment: OverflowBarAlignment.center,
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('إلغاء'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('تسجيل الخروج'),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!confirmed) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await FirebaseAuth.instance.signOut();

    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  Widget _buildInfoCard(String title, String value) {
    final isNumericValue = RegExp(r'^[\d+\-\s]+$').hasMatch(value);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsetsDirectional.fromSTEB(18, 14, 18, 14),
        decoration: BoxDecoration(
          color: DarbakColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DarbakColors.borderSoft),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              textAlign: TextAlign.start,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: DarbakColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Directionality(
              textDirection: isNumericValue
                  ? TextDirection.ltr
                  : TextDirection.rtl,
              child: Text(
                value,
                textAlign: isNumericValue ? TextAlign.end : TextAlign.start,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: DarbakColors.dark,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'app_theme.dart';
import 'app_widgets.dart';
import 'api_service.dart';
import 'location_picker_screens.dart';
import 'shipment_bids_detail_screen.dart';
import 'trip_screens.dart';

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
      appBar: AppBar(title: Text(titles[_currentIndex])),
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
    _loadShipments();
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
      final myShipments = allShipments.where((s) => s['shipper_id'] == shipperId).toList();
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
          // شريط أعلى + زر شحنة جديدة
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                ElevatedButton.icon(
                  onPressed: _activeShipmentsCount >= _maxActiveShipments
                      ? null
                      : () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CreateShipmentScreen(),
                      ),
                    );
                    // Refresh shipments after creating new one
                    _loadShipments();
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text(
                    'شحنة جديدة',
                    style: TextStyle(fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _shipments.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: DarbakColors.textSecondary,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'لا توجد شحنات حالياً',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: DarbakColors.dark,
                          ),
                        ),
                        SizedBox(height: 8),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'اضغط على "شحنة جديدة" لبدء إنشاء شحنتك الأولى',
                            style: TextStyle(
                              fontSize: 14,
                              color: DarbakColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
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
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${shipment['pickup_address'] ?? '-'} ➔ ${shipment['dropoff_address'] ?? '-'}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text('الوزن: ${shipment['weight_kg']} طن'),
                              Text('السعر الأساسي: ${shipment['base_price']} ريال'),
                              Text(
                                'الموعد النهائي: ${_formatExpectedDate(shipment['expected_delivery_date'])}',
                              ),
                              const SizedBox(height: 16),
                              // View Bids button - only show for bidding status
                              if (shipment['status'] == 'bidding')
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => ShipmentBidsDetailScreen(
                                            shipmentId: shipment['id'],
                                            shipmentTitle: 'شحنة #${shipment['id']}',
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.gavel_rounded),
                                    label: const Text('عرض العروض'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: DarbakColors.primaryGreen,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
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
                                              shipmentId: shipment['id'].toString(),
                                              otherUser: 'محادثة الرحلة',
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.chat_bubble_rounded),
                                      label: const Text('محادثة السائق'),
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
        ],
      ),
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
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _distanceController = TextEditingController();
  final TextEditingController _cargoTypeController = TextEditingController();
  final TextEditingController _basePriceController = TextEditingController();
  final TextEditingController _specialInstructionsController =
      TextEditingController();

  DateTime? _selectedDate;
  String _selectedPeriod = 'morning';
  int _auctionDurationHours = 24;
  bool _isSubmitting = false;

  // بيانات موقع التحميل
  String? pickupMapsUrl;
  double? pickupLat;
  double? pickupLng;

  // بيانات موقع التسليم
  String? dropoffMapsUrl;
  double? dropoffLat;
  double? dropoffLng;

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _weightController.dispose();
    _distanceController.dispose();
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

                  // المسافة
                  _buildTextField(
                    label: 'المسافة التقريبية (كم)',
                    controller: _distanceController,
                    keyboardType: TextInputType.number,
                    validatorMsg: 'الرجاء إدخال المسافة',
                  ),
                  const SizedBox(height: 12),

                  // السعر الأساسي
                  _buildTextField(
                    label: 'السعر الأساسي المقترح (ريال)',
                    controller: _basePriceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validatorMsg: 'الرجاء إدخال السعر الأساسي',
                  ),
                  const SizedBox(height: 12),

                  // الوزن
                  _buildTextField(
                    label: 'وزن الشحنة (بالطن)',
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validatorMsg: 'الرجاء إدخال الوزن',
                  ),
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
                          const Icon(Icons.calendar_today, color: Color(0xff168A57)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedDate != null
                                  ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                                  : 'اختر التاريخ',
                              style: TextStyle(
                                color: _selectedDate != null ? Colors.black : Colors.grey,
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
                      DropdownMenuItem(value: 'morning', child: Text('صباحي (06:00 - 12:00)')),
                      DropdownMenuItem(value: 'evening', child: Text('مسائي (12:00 - 18:00)')),
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
                    onPressed: _isSubmitting ? null : () async {
                      if (!(_formKey.currentState?.validate() ?? false)) return;
                      if (_selectedDate == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('يرجى تحديد موعد التسليم الأقصى'),
                          ),
                        );
                        return;
                      }

                      setState(() => _isSubmitting = true);

                      try {
                        // Format date as YYYY-MM-DD
                        final formattedDate = '${_selectedDate!.year.toString().padLeft(4, '0')}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';

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

                        final created = await ApiService.createShipment({
                          'weightKg':
                              double.tryParse(_weightController.text.trim()) ?? 0.0,
                          'cargoDescription': _cargoTypeController.text.trim(),
                          'pickupAddress': _fromController.text.trim(),
                          'dropoffAddress': _toController.text.trim(),
                          'pickupLat': pickupLat,
                          'pickupLng': pickupLng,
                          'dropoffLat': dropoffLat,
                          'dropoffLng': dropoffLng,
                          'basePrice':
                              double.tryParse(_basePriceController.text.trim()) ?? 0.0,
                          'expectedDeliveryDate': formattedDate,
                          'period': _selectedPeriod,
                          'auctionDurationHours': _auctionDurationHours,
                          'specialInstructions':
                              _specialInstructionsController.text.trim(),
                        });

                        debugPrint('Shipment created successfully: $created');
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
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        if (isRequired && (value == null || value.trim().isEmpty)) {
          return validatorMsg;
        }
        return null;
      },
      textAlign: TextAlign.right,
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

/// شاشة التنبيهات
class ShipperNotificationsScreen extends StatefulWidget {
  const ShipperNotificationsScreen({super.key});

  @override
  State<ShipperNotificationsScreen> createState() =>
      _ShipperNotificationsScreenState();
}

class _ShipperNotificationsScreenState extends State<ShipperNotificationsScreen> {
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
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final n = _items[i];
          final read = (n['is_read'] == 1 || n['is_read'] == true);
          return ListTile(
            leading: Icon(
              read ? Icons.notifications_none_rounded : Icons.notifications_active_rounded,
              color: read ? DarbakColors.textSecondary : DarbakColors.primaryGreen,
            ),
            title: Text(
              (n['title'] ?? 'تنبيه').toString(),
              style: TextStyle(
                fontWeight: read ? FontWeight.w500 : FontWeight.w700,
              ),
            ),
            subtitle: Text((n['message'] ?? '').toString()),
            trailing: Text(
              (n['created_at'] ?? '').toString(),
              style: const TextStyle(fontSize: 11, color: DarbakColors.textSecondary),
            ),
            onTap: () async {
              final id = (n['id'] as num?)?.toInt();
              if (id != null) {
                try {
                  await ApiService.markNotificationAsRead(id);
                } catch (_) {}
              }
              if (mounted) await _load();
            },
          );
        },
      ),
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
      if (!mounted) return;
      setState(() {
        _rows = raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
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
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final r = _rows[i];
          final sid = (r['shipment_id'] as num?)?.toInt();
          final name = (r['other_party_name'] ?? 'محادثة').toString();
          final last = (r['last_message'] ?? '').toString();
          final lastSender = (r['last_sender_id'] as num?)?.toInt();
          return FutureBuilder<int?>(
            future: SharedPreferences.getInstance().then((p) => p.getInt('user_id')),
            builder: (context, snap) {
              final myId = snap.data;
              final unread = myId != null &&
                  lastSender != null &&
                  lastSender != myId;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: DarbakColors.primaryGreen.withOpacity(0.15),
                  child: const Icon(
                    Icons.chat_bubble_rounded,
                    color: DarbakColors.primaryGreen,
                  ),
                ),
                title: Text(name),
                subtitle: Text(
                  last,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: unread
                    ? const Icon(Icons.circle, color: Colors.redAccent, size: 12)
                    : const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () {
                  if (sid == null) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        shipmentId: sid.toString(),
                        otherUser: name,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
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
      final profile = await ApiService.getProfile(userId);
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
      await ApiService.updateProfile(userId, {
        'fullName': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'licenseNo': _user?['license_no'],
        'commercialNo': _user?['commercial_no'],
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تحديث البيانات بنجاح')));
      _isEditing = false;
      await _loadProfile();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في تحديث التفاصيل: $e')));
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_user == null)
      return const Center(child: Text('لا يوجد بيانات مستخدم'));

    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            )
          else
            IconButton(icon: const Icon(Icons.save), onPressed: _updateProfile),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_isEditing) ...[
                const Center(
                  child: DarbakProfileAvatar(icon: Icons.domain_rounded),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(labelText: 'الاسم الكامل'),
                enabled: _isEditing,
                validator: (value) =>
                    (value == null || value.isEmpty) ? 'مطلوب' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                ),
                enabled: _isEditing,
                validator: (value) =>
                    (value == null || value.isEmpty) ? 'مطلوب' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'رقم الجوال'),
                enabled: _isEditing,
                validator: (value) =>
                    (value == null || value.isEmpty) ? 'مطلوب' : null,
              ),
              const SizedBox(height: 20),
              if (!_isEditing) ...[
                _buildInfoCard('الشركة', _user?['full_name'] ?? ''),
                _buildInfoCard('رقم السجل التجاري', _user?['commercial_no'] ?? 'غير متوفر'),
                _buildInfoCard(
                  'حالة التحقق',
                  _user?['verification_status'] == 'verified' ? 'موثق' : 'قيد المراجعة',
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
          builder: (context) => AlertDialog(
            title: const Text('تأكيد تسجيل الخروج'),
            content: const Text('هل تريد فعلاً تسجيل الخروج؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('الغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('تسجيل الخروج'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  Widget _buildInfoCard(String title, String value) {
    return Card(
      elevation: 0,
      color: DarbakColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(value),
      ),
    );
  }
}

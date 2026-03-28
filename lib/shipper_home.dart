import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'app_widgets.dart';
import 'location_picker_screens.dart';
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
      const ShipperShipmentsScreen(),      // شحناتي
      const ShipperNotificationsScreen(),  // التنبيهات
      const ShipperMessagesScreen(),       // الرسائل
      const ShipperProfileScreen(),        // الحساب
    ];

    final titles = [
      'شحناتي',
      'التنبيهات',
      'الرسائل',
      'حسابي',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_currentIndex]),
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

/// شاشة شحنات الشاحن (Empty State + زر شحنة جديدة)
class ShipperShipmentsScreen extends StatelessWidget {
  const ShipperShipmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // شريط أعلى + زر شحنة جديدة
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: DarbakColors.cardBackground,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Row(
                        children: const [
                          Icon(
                            Icons.local_shipping_rounded,
                            size: 18,
                            color: DarbakColors.dark,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'الشحنات النشطة: 0',
                            style: TextStyle(
                              fontSize: 13,
                              color: DarbakColors.dark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CreateShipmentScreen(),
                      ),
                    );
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
          ),
          Expanded(
            child: const Center(
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
                      'ستظهر هنا شحناتك عند ربط النظام الخلفي\n(ListView.builder + API)',
                      style: TextStyle(
                        fontSize: 14,
                        color: DarbakColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
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
  final TextEditingController _edtController = TextEditingController();

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
    _edtController.dispose();
    super.dispose();
  }

  Future<void> _pickPickupLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PickupLocationPickerScreen(),
      ),
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
      MaterialPageRoute(
        builder: (_) => const DropoffLocationPickerScreen(),
      ),
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
      appBar: AppBar(
        title: const Text('شحنة جديدة'),
      ),
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
                  const DarbakSectionTitle(
                    title: 'بيانات الشحنة',
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
                        Icon(Icons.check_circle,
                            color: Colors.green, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'تم تحديد موقع التحميل',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                          ),
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
                        Icon(Icons.check_circle,
                            color: Colors.orange, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'تم تحديد موقع التسليم',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                          ),
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

                  // الوزن
                  _buildTextField(
                    label: 'وزن الشحنة (بالطن)',
                    controller: _weightController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
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
                  const SizedBox(height: 16),

                  const DarbakSectionTitle(
                    title: 'موعد التسليم الأقصى (EDT)',
                    subtitle:
                        'يجب تسليم الشحنة قبل أو في هذا الموعد، وبعده يتم احتساب خصم تأخير آلياً.',
                  ),
                  const SizedBox(height: 8),

                  _buildTextField(
                    label: 'مثال: 18 يناير 2025 - 06:00 م',
                    controller: _edtController,
                    validatorMsg: 'تحديد EDT إلزامي وفقاً لمتطلبات النظام',
                  ),
                  const SizedBox(height: 24),

                  DarbakPrimaryButton(
                    label: 'حفظ ونشر الشحنة في السوق',
                    icon: Icons.check_circle_outline_rounded,
                    onPressed: () {
                      if (_formKey.currentState?.validate() ?? false) {
                        // هنا لاحقاً نرسل كل شيء للباك إند:
                        // pickupLat, pickupLng, pickupMapsUrl,
                        // dropoffLat, dropoffLng, dropoffMapsUrl, ...
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'تم إنشاء الشحنة محلياً. لاحقاً سيتم إرسالها للنظام الخلفي.',
                            ),
                          ),
                        );
                        Navigator.of(context).pop();
                      }
                    },
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
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return validatorMsg;
        }
        return null;
      },
      textAlign: TextAlign.right,
    );
  }
}



/// شاشة صورية لقائمة العروض
class ShipperBidsListScreen extends StatelessWidget {
  const ShipperBidsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('عروض السائقين'),
      ),
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
      appBar: AppBar(
        title: const Text('العقد الإلكتروني'),
      ),
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
class ShipperNotificationsScreen extends StatelessWidget {
  const ShipperNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_outlined,
            size: 64,
            color: DarbakColors.textSecondary,
          ),
          SizedBox(height: 16),
          Text(
            'لا توجد تنبيهات جديدة',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: DarbakColors.dark,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'ستظهر هنا تنبيهات التصعيد والتأخير عند ربط النظام الخلفي\n\n'
            'مثال: تنبيه قبل 24 ساعة من EDT، تنبيه بعد ساعة تأخير',
            style: TextStyle(
              fontSize: 14,
              color: DarbakColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// شاشة الرسائل
class ShipperMessagesScreen extends StatelessWidget {
  const ShipperMessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person_rounded)),
          title: const Text('السائق عبدالله'),
          subtitle: const Text('حول شحنة الرياض - الدمام'),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const ChatScreen(shipmentId: '0098', otherUser: 'السائق عبدالله'),
            ));
          },
        ),
      ],
    );
  }
}

/// شاشة الحساب (الشاحن/الشركة)
class ShipperProfileScreen extends StatelessWidget {
  const ShipperProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ملف الشركة')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DarbakSectionTitle(title: 'معلومات الشركة'),
            const SizedBox(height: 10),
            _buildInfoCard('اسم الشركة', 'دربك للنقل'),
            _buildInfoCard('السجل التجاري', '1010265071'),
            _buildInfoCard('الـ VAT', '300205584400003'),
            _buildInfoCard('العنوان', 'الرياض، حي السليمانية'),
            const SizedBox(height: 16),
            const DarbakSectionTitle(title: 'تفاصيل الاتصال'),
            const SizedBox(height: 8),
            _buildInfoCard('البريد الإلكتروني', 'info@darbak.sa'),
            _buildInfoCard('الهاتف', '+966555000111'),
            const SizedBox(height: 16),
            const DarbakSectionTitle(title: 'تقييم الأداء'),
            const SizedBox(height: 10),
            Card(
              elevation: 0,
              color: DarbakColors.cardBackground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: const [
                    Icon(Icons.star, color: DarbakColors.warningYellow),
                    SizedBox(width: 8),
                    Text('4.7 / 5.0', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Spacer(),
                    Text('851 تقييم', style: TextStyle(color: DarbakColors.textSecondary)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            DarbakOutlinedButton(
              label: 'تحديث بيانات الشركة',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('قريباً: واجهة تحديث بيانات الشركة')));
              },
            ),
          ],
        ),
      ),
    );
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

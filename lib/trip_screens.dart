import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'app_widgets.dart';

/// شاشة تتبع الرحلة (Timeline) للسائق والشاحن
class TripTrackingScreen extends StatefulWidget {
  final String shipmentId;
  final String driverName;
  final String driverRating;
  final String driverPhone;

  const TripTrackingScreen({
    super.key,
    required this.shipmentId,
    required this.driverName,
    required this.driverRating,
    required this.driverPhone,
  });

  @override
  State<TripTrackingScreen> createState() => _TripTrackingScreenState();
}

class _TripTrackingScreenState extends State<TripTrackingScreen> {
  int _currentStep = 2; // الحالة الحالية: "جاري التحميل"

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تتبع الرحلة'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    shipmentId: widget.shipmentId,
                    otherUser: widget.driverName,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.chat_bubble_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // بطاقة معلومات السائق
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: DarbakColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor:
                            DarbakColors.primaryGreen.withOpacity(0.2),
                        child: const Icon(
                          Icons.person_rounded,
                          color: DarbakColors.primaryGreen,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.driverName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 16,
                                  color: DarbakColors.warningYellow,
                                ),
                                const SizedBox(width: 4),
                                Text(widget.driverRating),
                                const SizedBox(width: 12),
                                const Icon(
                                  Icons.phone_rounded,
                                  size: 16,
                                  color: DarbakColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(widget.driverPhone),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // خط الوقت (Timeline)
                const DarbakSectionTitle(
                  title: 'حالة الرحلة',
                ),
                const SizedBox(height: 16),

                _TimelineStep(
                  icon: Icons.schedule_rounded,
                  title: 'تلقّي العرض وتوقيع العقد',
                  subtitle: 'قبل 3 ساعات',
                  isCompleted: true,
                  isCurrent: false,
                ),
                _TimelineStep(
                  icon: Icons.inventory_2_rounded,
                  title: 'جاري التحميل',
                  subtitle: 'الآن',
                  isCompleted: false,
                  isCurrent: true,
                ),
                _TimelineStep(
                  icon: Icons.route_rounded,
                  title: 'جاري النقل',
                  subtitle: 'قريباً',
                  isCompleted: false,
                  isCurrent: false,
                ),
                _TimelineStep(
                  icon: Icons.flag_rounded,
                  title: 'تم التسليم',
                  subtitle: 'قريباً',
                  isCompleted: false,
                  isCurrent: false,
                ),

                const SizedBox(height: 24),

                const DarbakSectionTitle(
                  title: 'الإجراءات المتاحة',
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _currentStep == 2
                            ? () {
                                setState(() {
                                  _currentStep = 3;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('تم تحديث الحالة: جاري النقل'),
                                  ),
                                );
                              }
                            : null,
                        icon: const Icon(Icons.route_rounded),
                        label: const Text('بدء الرحلة'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ProofOfDeliveryScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.camera_alt_rounded),
                        label: const Text('إثبات التسليم'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isCompleted;
  final bool isCurrent;

  const _TimelineStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isCompleted,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 3,
                height: 32,
                color: isCompleted
                    ? DarbakColors.primaryGreen
                    : isCurrent
                        ? DarbakColors.warningYellow
                        : Colors.grey,
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? DarbakColors.primaryGreen
                      : isCurrent
                          ? DarbakColors.warningYellow
                          : Colors.grey[300],
                  border: Border.all(
                    color: Colors.white,
                    width: 3,
                  ),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 14,
                ),
              ),
              Container(
                width: 3,
                height: 20,
                color: Colors.grey[200],
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isCompleted
                        ? DarbakColors.primaryGreen
                        : isCurrent
                            ? DarbakColors.warningYellow
                            : DarbakColors.dark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: DarbakColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// شاشة إثبات التسليم
class ProofOfDeliveryScreen extends StatefulWidget {
  const ProofOfDeliveryScreen({super.key});

  @override
  State<ProofOfDeliveryScreen> createState() => _ProofOfDeliveryScreenState();
}

class _ProofOfDeliveryScreenState extends State<ProofOfDeliveryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إثبات التسليم'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              children: [
                const DarbakSectionTitle(
                  title: 'إثبات وصول الشحنة وتسليمها',
                ),
                const SizedBox(height: 16),

                // منطقة الصور
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: DarbakColors.lightBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: DarbakColors.border),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt_outlined,
                          size: 48,
                          color: DarbakColors.textSecondary,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'التقط صورة للشحنة عند التسليم',
                          style: TextStyle(
                            color: DarbakColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  'توقيع المستلم',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: DarbakColors.lightBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: DarbakColors.border),
                  ),
                  child: const Center(
                    child: Text(
                      'مساحة التوقيع الرقمي',
                      style: TextStyle(
                        color: DarbakColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'كود الاستلام (اختياري)',
                    prefixIcon: Icon(Icons.qr_code_2_rounded),
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 24),

                DarbakPrimaryButton(
                  label: 'تأكيد التسليم',
                  icon: Icons.check_circle_outline_rounded,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'تم إثبات التسليم. سيتم تحديث حالة الرحلة وتحويل المبلغ للسائق.',
                        ),
                        backgroundColor: DarbakColors.successGreen,
                      ),
                    );
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// شاشة العقوبة (FR-22)
class PenaltyScreen extends StatelessWidget {
  const PenaltyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('عقوبة التأخير'),
        backgroundColor: DarbakColors.warningYellow,
        foregroundColor: DarbakColors.dark,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        DarbakColors.warningYellow,
                        DarbakColors.warningYellow.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: DarbakColors.dark,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'تم احتساب عقوبة تأخير',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: DarbakColors.dark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'الشحنة SHP-001',
                        style: TextStyle(
                          fontSize: 14,
                          color: DarbakColors.dark.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const DarbakSectionTitle(
                  title: 'تفاصيل الخصم',
                ),
                const SizedBox(height: 12),

                const _PenaltyDetailRow(
                  label: 'الموعد المتفق عليه (EDT)',
                  value: '18 يناير 2025 - 06:00 م',
                ),
                const _PenaltyDetailRow(
                  label: 'وقت التسليم الفعلي',
                  value: '19 يناير 2025 - 02:30 ص',
                  isWarning: true,
                ),
                const _PenaltyDetailRow(
                  label: 'عدد أيام التأخير',
                  value: '1 يوم',
                  isWarning: true,
                ),
                const _PenaltyDetailRow(
                  label: 'نسبة الخصم (5% يومياً)',
                  value: '5%',
                  isWarning: true,
                ),
                const _PenaltyDetailRow(
                  label: 'المبلغ الأصلي',
                  value: '4,500 ر.س',
                ),
                const _PenaltyDetailRow(
                  label: 'قيمة الخصم',
                  value: '225 ر.س',
                  isWarning: true,
                ),
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: DarbakColors.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: DarbakColors.primaryGreen),
                  ),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.attach_money_rounded,
                        color: DarbakColors.primaryGreen,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'المبلغ المستحق بعد الخصم: ',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '4,275 ر.س',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: DarbakColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                DarbakPrimaryButton(
                  label: 'تأكيد وإنهاء الرحلة',
                  icon: Icons.check_circle_outline_rounded,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'تم إنهاء الرحلة وتحديث الحسابات. يمكنك الآن الاطلاع على تقرير الرحلة الكامل.',
                        ),
                      ),
                    );
                    Navigator.of(context).pop();
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {
                    // لاحقاً: شاشة الاعتراض على العقوبة
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: DarbakColors.warningYellow),
                  ),
                  child: const Text(
                    'الاعتراض على العقوبة',
                    style: TextStyle(color: DarbakColors.warningYellow),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PenaltyDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isWarning;

  const _PenaltyDetailRow({
    required this.label,
    required this.value,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isWarning ? DarbakColors.warningYellow : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// شاشة المحادثة
class ChatScreen extends StatelessWidget {
  final String shipmentId;
  final String otherUser;

  const ChatScreen({
    super.key,
    required this.shipmentId,
    required this.otherUser,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(otherUser),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              // لاحقاً: مكالمة صوتية/فيديو
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'call', child: Text('مكالمة صوتية')),
              PopupMenuItem(value: 'video', child: Text('مكالمة فيديو')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 10,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Align(
                  alignment: index % 2 == 0
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: index % 2 == 0
                          ? DarbakColors.primaryGreen
                          : DarbakColors.cardBackground,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      index % 2 == 0
                          ? 'مرحبا، الشحنة جاهزة للتحميل الآن.'
                          : 'تمام، سأتوجه للموقع فوراً.',
                      style: TextStyle(
                        color:
                            index % 2 == 0 ? Colors.white : DarbakColors.dark,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const TextField(
                        decoration: InputDecoration(
                          hintText: 'اكتب رسالتك...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                    mini: true,
                    onPressed: () {},
                    backgroundColor: DarbakColors.primaryGreen,
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
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

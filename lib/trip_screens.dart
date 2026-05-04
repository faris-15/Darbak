import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'app_theme.dart';
import 'app_widgets.dart';
import 'api_service.dart';

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
                              builder: (_) => ProofOfDeliveryScreen(shipmentId: widget.shipmentId),
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
  final String shipmentId;
  const ProofOfDeliveryScreen({super.key, required this.shipmentId});

  @override
  State<ProofOfDeliveryScreen> createState() => _ProofOfDeliveryScreenState();
}

class _ProofOfDeliveryScreenState extends State<ProofOfDeliveryScreen> {
  XFile? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  final TextEditingController _codeController = TextEditingController();

  Future<void> _pickImage() async {
    final XFile? selected = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );
    if (selected != null) {
      setState(() {
        _imageFile = selected;
      });
    }
  }

  Future<void> _submit() async {
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى التقاط صورة للشحنة أولاً')),
      );
      return;
    }

    setState(() => _isUploading = true);
    try {
      final shipmentIdInt = int.tryParse(widget.shipmentId) ?? 0;
      await ApiService.updateShipmentStatus(
        shipmentId: shipmentIdInt,
        status: 'delivered',
        epodPhoto: _imageFile,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إثبات التسليم بنجاح!'),
          backgroundColor: DarbakColors.successGreen,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في الرفع: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إثبات التسليم'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
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
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: DarbakColors.lightBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: DarbakColors.border),
                    ),
                    child: _imageFile == null
                        ? const Center(
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
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              File(_imageFile!.path),
                              fit: BoxFit.cover,
                            ),
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
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'كود الاستلام (اختياري)',
                    prefixIcon: Icon(Icons.qr_code_2_rounded),
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 24),

                _isUploading
                    ? const CircularProgressIndicator()
                    : DarbakPrimaryButton(
                        label: 'تأكيد التسليم',
                        icon: Icons.check_circle_outline_rounded,
                        onPressed: _submit,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// شاشة العقوبة (FR-22) - يتم احتسابها ديناميكياً
class PenaltyScreen extends StatelessWidget {
  final Map<String, dynamic> shipmentData;

  const PenaltyScreen({super.key, required this.shipmentData});

  @override
  Widget build(BuildContext context) {
    // استخراج البيانات وتحويل التواريخ
    final String shipmentId = shipmentData['shipment_id']?.toString() ?? 'N/A';
    final double originalAmount =
        double.tryParse(shipmentData['bid_amount']?.toString() ?? '0') ?? 0;

    DateTime? expectedDate;
    if (shipmentData['expected_delivery_at'] != null) {
      expectedDate = DateTime.tryParse(shipmentData['expected_delivery_at']);
    }

    // نستخدم الوقت الحالي كـ "وقت تسليم" إذا لم يتوفر في البيانات
    final DateTime actualDate = shipmentData['delivered_at'] != null
        ? DateTime.tryParse(shipmentData['delivered_at']) ?? DateTime.now()
        : DateTime.now();

    int delayDays = 0;
    double penaltyAmount = 0;
    double penaltyPercentage = 0;

    if (expectedDate != null && actualDate.isAfter(expectedDate)) {
      delayDays = actualDate.difference(expectedDate).inDays;
      // إذا كان هناك كسر يوم (مثلاً 1.2 يوم) يُحسب يومين أو نعتمد الساعات، هنا سنعتمد الأيام الكاملة
      if (actualDate.difference(expectedDate).inHours % 24 > 0) {
        delayDays += 1;
      }
      penaltyPercentage = delayDays * 0.05; // 5% لكل يوم
      penaltyAmount = originalAmount * penaltyPercentage;
    }

    final double finalAmount = originalAmount - penaltyAmount;

    final dateFormat = DateFormat('yyyy-MM-dd - hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الدفع والعقوبات'),
        backgroundColor:
            delayDays > 0 ? DarbakColors.warningYellow : DarbakColors.primaryGreen,
        foregroundColor: delayDays > 0 ? DarbakColors.dark : Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
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
                      colors: delayDays > 0
                          ? [DarbakColors.warningYellow, DarbakColors.warningYellow.withOpacity(0.8)]
                          : [DarbakColors.primaryGreen, DarbakColors.primaryGreen.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        delayDays > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                        color: delayDays > 0 ? DarbakColors.dark : Colors.white,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        delayDays > 0 ? 'تم احتساب عقوبة تأخير' : 'تم التسليم في الموعد',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: delayDays > 0 ? DarbakColors.dark : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'شحنة رقم #$shipmentId',
                        style: TextStyle(
                          fontSize: 14,
                          color: delayDays > 0 ? DarbakColors.dark.withOpacity(0.8) : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const DarbakSectionTitle(title: 'ملخص الحساب المالي'),
                const SizedBox(height: 12),

                _PenaltyDetailRow(
                  label: 'الموعد المتفق عليه (EDT)',
                  value: expectedDate != null ? dateFormat.format(expectedDate.toLocal()) : 'غير محدد',
                ),
                _PenaltyDetailRow(
                  label: 'وقت التسليم الفعلي',
                  value: dateFormat.format(actualDate.toLocal()),
                  isWarning: delayDays > 0,
                ),
                if (delayDays > 0) ...[
                  _PenaltyDetailRow(
                    label: 'مدة التأخير',
                    value: '$delayDays يوم',
                    isWarning: true,
                  ),
                  _PenaltyDetailRow(
                    label: 'نسبة الخصم (5% يومياً)',
                    value: '${(penaltyPercentage * 100).toInt()}%',
                    isWarning: true,
                  ),
                ],
                _PenaltyDetailRow(
                  label: 'المبلغ الأصلي للمناقصة',
                  value: '${originalAmount.toStringAsFixed(2)} ر.س',
                ),
                if (delayDays > 0)
                  _PenaltyDetailRow(
                    label: 'قيمة الخصم المستقطع',
                    value: '- ${penaltyAmount.toStringAsFixed(2)} ر.س',
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
                    children: [
                      const Icon(Icons.attach_money_rounded, color: DarbakColors.primaryGreen),
                      const SizedBox(width: 8),
                      const Text(
                        'المبلغ الصافي للتحويل: ',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${finalAmount.toStringAsFixed(2)} ر.س',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: DarbakColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
                DarbakPrimaryButton(
                  label: 'تأكيد واستلام المستحقات',
                  icon: Icons.account_balance_wallet_rounded,
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                ),
                if (delayDays > 0) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم رفع طلب اعتراض، سيراجع الأدمن الحالة')),
                      );
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

/// شاشة المحادثة (تفاعلية محلية)
class ChatScreen extends StatefulWidget {
  final String shipmentId;
  final String otherUser;
  final int? otherUserId;

  const ChatScreen({
    super.key,
    required this.shipmentId,
    required this.otherUser,
    this.otherUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _controller = TextEditingController();
  Timer? _poller;
  bool _loading = true;
  int? _myUserId;
  int? _resolvedOtherUserId;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _poller = Timer.periodic(const Duration(seconds: 3), (_) => _loadMessages());
  }

  Future<void> _bootstrap() async {
    await _resolveUsers();
    await _loadMessages();
  }

  Future<void> _resolveUsers() async {
    if (widget.otherUserId != null) {
      _resolvedOtherUserId = widget.otherUserId;
    }
    final shipmentIdInt = int.tryParse(widget.shipmentId);
    if (shipmentIdInt == null) return;
    final shipment = await ApiService.getShipment(shipmentIdInt);
    final prefs = await SharedPreferences.getInstance();
    _myUserId = prefs.getInt('user_id');
    final isDriver = prefs.getString('user_role') == 'driver';
    _resolvedOtherUserId ??= isDriver
        ? (shipment['shipper_id'] as num?)?.toInt()
        : (shipment['driver_id'] as num?)?.toInt();
  }

  Future<void> _loadMessages() async {
    final shipmentIdInt = int.tryParse(widget.shipmentId);
    if (shipmentIdInt == null) return;
    try {
      final rows = await ApiService.getChatMessages(shipmentIdInt);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(rows.map((e) => Map<String, dynamic>.from(e as Map)));
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final shipmentIdInt = int.tryParse(widget.shipmentId);
    if (shipmentIdInt == null || _resolvedOtherUserId == null) return;
    try {
      await ApiService.sendChatMessage(
        shipmentId: shipmentIdInt,
        receiverId: _resolvedOtherUserId!,
        message: text,
      );
      _controller.clear();
      await _loadMessages();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إرسال الرسالة: $e')),
      );
    }
  }

  @override
  void dispose() {
    _poller?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUser),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final senderId = (msg['sender_id'] as num?)?.toInt();
                final isMe = senderId != null && senderId == _myUserId;
                final senderName =
                    (msg['sender_name'] ?? '').toString().trim();
                final ts = msg['created_at']?.toString();
                String timeLabel = '';
                if (ts != null && ts.isNotEmpty) {
                  try {
                    timeLabel = DateFormat('dd/MM HH:mm')
                        .format(DateTime.parse(ts).toLocal());
                  } catch (_) {
                    timeLabel = ts;
                  }
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Align(
                    alignment:
                        isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      decoration: BoxDecoration(
                        color: isMe
                            ? DarbakColors.primaryGreen
                            : DarbakColors.cardBackground,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (senderName.isNotEmpty)
                            Text(
                              senderName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isMe
                                    ? Colors.white70
                                    : DarbakColors.textSecondary,
                              ),
                            ),
                          Text(
                            (msg['message'] ?? '').toString(),
                            style: TextStyle(
                              color: isMe ? Colors.white : DarbakColors.dark,
                            ),
                          ),
                          if (timeLabel.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                timeLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isMe
                                      ? Colors.white70
                                      : DarbakColors.textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'اكتب رسالتك...',
                        border: InputBorder.none,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: DarbakColors.primaryGreen),
                    onPressed: _sendMessage,
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

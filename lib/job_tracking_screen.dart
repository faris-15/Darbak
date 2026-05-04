import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'app_theme.dart';
import 'app_widgets.dart';
import 'api_service.dart';
import 'trip_screens.dart';
import 'ratings_screen.dart';

/// شاشة متابعة حالة الرحلة مع Timeline و ePOD
class JobTrackingScreen extends StatefulWidget {
  final int shipmentId;
  final Map<String, dynamic> shipmentData;

  const JobTrackingScreen({
    super.key,
    required this.shipmentId,
    required this.shipmentData,
  });

  @override
  State<JobTrackingScreen> createState() => _JobTrackingScreenState();
}

class _JobTrackingScreenState extends State<JobTrackingScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _shipment;
  bool _isLoading = true;
  XFile? _podPhotoFile;
  String? _podPhotoBackendPath;
  bool _isUpdatingStatus = false;
  bool _isSubmittingPOD = false;
  Timer? _locationTimer;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  static const Set<String> _chatEnabledStatuses = {
    'assigned',
    'at_pickup',
    'en_route',
    'at_dropoff',
  };

  // Timeline steps
  final List<Map<String, dynamic>> _timelineSteps = [
    {
      'status': 'assigned',
      'label': 'تم قبول العرض والتعيين',
      'icon': Icons.handshake_outlined,
      'color': Colors.green,
    },
    {
      'status': 'at_pickup',
      'label': 'وصلت لموقع التحميل',
      'icon': Icons.location_on,
      'color': Colors.blue,
    },
    {
      'status': 'en_route',
      'label': 'بدأت الرحلة (في الطريق)',
      'icon': Icons.local_shipping_outlined,
      'color': Colors.orange,
    },
    {
      'status': 'at_dropoff',
      'label': 'وصلت لموقع التسليم',
      'icon': Icons.location_on,
      'color': Colors.orange,
    },
    {
      'status': 'delivered',
      'label': 'تم التسليم بنجاح',
      'icon': Icons.check_circle,
      'color': Colors.green,
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _loadShipmentData();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _restartLocationPing() {
    _locationTimer?.cancel();
    _locationTimer = null;
    final shipment = _shipment ?? widget.shipmentData;
    final st = (shipment['status'] ?? '').toString();
    const active = {'assigned', 'at_pickup', 'en_route', 'at_dropoff'};
    if (!active.contains(st)) return;
    _locationTimer = Timer.periodic(const Duration(seconds: 40), (_) {
      _pushLiveLocation();
    });
    _pushLiveLocation();
  }

  Future<void> _pushLiveLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await ApiService.recordShipmentLiveLocation(
        shipmentId: widget.shipmentId,
        lat: pos.latitude,
        lng: pos.longitude,
      );
    } catch (_) {
      /* ignore intermittent GPS / network errors */
    }
  }

  Future<void> _openRatePartner() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getInt('user_id');
    final role = prefs.getString('user_role');
    final s = _shipment ?? widget.shipmentData;
    final sid = (s['shipper_id'] as num?)?.toInt();
    final did = (s['driver_id'] as num?)?.toInt();
    if (uid == null || role == null || sid == null || did == null) return;
    final otherId = role == 'driver' ? sid : did;
    if (otherId == uid) return;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RatingsScreen(
          shipmentId: widget.shipmentId,
          otherUserId: otherId,
          otherUserRole: role == 'driver' ? 'shipper' : 'driver',
          otherUserName: role == 'driver' ? 'الشاحن' : 'السائق',
        ),
      ),
    );
  }

  Future<void> _openContract() async {
    try {
      final urlStr = await ApiService.getShipmentContractSignedUrl(
        widget.shipmentId,
      );
      if (urlStr == null || urlStr.isEmpty) return;
      final url = Uri.parse(urlStr);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر فتح العقد: $e')),
      );
    }
  }

  Future<void> _loadShipmentData() async {
    try {
      final shipment = await ApiService.getShipment(widget.shipmentId);
      final historyResponse = await ApiService.getShipmentStatusHistory(
        widget.shipmentId,
      );
      final history = (historyResponse['history'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      setState(() {
        _shipment = shipment;
        _podPhotoBackendPath = _extractLatestPodPath(history);
        _isLoading = false;
      });
      _restartLocationPing();
    } catch (e) {
      setState(() => _isLoading = false);
      final message = e.toString();
      final userMessage = message.contains('401')
          ? 'الجلسة انتهت، يرجى تسجيل الدخول مرة أخرى'
          : message.contains('SocketException') ||
                message.contains('Connection refused')
          ? 'تعذر الاتصال بالخادم، تأكد من تشغيل السيرفر'
          : 'خطأ: $message';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userMessage)));
    }
  }

  Future<void> _pickPODPhoto() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _podPhotoFile = XFile(result.files.single.path!);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم اختيار الملف بنجاح')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في اختيار الملف: $e')),
      );
    }
  }

  bool _isPdf(String? path) {
    if (path == null) return false;
    return path.toLowerCase().endsWith('.pdf');
  }

  Future<void> _submitPOD() async {
    if (_podPhotoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى التقاط صورة الاستلام أولاً')),
      );
      return;
    }

    setState(() => _isSubmittingPOD = true);
    try {
      final response = await ApiService.updateShipmentStatus(
        shipmentId: widget.shipmentId,
        status: 'delivered',
        epodPhoto: _podPhotoFile,
      );
      final history = response['history'] as Map<String, dynamic>?;

      setState(() {
        _podPhotoBackendPath =
            history?['photo_path']?.toString() ?? _podPhotoBackendPath;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل وثيقة الاستلام بنجاح')),
      );
      await _loadShipmentData();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      setState(() => _isSubmittingPOD = false);
    }
  }

  String? _nextStatusFor(String currentStatus) {
    switch (currentStatus) {
      case 'assigned':
        return 'at_pickup';
      case 'at_pickup':
        return 'en_route';
      case 'en_route':
        return 'at_dropoff';
      default:
        return null;
    }
  }

  String _statusLabel(String status) {
    final step = _timelineSteps.where((s) => s['status'] == status).toList();
    if (step.isNotEmpty) {
      return step.first['label'] as String;
    }
    return status;
  }

  Future<Position?> _tryCurrentPosition() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isUpdatingStatus = true);
    try {
      final pos = await _tryCurrentPosition();
      await ApiService.updateShipmentStatus(
        shipmentId: widget.shipmentId,
        status: newStatus,
        locationLat: pos?.latitude,
        locationLng: pos?.longitude,
      );

      await _loadShipmentData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تحديث الحالة إلى: ${_statusLabel(newStatus)}')),
      );
    } catch (e) {
      final message = e.toString();
      final userMessage = message.contains('401')
          ? 'الجلسة انتهت، يرجى تسجيل الدخول مرة أخرى'
          : message.contains('SocketException') ||
                message.contains('Connection refused')
          ? 'تعذر الاتصال بالخادم، تأكد من تشغيل السيرفر'
          : 'خطأ في تحديث الحالة: $message';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userMessage)));
    } finally {
      setState(() => _isUpdatingStatus = false);
    }
  }

  int _getCurrentStepIndex() {
    final status = _shipment?['status'] ?? 'pending';
    final index = _timelineSteps.indexWhere((step) => step['status'] == status);
    return index == -1 ? 0 : index;
  }

  String _getCurrentLocationLabel() {
    final shipment = _shipment ?? widget.shipmentData;
    final status = shipment['status']?.toString() ?? '';
    if (status.contains('pickup') || status == 'assigned') {
      return 'الذهاب لنقطة التحميل';
    }
    if (status.contains('dropoff') || status == 'en_route') {
      return 'الذهاب لنقطة التسليم';
    }
    return 'تحديد الموقع';
  }

  bool _isPickupStage(String status) {
    return status.contains('pickup') || status == 'assigned';
  }

  bool _isDropoffStage(String status) {
    return status.contains('dropoff') || status == 'en_route';
  }

  String _getCurrentLocationAddress() {
    final shipment = _shipment ?? widget.shipmentData;
    final status = shipment['status']?.toString() ?? '';
    if (_isPickupStage(status)) {
      return shipment['pickup_address']?.toString().trim() ?? '';
    }
    if (_isDropoffStage(status)) {
      return shipment['dropoff_address']?.toString().trim() ?? '';
    }
    return '';
  }

  String _getCurrentLocationUrl() {
    final shipment = _shipment ?? widget.shipmentData;
    final status = shipment['status']?.toString() ?? '';
    double? lat;
    double? lng;

    if (_isPickupStage(status)) {
      lat = _toDouble(shipment['pickup_lat']);
      lng = _toDouble(shipment['pickup_lng']);
    } else if (_isDropoffStage(status)) {
      lat = _toDouble(shipment['dropoff_lat']);
      lng = _toDouble(shipment['dropoff_lng']);
    }

    if (lat == null || lng == null) return '';
    return 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String? _extractLatestPodPath(List<Map<String, dynamic>> history) {
    for (int i = history.length - 1; i >= 0; i--) {
      final path = history[i]['photo_path']?.toString();
      if (path != null && path.trim().isNotEmpty) {
        return path;
      }
    }
    return null;
  }

  Future<String?> _getSignedUrlOrPath(String path) async {
    if (path.startsWith('http')) return path;
    try {
      // استخدام API التوقيع الموجود في الباكيند
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/admin/get-signed-url?url=${Uri.encodeComponent(path)}'),
        headers: await ApiService.authHeaders(jsonContentType: false),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['signedUrl'];
      }
    } catch (e) {
      debugPrint('Error getting signed URL: $e');
    }
    return _buildBackendImageUrl(path);
  }

  String? _buildBackendImageUrl(String? maybePath) {
    if (maybePath == null || maybePath.trim().isEmpty) return null;
    final path = maybePath.trim();
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final apiUri = Uri.parse(ApiService.baseUrl);
    final origin = '${apiUri.scheme}://${apiUri.host}${apiUri.hasPort ? ':${apiUri.port}' : ''}';
    
    // التحقق إذا كان المسار عبارة عن مفتاح S3 وليس رابطاً كاملاً
    if (!path.startsWith('http')) {
      // نفضل استخدام endpoint التوقيع في AdminController أو آلية مماثلة لو كانت متوفرة للكل
      // حالياً سنحاول بنائه كـ Static URL إذا كان الـ Bucket مفتوحاً أو عبر بروكسي الباكيند
      if (path.startsWith('/')) {
        return '$origin$path';
      }
      // إذا كان مخزناً كـ Key في S3 (مثل epod/xxx.jpg)
      return '$origin/api/admin/get-signed-url?url=${Uri.encodeComponent(path)}'; 
    }
    
    return path;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('متابعة الرحلة')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final shipment = _shipment ?? widget.shipmentData;
    final currentStepIndex = _getCurrentStepIndex();

    return Scaffold(
      appBar: AppBar(
        title: const Text('متابعة الرحلة'),
        actions: [
          if (_chatEnabledStatuses.contains((shipment['status'] ?? '').toString()))
            IconButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      shipmentId: widget.shipmentId.toString(),
                      otherUser: 'المحادثة',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.chat_bubble_rounded),
            ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status Badge
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange, width: 2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'الحالة الحالية: ${shipment['status'] ?? 'قيد المعالجة'}',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Timeline
              _buildTimeline(currentStepIndex),

              const SizedBox(height: 24),

              // Action Button to advance status
              if (_shipment?['status'] != 'delivered' &&
                  _nextStatusFor((_shipment?['status'] ?? '').toString()) != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _isUpdatingStatus
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: () => _updateStatus(
                            _nextStatusFor((_shipment?['status'] ?? '').toString())!,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: DarbakColors.primaryGreen,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            'تحديث الحالة إلى: ${_statusLabel(_nextStatusFor((_shipment?['status'] ?? '').toString())!)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),

              // Location Button (Contextual)
              if (_getCurrentLocationAddress().isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () async {
                    final locationUrl = _getCurrentLocationUrl();
                    if (locationUrl.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('إحداثيات الموقع غير متوفرة لهذه الشحنة'),
                        ),
                      );
                      return;
                    }
                    final url = Uri.parse(locationUrl);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تعذر فتح الخرائط')),
                      );
                    }
                  },
                  icon: const Icon(Icons.location_on),
                  label: Text(_getCurrentLocationLabel()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DarbakColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),

              const SizedBox(height: 24),

              // ePOD Section (only show if delivered status)
              if (shipment['status'] == 'at_dropoff' ||
                  shipment['status'] == 'delivered') ...[
                const Divider(),
                const SizedBox(height: 16),
                const Text(
                  'وثيقة الاستلام الإلكترونية (ePOD)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: DarbakColors.dark,
                  ),
                ),
                const SizedBox(height: 12),
                if (_podPhotoFile != null)
                  Card(
                    elevation: 0,
                    color: DarbakColors.cardBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _isPdf(_podPhotoFile!.path)
                          ? Container(
                              height: 150,
                              width: double.infinity,
                              color: Colors.red.shade50,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.picture_as_pdf, size: 48, color: Colors.red),
                                  const SizedBox(height: 8),
                                  Text(_podPhotoFile!.name),
                                ],
                              ),
                            )
                          : Image.file(
                              File(_podPhotoFile!.path),
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                if (_podPhotoFile == null &&
                    _podPhotoBackendPath != null)
                  FutureBuilder<String?>(
                    future: _getSignedUrlOrPath(_podPhotoBackendPath!),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
                      }
                      final url = snapshot.data;
                      if (url == null) return const SizedBox.shrink();

                      return Card(
                        elevation: 0,
                        color: DarbakColors.cardBackground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _isPdf(_podPhotoBackendPath)
                              ? ListTile(
                                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                                  title: const Text('عرض وثيقة PDF'),
                                  onTap: () async {
                                    final uri = Uri.parse(url);
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    }
                                  },
                                )
                              : Image.network(
                                  url,
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const SizedBox(
                                    height: 120,
                                    child: Center(
                                      child: Text('تعذر تحميل صورة إثبات التسليم'),
                                    ),
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 12),
                if (shipment['status'] == 'at_dropoff')
                  ElevatedButton.icon(
                    onPressed: _pickPODPhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('التقاط صورة الاستلام'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                if (_podPhotoFile != null &&
                    shipment['status'] == 'at_dropoff')
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _isSubmittingPOD
                        ? const Center(child: CircularProgressIndicator())
                        : DarbakPrimaryButton(
                            label: 'تأكيد التسليم',
                            icon: Icons.check_circle_outline,
                            onPressed: _submitPOD,
                          ),
                  ),
              ],

              const SizedBox(height: 24),

              if ((shipment['status'] ?? '').toString() == 'delivered') ...[
                const Text(
                  'بعد التسليم',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: DarbakColors.dark,
                  ),
                ),
                const SizedBox(height: 10),
                if ((_shipment?['contract_pdf_key'] ?? shipment['contract_pdf_key'])
                        ?.toString()
                        .trim()
                        .isNotEmpty ==
                    true)
                  OutlinedButton.icon(
                    onPressed: _openContract,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('عرض / تنزيل العقد الإلكتروني'),
                  ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _openRatePartner,
                  icon: const Icon(Icons.star_rate_rounded),
                  label: const Text('تقييم الطرف الآخر'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DarbakColors.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Shipment Details
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'تفاصيل الشحنة',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: DarbakColors.dark,
                ),
              ),
              const SizedBox(height: 12),
              _buildDetailRow('الوزن', '${shipment['weight_kg']} كجم'),
              _buildDetailRow(
                'الوصف',
                shipment['cargo_description'] ?? 'لا يوجد',
              ),
              _buildDetailRow('السعر الأساسي', '${shipment['base_price']} ر.س'),
              _buildDetailRow(
                'الموعد المتوقع',
                shipment['expected_delivery_date']?.toString() ??
                    'لم يتم تحديده',
              ),
              if ((shipment['special_instructions']?.toString().trim() ?? '')
                  .isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'تعليمات خاصة',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: DarbakColors.dark,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: DarbakColors.cardBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    shipment['special_instructions'].toString().trim(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: DarbakColors.dark,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeline(int currentStepIndex) {
    return Column(
      children: List.generate(_timelineSteps.length, (index) {
        final step = _timelineSteps[index];
        final isCompleted = index < currentStepIndex;
        final isActive = index == currentStepIndex;

        return Padding(
          padding: EdgeInsets.only(
            bottom: index < _timelineSteps.length - 1 ? 12 : 0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline Point
              Column(
                children: [
                  ScaleTransition(
                    scale: isActive
                        ? _pulseAnimation
                        : const AlwaysStoppedAnimation(1.0),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: isCompleted || isActive
                          ? Colors.green
                          : Colors.grey[300],
                      child: Icon(
                        step['icon'],
                        size: 20,
                        color: isCompleted || isActive
                            ? Colors.white
                            : Colors.grey[600],
                      ),
                    ),
                  ),
                  if (index < _timelineSteps.length - 1)
                    Container(
                      width: 2,
                      height: 40,
                      color: isCompleted || isActive
                          ? Colors.green
                          : Colors.grey[300],
                    ),
                ],
              ),
              const SizedBox(width: 16),
              // Timeline Label
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step['label'],
                        style: TextStyle(
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.w500,
                          fontSize: isActive ? 14 : 13,
                          color: isCompleted || isActive
                              ? DarbakColors.dark
                              : DarbakColors.textSecondary,
                        ),
                      ),
                      if (isActive)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: DarbakColors.primaryGreen,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'الحالة الحالية',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: DarbakColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: DarbakColors.dark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

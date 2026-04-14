import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'app_theme.dart';
import 'app_widgets.dart';
import 'api_service.dart';

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

class _JobTrackingScreenState extends State<JobTrackingScreen> {
  Map<String, dynamic>? _shipment;
  bool _isLoading = true;
  XFile? _podPhotoFile;
  bool _isSubmittingPOD = false;

  // Timeline steps
  final List<Map<String, dynamic>> _timelineSteps = [
    {
      'status': 'order_placed',
      'label': 'تم إنشاء الطلب',
      'icon': Icons.check_circle,
      'color': Colors.green,
    },
    {
      'status': 'bid_accepted',
      'label': 'تم قبول العرض',
      'icon': Icons.handshake_outlined,
      'color': Colors.green,
    },
    {
      'status': 'driver_assigned',
      'label': 'السائق على الطريق للتحميل',
      'icon': Icons.directions_car,
      'color': Colors.blue,
    },
    {
      'status': 'pickup_arrived',
      'label': 'وصول نقطة التحميل',
      'icon': Icons.location_on,
      'color': Colors.blue,
    },
    {
      'status': 'en_route',
      'label': 'في الطريق للتسليم',
      'icon': Icons.local_shipping_outlined,
      'color': Colors.orange,
    },
    {
      'status': 'dropoff_arrived',
      'label': 'وصول نقطة التسليم',
      'icon': Icons.location_on,
      'color': Colors.orange,
    },
    {
      'status': 'pod_required',
      'label': 'تصوير وثيقة الاستلام',
      'icon': Icons.camera_alt,
      'color': Colors.purple,
    },
    {
      'status': 'delivered',
      'label': 'تم التسليم',
      'icon': Icons.check_circle,
      'color': Colors.green,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadShipmentData();
  }

  Future<void> _loadShipmentData() async {
    try {
      final shipment = await ApiService.getShipment(widget.shipmentId);
      setState(() {
        _shipment = shipment;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Future<void> _pickPODPhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      setState(() {
        _podPhotoFile = image;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم التقاط الصورة بنجاح')));
    }
  }

  Future<void> _submitPOD() async {
    if (_podPhotoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى التقاط صورة الاستلام أولاً')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final driverId = prefs.getInt('user_id');

    if (driverId == null) return;

    setState(() => _isSubmittingPOD = true);
    try {
      // Record ePOD in shipment_status_history table
      await ApiService.recordShipmentStatus({
        'shipment_id': widget.shipmentId,
        'status': 'delivered',
        'photo_path': _podPhotoFile!.path,
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

  int _getCurrentStepIndex() {
    final status = _shipment?['status'] ?? 'pending';
    return _timelineSteps.indexWhere((step) => step['status'] == status);
  }

  String _getCurrentLocationLabel() {
    final status = _shipment?['status'] ?? '';
    if (status.contains('pickup') || status == 'driver_assigned') {
      return 'الذهاب لنقطة التحميل';
    } else if (status.contains('dropoff') || status == 'en_route') {
      return 'الذهاب لنقطة التسليم';
    }
    return 'تحديد الموقع';
  }

  String _getCurrentLocationUrl() {
    final status = _shipment?['status'] ?? '';
    if (status.contains('pickup') || status == 'driver_assigned') {
      // Return pickup location URL (would be from shipment data)
      return 'https://maps.google.com/?q=${_shipment?['pickup_address'] ?? ''}';
    } else if (status.contains('dropoff') || status == 'en_route') {
      return 'https://maps.google.com/?q=${_shipment?['dropoff_address'] ?? ''}';
    }
    return '';
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

              // Location Button (Contextual)
              if (_getCurrentLocationUrl().isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () {
                    // Would open maps
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('فتح: ${_getCurrentLocationLabel()}'),
                      ),
                    );
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
              if (shipment['status'] == 'pod_required' ||
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
                      child: Image.file(
                        File(_podPhotoFile!.path),
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                if (shipment['status'] == 'pod_required')
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
                    shipment['status'] == 'pod_required')
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
                  CircleAvatar(
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

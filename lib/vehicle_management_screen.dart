import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'app_theme.dart';
import 'app_widgets.dart';
import 'api_service.dart';
import 'truck_classification/truck_classification_catalog.dart';
import 'truck_classification/truck_classification_models.dart';
import 'truck_classification/truck_classification_service.dart';
import 'truck_classification/widgets/truck_configuration_form.dart';

/// شاشة إدارة بيانات الشاحنة للسائقين
class VehicleManagementScreen extends StatefulWidget {
  const VehicleManagementScreen({super.key});

  @override
  State<VehicleManagementScreen> createState() =>
      _VehicleManagementScreenState();
}

class _TruckViewData {
  const _TruckViewData({
    required this.id,
    required this.plateNumber,
    required this.isthimaraNo,
    required this.truckType,
    required this.categoryId,
    required this.axleCount,
    required this.bodyTypeId,
    required this.payloadCapacityId,
    required this.isActive,
    required this.verificationStatus,
    required this.insuranceDocumentUrl,
  });

  final int id;
  final String plateNumber;
  final String isthimaraNo;
  final String truckType;
  final String categoryId;
  final int? axleCount;
  final String bodyTypeId;
  final String payloadCapacityId;
  final bool isActive;
  final String verificationStatus;
  final String? insuranceDocumentUrl;

  bool get hasInsurance => insuranceDocumentUrl?.trim().isNotEmpty == true;

  factory _TruckViewData.fromJson(Map<String, dynamic> json) {
    final selection = const TruckClassificationService().selectionFromTruckJson(
      json,
    );
    return _TruckViewData(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      plateNumber: json['plate_number']?.toString() ?? '',
      isthimaraNo: json['isthimara_no']?.toString() ?? '',
      truckType: json['truck_type']?.toString() ?? '',
      categoryId: selection.categoryId ?? '',
      axleCount: selection.axleCount,
      bodyTypeId: selection.bodyTypeId ?? '',
      payloadCapacityId: selection.capacityId ?? '',
      isActive: _parseBool(json['is_active']),
      verificationStatus: (json['verification_status'] ?? 'pending').toString(),
      insuranceDocumentUrl: json['insurance_document_url']?.toString(),
    );
  }

  static bool _parseBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value == 1;
    final normalized = value?.toString().toLowerCase().trim();
    return normalized == '1' || normalized == 'true';
  }
}

class _TruckSummaryHeader extends StatelessWidget {
  const _TruckSummaryHeader({
    required this.truckCount,
    required this.maxTrucks,
    required this.isRefreshing,
  });

  final int truckCount;
  final int maxTrucks;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DarbakColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_shipping_rounded,
            color: DarbakColors.primaryGreen,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'شاحناتي: $truckCount/$maxTrucks',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (isRefreshing)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}

class _TruckErrorBanner extends StatelessWidget {
  const _TruckErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.start,
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
        ],
      ),
    );
  }
}

class _EmptyTruckState extends StatelessWidget {
  const _EmptyTruckState();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DarbakColors.lightBackground,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.local_shipping_outlined,
            color: DarbakColors.textSecondary,
          ),
          SizedBox(height: 8),
          Text(
            'لا توجد شاحنات مسجلة بعد',
            style: TextStyle(color: DarbakColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _TruckManagementCard extends StatelessWidget {
  const _TruckManagementCard({
    required this.truck,
    required this.isActivating,
    required this.onSetActive,
    required this.onEdit,
    required this.onUploadInsurance,
    required this.isUploadingInsurance,
    required this.insuranceUploadProgress,
  });

  final _TruckViewData truck;
  final bool isActivating;
  final VoidCallback onSetActive;
  final VoidCallback onEdit;
  final VoidCallback onUploadInsurance;
  final bool isUploadingInsurance;
  final double insuranceUploadProgress;

  @override
  Widget build(BuildContext context) {
    final activeColor = truck.isActive
        ? DarbakColors.primaryGreen
        : DarbakColors.border;

    return Card(
      elevation: 0,
      color: truck.isActive
          ? DarbakColors.primaryGreen.withValues(alpha: 0.08)
          : DarbakColors.cardBackground,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: activeColor, width: truck.isActive ? 1.4 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            _ActiveTruckButton(
              isActive: truck.isActive,
              isLoading: isActivating,
              onPressed: onSetActive,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${truck.truckType} - ${truck.plateNumber}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'رخصة سير المركبة : ${truck.isthimaraNo.isEmpty ? '-' : truck.isthimaraNo}',
                    style: const TextStyle(color: DarbakColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _VerificationStatusChip(status: truck.verificationStatus),
                      _ActiveStatusChip(isActive: truck.isActive),
                      _InsuranceStatusChip(isUploaded: truck.hasInsurance),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _TruckInsuranceButton(
                    isUploaded: truck.hasInsurance,
                    isLoading: isUploadingInsurance,
                    progress: insuranceUploadProgress,
                    onPressed: onUploadInsurance,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'تعديل',
              onPressed: isActivating ? null : onEdit,
              icon: const Icon(Icons.edit, color: DarbakColors.primaryGreen),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveTruckButton extends StatelessWidget {
  const _ActiveTruckButton({
    required this.isActive,
    required this.isLoading,
    required this.onPressed,
  });

  final bool isActive;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        width: 40,
        height: 40,
        child: Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return IconButton(
      tooltip: isActive ? 'الشاحنة النشطة' : 'تحديد كشاحنة نشطة',
      onPressed: isActive ? null : onPressed,
      icon: Icon(
        isActive ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
        color: isActive
            ? DarbakColors.primaryGreen
            : DarbakColors.textSecondary,
        size: 30,
      ),
    );
  }
}

class _VerificationStatusChip extends StatelessWidget {
  const _VerificationStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final config = switch (status) {
      'verified' => const _StatusChipConfig(
        label: 'موثقة',
        icon: Icons.verified_rounded,
        color: DarbakColors.successGreen,
      ),
      'rejected' => const _StatusChipConfig(
        label: 'مرفوضة',
        icon: Icons.cancel_rounded,
        color: Colors.red,
      ),
      _ => const _StatusChipConfig(
        label: 'بانتظار التحقق',
        icon: Icons.schedule_rounded,
        color: Colors.orange,
      ),
    };
    return _StatusChip(config: config);
  }
}

class _ActiveStatusChip extends StatelessWidget {
  const _ActiveStatusChip({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return _StatusChip(
      config: _StatusChipConfig(
        label: isActive ? 'نشطة' : 'غير نشطة',
        icon: isActive
            ? Icons.check_circle_outline
            : Icons.pause_circle_outline,
        color: isActive
            ? DarbakColors.primaryGreen
            : DarbakColors.textSecondary,
      ),
    );
  }
}

class _InsuranceStatusChip extends StatelessWidget {
  const _InsuranceStatusChip({required this.isUploaded});

  final bool isUploaded;

  @override
  Widget build(BuildContext context) {
    return _StatusChip(
      config: _StatusChipConfig(
        label: isUploaded ? 'تأمين مرفوع' : 'بدون تأمين',
        icon: isUploaded
            ? Icons.description_rounded
            : Icons.upload_file_rounded,
        color: isUploaded ? DarbakColors.successGreen : Colors.blueGrey,
      ),
    );
  }
}

class _TruckInsuranceButton extends StatelessWidget {
  const _TruckInsuranceButton({
    required this.isUploaded,
    required this.isLoading,
    required this.progress,
    required this.onPressed,
  });

  final bool isUploaded;
  final bool isLoading;
  final double progress;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(value: progress > 0 ? progress : null),
          const SizedBox(height: 6),
          Text(
            'جاري رفع التأمين ${(progress * 100).clamp(0, 100).round()}%',
            style: const TextStyle(
              color: DarbakColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      );
    }

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(isUploaded ? Icons.refresh : Icons.upload_file, size: 18),
        label: Text(
          isUploaded ? 'تحديث تأمين هذه الشاحنة' : 'رفع تأمين هذه الشاحنة',
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.config});

  final _StatusChipConfig config;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: 16, color: config.color),
          const SizedBox(width: 4),
          Text(
            config.label,
            style: TextStyle(
              color: config.color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChipConfig {
  const _StatusChipConfig({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

class _TruckFormPanel extends StatelessWidget {
  const _TruckFormPanel({required this.isEditing, required this.child});

  final bool isEditing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DarbakColors.lightBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DarbakColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isEditing ? 'تعديل بيانات الشاحنة' : 'إضافة شاحنة جديدة',
            style: const TextStyle(fontWeight: FontWeight.w700),
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _VehicleManagementScreenState extends State<VehicleManagementScreen> {
  static const int _maxTrucks = 5;
  static const Duration _statusRefreshInterval = Duration(seconds: 20);
  List<_TruckViewData> _trucks = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isRefreshing = false;
  String? _errorMessage;
  int? _activatingTruckId;
  int? _insuranceUploadingTruckId;
  double _insuranceUploadProgress = 0;
  Uint8List? _lastInsuranceBytes;
  String? _lastInsuranceFileName;
  int? _lastInsuranceTruckId;
  Timer? _statusRefreshTimer;

  final _formKey = GlobalKey<FormState>();
  final _truckConfigFormKey = GlobalKey<TruckConfigurationFormState>();
  int? _editingTruckId;
  late TextEditingController _plateNoController;
  late TextEditingController _isthimaraNoController;
  TruckGroup? _editGroup;
  String? _editCategoryId;
  int? _editAxleCount;
  String? _editBodyTypeId;
  String? _editCapacityId;
  TruckConfiguration? _truckConfiguration;

  @override
  void initState() {
    super.initState();
    _plateNoController = TextEditingController();
    _isthimaraNoController = TextEditingController();
    _loadTrucks(showInitialLoader: true);
    _statusRefreshTimer = Timer.periodic(_statusRefreshInterval, (_) {
      if (mounted && !_isSaving && _activatingTruckId == null) {
        _loadTrucks(silent: true);
      }
    });
  }

  Future<void> _loadTrucks({
    bool showInitialLoader = false,
    bool silent = false,
  }) async {
    if (!mounted) return;
    if (showInitialLoader) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else if (!silent) {
      setState(() {
        _isRefreshing = true;
        _errorMessage = null;
      });
    }

    try {
      final trucksRaw = await ApiService.getMyTrucks();
      final trucks = trucksRaw
          .whereType<Map>()
          .map((e) => _TruckViewData.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (!mounted) return;
      setState(() {
        _trucks = trucks;
        _isLoading = false;
        _isRefreshing = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        if (!silent) {
          _errorMessage = e.toString();
        }
      });
    }
  }

  void _resetForm() {
    void resetValues() {
      _editingTruckId = null;
      _plateNoController.text = '';
      _isthimaraNoController.text = '';
      _editGroup = null;
      _editCategoryId = null;
      _editAxleCount = null;
      _editBodyTypeId = null;
      _editCapacityId = null;
      _truckConfiguration = null;
    }

    if (!mounted) {
      resetValues();
      return;
    }
    setState(resetValues);
  }

  void _startEditing(_TruckViewData truck) {
    setState(() {
      _editingTruckId = truck.id;
      _plateNoController.text = truck.plateNumber;
      _isthimaraNoController.text = truck.isthimaraNo;
      _editGroup = TruckClassificationCatalog.categoryById(truck.categoryId)?.group;
      _editCategoryId = truck.categoryId.isEmpty ? null : truck.categoryId;
      _editAxleCount = truck.axleCount;
      _editBodyTypeId = truck.bodyTypeId.isEmpty ? null : truck.bodyTypeId;
      _editCapacityId =
          truck.payloadCapacityId.isEmpty ? null : truck.payloadCapacityId;
      _truckConfiguration = const TruckClassificationService().resolveConfiguration(
        group: _editGroup,
        categoryId: _editCategoryId,
        axleCount: _editAxleCount,
        bodyTypeId: _editBodyTypeId,
        capacityId: _editCapacityId,
      );
    });
  }

  Future<void> _saveTruck() async {
    if (!_formKey.currentState!.validate()) return;
    final configValid = _truckConfigFormKey.currentState?.validateAll() ?? false;
    if (!configValid || _truckConfiguration == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إكمال تصنيف الشاحنة')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final isEditing = _editingTruckId != null;
      final payload = {
        'plate_number': _plateNoController.text.trim(),
        'isthimara_no': _isthimaraNoController.text.trim(),
        ..._truckConfiguration!.toApiPayload(),
      };
      if (_editingTruckId == null) {
        await ApiService.registerTruck(payload);
      } else {
        await ApiService.updateTruck(_editingTruckId!, payload);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'تم تحديث بيانات الشاحنة بنجاح'
                : 'تمت إضافة الشاحنة بنجاح',
          ),
        ),
      );
      _resetForm();
      await _loadTrucks(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _setActiveTruck(_TruckViewData truck) async {
    if (truck.isActive || _activatingTruckId != null || _isSaving) return;

    setState(() {
      _activatingTruckId = truck.id;
      _errorMessage = null;
    });

    try {
      final raw = await ApiService.setActiveTruck(truck.id);
      final trucks = raw
          .whereType<Map>()
          .map((e) => _TruckViewData.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (!mounted) return;
      setState(() {
        _trucks = trucks;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تفعيل الشاحنة ${truck.plateNumber}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر تفعيل الشاحنة: $e')));
      await _loadTrucks(silent: true);
    } finally {
      if (mounted) {
        setState(() {
          _activatingTruckId = null;
        });
      }
    }
  }

  String? _validateInsuranceFile(PlatformFile file) {
    final name = file.name.trim();
    final extension =
        (file.extension ?? (name.contains('.') ? name.split('.').last : ''))
            .toLowerCase();
    const allowedExtensions = {
      'pdf',
      'jpg',
      'jpeg',
      'png',
      'webp',
      'gif',
      'heic',
      'heif',
    };

    if (name.isEmpty || !allowedExtensions.contains(extension)) {
      return 'نوع الملف غير مدعوم. ارفع PDF أو صورة فقط';
    }
    if (file.size <= 0 || file.bytes == null || file.bytes!.isEmpty) {
      return 'تعذر قراءة الملف المحدد';
    }
    if (file.size > ApiService.maxInsuranceFileBytes ||
        file.bytes!.length > ApiService.maxInsuranceFileBytes) {
      return 'حجم الملف يجب ألا يتجاوز 10 ميجابايت';
    }
    return null;
  }

  Future<void> _pickAndUploadTruckInsurance(_TruckViewData truck) async {
    if (_insuranceUploadingTruckId != null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'jpg',
        'jpeg',
        'png',
        'webp',
        'gif',
        'heic',
        'heif',
      ],
      allowMultiple: false,
      withData: true,
    );

    if (!mounted || result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final validationError = _validateInsuranceFile(file);
    if (validationError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }

    _lastInsuranceTruckId = truck.id;
    _lastInsuranceBytes = file.bytes;
    _lastInsuranceFileName = file.name;
    await _uploadTruckInsurance(truck.id, file.name, file.bytes!);
  }

  Future<void> _uploadTruckInsurance(
    int truckId,
    String fileName,
    Uint8List bytes,
  ) async {
    setState(() {
      _insuranceUploadingTruckId = truckId;
      _insuranceUploadProgress = 0;
    });

    try {
      await ApiService.uploadTruckInsurance(
        truckId: truckId,
        fileName: fileName,
        bytes: bytes,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _insuranceUploadProgress = progress.clamp(0, 1).toDouble();
          });
        },
      );
      await _loadTrucks(silent: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم رفع تأمين الشاحنة بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل رفع تأمين الشاحنة: $e'),
          action: SnackBarAction(
            label: 'إعادة المحاولة',
            onPressed: () {
              final retryTruckId = _lastInsuranceTruckId;
              final retryFileName = _lastInsuranceFileName;
              final retryBytes = _lastInsuranceBytes;
              if (retryTruckId != null &&
                  retryFileName != null &&
                  retryBytes != null) {
                _uploadTruckInsurance(retryTruckId, retryFileName, retryBytes);
              }
            },
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _insuranceUploadingTruckId = null;
          _insuranceUploadProgress = 0;
        });
      }
    }
  }

  @override
  void dispose() {
    _statusRefreshTimer?.cancel();
    _plateNoController.dispose();
    _isthimaraNoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('إدارة الشاحنة')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('شاحناتي')),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: RefreshIndicator(
          onRefresh: () => _loadTrucks(silent: true),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _TruckSummaryHeader(
                truckCount: _trucks.length,
                maxTrucks: _maxTrucks,
                isRefreshing: _isRefreshing,
              ),
              if (_errorMessage != null)
                _TruckErrorBanner(
                  message: _errorMessage!,
                  onRetry: () => _loadTrucks(showInitialLoader: true),
                ),
              if (_trucks.isEmpty && _errorMessage == null)
                const _EmptyTruckState(),
              ..._trucks.map(
                (truck) => _TruckManagementCard(
                  truck: truck,
                  isActivating: _activatingTruckId == truck.id,
                  isUploadingInsurance: _insuranceUploadingTruckId == truck.id,
                  insuranceUploadProgress:
                      _insuranceUploadingTruckId == truck.id
                      ? _insuranceUploadProgress
                      : 0,
                  onSetActive: () => _setActiveTruck(truck),
                  onEdit: () => _startEditing(truck),
                  onUploadInsurance: () => _pickAndUploadTruckInsurance(truck),
                ),
              ),
              if (_editingTruckId == null && _trucks.length >= _maxTrucks)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'وصلت للحد الأعلى (5 شاحنات)',
                    style: TextStyle(color: Colors.red),
                    textAlign: TextAlign.start,
                  ),
                ),
              if (_editingTruckId != null || _trucks.length < _maxTrucks) ...[
                const SizedBox(height: 12),
                _TruckFormPanel(
                  isEditing: _editingTruckId != null,
                  child: _buildForm(),
                ),
                const SizedBox(height: 12),
                _buildActionButtons(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final saveButton = _isSaving
        ? const SizedBox(
            height: 52,
            child: Center(child: CircularProgressIndicator()),
          )
        : DarbakPrimaryButton(
            label: _editingTruckId == null ? 'إضافة شاحنة' : 'حفظ التعديلات',
            icon: Icons.save_outlined,
            onPressed: _saveTruck,
          );

    if (_editingTruckId == null) {
      return saveButton;
    }

    final cancelButton = SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: _isSaving ? null : _resetForm,
        child: const Text('إلغاء'),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 430) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [saveButton, const SizedBox(height: 10), cancelButton],
          );
        }
        return Row(
          children: [
            Expanded(child: saveButton),
            const SizedBox(width: 10),
            Expanded(child: cancelButton),
          ],
        );
      },
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _plateNoController,
            decoration: const InputDecoration(
              labelText: 'رقم اللوحة',
              hintText: 'مثال: س ج 1234',
            ),
            validator: (value) =>
                (value == null || value.isEmpty) ? 'رقم اللوحة مطلوب' : null,
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _isthimaraNoController,
            decoration: const InputDecoration(labelText: 'رخصة سير المركبة'),
            validator: (value) =>
                (value == null || value.isEmpty) ? 'رخصة سير المركبة مطلوب' : null,
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: 12),
          KeyedSubtree(
            key: ValueKey(
              'truck-cfg-${_editingTruckId ?? 'new'}-$_editCategoryId-$_editAxleCount',
            ),
            child: TruckConfigurationForm(
              key: _truckConfigFormKey,
              initialGroup: _editGroup,
              initialCategoryId: _editCategoryId,
              initialAxleCount: _editAxleCount,
              initialBodyTypeId: _editBodyTypeId,
              initialCapacityId: _editCapacityId,
              onChanged: (config) {
                setState(() => _truckConfiguration = config);
              },
            ),
          ),
        ],
      ),
    );
  }
}

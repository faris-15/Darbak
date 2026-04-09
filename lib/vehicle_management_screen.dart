import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import 'app_widgets.dart';
import 'api_service.dart';

/// شاشة إدارة بيانات الشاحنة للسائقين
class VehicleManagementScreen extends StatefulWidget {
  const VehicleManagementScreen({super.key});

  @override
  State<VehicleManagementScreen> createState() =>
      _VehicleManagementScreenState();
}

class _VehicleManagementScreenState extends State<VehicleManagementScreen> {
  Map<String, dynamic>? _truck;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _plateNoController;
  late TextEditingController _truckTypeController;
  late TextEditingController _capacityController;
  late TextEditingController _yearController;
  late TextEditingController _insuranceController;

  @override
  void initState() {
    super.initState();
    _loadTruck();
  }

  Future<void> _loadTruck() async {
    final prefs = await SharedPreferences.getInstance();
    final driverId = prefs.getInt('user_id');

    if (driverId == null) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لم يتم العثور على بيانات المستخدم')),
      );
      return;
    }

    try {
      final truck = await ApiService.getTruckByDriver(driverId);
      setState(() {
        _truck = truck;
        _plateNoController = TextEditingController(text: truck['plate_number']);
        _truckTypeController = TextEditingController(text: truck['truck_type']);
        _capacityController = TextEditingController(
          text: truck['capacity_kg'].toString(),
        );
        _yearController = TextEditingController(
          text: truck['manufacturing_year']?.toString() ?? '',
        );
        _insuranceController = TextEditingController(
          text: truck['insurance_expiry_date'] ?? '',
        );
        _isLoading = false;
      });
    } catch (e) {
      // Truck not found, user needs to register one
      setState(() {
        _truck = null;
        _isLoading = false;
        _plateNoController = TextEditingController();
        _truckTypeController = TextEditingController();
        _capacityController = TextEditingController();
        _yearController = TextEditingController();
        _insuranceController = TextEditingController();
      });
    }
  }

  Future<void> _saveTruck() async {
    if (!_formKey.currentState!.validate()) return;

    final prefs = await SharedPreferences.getInstance();
    final driverId = prefs.getInt('user_id');

    if (driverId == null) return;

    setState(() => _isSaving = true);
    try {
      if (_truck == null) {
        // Register new truck
        await ApiService.registerTruck({
          'user_id': driverId,
          'plate_number': _plateNoController.text.trim(),
          'truck_type': _truckTypeController.text.trim(),
          'capacity_kg': double.parse(_capacityController.text),
          'manufacturing_year': _yearController.text.isNotEmpty
              ? int.parse(_yearController.text)
              : null,
          'insurance_expiry_date': _insuranceController.text.trim(),
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم تسجيل الشاحنة بنجاح')));
      } else {
        // Update existing truck
        await ApiService.updateTruck(_truck!['id'], {
          'plate_number': _plateNoController.text.trim(),
          'truck_type': _truckTypeController.text.trim(),
          'capacity_kg': double.parse(_capacityController.text),
          'insurance_expiry_date': _insuranceController.text.trim(),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث بيانات الشاحنة بنجاح')),
        );
      }
      setState(() => _isEditing = false);
      await _loadTruck();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _plateNoController.dispose();
    _truckTypeController.dispose();
    _capacityController.dispose();
    _yearController.dispose();
    _insuranceController.dispose();
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
      appBar: AppBar(
        title: const Text('إدارة الشاحنة'),
        actions: [
          if (!_isEditing && _truck != null)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_truck == null)
                // Registration Mode
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      elevation: 0,
                      color: const Color(0xFFFFF3E0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Colors.orange),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.info, color: Colors.orange),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'يجب تسجيل بيانات شاحنتك قبل البدء في العمل',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'بيانات الشاحنة',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: DarbakColors.dark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildForm(),
                    const SizedBox(height: 20),
                    _isSaving
                        ? const Center(child: CircularProgressIndicator())
                        : DarbakPrimaryButton(
                            label: 'تسجيل الشاحنة',
                            icon: Icons.check_circle_outline,
                            onPressed: _saveTruck,
                          ),
                  ],
                )
              else
                // View Mode
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isEditing)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildForm(),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () =>
                                      setState(() => _isEditing = false),
                                  child: const Text('الغاء'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _isSaving
                                    ? const Center(
                                        child: CircularProgressIndicator(),
                                      )
                                    : DarbakPrimaryButton(
                                        label: 'حفظ',
                                        onPressed: _saveTruck,
                                      ),
                              ),
                            ],
                          ),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Verification Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  _truck!['verification_status'] == 'verified'
                                  ? Colors.green[100]
                                  : Colors.orange[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    _truck!['verification_status'] == 'verified'
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _truck!['verification_status'] == 'verified'
                                      ? Icons.check_circle
                                      : Icons.schedule,
                                  color:
                                      _truck!['verification_status'] ==
                                          'verified'
                                      ? Colors.green
                                      : Colors.orange,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _truck!['verification_status'] == 'verified'
                                      ? 'تم التحقق من الشاحنة'
                                      : 'في انتظار التحقق',
                                  style: TextStyle(
                                    color:
                                        _truck!['verification_status'] ==
                                            'verified'
                                        ? Colors.green
                                        : Colors.orange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildInfoCard(
                            icon: Icons.confirmation_number,
                            label: 'لوحة الترخيص',
                            value: _truck!['plate_no'],
                          ),
                          _buildInfoCard(
                            icon: Icons.directions_car,
                            label: 'نوع الشاحنة',
                            value: _truck!['truck_type'],
                          ),
                          _buildInfoCard(
                            icon: Icons.scale,
                            label: 'السعة',
                            value: '${_truck!['capacity_tons']} طن',
                          ),
                          if (_truck!['year_manufactured'] != null)
                            _buildInfoCard(
                              icon: Icons.calendar_today,
                              label: 'سنة الصنع',
                              value: _truck!['year_manufactured'].toString(),
                            ),
                          if (_truck!['insurance_expiry_date'] != null)
                            _buildInfoCard(
                              icon: Icons.security,
                              label: 'انتهاء التأمين',
                              value: _truck!['insurance_expiry_date'],
                            ),
                        ],
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
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
              labelText: 'لوحة الترخيص',
              hintText: 'مثال: س ج 1234',
            ),
            validator: (value) =>
                (value == null || value.isEmpty) ? 'لوحة الترخيص مطلوبة' : null,
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _truckTypeController,
            decoration: const InputDecoration(
              labelText: 'نوع الشاحنة',
              hintText: 'مثال: قلاب، نقل عام، تبريد',
            ),
            validator: (value) =>
                (value == null || value.isEmpty) ? 'نوع الشاحنة مطلوب' : null,
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _capacityController,
            decoration: const InputDecoration(
              labelText: 'السعة (بالطن)',
              hintText: '10.5',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value == null || value.isEmpty) return 'السعة مطلوبة';
              if (double.tryParse(value) == null) return 'أدخل قيمة صحيحة';
              return null;
            },
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _yearController,
            decoration: const InputDecoration(
              labelText: 'سنة الصنع (اختياري)',
              hintText: '2021',
            ),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _insuranceController,
            decoration: const InputDecoration(
              labelText: 'تاريخ انتهاء التأمين',
              hintText: '2025-12-31',
            ),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Card(
      elevation: 0,
      color: DarbakColors.cardBackground,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(icon, color: DarbakColors.primaryGreen),
        title: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: DarbakColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: DarbakColors.dark,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
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
  static const int _maxTrucks = 5;
  List<Map<String, dynamic>> _trucks = [];
  bool _isLoading = true;
  bool _isSaving = false;

  final _formKey = GlobalKey<FormState>();
  int? _editingTruckId;
  late TextEditingController _plateNoController;
  late TextEditingController _isthimaraNoController;
  late TextEditingController _truckTypeController;
  static const List<String> _saudiTruckTypes = [
    'دباب نقل',
    'وانيت',
    'دينا',
    'لوري',
    'سطحة',
    'تريلا جوانب',
    'تريلا ستارة',
    'برادة',
    'صهريج',
    'قلاب',
  ];
  String? _selectedTruckType;

  @override
  void initState() {
    super.initState();
    _plateNoController = TextEditingController();
    _isthimaraNoController = TextEditingController();
    _truckTypeController = TextEditingController();
    _loadTruck();
  }

  Future<void> _loadTruck() async {
    try {
      final trucksRaw = await ApiService.getMyTrucks();
      setState(() {
        _trucks = trucksRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _trucks = [];
        _isLoading = false;
      });
    }
  }

  void _resetForm() {
    _editingTruckId = null;
    _plateNoController.text = '';
    _isthimaraNoController.text = '';
    _truckTypeController.text = '';
    _selectedTruckType = null;
  }

  void _startEditing(Map<String, dynamic> truck) {
    setState(() {
      _editingTruckId = truck['id'] as int;
      _plateNoController.text = (truck['plate_number'] ?? '').toString();
      _isthimaraNoController.text = (truck['isthimara_no'] ?? '').toString();
      _truckTypeController.text = (truck['truck_type'] ?? '').toString();
      _selectedTruckType = _truckTypeController.text.isEmpty
          ? null
          : _truckTypeController.text;
    });
  }

  Future<void> _saveTruck() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      if (_editingTruckId == null) {
        await ApiService.registerTruck({
          'plate_number': _plateNoController.text.trim(),
          'isthimara_no': _isthimaraNoController.text.trim(),
          'truck_type': _selectedTruckType ?? _truckTypeController.text.trim(),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت إضافة الشاحنة بنجاح')),
        );
      } else {
        await ApiService.updateTruck(_editingTruckId!, {
          'plate_number': _plateNoController.text.trim(),
          'isthimara_no': _isthimaraNoController.text.trim(),
          'truck_type': _selectedTruckType ?? _truckTypeController.text.trim(),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث بيانات الشاحنة بنجاح')),
        );
      }
      _resetForm();
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
    _isthimaraNoController.dispose();
    _truckTypeController.dispose();
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
        title: const Text('شاحناتي'),
      ),
      floatingActionButton: _editingTruckId == null && _trucks.length < _maxTrucks
          ? FloatingActionButton.extended(
              backgroundColor: DarbakColors.primaryGreen,
              onPressed: () {
                setState(() {
                  _editingTruckId = null;
                });
                _resetForm();
              },
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('إضافة شاحنة', style: TextStyle(color: Colors.white)),
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DarbakColors.cardBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'شاحناتي: ${_trucks.length}/$_maxTrucks',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (_trucks.isNotEmpty)
                ..._trucks.map(
                  (truck) => Card(
                    elevation: 0,
                    color: DarbakColors.cardBackground,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text('${truck['truck_type']} - ${truck['plate_number']}'),
                      subtitle: Text('الاستمارة: ${truck['isthimara_no'] ?? '-'}'),
                      trailing: IconButton(
                        onPressed: () => _startEditing(truck),
                        icon: const Icon(Icons.edit, color: DarbakColors.primaryGreen),
                      ),
                    ),
                  ),
                ),
              if (_editingTruckId == null && _trucks.length >= _maxTrucks)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'وصلت للحد الأعلى (5 شاحنات)',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              if (_editingTruckId != null || _trucks.length < _maxTrucks) ...[
                const SizedBox(height: 12),
                _buildForm(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (_editingTruckId != null)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _resetForm,
                          child: const Text('إلغاء'),
                        ),
                      ),
                    if (_editingTruckId != null) const SizedBox(width: 10),
                    Expanded(
                      child: _isSaving
                          ? const Center(child: CircularProgressIndicator())
                          : DarbakPrimaryButton(
                              label: _editingTruckId == null ? 'إضافة شاحنة' : 'حفظ التعديلات',
                              icon: Icons.check_circle_outline,
                              onPressed: _saveTruck,
                            ),
                    ),
                  ],
                ),
              ],
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
            controller: _isthimaraNoController,
            decoration: const InputDecoration(
              labelText: 'رقم الاستمارة',
            ),
            validator: (value) =>
                (value == null || value.isEmpty) ? 'رقم الاستمارة مطلوب' : null,
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedTruckType,
            items: _saudiTruckTypes
                .map(
                  (type) => DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedTruckType = value;
                _truckTypeController.text = value ?? '';
              });
            },
            decoration: const InputDecoration(
              labelText: 'نوع الشاحنة',
            ),
            validator: (value) =>
                (value == null || value.isEmpty) ? 'نوع الشاحنة مطلوب' : null,
          ),
        ],
      ),
    );
  }

}

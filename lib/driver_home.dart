import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import 'app_widgets.dart';
import 'available_loads_screen.dart';
import 'trip_screens.dart';
import 'api_service.dart';
import 'auth_screens.dart';
import 'job_tracking_screen.dart';
import 'vehicle_management_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  int _currentIndex = 0;
  int _activeJobsCount = 0;
  bool _isRefreshingBadge = false;
  Timer? _badgePollingTimer;
  final _appLifecycleObserver = _DriverLifecycleObserver();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_appLifecycleObserver);
    _appLifecycleObserver.onResume = _refreshActiveJobsBadge;
    _refreshActiveJobsBadge();
    _badgePollingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _refreshActiveJobsBadge();
    });
  }

  Future<void> _refreshActiveJobsBadge() async {
    if (_isRefreshingBadge) return;
    _isRefreshingBadge = true;
    try {
      final shipments = await ApiService.getDriverActiveShipments();
      if (!mounted) return;
      setState(() {
        _activeJobsCount = shipments.length;
      });
    } catch (_) {
      // Keep previous badge state on intermittent errors.
    } finally {
      _isRefreshingBadge = false;
    }
  }

  @override
  void dispose() {
    _badgePollingTimer?.cancel();
    WidgetsBinding.instance.removeObserver(_appLifecycleObserver);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const AvailableLoadsScreen(), // سوق الشحنات - Professional UI
      DriverTripsScreen(
        onActiveJobsChanged: (count) {
          if (!mounted) return;
          setState(() {
            _activeJobsCount = count;
          });
        },
      ),
      const DriverMessagesScreen(), // الرسائل
      const DriverProfileScreen(), // الملف الشخصي
    ];

    final titles = ['سوق الشحنات', 'رحلاتي', 'الرسائل', 'حسابي'];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_currentIndex]),
        elevation: 0,
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
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping_outlined),
            activeIcon: Icon(Icons.local_shipping_rounded),
            label: 'السوق',
          ),
          BottomNavigationBarItem(
            icon: _TripsNavIcon(hasActiveJobs: _activeJobsCount > 0),
            activeIcon: Icon(Icons.route_rounded),
            label: 'رحلاتي',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            activeIcon: Icon(Icons.chat_bubble_rounded),
            label: 'الرسائل',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'حسابي',
          ),
        ],
      ),
    );
  }
}

// شاشات مؤقتة للتابات الأخرى (سنطوّرها في دفعات لاحقة)

class DriverTripsScreen extends StatefulWidget {
  final ValueChanged<int>? onActiveJobsChanged;

  const DriverTripsScreen({super.key, this.onActiveJobsChanged});

  @override
  State<DriverTripsScreen> createState() => _DriverTripsScreenState();
}

class _DriverTripsScreenState extends State<DriverTripsScreen> {
  static const Set<String> _activeStatuses = {
    'assigned',
    'at_pickup',
    'en_route',
    'at_dropoff',
  };

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _activeTrips = const [];
  List<Map<String, dynamic>> _historyTrips = const [];
  String _lastSignature = '';

  bool _isActiveStatus(String status) => _activeStatuses.contains(status);

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  String _buildSignature(
    List<Map<String, dynamic>> active,
    List<Map<String, dynamic>> history,
  ) {
    final parts = <String>[];
    for (final shipment in [...active, ...history]) {
      parts.add(
        '${shipment['id']}:${shipment['status']}:${shipment['updated_at'] ?? shipment['created_at'] ?? ''}',
      );
    }
    return parts.join('|');
  }

  Future<void> _loadTrips({bool forceLoadingState = false}) async {
    if (forceLoadingState && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final raw = await ApiService.getDriverShipments();
      final shipments = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final active = shipments
          .where((s) => _isActiveStatus((s['status'] ?? '').toString()))
          .toList();
      final history = shipments
          .where((s) => !_isActiveStatus((s['status'] ?? '').toString()))
          .toList();

      final nextSignature = _buildSignature(active, history);

      if (!mounted) return;

      final didChangeData = nextSignature != _lastSignature;
      if (didChangeData || _isLoading || _errorMessage != null) {
        setState(() {
          _activeTrips = active;
          _historyTrips = history;
          _isLoading = false;
          _errorMessage = null;
          _lastSignature = nextSignature;
        });
      } else if (_isLoading) {
        setState(() {
          _isLoading = false;
        });
      }

      widget.onActiveJobsChanged?.call(active.length);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'تعذر تحميل الرحلات.\n$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: DarbakColors.textSecondary),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _loadTrips(forceLoadingState: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
      );
    }

    if (_activeTrips.isEmpty && _historyTrips.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'لا توجد رحلات حالية',
                style: TextStyle(
                  fontSize: 16,
                  color: DarbakColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _loadTrips(forceLoadingState: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadTrips(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_activeTrips.isNotEmpty) ...[
            const Text(
              'الرحلات النشطة',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: DarbakColors.primaryGreen,
              ),
            ),
            const SizedBox(height: 10),
            ..._activeTrips.map(
              (shipment) => _ShipmentTripCard(
                shipment: shipment,
                isActive: true,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => JobTrackingScreen(
                        shipmentId: shipment['id'] as int,
                        shipmentData: shipment,
                      ),
                    ),
                  );
                  await _loadTrips(forceLoadingState: true);
                },
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (_historyTrips.isNotEmpty) ...[
            const Text(
              'السجل السابق',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 10),
            ..._historyTrips.map(
              (shipment) => _ShipmentTripCard(
                shipment: shipment,
                isActive: false,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ShipmentSummaryScreen(shipment: shipment),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TripsNavIcon extends StatelessWidget {
  final bool hasActiveJobs;

  const _TripsNavIcon({required this.hasActiveJobs});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.route_outlined),
        if (hasActiveJobs)
          Positioned(
            right: -1,
            top: -1,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: DarbakColors.primaryGreen,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}

class _ShipmentTripCard extends StatelessWidget {
  final Map<String, dynamic> shipment;
  final bool isActive;
  final VoidCallback onTap;

  const _ShipmentTripCard({
    required this.shipment,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isActive ? DarbakColors.primaryGreen : Colors.blueGrey;
    final cardBg = isActive
        ? DarbakColors.primaryGreen.withOpacity(0.08)
        : Colors.blueGrey.withOpacity(0.08);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderColor, width: 1.4),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          isActive ? Icons.local_shipping_rounded : Icons.receipt_long_rounded,
          color: borderColor,
        ),
        title: Text(
          'شحنة #${shipment['id']}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${shipment['pickup_address'] ?? '-'}  →  ${shipment['dropoff_address'] ?? '-'}\nالحالة: ${shipment['status'] ?? '-'}',
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: borderColor,
        ),
      ),
    );
  }
}

class ShipmentSummaryScreen extends StatelessWidget {
  final Map<String, dynamic> shipment;

  const ShipmentSummaryScreen({super.key, required this.shipment});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ملخص الرحلة')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.blueGrey.withOpacity(0.08),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.blueGrey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'شحنة #${shipment['id']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('الحالة النهائية: ${shipment['status'] ?? '-'}'),
                  Text('من: ${shipment['pickup_address'] ?? '-'}'),
                  Text('إلى: ${shipment['dropoff_address'] ?? '-'}'),
                  Text('الوزن: ${shipment['weight_kg'] ?? '-'} كجم'),
                  Text('السعر الأساسي: ${shipment['base_price'] ?? '-'} ر.س'),
                  Text('السعر النهائي: ${shipment['final_price'] ?? '-'} ر.س'),
                  Text('تاريخ الإنشاء: ${shipment['created_at'] ?? '-'}'),
                  Text(
                    'تاريخ التسليم: ${shipment['actual_delivery_date'] ?? 'غير متوفر'}',
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

class _DriverLifecycleObserver with WidgetsBindingObserver {
  VoidCallback? onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResume?.call();
    }
  }
}

class DriverMessagesScreen extends StatelessWidget {
  const DriverMessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          leading: const CircleAvatar(
            child: Icon(Icons.local_shipping_rounded),
          ),
          title: const Text('شركة دربك'),
          subtitle: const Text('حسب الشحنة رقم #0045'),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ChatScreen(
                  shipmentId: '0045',
                  otherUser: 'شركة دربك',
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _licenseController;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لم يتم العثور على بيانات المستخدم')),
      );
      return;
    }
    try {
      final user = await ApiService.getProfile(userId);
      setState(() {
        _user = user;
        _fullNameController = TextEditingController(text: user['full_name']);
        _emailController = TextEditingController(text: user['email'] ?? '');
        _phoneController = TextEditingController(text: user['phone']);
        _licenseController = TextEditingController(
          text: user['license_no'] ?? '',
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في تحميل البيانات: $e')));
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لم يتم العثور على بيانات المستخدم')),
      );
      setState(() => _isLoading = false);
      return;
    }
    try {
      await ApiService.updateProfile(userId, {
        'fullName': _fullNameController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
        'licenseNo': _licenseController.text,
        'commercialNo': _user?['commercial_no'],
      });
      setState(() => _isEditing = false);
      await _loadProfile();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تحديث البيانات بنجاح')));
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في التحديث: $e')));
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('تأكيد تسجيل الخروج'),
            content: const Text('هل تريد فعلاً تسجيل الخروج؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('تسجيل الخروج'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const ChooseRoleScreen(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تسجيل الخروج: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_user == null) {
      return const Scaffold(body: Center(child: Text('فشل في تحميل البيانات')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('الملف الشخصي للسائق'),
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
              CircleAvatar(
                radius: 46,
                backgroundColor: DarbakColors.lightBackground,
                child: const Icon(
                  Icons.person,
                  size: 48,
                  color: DarbakColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 12),
              if (_isEditing) ...[
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(labelText: 'الاسم الكامل'),
                  validator: (value) => value!.isEmpty ? 'مطلوب' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) => value!.isEmpty ? 'مطلوب' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'رقم الجوال'),
                  validator: (value) => value!.isEmpty ? 'مطلوب' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _licenseController,
                  decoration: const InputDecoration(labelText: 'رقم الرخصة'),
                ),
              ] else ...[
                Text(
                  _user!['full_name'],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'البريد الإلكتروني: ${_user!['email'] ?? ''}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: DarbakColors.textSecondary),
                ),
                const SizedBox(height: 6),
                Text(
                  'رقم الجوال: ${_user!['phone']}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: DarbakColors.textSecondary),
                ),
                const SizedBox(height: 6),
                if (_user!['license_no'] != null)
                  Text(
                    'رقم رخصة: ${_user!['license_no']}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: DarbakColors.textSecondary),
                  ),
              ],
              const SizedBox(height: 20),
              const DarbakSectionTitle(title: 'معلومات الشاحنة'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const VehicleManagementScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.local_shipping_rounded),
                label: const Text('إدارة شاحناتي'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: DarbakColors.primaryGreen),
                  foregroundColor: DarbakColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 16),
              const DarbakSectionTitle(title: 'المستندات'),
              const SizedBox(height: 8),
              _buildDocumentTile(
                'رخصة قيادة',
                isUploaded: _user!['document_path'] != null,
              ),
              _buildDocumentTile('تأمين الشاحنة', isUploaded: false),
              _buildDocumentTile('استمارة السيارة', isUploaded: true),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text('تسجيل الخروج'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[400],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentTile(String title, {required bool isUploaded}) {
    return Card(
      elevation: 0,
      color: DarbakColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(title),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isUploaded
                ? DarbakColors.successGreen
                : DarbakColors.primaryGreen,
            minimumSize: const Size(100, 36),
          ),
          onPressed: () {
            // لاحقًا: رفع ملف
          },
          child: Text(
            isUploaded ? 'مرفوع' : 'رفع',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

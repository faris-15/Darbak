import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import 'app_widgets.dart';
import 'available_loads_screen.dart';
import 'trip_screens.dart';
import 'api_service.dart';
import 'auth_screens.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const AvailableLoadsScreen(), // سوق الشحنات - Professional UI
      const DriverTripsScreen(), // رحلاتي (لاحقاً سنفصلها)
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
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping_outlined),
            activeIcon: Icon(Icons.local_shipping_rounded),
            label: 'السوق',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.route_outlined),
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

class DriverTripsScreen extends StatelessWidget {
  const DriverTripsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.route_outlined,
            size: 64,
            color: DarbakColors.textSecondary,
          ),
          SizedBox(height: 16),
          Text(
            'لا توجد رحلات نشطة حالياً',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: DarbakColors.dark,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'ستظهر هنا رحلاتك النشطة عند ربط النظام الخلفي',
            style: TextStyle(fontSize: 14, color: DarbakColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
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
              _buildInfoRow(
                'نوع الشاحنة',
                'قلاب 10 طن',
              ), // TODO: Add to user model
              _buildInfoRow('موديل', '2021'),
              _buildInfoRow('لوحة', 'س ج 1234'),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: DarbakColors.textSecondary),
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
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

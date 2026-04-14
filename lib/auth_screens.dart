import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'app_theme.dart';
import 'app_widgets.dart';
import 'driver_home.dart';
import 'shipper_home.dart';
import 'api_service.dart';

/// شاشة السبلاتش (الشعار)
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Ensure minimum 4 seconds, but since animation completed, navigate
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _navigateToLogin(context);
          }
        });
      }
    });
    // Also set a minimum delay of 5 seconds in case animation is short
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && !_controller.isCompleted) {
        _controller.stop();
        _navigateToLogin(context);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _navigateToLogin(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    final savedRole = prefs.getString('user_role');

    Widget target = const LoginScreen();

    if (isLoggedIn && savedRole != null) {
      if (savedRole == 'driver') {
        target = const DriverHomeScreen();
      } else if (savedRole == 'shipper') {
        target = const ShipperHomeScreen();
      } else {
        target = const LoginScreen();
      }
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => target,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double animationSize = screenWidth * 0.6;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Lottie animation
              LottieBuilder.asset(
                'assets/animations/animation.json',
                controller: _controller,
                repeat: false,
                width: animationSize,
                height: animationSize,
                onLoaded: (composition) {
                  _controller.duration = composition.duration;
                  _controller.forward();
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'D A R B A K',
                style: TextStyle(
                  fontSize: 24,
                  letterSpacing: 6,
                  fontWeight: FontWeight.w700,
                  color: DarbakColors.dark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'دربك... خضر',
                style: TextStyle(
                  fontSize: 16,
                  color: DarbakColors.primaryGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// اختيار نوع الحساب (سائق / شاحن)
class ChooseRoleScreen extends StatefulWidget {
  const ChooseRoleScreen({super.key});

  @override
  State<ChooseRoleScreen> createState() => _ChooseRoleScreenState();
}

class _ChooseRoleScreenState extends State<ChooseRoleScreen> {
  String _selectedRole = 'driver'; // driver or shipper

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('اختر نوع حسابك'),
        leading: const SizedBox(),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DarbakSectionTitle(
                title: 'اختر نوع حسابك',
                subtitle: 'حدّد دورك لتخصيص تجربتك في دربك',
              ),
              const SizedBox(height: 24),
              _buildRoleCard(
                title: 'سائق',
                description:
                    'أنت مالك شاحنة أو سائق تبحث عن شحنات تشارك في المناقصات عليها للحصول على أفضل سعر عادل.',
                bullets: const [
                  'تصفّح الشحنات المتاحة',
                  'تقديم العروض',
                  'متابعة حالة الرحلة حتى التسليم',
                ],
                icon: Icons.local_shipping_rounded,
                value: 'driver',
              ),
              const SizedBox(height: 16),
              _buildRoleCard(
                title: 'شركة/صاحب شحنة',
                description:
                    'أنت شركة أو جهة تمتلك بضائع وتريد طرحها في مناقصات نقل لاختيار أفضل سائق عرضاً والتزاماً.',
                bullets: const [
                  'نشر شحنات جديدة',
                  'مراجعة العروض',
                  'إدارة العقود والرحلات',
                ],
                icon: Icons.business_rounded,
                value: 'shipper',
              ),
              const Spacer(),
              DarbakPrimaryButton(
                label: 'متابعة',
                icon: Icons.arrow_back_ios_new_rounded,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RegistrationScreen(role: _selectedRole),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'هل لديك حساب بالفعل؟ تسجيل الدخول',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String title,
    required String description,
    required List<String> bullets,
    required IconData icon,
    required String value,
  }) {
    final bool isSelected = _selectedRole == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRole = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? DarbakColors.primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? DarbakColors.primaryGreen : DarbakColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    color: isSelected
                        ? Colors.white
                        : DarbakColors.primaryGreen,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : DarbakColors.dark,
                    ),
                  ),
                  const Spacer(),
                  if (isSelected)
                    const Icon(Icons.check_circle, color: Colors.white),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: isSelected
                      ? Colors.white70
                      : DarbakColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: bullets
                    .map(
                      (b) => Chip(
                        label: Text(
                          b,
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected
                                ? DarbakColors.primaryGreen
                                : DarbakColors.dark,
                          ),
                        ),
                        backgroundColor: isSelected
                            ? Colors.white
                            : DarbakColors.cardBackground,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 0,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// صفحة تسجيل الدخول
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneEmailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _phoneEmailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.login(
        _phoneEmailController.text.trim(),
        _passwordController.text.trim(),
      );
      final user = data['user'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);
      await prefs.setInt('user_id', user['id']);
      await prefs.setString('user_role', user['role']);
      await prefs.setString('user_email', user['email'] ?? '');
      await prefs.setString('user_name', user['full_name'] ?? '');

      if (user['role'] == 'driver') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
        );
      } else if (user['role'] == 'shipper') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ShipperHomeScreen()),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('دور المستخدم غير معروف')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل الدخول')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                    Image.asset('lib/assets/assets-logo.jpeg', height: 180),
                    const SizedBox(height: 12),
                    const Text(
                      'تسجيل الدخول',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: DarbakColors.dark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'رقم الجوال / البريد الإلكتروني',
                      style: TextStyle(
                        fontSize: 13,
                        color: DarbakColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              DarbakAuthTextField(
                hint: '05xxxxxxxx أو example@mail.com',
                controller: _phoneEmailController,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 16),
              Directionality(
                textDirection: TextDirection.rtl,
                child: TextField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    hintText: 'كلمة المرور',
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      color: DarbakColors.primaryGreen,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscure = !_obscure;
                        });
                      },
                    ),
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    // لاحقًا: شاشة نسيت كلمة المرور
                  },
                  child: const Text(
                    'نسيت كلمة المرور؟ استعادة كلمة المرور',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : DarbakPrimaryButton(
                      label: 'متابعة',
                      icon: Icons.arrow_back_ios_new_rounded,
                      onPressed: _login,
                    ),
              const SizedBox(height: 16),
              const SizedBox(height: 16),
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    const Text(
                      'ليس لديك حساب؟ ',
                      style: TextStyle(
                        fontSize: 13,
                        color: DarbakColors.textSecondary,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushNamed('/roleSelection');
                      },
                      child: const Text(
                        'سجل الآن',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// شاشة التسجيل متعددة الخطوات
class RegistrationScreen extends StatefulWidget {
  final String role;

  const RegistrationScreen({super.key, required this.role});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  final _licenseNoController = TextEditingController();
  final _commercialNoController = TextEditingController();
  final _issueDateController = TextEditingController();
  final _expiryDateController = TextEditingController();

  String? _documentPath;
  bool _loading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _licenseNoController.dispose();
    _commercialNoController.dispose();
    _issueDateController.dispose();
    _expiryDateController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _documentPath = result.files.first.path;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم اختيار الملف بنجاح')));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('لم يتم اختيار أي ملف')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في اختيار الملف: $e')));
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final data = {
        'fullName': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'password': _passwordController.text.trim(),
        'role': widget.role,
        'licenseNo': widget.role == 'driver'
            ? _licenseNoController.text.trim()
            : null,
        'commercialNo': widget.role == 'shipper'
            ? _commercialNoController.text.trim()
            : null,
        'documentPath': _documentPath,
        'issueDate': widget.role == 'driver'
            ? _issueDateController.text.trim()
            : null,
        'expiryDate': widget.role == 'driver'
            ? _expiryDateController.text.trim()
            : null,
      };

      await ApiService.register(data);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم التسجيل بنجاح! انتظر التحقق من الأدمن'),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إنشاء حساب جديد')),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep < 2) {
            setState(() => _currentStep++);
          } else {
            _register();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep--);
          }
        },
        steps: [
          Step(
            title: const Text('البيانات الأساسية'),
            content: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(
                      labelText: 'الاسم الكامل',
                    ),
                    validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                  ),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                  ),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(labelText: 'رقم الجوال'),
                    validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                  ),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'كلمة المرور'),
                    obscureText: true,
                    validator: (v) =>
                        v!.length < 6 ? 'يجب أن تكون 6 أحرف على الأقل' : null,
                  ),
                ],
              ),
            ),
          ),
          Step(
            title: const Text('بيانات إضافية'),
            content: Column(
              children: [
                if (widget.role == 'driver') ...[
                  TextFormField(
                    controller: _licenseNoController,
                    decoration: const InputDecoration(
                      labelText: 'رقم رخصة القيادة',
                    ),
                  ),
                  TextFormField(
                    controller: _issueDateController,
                    decoration: const InputDecoration(
                      labelText: 'تاريخ الإصدار',
                    ),
                    readOnly: true,
                    onTap: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(1900),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        _issueDateController.text = picked.toIso8601String().split('T')[0];
                      }
                    },
                  ),
                  TextFormField(
                    controller: _expiryDateController,
                    decoration: const InputDecoration(
                      labelText: 'تاريخ الانتهاء',
                    ),
                    readOnly: true,
                    onTap: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(1900),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        _expiryDateController.text = picked.toIso8601String().split('T')[0];
                      }
                    },
                  ),
                ],
                if (widget.role == 'shipper')
                  TextFormField(
                    controller: _commercialNoController,
                    decoration: const InputDecoration(
                      labelText: 'رقم السجل التجاري',
                    ),
                  ),
              ],
            ),
          ),
          Step(
            title: const Text('رفع الوثائق'),
            content: Column(
              children: [
                Text('يرجى رفع ${widget.role == 'driver' ? 'رخصة القيادة' : 'السجل التجاري'} (PDF)'),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _pickDocument,
                  icon: const Icon(Icons.upload_file),
                  label: Text(widget.role == 'driver' ? 'رفع رخصة القيادة' : 'رفع السجل التجاري'),
                ),
                if (_documentPath != null) Text('تم اختيار: $_documentPath'),
                const SizedBox(height: 16),
                _loading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _register,
                        child: const Text('إنشاء الحساب'),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// شاشات التسجيل وتسجيل الدخول ونسيت كلمة المرور.
// إعادة التعيين عبر Firebase فقط؛ عند 401 من الخادم مع بريد إلكتروني يُجرّب تسجيل دخول Firebase ثم POST /auth/login-firebase.

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_theme.dart';
import 'app_widgets.dart';
import 'truck_classification/truck_classification_models.dart';
import 'truck_classification/widgets/truck_configuration_form.dart';
import 'driver_home.dart';
import 'shipper_home.dart';
import 'api_service.dart';
import 'services/profile_repository.dart';
import 'utils/auth_messages.dart';

/// مقاسات موحّدة لواجهات المصادقة (تسجيل الدخول، اختيار الدور، التسجيل).
abstract final class DarbakAuthLayout {
  DarbakAuthLayout._();

  /// عرض زر «متابعة» كنسبة من عرض المحتوى (هوامش يمنى ويسرى مثل التصميم).
  static const double primaryButtonWidthFactor = 0.82;
}

/// شاشة السبلاتش (الشعار)
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.completeImmediatelyForTest = false});

  /// Test seam: skip Lottie and navigate on the first frame.
  final bool completeImmediatelyForTest;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  @override
  void initState() {
    super.initState();
    if (widget.completeImmediatelyForTest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _navigateToLogin(context);
      });
      return;
    }
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          _navigateToLogin(context);
        }
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
    double animationSize = screenWidth * 1;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Lottie.asset(
          'assets/animations/animation.json',
          controller: _controller,
          onLoaded: (composition) {
            _controller
              ..duration = composition.duration
              ..forward();
          },
          width: animationSize,
          fit: BoxFit.contain,
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
                widthFactor: DarbakAuthLayout.primaryButtonWidthFactor,
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
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
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
  const LoginScreen({super.key, this.firebaseSignInOverride});

  /// Test seam: return Firebase ID token without calling FirebaseAuth.
  final Future<String?> Function(String email, String password)?
      firebaseSignInOverride;

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

  Future<void> _completeLogin(Map<String, dynamic> data) async {
    final user = data['user'];
    final token = data['token']?.toString() ?? '';
    if (token.isEmpty) {
      throw DarbakException('لم يتم استلام رمز الدخول من الخادم');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await prefs.setBool('is_logged_in', true);
    await prefs.setInt('user_id', user['id']);
    await prefs.setString('user_role', user['role']);
    await prefs.setString('user_email', user['email'] ?? '');
    await prefs.setString('user_name', user['full_name'] ?? '');
    await prefs.setString('auth_token', token);
    await ProfileRepository.cacheProfile(Map<String, dynamic>.from(user));

    if (!mounted) return;
    if (user['role'] == 'driver') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
      );
    } else if (user['role'] == 'shipper') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ShipperHomeScreen()),
      );
    } else if (user['role'] == 'admin') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ShipperHomeScreen()),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('دور المستخدم غير معروف')));
    }
  }

  Future<void> _login() async {
    setState(() => _loading = true);
    final identifier = _phoneEmailController.text.trim();
    final password = _passwordController.text.trim();
    try {
      final data = await ApiService.login(identifier, password);
      await _completeLogin(data);
    } catch (e) {
      final isEmail = identifier.contains('@');
      if (e is DarbakException && isEmail && e.httpStatus == 401) {
        try {
          final override = widget.firebaseSignInOverride;
          final idToken = override != null
              ? await override(identifier, password)
              : await FirebaseAuth.instance
                  .signInWithEmailAndPassword(
                    email: identifier,
                    password: password,
                  )
                  .then((cred) => cred.user?.getIdToken());
          if (idToken == null || idToken.isEmpty) {
            throw DarbakException('تعذّر إكمال تسجيل الدخول');
          }
          final data = await ApiService.loginWithFirebaseIdToken(
            idToken,
            password: password,
          );
          await _completeLogin(data);
        } catch (fe) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(firebaseLoginMessage(fe))));
        }
      } else {
        if (!mounted) return;
        final msg = e is DarbakException
            ? stripThirdPartyFromAuthMessage(e.message)
            : stripThirdPartyFromAuthMessage(e.toString());
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل الدخول'),
        automaticallyImplyLeading: false,
      ),
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
                    Image.asset(
                      'lib/assets/assets-logo.jpeg',
                      width: MediaQuery.of(context).size.width * 0.43,
                      fit: BoxFit.contain,
                    ),
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
                  textAlign: TextAlign.start,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ForgotPasswordScreen(),
                      ),
                    );
                  },
                  child: const Text.rich(
                    TextSpan(
                      text: 'نسيت كلمة المرور؟ ',
                      children: [
                        TextSpan(
                          text: 'استعادة كلمة المرور',
                          style: TextStyle(
                            color: DarbakColors.primaryGreen,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: DarbakColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : DarbakPrimaryButton(
                      label: 'متابعة',
                      widthFactor: DarbakAuthLayout.primaryButtonWidthFactor,
                      onPressed: _login,
                    ),
              const SizedBox(height: 16),
              const SizedBox(height: 16),
              Center(
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'ليس لديك حساب؟',
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
                          style: TextStyle(
                            fontSize: 13,
                            color: DarbakColors.primaryGreen,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
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

  /// Test seam: bypass platform file picker in widget tests.
  final Future<({String path, String name})?> Function()? pickDocumentOverride;

  /// Test seam: skip Firebase account linking after MySQL registration.
  final Future<void> Function(String email, String password)?
      linkFirebaseOverride;

  /// Test seam: pre-set uploaded document path (skips file picker).
  final String? documentPathForTest;

  /// Test seam: jump directly to a registration step in widget tests.
  final int? initialStepForTest;

  /// Test seam: override the registration API call (avoids real file I/O).
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> data)?
      registerOverride;

  const RegistrationScreen({
    super.key,
    required this.role,
    this.pickDocumentOverride,
    this.linkFirebaseOverride,
    this.documentPathForTest,
    this.initialStepForTest,
    this.registerOverride,
  });

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
  final _plateNumberController = TextEditingController();
  final _isthimaraNoController = TextEditingController();
  final _truckConfigFormKey = GlobalKey<TruckConfigurationFormState>();
  TruckConfiguration? _truckConfiguration;

  String? _documentPath;
  String? _documentFileName;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.documentPathForTest != null) {
      _documentPath = widget.documentPathForTest;
      _documentFileName = widget.documentPathForTest!.split('/').last;
    }
    if (widget.initialStepForTest != null) {
      _currentStep = widget.initialStepForTest!.clamp(0, 2);
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _licenseNoController.dispose();
    _commercialNoController.dispose();
    _issueDateController.dispose();
    _expiryDateController.dispose();
    _plateNumberController.dispose();
    _isthimaraNoController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    try {
      final override = widget.pickDocumentOverride;
      if (override != null) {
        final picked = await override();
        if (picked == null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('لم يتم اختيار أي ملف')));
          return;
        }
        setState(() {
          _documentPath = picked.path;
          _documentFileName = picked.name;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم اختيار الملف بنجاح')));
        return;
      }

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _documentPath = result.files.first.path;
          _documentFileName = result.files.first.name;
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

  /// بعد نجاح التسجيل في MySQL ينشئ نفس البريف في Firebase حتى تعمل `sendPasswordResetEmail`.
  Future<void> _linkFirebaseAfterMysqlRegister(
    String email,
    String password,
  ) async {
    final override = widget.linkFirebaseOverride;
    if (override != null) {
      await override(email, password);
      return;
    }
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        return;
      } on FirebaseAuthException catch (fe) {
        if (fe.code == 'email-already-in-use') return;
        final looksLikeNetwork =
            fe.code == 'network-request-failed' ||
            (fe.message?.toLowerCase().contains('network') ?? false);
        if (attempt == 0 && looksLikeNetwork) {
          await Future<void>.delayed(const Duration(seconds: 2));
          continue;
        }
        if (!mounted) return;
        final msg = looksLikeNetwork
            ? 'تعذّر الاتصال بالإنترنت. تأكد من الشبكة ثم أعد المحاولة.'
            : 'تم إنشاء الحساب. إن واجهت مشكلة في تسجيل الدخول لاحقاً، جرّب «نسيت كلمة المرور» أو تواصل مع الدعم.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
        return;
      }
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _currentStep = 0);
      return;
    }

    if (widget.role == 'driver') {
      final truckConfigValid =
          _truckConfigFormKey.currentState?.validateAll() ?? false;
      if (_licenseNoController.text.isEmpty ||
          _issueDateController.text.isEmpty ||
          _expiryDateController.text.isEmpty ||
          !truckConfigValid ||
          _truckConfiguration == null ||
          _plateNumberController.text.isEmpty ||
          _isthimaraNoController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى إكمال جميع بيانات السائق والشاحنة'),
          ),
        );
        setState(() => _currentStep = 1);
        return;
      }
    } else if (widget.role == 'shipper') {
      if (_commercialNoController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى إدخال رقم السجل التجاري')),
        );
        setState(() => _currentStep = 1);
        return;
      }
    }

    if (_documentPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى رفع الوثيقة المطلوبة')),
      );
      setState(() => _currentStep = 2);
      return;
    }

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
        if (widget.role == 'driver' && _truckConfiguration != null)
          ..._truckConfiguration!.toApiPayload(),
        'plateNumber': widget.role == 'driver'
            ? _plateNumberController.text.trim()
            : null,
        'isthimaraNo': widget.role == 'driver'
            ? _isthimaraNoController.text.trim()
            : null,
      };

      if (widget.registerOverride != null) {
        await widget.registerOverride!(data);
      } else {
        await ApiService.register(data);
      }
      await _linkFirebaseAfterMysqlRegister(
        _emailController.text.trim().toLowerCase(),
        _passwordController.text.trim(),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم التسجيل بنجاح! انتظر التحقق من الأدارة'),
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
        controlsBuilder: (context, details) {
          final isLast = _currentStep >= 2;
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_loading && isLast)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else
                  DarbakPrimaryButton(
                    label: isLast ? 'إنشاء الحساب' : 'متابعة',
                    widthFactor: DarbakAuthLayout.primaryButtonWidthFactor,
                    onPressed: _loading ? null : details.onStepContinue,
                  ),
                if (_currentStep > 0) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: details.onStepCancel,
                      child: const Text('السابق'),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('البيانات الأساسية'),
            content: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 2.3),
                  TextFormField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(
                      labelText: 'الاسم الكامل',
                    ),
                    validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: 13),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: 13),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(labelText: 'رقم الجوال'),
                    validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: 13),
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
                  const SizedBox(height: 8),
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
                        _issueDateController.text = picked
                            .toIso8601String()
                            .split('T')[0];
                      }
                    },
                  ),
                  const SizedBox(height: 8),
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
                        _expiryDateController.text = picked
                            .toIso8601String()
                            .split('T')[0];
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: TruckConfigurationForm(
                      key: _truckConfigFormKey,
                      onChanged: (config) {
                        setState(() => _truckConfiguration = config);
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _plateNumberController,
                    decoration: const InputDecoration(labelText: 'رقم اللوحة'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _isthimaraNoController,
                    decoration: const InputDecoration(
                      labelText: 'رخصة سير المركبة',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                  ),
                ],
                if (widget.role == 'shipper') ...[
                  const SizedBox(height: 0),
                  TextFormField(
                    controller: _commercialNoController,
                    decoration: const InputDecoration(
                      labelText: 'رقم السجل التجاري',
                    ),
                  ),
                ],
              ],
            ),
          ),
          Step(
            title: const Text('رفع الوثائق'),
            content: Column(
              children: [
                Text(
                  'يرجى رفع ${widget.role == 'driver' ? 'رخصة القيادة' : 'السجل التجاري'} (PDF/Image)',
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _pickDocument,
                  icon: const Icon(Icons.upload_file),
                  label: Text(
                    widget.role == 'driver'
                        ? 'رفع رخصة القيادة'
                        : 'رفع السجل التجاري',
                  ),
                ),
                if (_documentPath != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: DarbakColors.successGreen,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Chip(
                          avatar: const Icon(Icons.attach_file, size: 18),
                          label: Text(
                            _documentFileName ?? 'تم اختيار الملف',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// شاشة «نسيت كلمة المرور»: الطلب يمر عبر الخادم (التحقق من Firebase ثم sendOobCode) لتسجيل الرد وتجنب نجاح وهمي.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final email = _emailController.text.trim().toLowerCase();
    try {
      await ApiService.requestFirebasePasswordReset(email);
      if (kDebugMode) {
        debugPrint('[ForgotPassword] طلب إعادة التعيين عبر الخادم نجح: $email');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('سيصلك بريد لإعادة تعيين كلمة المرور.')),
      );
      Navigator.of(context).pop();
    } on DarbakException catch (e) {
      if (forgotPasswordUseFirebaseClientFallback(e)) {
        try {
          await FirebaseAuth.instance.setLanguageCode('ar');
          await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
          if (kDebugMode) {
            debugPrint(
              '[ForgotPassword] تم الإرسال عبر Firebase من التطبيق (احتياطي)',
            );
          }
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('سيصلك بريد لإعادة تعيين كلمة المرور.'),
            ),
          );
          Navigator.of(context).pop();
        } catch (fe) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(userFacingForgotPasswordMessage(fe))),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingForgotPasswordMessage(e))),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingForgotPasswordMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('نسيت كلمة المرور')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('أدخل بريدك المسجل.'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.isEmpty) return 'يرجى إدخال البريد';
                  if (!t.contains('@')) return 'بريد غير صالح';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _submit,
                      child: const Text('إرسال رابط إعادة التعيين'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

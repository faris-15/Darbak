import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'app_widgets.dart';
import 'driver_home.dart';
import 'shipper_home.dart';


/// شاشة السبلاتش (الشعار)
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Future.delayed(const Duration(seconds: 2), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ChooseRoleScreen()),
      );
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // لاحقًا: استبدلي الأيقونة بصورة اللوقو
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: DarbakColors.lightBackground,
                ),
                child: const Icon(
                  Icons.local_shipping_rounded,
                  color: DarbakColors.primaryGreen,
                  size: 80,
                ),
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
                icon: Icons.domain_rounded,
                value: 'shipper',
              ),
              const Spacer(),
              DarbakPrimaryButton(
                label: 'متابعة',
                icon: Icons.arrow_back_ios_new_rounded,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LoginScreen(
                        role: _selectedRole,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
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
            color: isSelected
                ? DarbakColors.primaryGreen
                : DarbakColors.border,
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
                    color: isSelected ? Colors.white : DarbakColors.primaryGreen,
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
                    const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: isSelected ? Colors.white70 : DarbakColors.textSecondary,
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
  final String role; // 'driver' or 'shipper'

  const LoginScreen({super.key, required this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneEmailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _phoneEmailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String roleLabel =
        widget.role == 'driver' ? 'سائق' : 'شركة/صاحب شحنة';

    return Scaffold(
      appBar: AppBar(
        title: Text('تسجيل الدخول - $roleLabel'),
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
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: DarbakColors.lightBackground,
                      ),
                      child: const Icon(
                        Icons.local_shipping_rounded,
                        color: DarbakColors.primaryGreen,
                        size: 48,
                      ),
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
                    Text(
                      'رقم الجوال / البريد الإلكتروني',
                      style: const TextStyle(
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
              DarbakPrimaryButton(
                label: 'متابعة',
                icon: Icons.arrow_back_ios_new_rounded,



               onPressed: () {
  if (widget.role == 'driver') {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
    );
  } else {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ShipperHomeScreen()),
    );
  }
},




              ),
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
                        // لاحقًا: شاشة إنشاء حساب
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

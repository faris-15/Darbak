import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'shipment_screens.dart';

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
      const DriverShipmentsMarketScreen(), // سوق الشحنات
      const DriverTripsScreen(),           // رحلاتي (لاحقاً سنفصلها)
      const DriverMessagesScreen(),        // الرسائل
      const DriverProfileScreen(),         // الملف الشخصي
    ];

    final titles = [
      'سوق الشحنات',
      'رحلاتي',
      'الرسائل',
      'حسابي',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_currentIndex]),
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
        Icon(Icons.route_outlined, size: 64, color: DarbakColors.textSecondary),
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
          style: TextStyle(
            fontSize: 14,
            color: DarbakColors.textSecondary,
          ),
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
    return const Center(
      child: Text(
        'هنا قائمة المحادثات بين السائقين والشاحنين (سيتم تصميمها لاحقاً).',
        textAlign: TextAlign.center,
      ),
    );
  }
}

class DriverProfileScreen extends StatelessWidget {
  const DriverProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'هنا ملف السائق الشخصي والوثائق والتقييمات (سيتم تصميمها لاحقاً).',
        textAlign: TextAlign.center,
      ),
    );
  }
}

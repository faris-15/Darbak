import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'app_widgets.dart';
import 'shipment_screens.dart';
import 'trip_screens.dart';

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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          leading: const CircleAvatar(child: Icon(Icons.local_shipping_rounded)),
          title: const Text('شركة دربك'),
          subtitle: const Text('حسب الشحنة رقم #0045'),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const ChatScreen(shipmentId: '0045', otherUser: 'شركة دربك'),
            ));
          },
        ),
      ],
    );
  }
}

class DriverProfileScreen extends StatelessWidget {
  const DriverProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الملف الشخصي للسائق')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CircleAvatar(
              radius: 46,
              backgroundColor: DarbakColors.lightBackground,
              child: const Icon(Icons.person, size: 48, color: DarbakColors.primaryGreen),
            ),
            const SizedBox(height: 12),
            const Text('محمد العتيبي', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('سائق / رقم رخصة: 123456789', textAlign: TextAlign.center, style: TextStyle(color: DarbakColors.textSecondary)),
            const SizedBox(height: 20),
            const DarbakSectionTitle(title: 'معلومات الشاحنة'),
            const SizedBox(height: 8),
            _buildInfoRow('نوع الشاحنة', 'قلاب 10 طن'),
            _buildInfoRow('موديل', '2021'),
            _buildInfoRow('لوحة', 'س ج 1234'),
            const SizedBox(height: 16),
            const DarbakSectionTitle(title: 'المستندات'),
            const SizedBox(height: 8),
            _buildDocumentTile('رخصة قيادة', isUploaded: true),
            _buildDocumentTile('تأمين الشاحنة', isUploaded: false),
            _buildDocumentTile('استمارة السيارة', isUploaded: true),
            const SizedBox(height: 24),
            DarbakOutlinedButton(
              label: 'تحديث البيانات',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('قريباً: واجهة التعديل')));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: DarbakColors.textSecondary))),
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
            backgroundColor: isUploaded ? DarbakColors.successGreen : DarbakColors.primaryGreen,
            minimumSize: const Size(100, 36),
          ),
          onPressed: () {
            // لاحقًا: رفع ملف
          },
          child: Text(isUploaded ? 'مرفوع' : 'رفع', style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}

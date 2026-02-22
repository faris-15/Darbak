import 'package:flutter/material.dart';

/// شاشة اختيار موقع التحميل
class PickupLocationPickerScreen extends StatelessWidget {
  const PickupLocationPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تحديد موقع التحميل')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_on, size: 100, color: Colors.green),
            const SizedBox(height: 32),
            const Text(
              'موقع التحميل (مثال)',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'جدة - حي النسيم',
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              onPressed: () {
                Navigator.pop(context, {
                  'lat': 21.543333,
                  'lng': 39.172779,
                  'mapsUrl':
                      'https://www.google.com/maps/search/?api=1&query=21.543333,39.172779',
                });
              },
              child: const Text(
                'تأكيد موقع التحميل',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// شاشة اختيار موقع التسليم
class DropoffLocationPickerScreen extends StatelessWidget {
  const DropoffLocationPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تحديد موقع التسليم')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_on, size: 100, color: Colors.orange),
            const SizedBox(height: 32),
            const Text(
              'موقع التسليم (مثال)',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'الرياض - حي الملقا',
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              onPressed: () {
                Navigator.pop(context, {
                  'lat': 24.713552,
                  'lng': 46.675297,
                  'mapsUrl':
                      'https://www.google.com/maps/search/?api=1&query=24.713552,46.675297',
                });
              },
              child: const Text(
                'تأكيد موقع التسليم',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'app_theme.dart';

/// شاشة سوق الشحنات للسائق (Empty State جاهز للباك إند)
class DriverShipmentsMarketScreen extends StatelessWidget {
  const DriverShipmentsMarketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // شريط البحث والفلتر (جاهز للباك إند)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    // لاحقاً: API call لفلترة الشحنات
                  },
                  icon: const Icon(Icons.filter_list_rounded),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'ابحث عن شحنة...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: DarbakColors.lightBackground,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: const BorderSide(color: Colors.transparent),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: const BorderSide(color: Colors.transparent),
                        ),
                      ),
                      // لاحقاً: onChanged → API search
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_shipping_outlined, 
                       size: 64, color: DarbakColors.textSecondary),
                  SizedBox(height: 16),
                  Text(
                    'لا توجد شحنات متاحة حالياً',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: DarbakColors.dark,
                    ),
                  ),
                  SizedBox(height: 8),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'ستظهر هنا شحنات السوق عند ربط النظام الخلفي\nFutureBuilder/ListView.builder مع API',
                      style: TextStyle(
                        fontSize: 14,
                        color: DarbakColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
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

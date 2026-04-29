import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'api_service.dart';
import 'bidding_room_screen.dart';

class AppColors {
  static const primary = Color(0xff168A57);
  static const primaryDark = Color(0xff0E6D44);
  static const background = Color(0xffF5F7FA);
  static const card = Colors.white;
  static const border = Color(0xffE6E9EF);
  static const text = Color(0xff1B1F24);
  static const subText = Color(0xff6B7280);
  static const danger = Color(0xffD94C4C);
  static const orange = Color(0xffF59E0B);
  static const lightGreen = Color(0xffE9F8F0);
}

class AvailableLoadsScreen extends StatefulWidget {
  const AvailableLoadsScreen({super.key});

  @override
  State<AvailableLoadsScreen> createState() => _AvailableLoadsScreenState();
}

class _AvailableLoadsScreenState extends State<AvailableLoadsScreen> {
  List<dynamic> shipments = [];
  bool isLoading = true;
  String errorMessage = '';
  String userName = 'المستخدم';
  int userId = 0;
  String userRating = '4.8';
  String totalEarnings = '25000';
  String completedTrips = '12';
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadAvailableShipments();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        userName = prefs.getString('user_name') ?? 'المستخدم';
        userId = prefs.getInt('user_id') ?? 0;
      });

      // Load user profile from backend if needed
      if (userId > 0) {
        final profile = await ApiService.getProfile(userId);
        setState(() {
          userName = profile['name'] ?? userName;
          userRating = (profile['rating'] ?? 4.8).toString();
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _loadAvailableShipments() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      final allShipments = await ApiService.getShipments();
      
      // Filter shipments with status 'pending' or 'bidding'
      final filteredShipments = allShipments
          .where((shipment) =>
              shipment['status'] == 'pending' || shipment['status'] == 'bidding')
          .toList();

      setState(() {
        shipments = filteredShipments;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'فشل في تحميل الشحنات: ${e.toString()}';
      });
      print('Error loading shipments: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _TopDashboardHeader(
                userName: userName,
                rating: userRating,
                completedTrips: completedTrips,
                totalEarnings: totalEarnings,
              ),
              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : errorMessage.isNotEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: AppColors.danger,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  errorMessage,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: AppColors.text,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: _loadAvailableShipments,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('إعادة محاولة'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : shipments.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.inbox_outlined,
                                      size: 64,
                                      color: AppColors.subText,
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'لا توجد شحنات متاحة حالياً',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.text,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'برجاء المحاولة لاحقاً',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.subText,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 16, 16, 24),
                                children: [
                                  const _FiltersRow(),
                                  const SizedBox(height: 18),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'الشحنات المتاحة',
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.text,
                                        ),
                                      ),
                                      _CountChip(
                                        label:
                                            '${shipments.length} شحنة',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  ...shipments.asMap().entries.map((entry) {
                                    int index = entry.key;
                                    Map<String, dynamic> shipment =
                                        entry.value;
                                    return Padding(
                                      padding: EdgeInsets.only(
                                        bottom: index < shipments.length - 1
                                            ? 14
                                            : 0,
                                      ),
                                      child: ShipmentCard(
                                        shipmentData: shipment,
                                        isAuctionExpired: _isAuctionExpired(shipment),
                                        countdownText: _countdownText(shipment),
                                        onBidTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  BidDetailsScreen(
                                                shipmentId: shipment['id'],
                                                shipmentData: shipment,
                                                driverId: userId,
                                                driverName: userName,
                                              ),
                                            ),
                                          ).then((_) {
                                            // Refresh shipments after returning
                                            _loadAvailableShipments();
                                          });
                                        },
                                      ),
                                    );
                                  }).toList(),
                                ],
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isAuctionExpired(Map<String, dynamic> shipment) {
    final raw = shipment['auction_end_time']?.toString();
    if (raw == null || raw.isEmpty) return false;
    final end = DateTime.tryParse(raw);
    if (end == null) return false;
    return DateTime.now().isAfter(end);
  }

  String _countdownText(Map<String, dynamic> shipment) {
    final raw = shipment['auction_end_time']?.toString();
    if (raw == null || raw.isEmpty) return 'غير محدد';
    final end = DateTime.tryParse(raw);
    if (end == null) return 'غير محدد';
    final diff = end.difference(DateTime.now());
    if (diff.isNegative || diff.inSeconds <= 0) return 'انتهى المزاد';
    final h = diff.inHours.toString().padLeft(2, '0');
    final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class _TopDashboardHeader extends StatelessWidget {
  final String userName;
  final String rating;
  final String completedTrips;
  final String totalEarnings;

  const _TopDashboardHeader({
    required this.userName,
    required this.rating,
    required this.completedTrips,
    required this.totalEarnings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.16),
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.notifications_none, color: Colors.white),
                    Positioned(
                      top: 7,
                      left: 7,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '3',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'مرحباً بك',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.description_outlined,
                    color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'إجمالي الأرباح',
                  value: totalEarnings,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: 'التقييم',
                  value: rating,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: 'رحلة مكتملة',
                  value: completedTrips,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FiltersRow extends StatelessWidget {
  const _FiltersRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: FilterBox(label: 'الكل')),
        SizedBox(width: 10),
        Expanded(child: FilterBox(label: 'الكل')),
        SizedBox(width: 10),
        FilterActionButton(),
      ],
    );
  }
}

class FilterBox extends StatelessWidget {
  final String label;

  const FilterBox({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              color: AppColors.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.subText),
        ],
      ),
    );
  }
}

class FilterActionButton extends StatelessWidget {
  const FilterActionButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 98,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'فلترة',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(width: 8),
          Icon(Icons.tune_rounded),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;

  const _CountChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xffF0F2F5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.text,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class ShipmentCard extends StatelessWidget {
  final Map<String, dynamic> shipmentData;
  final bool isAuctionExpired;
  final String countdownText;
  final VoidCallback onBidTap;

  const ShipmentCard({
    super.key,
    required this.shipmentData,
    required this.isAuctionExpired,
    required this.countdownText,
    required this.onBidTap,
  });

  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    return price.toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (Match match) => ',',
        );
  }

  String _getCategory(String? description) {
    if (description == null || description.isEmpty) return 'عام';
    // Extract category from description or return first word
    return description.split(' ').first;
  }

  String _getCityDisplay(String? address) {
    if (address == null || address.isEmpty) return 'Unknown';
    // Extract city from address (assuming format like "City, Country" or just "City")
    return address.split(',')[0].trim();
  }

  @override
  Widget build(BuildContext context) {
    final cityFrom = _getCityDisplay(shipmentData['pickup_address']);
    final cityTo = _getCityDisplay(shipmentData['dropoff_address']);
    final category = _getCategory(shipmentData['cargo_description']);
    final weight = '${shipmentData['weight_kg'] ?? 0} طن';
    final price = _formatPrice(shipmentData['base_price']);
    final rating = '4.8'; // Default rating, can be updated from shipper data
    
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.03),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xffEEF2FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'من',
                            style: TextStyle(
                              color: AppColors.subText,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            cityFrom,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'إلى',
                            style: TextStyle(
                              color: AppColors.subText,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            cityTo,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 112,
                      child: Column(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Container(
                              width: 2,
                              color: const Color(0xffE5E7EB),
                            ),
                          ),
                          Container(
                            width: 14,
                            height: 14,
                            decoration: const BoxDecoration(
                              color: Color(0xffE5E7EB),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 26, color: AppColors.border),
                Row(
                  children: [
                    _MiniInfo(
                      icon: Icons.scale_outlined,
                      text: weight,
                    ),
                    const SizedBox(width: 14),
                    _MiniInfo(
                      icon: Icons.star_rounded,
                      text: rating,
                    ),
                    const SizedBox(width: 14),
                    _MiniInfo(
                      icon: Icons.access_time_rounded,
                      text: isAuctionExpired ? 'انتهى المزاد' : countdownText,
                      color: isAuctionExpired ? AppColors.danger : AppColors.orange,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Text(
                      'ابدأ من',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.subText,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$price ر.س',
                      style: const TextStyle(
                        fontSize: 20,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.border),
              ),
            ),
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: isAuctionExpired ? null : onBidTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: const Color(0xffDCEFE6),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'تقديم عرض',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _MiniInfo({
    required this.icon,
    required this.text,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color ?? AppColors.subText),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 15,
            color: color ?? AppColors.text,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

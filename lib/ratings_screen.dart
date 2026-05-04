import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import 'app_widgets.dart';
import 'api_service.dart';

/// شاشة تقييم التسليم والاستقبال (Bilateral Ratings)
class RatingsScreen extends StatefulWidget {
  final int shipmentId;
  final int otherUserId;
  final String otherUserRole; // 'driver' or 'shipper'
  final String otherUserName;

  const RatingsScreen({
    super.key,
    required this.shipmentId,
    required this.otherUserId,
    required this.otherUserRole,
    required this.otherUserName,
  });

  @override
  State<RatingsScreen> createState() => _RatingsScreenState();
}

class _RatingsScreenState extends State<RatingsScreen> {
  Map<String, dynamic>? _userRatings;
  int? _selectedRating;
  final TextEditingController _commentsController = TextEditingController();
  bool _isLoading = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadUserRatings();
  }

  Future<void> _loadUserRatings() async {
    setState(() => _isLoading = true);
    try {
      final ratings = await ApiService.getUserRatings(widget.otherUserId);
      setState(() {
        _userRatings = ratings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Future<void> _submitRating() async {
    if (_selectedRating == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('يرجى اختيار تقييم')));
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    final userRole = prefs.getString('user_role');

    if (userId == null || userRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لم يتم العثور على بيانات المستخدم')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ApiService.addRating({
        'shipment_id': widget.shipmentId,
        'rated_id': widget.otherUserId,
        'stars': _selectedRating,
        'comment': _commentsController.text.trim(),
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم إرسال التقييم بنجاح')));
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _commentsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التقييم والتقييمات'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // User Info Card
                    _buildUserCard(),
                    const SizedBox(height: 24),

                    // Rating Stats
                    if (_userRatings != null) ...[
                      _buildRatingStats(),
                      const SizedBox(height: 24),
                    ],

                    // Rating Form (Add your own rating)
                    _buildRatingForm(),

                    const SizedBox(height: 24),

                    // Past Ratings
                    if (_userRatings != null &&
                        (_userRatings?['ratings'] as List?)?.isNotEmpty == true)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Divider(),
                          const SizedBox(height: 16),
                          const Text(
                            'التقييمات السابقة',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: DarbakColors.dark,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._buildRatingsList(),
                        ],
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildUserCard() {
    return Card(
      elevation: 0,
      color: DarbakColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: DarbakColors.primaryGreen,
              child: Icon(
                widget.otherUserRole == 'driver'
                    ? Icons.person_pin_circle
                    : Icons.business,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: DarbakColors.dark,
                    ),
                  ),
                  Text(
                    widget.otherUserRole == 'driver' ? 'سائق' : 'شاحن',
                    style: const TextStyle(
                      fontSize: 12,
                      color: DarbakColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingStats() {
    final avgRating =
        double.tryParse(_userRatings?['average_rating']?.toString() ?? '0') ??
        0.0;
    final totalRatings = _userRatings?['total_ratings'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 0,
          color: DarbakColors.cardBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      avgRating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: DarbakColors.primaryGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStarRating(avgRating.toInt()),
                        const SizedBox(height: 4),
                        Text(
                          'من $totalRatings تقييم',
                          style: const TextStyle(
                            fontSize: 12,
                            color: DarbakColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRatingForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'أضف تقييمك',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: DarbakColors.dark,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedRating = index + 1;
                    });
                  },
                  child: Icon(
                    Icons.star,
                    size: 40,
                    color: (_selectedRating ?? 0) > index
                        ? Colors.amber
                        : Colors.grey[300],
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _commentsController,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: 'تعليقاتك (اختياري)',
            hintText: 'شارك رأيك عن التسليم والخدمة...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          textAlign: TextAlign.right,
        ),
        const SizedBox(height: 20),
        _isSubmitting
            ? const Center(child: CircularProgressIndicator())
            : DarbakPrimaryButton(
                label: 'إرسال التقييم',
                icon: Icons.send,
                onPressed: _submitRating,
              ),
      ],
    );
  }

  List<Widget> _buildRatingsList() {
    final ratings = (_userRatings?['ratings'] as List?) ?? [];
    return ratings.map<Widget>((rating) {
      return Card(
        elevation: 0,
        color: Colors.grey[50],
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStarRating(
                    int.tryParse(
                          '${rating['stars'] ?? rating['rating_stars'] ?? 0}',
                        ) ??
                        0,
                  ),
                  const Text(
                    'تقييم',
                    style: TextStyle(
                      fontSize: 11,
                      color: DarbakColors.textSecondary,
                    ),
                  ),
                ],
              ),
              if (((rating['comment'] ?? rating['comments']) as String?)
                      ?.isNotEmpty ==
                  true) ...[
                const SizedBox(height: 8),
                Text(
                  (rating['comment'] ?? rating['comments']).toString(),
                  style: const TextStyle(
                    fontSize: 12,
                    color: DarbakColors.dark,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                rating['created_at']?.toString() ?? '',
                style: const TextStyle(
                  fontSize: 10,
                  color: DarbakColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildStarRating(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          Icons.star,
          size: 16,
          color: index < rating ? Colors.amber : Colors.grey[300],
        );
      }),
    );
  }
}

/// شاشة لعرض تقييمات المستخدم الشامل
class UserRatingsOverviewScreen extends StatefulWidget {
  final int userId;
  final String userName;

  const UserRatingsOverviewScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<UserRatingsOverviewScreen> createState() =>
      _UserRatingsOverviewScreenState();
}

class _UserRatingsOverviewScreenState extends State<UserRatingsOverviewScreen> {
  Map<String, dynamic>? _ratings;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRatings();
  }

  Future<void> _loadRatings() async {
    try {
      final ratings = await ApiService.getUserRatings(widget.userId);
      setState(() {
        _ratings = ratings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('التقييمات')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final avgRating =
        double.tryParse(_ratings?['average_rating']?.toString() ?? '0') ?? 0.0;
    final totalRatings = _ratings?['total_ratings'] ?? 0;
    final ratingsList = (_ratings?['ratings'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقييمات'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Summary Card
              Card(
                elevation: 0,
                color: DarbakColors.cardBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        widget.userName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            avgRating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: DarbakColors.primaryGreen,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: List.generate(5, (index) {
                                  return Icon(
                                    Icons.star,
                                    size: 20,
                                    color: index < avgRating.toInt()
                                        ? Colors.amber
                                        : Colors.grey[300],
                                  );
                                }),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'من $totalRatings تقييم',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: DarbakColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'آخر التقييمات',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (ratingsList.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text('لا توجد تقييمات حتى الآن'),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: ratingsList.length,
                  itemBuilder: (context, index) {
                    final rating = ratingsList[index];
                    return Card(
                      elevation: 0,
                      color: Colors.grey[50],
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: List.generate(5, (idx) {
                                    final starCount = int.tryParse(
                                          '${rating['stars'] ?? rating['rating_stars'] ?? 0}',
                                        ) ??
                                        0;
                                    return Icon(
                                      Icons.star,
                                      size: 16,
                                      color: idx < starCount
                                          ? Colors.amber
                                          : Colors.grey[300],
                                    );
                                  }),
                                ),
                                const Text(
                                  'تقييم',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: DarbakColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            if (((rating['comment'] ?? rating['comments'])
                                        as String?)
                                    ?.isNotEmpty ==
                                true) ...[
                              const SizedBox(height: 8),
                              Text(
                                (rating['comment'] ?? rating['comments'])
                                    .toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: DarbakColors.dark,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

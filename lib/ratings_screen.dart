import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import 'app_widgets.dart';
import 'api_service.dart';
import 'models/review_target_profile.dart';
import 'widgets/review_target_profile_card.dart';

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
  ReviewTargetProfile? _reviewTarget;
  int? _selectedRating;
  int? _currentUserId;
  final TextEditingController _commentsController = TextEditingController();
  bool _ratingsLoading = true;
  bool _profileLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Map<String, dynamic> get _emptyRatings => {
    'average_rating': '0.00',
    'total_ratings': 0,
    'ratings': <Map<String, dynamic>>[],
  };

  List<Map<String, dynamic>> get _ratingsList {
    final raw = _userRatings?['ratings'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((rating) => Map<String, dynamic>.from(rating))
        .toList();
  }

  double get _averageRating => _readDouble(_userRatings?['average_rating']);

  int get _totalRatings => _readInt(_userRatings?['total_ratings']);

  bool get _hasRatedThisShipment {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return false;
    return _ratingsList.any((rating) {
      final shipmentId = _readInt(rating['shipment_id']);
      final raterId = _readInt(rating['rater_id']);
      return shipmentId == widget.shipmentId && raterId == currentUserId;
    });
  }

  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _currentUserId = prefs.getInt('user_id');
    });
    await _loadUserRatings(showLoader: false);
  }

  ReviewTargetProfile? _profileFromRatingsPayload(Map<String, dynamic> ratings) {
    final raw = ratings['rated_profile'];
    if (raw is! Map) return null;
    try {
      return ReviewTargetProfile.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadUserRatings({bool showLoader = true}) async {
    if (mounted && showLoader) setState(() => _ratingsLoading = true);
    try {
      final ratings = await ApiService.getUserRatings(widget.otherUserId);
      ReviewTargetProfile? profile = _profileFromRatingsPayload(ratings);
      if (profile == null) {
        try {
          profile = await ApiService.getUserProfileForReview(widget.otherUserId);
        } catch (_) {
          profile = null;
        }
      }
      if (!mounted) return;
      setState(() {
        _userRatings = ratings;
        _reviewTarget = profile;
        _profileLoading = false;
        _ratingsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _userRatings = _userRatings ?? _emptyRatings;
        _reviewTarget = null;
        _profileLoading = false;
        _ratingsLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _readDouble(dynamic value) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    if (parsed == null || !parsed.isFinite) return 0;
    return parsed.clamp(0, 5).toDouble();
  }

  static String _readText(dynamic value) => value?.toString().trim() ?? '';

  Future<void> _submitRating() async {
    if (_selectedRating == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('يرجى اختيار تقييم')));
      return;
    }

    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لم يتم العثور على بيانات المستخدم')),
      );
      return;
    }

    if (_hasRatedThisShipment) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تقييم هذه الرحلة مسبقاً')),
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

      if (!mounted) return;
      await _loadUserRatings(showLoader: false);
      if (!mounted) return;
      setState(() {
        _selectedRating = null;
        _commentsController.clear();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم إرسال التقييم بنجاح')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
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
        leading: const BackButton(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ReviewTargetProfileCard(
                isLoading: _profileLoading,
                profile: _reviewTarget,
                fallbackName: widget.otherUserName,
                fallbackRoleLabel:
                    widget.otherUserRole == 'driver' ? 'سائق' : 'شركة',
              ),
              const SizedBox(height: 24),
              if (_ratingsLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                if (_userRatings != null) ...[
                  _buildRatingStats(),
                  const SizedBox(height: 24),
                ],
                _buildRatingForm(),
                const SizedBox(height: 24),
                if (_ratingsList.isNotEmpty)
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingStats() {
    final avgRating = _averageRating;
    final totalRatings = _totalRatings;

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
    if (_hasRatedThisShipment) {
      return Card(
        elevation: 0,
        color: DarbakColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'تم إرسال تقييمك لهذه الرحلة. شكراً لمساهمتك.',
            textAlign: TextAlign.center,
            style: TextStyle(color: DarbakColors.textSecondary),
          ),
        ),
      );
    }

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
          textAlign: TextAlign.start,
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
    final ratings = _ratingsList;
    return ratings.map<Widget>((rating) {
      final comment = _readText(rating['comment'] ?? rating['comments']);
      final createdAt = _readText(rating['created_at']);
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
                    _readInt(rating['stars'] ?? rating['rating_stars']),
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
              if (comment.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  comment,
                  style: const TextStyle(
                    fontSize: 12,
                    color: DarbakColors.dark,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                createdAt,
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
      if (!mounted) return;
      setState(() {
        _ratings = ratings;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ratings = {
          'average_rating': '0.00',
          'total_ratings': 0,
          'ratings': <Map<String, dynamic>>[],
        };
        _isLoading = false;
      });
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

    final avgRating = _RatingsScreenState._readDouble(
      _ratings?['average_rating'],
    );
    final totalRatings = _RatingsScreenState._readInt(
      _ratings?['total_ratings'],
    );
    final ratingsList = ((_ratings?['ratings'] as List?) ?? [])
        .whereType<Map>()
        .map((rating) => Map<String, dynamic>.from(rating))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقييمات'),
        leading: const BackButton(),
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
                    final comment = _RatingsScreenState._readText(
                      rating['comment'] ?? rating['comments'],
                    );
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
                                    final starCount =
                                        _RatingsScreenState._readInt(
                                          rating['stars'] ??
                                              rating['rating_stars'],
                                        );
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
                            if (comment.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                comment,
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

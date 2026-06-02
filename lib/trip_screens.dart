import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'app_theme.dart';
import 'app_widgets.dart';
import 'api_service.dart';
import 'location_picker_screens.dart';
import 'models/chat_message.dart';
import 'services/chat_media_service.dart';
import 'services/chat_socket_service.dart';
import 'services/profile_repository.dart';
import 'widgets/profile_avatar.dart';
import 'widgets/sar_price.dart';

/// شاشة تتبع الرحلة (Timeline) للسائق والشاحن
class TripTrackingScreen extends StatefulWidget {
  final String shipmentId;
  final String driverName;
  final String driverRating;
  final String driverPhone;

  /// Test seam: override the ChatSocketService factory used when pushing the
  /// chat screen from this widget.  Production code leaves this null.
  @visibleForTesting
  final ChatSocketService Function()? chatSocketFactory;

  const TripTrackingScreen({
    super.key,
    required this.shipmentId,
    required this.driverName,
    required this.driverRating,
    required this.driverPhone,
    this.chatSocketFactory,
  });

  @override
  State<TripTrackingScreen> createState() => _TripTrackingScreenState();
}

class _TripTrackingScreenState extends State<TripTrackingScreen> {
  int _currentStep = 2; // الحالة الحالية: "جاري التحميل"

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تتبع الرحلة'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    shipmentId: widget.shipmentId,
                    otherUser: widget.driverName,
                    chatSocketFactory: widget.chatSocketFactory,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.chat_bubble_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // بطاقة معلومات السائق
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: DarbakColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: DarbakColors.primaryGreen.withOpacity(
                          0.2,
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: DarbakColors.primaryGreen,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.driverName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 16,
                                  color: DarbakColors.warningYellow,
                                ),
                                const SizedBox(width: 4),
                                Text(widget.driverRating),
                                const SizedBox(width: 12),
                                const Icon(
                                  Icons.phone_rounded,
                                  size: 16,
                                  color: DarbakColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(widget.driverPhone),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // خط الوقت (Timeline)
                const DarbakSectionTitle(title: 'حالة الرحلة'),
                const SizedBox(height: 16),

                _TimelineStep(
                  icon: Icons.schedule_rounded,
                  title: 'تلقّي العرض وتوقيع العقد',
                  subtitle: 'قبل 3 ساعات',
                  isCompleted: true,
                  isCurrent: false,
                ),
                _TimelineStep(
                  icon: Icons.inventory_2_rounded,
                  title: 'جاري التحميل',
                  subtitle: 'الآن',
                  isCompleted: false,
                  isCurrent: true,
                ),
                _TimelineStep(
                  icon: Icons.route_rounded,
                  title: 'جاري النقل',
                  subtitle: 'قريباً',
                  isCompleted: false,
                  isCurrent: false,
                ),
                _TimelineStep(
                  icon: Icons.flag_rounded,
                  title: 'تم التسليم',
                  subtitle: 'قريباً',
                  isCompleted: false,
                  isCurrent: false,
                ),

                const SizedBox(height: 24),

                const DarbakSectionTitle(title: 'الإجراءات المتاحة'),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _currentStep == 2
                            ? () {
                                setState(() {
                                  _currentStep = 3;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'تم تحديث الحالة: جاري النقل',
                                    ),
                                  ),
                                );
                              }
                            : null,
                        icon: const Icon(Icons.route_rounded),
                        label: const Text('بدء الرحلة'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ProofOfDeliveryScreen(
                                shipmentId: widget.shipmentId,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.camera_alt_rounded),
                        label: const Text('إثبات التسليم'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageStatusIcon extends StatelessWidget {
  const _MessageStatusIcon({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.hasFailed) {
      return const Icon(Icons.error_outline, size: 13, color: Colors.white70);
    }
    if (message.isPending) {
      return const Icon(Icons.access_time, size: 13, color: Colors.white70);
    }
    if (message.isRead) {
      return const Icon(
        Icons.done_all,
        size: 15,
        color: Colors.lightBlueAccent,
      );
    }
    if (message.isDelivered) {
      return const Icon(Icons.done_all, size: 15, color: Colors.white70);
    }
    return const Icon(Icons.done, size: 15, color: Colors.white70);
  }
}

class _ChatAppBarIdentity extends StatelessWidget {
  const _ChatAppBarIdentity({
    required this.name,
    required this.imageUrl,
    required this.imageKey,
    required this.role,
  });

  final String name;
  final String? imageUrl;
  final String? imageKey;
  final String role;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.62,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: TextDirection.rtl,
        children: [
          ProfileAvatar(
            imageUrl: imageUrl,
            imageKey: imageKey,
            role: role,
            radius: 18,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageMessageContent extends StatelessWidget {
  const _ImageMessageContent({
    required this.imageUrl,
    required this.caption,
    required this.textColor,
    this.progress,
    this.failed = false,
  });

  final String? imageUrl;
  final String caption;
  final Color textColor;
  final double? progress;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final hasRemoteImage = imageUrl != null && imageUrl!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: GestureDetector(
            onTap: hasRemoteImage
                ? () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _ImagePreviewScreen(imageUrl: imageUrl!),
                    ),
                  )
                : null,
            child: Container(
              width: 210,
              height: 170,
              color: Colors.black12,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasRemoteImage)
                    CachedNetworkImage(imageUrl: imageUrl!, fit: BoxFit.cover)
                  else
                    const Center(
                      child: Icon(
                        Icons.image_rounded,
                        size: 44,
                        color: Colors.white70,
                      ),
                    ),
                  if (progress != null)
                    Container(
                      color: Colors.black38,
                      child: Center(
                        child: CircularProgressIndicator(value: progress),
                      ),
                    ),
                  if (failed)
                    Container(
                      color: Colors.black45,
                      child: const Center(
                        child: Icon(
                          Icons.error_outline,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (caption.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(caption, style: TextStyle(color: textColor)),
        ],
      ],
    );
  }
}

class _VideoMessageContent extends StatelessWidget {
  const _VideoMessageContent({
    required this.videoUrl,
    required this.fileName,
    required this.caption,
    required this.textColor,
    this.progress,
    this.failed = false,
  });

  final String? videoUrl;
  final String? fileName;
  final String caption;
  final Color textColor;
  final double? progress;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final hasVideo = videoUrl != null && videoUrl!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: hasVideo
              ? () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _VideoPreviewScreen(videoUrl: videoUrl!),
                  ),
                )
              : null,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 210,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.play_circle_fill_rounded,
                      size: 46,
                      color: Colors.white,
                    ),
                    if (progress != null)
                      SizedBox(
                        width: 52,
                        height: 52,
                        child: CircularProgressIndicator(value: progress),
                      ),
                    if (failed)
                      const Icon(
                        Icons.error_outline,
                        color: Colors.redAccent,
                        size: 54,
                      ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    fileName?.isNotEmpty == true ? fileName! : 'فيديو',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (caption.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(caption, style: TextStyle(color: textColor)),
        ],
      ],
    );
  }
}

class _LocationMessageContent extends StatelessWidget {
  const _LocationMessageContent({
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.textColor,
  });

  final double? latitude;
  final double? longitude;
  final String label;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final lat = latitude;
    final lng = longitude;
    if (lat == null || lng == null) {
      return Text(
        label.isNotEmpty ? label : 'موقع',
        style: TextStyle(color: textColor),
      );
    }
    final point = LatLng(lat, lng);
    return InkWell(
      onTap: () async {
        final uri = Uri.parse('https://www.google.com/maps?q=$lat,$lng');
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 220,
              height: 150,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: point,
                  initialZoom: 14,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.darbak',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: point,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: Colors.redAccent,
                          size: 36,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label.isNotEmpty ? label : 'موقع',
            style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
          ),
          Text(
            '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
            style: TextStyle(
              color: textColor.withValues(alpha: 0.72),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePreviewScreen extends StatelessWidget {
  const _ImagePreviewScreen({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black),
      body: Center(
        child: InteractiveViewer(child: CachedNetworkImage(imageUrl: imageUrl)),
      ),
    );
  }
}

class _VideoPreviewScreen extends StatefulWidget {
  const _VideoPreviewScreen({required this.videoUrl});

  final String videoUrl;

  @override
  State<_VideoPreviewScreen> createState() => _VideoPreviewScreenState();
}

class _VideoPreviewScreenState extends State<_VideoPreviewScreen> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _ready = true);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black),
      body: Center(
        child: _ready
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            : const CircularProgressIndicator(),
      ),
      floatingActionButton: _ready
          ? FloatingActionButton(
              onPressed: () {
                setState(() {
                  _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play();
                });
              },
              child: Icon(
                _controller.value.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
              ),
            )
          : null,
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isCompleted;
  final bool isCurrent;

  const _TimelineStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isCompleted,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 3,
                height: 32,
                color: isCompleted
                    ? DarbakColors.primaryGreen
                    : isCurrent
                    ? DarbakColors.warningYellow
                    : Colors.grey,
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? DarbakColors.primaryGreen
                      : isCurrent
                      ? DarbakColors.warningYellow
                      : Colors.grey[300],
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: Icon(icon, color: Colors.white, size: 14),
              ),
              Container(width: 3, height: 20, color: Colors.grey[200]),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isCompleted
                        ? DarbakColors.primaryGreen
                        : isCurrent
                        ? DarbakColors.warningYellow
                        : DarbakColors.dark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
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
    );
  }
}

/// شاشة إثبات التسليم
class ProofOfDeliveryScreen extends StatefulWidget {
  final String shipmentId;
  const ProofOfDeliveryScreen({super.key, required this.shipmentId});

  @override
  State<ProofOfDeliveryScreen> createState() => _ProofOfDeliveryScreenState();
}

class _ProofOfDeliveryScreenState extends State<ProofOfDeliveryScreen> {
  XFile? _imageFile;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  final TextEditingController _codeController = TextEditingController();

  Future<void> _pickImage() async {
    final XFile? selected = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );
    if (selected != null) {
      setState(() {
        _imageFile = selected;
      });
    }
  }

  Future<void> _submit() async {
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى التقاط صورة للشحنة أولاً')),
      );
      return;
    }

    setState(() => _isUploading = true);
    try {
      final shipmentIdInt = int.tryParse(widget.shipmentId) ?? 0;
      await ApiService.updateShipmentStatus(
        shipmentId: shipmentIdInt,
        status: 'delivered',
        epodPhoto: _imageFile,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إثبات التسليم بنجاح!'),
          backgroundColor: DarbakColors.successGreen,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في الرفع: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إثبات التسليم')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              children: [
                const DarbakSectionTitle(title: 'إثبات وصول الشحنة وتسليمها'),
                const SizedBox(height: 16),

                // منطقة الصور
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: DarbakColors.lightBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: DarbakColors.border),
                    ),
                    child: _imageFile == null
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.camera_alt_outlined,
                                  size: 48,
                                  color: DarbakColors.textSecondary,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'التقط صورة للشحنة عند التسليم',
                                  style: TextStyle(
                                    color: DarbakColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              File(_imageFile!.path),
                              fit: BoxFit.cover,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  'توقيع المستلم',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: DarbakColors.lightBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: DarbakColors.border),
                  ),
                  child: const Center(
                    child: Text(
                      'مساحة التوقيع الرقمي',
                      style: TextStyle(
                        color: DarbakColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'كود الاستلام (اختياري)',
                    prefixIcon: Icon(Icons.qr_code_2_rounded),
                  ),
                  textAlign: TextAlign.start,
                ),
                const SizedBox(height: 24),

                _isUploading
                    ? const CircularProgressIndicator()
                    : DarbakPrimaryButton(
                        label: 'تأكيد التسليم',
                        icon: Icons.check_circle_outline_rounded,
                        onPressed: _submit,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// شاشة العقوبة (FR-22) - يتم احتسابها ديناميكياً
class PenaltyScreen extends StatelessWidget {
  final Map<String, dynamic> shipmentData;

  const PenaltyScreen({super.key, required this.shipmentData});

  @override
  Widget build(BuildContext context) {
    // استخراج البيانات وتحويل التواريخ
    final String shipmentId = shipmentData['shipment_id']?.toString() ?? 'N/A';
    final double originalAmount =
        double.tryParse(shipmentData['bid_amount']?.toString() ?? '0') ?? 0;

    DateTime? expectedDate;
    if (shipmentData['expected_delivery_at'] != null) {
      expectedDate = DateTime.tryParse(shipmentData['expected_delivery_at']);
    }

    // نستخدم الوقت الحالي كـ "وقت تسليم" إذا لم يتوفر في البيانات
    final DateTime actualDate = shipmentData['delivered_at'] != null
        ? DateTime.tryParse(shipmentData['delivered_at']) ?? DateTime.now()
        : DateTime.now();

    int delayDays = 0;
    double penaltyAmount = 0;
    double penaltyPercentage = 0;

    if (expectedDate != null && actualDate.isAfter(expectedDate)) {
      delayDays = actualDate.difference(expectedDate).inDays;
      // إذا كان هناك كسر يوم (مثلاً 1.2 يوم) يُحسب يومين أو نعتمد الساعات، هنا سنعتمد الأيام الكاملة
      if (actualDate.difference(expectedDate).inHours % 24 > 0) {
        delayDays += 1;
      }
      penaltyPercentage = delayDays * 0.05; // 5% لكل يوم
      penaltyAmount = originalAmount * penaltyPercentage;
    }

    final double finalAmount = originalAmount - penaltyAmount;

    final dateFormat = DateFormat('yyyy-MM-dd - hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الدفع والعقوبات'),
        backgroundColor: delayDays > 0
            ? DarbakColors.warningYellow
            : DarbakColors.primaryGreen,
        foregroundColor: delayDays > 0 ? DarbakColors.dark : Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: delayDays > 0
                          ? [
                              DarbakColors.warningYellow,
                              DarbakColors.warningYellow.withOpacity(0.8),
                            ]
                          : [
                              DarbakColors.primaryGreen,
                              DarbakColors.primaryGreen.withOpacity(0.8),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        delayDays > 0
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline_rounded,
                        color: delayDays > 0 ? DarbakColors.dark : Colors.white,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        delayDays > 0
                            ? 'تم احتساب عقوبة تأخير'
                            : 'تم التسليم في الموعد',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: delayDays > 0
                              ? DarbakColors.dark
                              : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'شحنة رقم #$shipmentId',
                        style: TextStyle(
                          fontSize: 14,
                          color: delayDays > 0
                              ? DarbakColors.dark.withOpacity(0.8)
                              : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const DarbakSectionTitle(title: 'ملخص الحساب المالي'),
                const SizedBox(height: 12),

                _PenaltyDetailRow(
                  label: 'الموعد المتفق عليه (EDT)',
                  value: expectedDate != null
                      ? dateFormat.format(expectedDate.toLocal())
                      : 'غير محدد',
                ),
                _PenaltyDetailRow(
                  label: 'وقت التسليم الفعلي',
                  value: dateFormat.format(actualDate.toLocal()),
                  isWarning: delayDays > 0,
                ),
                if (delayDays > 0) ...[
                  _PenaltyDetailRow(
                    label: 'مدة التأخير',
                    value: '$delayDays يوم',
                    isWarning: true,
                  ),
                  _PenaltyDetailRow(
                    label: 'نسبة الخصم (5% يومياً)',
                    value: '${(penaltyPercentage * 100).toInt()}%',
                    isWarning: true,
                  ),
                ],
                _PenaltyDetailRow(
                  label: 'المبلغ الأصلي للمناقصة',
                  valueWidget: SarPrice(
                    amount: originalAmount,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    iconSize: 13,
                  ),
                ),
                if (delayDays > 0)
                  _PenaltyDetailRow(
                    label: 'قيمة الخصم المستقطع',
                    valueWidget: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '- ',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: DarbakColors.warningYellow,
                          ),
                        ),
                        SarPrice(
                          amount: penaltyAmount,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: DarbakColors.warningYellow,
                          ),
                          iconSize: 13,
                        ),
                      ],
                    ),
                    isWarning: true,
                  ),

                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: DarbakColors.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: DarbakColors.primaryGreen),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.attach_money_rounded,
                        color: DarbakColors.primaryGreen,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'المبلغ الصافي للتحويل: ',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SarPrice(
                        amount: finalAmount,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: DarbakColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
                DarbakPrimaryButton(
                  label: 'تأكيد واستلام المستحقات',
                  icon: Icons.account_balance_wallet_rounded,
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                ),
                if (delayDays > 0) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'تم رفع طلب اعتراض، سيراجع الأدمن الحالة',
                          ),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: DarbakColors.warningYellow),
                    ),
                    child: const Text(
                      'الاعتراض على العقوبة',
                      style: TextStyle(color: DarbakColors.warningYellow),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PenaltyDetailRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? valueWidget;
  final bool isWarning;

  const _PenaltyDetailRow({
    required this.label,
    this.value,
    this.valueWidget,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          valueWidget ??
              Text(
                value ?? '',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isWarning ? DarbakColors.warningYellow : null,
                ),
              ),
        ],
      ),
    );
  }
}

/// شاشة المحادثة (تفاعلية محلية)
class ChatScreen extends StatefulWidget {
  final String shipmentId;
  final String otherUser;
  final int? otherUserId;
  final String? otherUserProfileImageUrl;
  final String? otherUserProfileImageKey;
  final String? otherUserRole;

  const ChatScreen({
    super.key,
    required this.shipmentId,
    required this.otherUser,
    this.otherUserId,
    this.otherUserProfileImageUrl,
    this.otherUserProfileImageKey,
    this.otherUserRole,
    this.chatSocketFactory,
    this.pickImage,
    this.pickVideo,
    this.currentPositionProvider,
    this.pickLocation,
  });

  /// Optional factory used to build the [ChatSocketService] for this screen.
  /// Production code lets the default factory create a real socket; tests can
  /// inject a fake that never attempts a real network connection.
  final ChatSocketService Function()? chatSocketFactory;
  final Future<PickedChatMedia?> Function(ImageSource source)? pickImage;
  final Future<PickedChatMedia?> Function(ImageSource source)? pickVideo;
  final Future<Position> Function()? currentPositionProvider;
  final Future<Map<String, dynamic>?> Function(
    BuildContext context,
    LatLng initialLocation,
  )?
  pickLocation;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final ChatSocketService _chatSocket =
      widget.chatSocketFactory?.call() ?? ChatSocketService();
  final List<StreamSubscription<dynamic>> _socketSubscriptions = [];
  final Map<String, double> _uploadProgressByClientId = {};
  static const double _showScrollToBottomAfterOffset = 120;
  Timer? _poller;
  bool _loading = true;
  bool _showScrollToBottom = false;
  int? _myUserId;
  int? _resolvedOtherUserId;
  String? _otherUserProfileImageUrl;
  String? _otherUserProfileImageKey;
  String _otherUserRole = 'shipper';
  final Map<int, String?> _senderProfileImageUrlsByUserId = {};
  final Map<int, String?> _senderProfileImageKeysByUserId = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleChatScroll);
    _bindSocketEvents();
    _bootstrap();
    _poller = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadMessages(),
    );
  }

  Future<void> _bootstrap() async {
    await _resolveUsers();
    await _loadOtherUserProfile();
    await _loadMessages();
    await _connectSocket();
  }

  void _bindSocketEvents() {
    _socketSubscriptions
      ..add(_chatSocket.newMessages.listen(_handleIncomingMessage))
      ..add(_chatSocket.sentMessages.listen(_handleSentMessage))
      ..add(_chatSocket.statusUpdates.listen(_handleStatusUpdate))
      ..add(_chatSocket.errors.listen(_handleSocketError));
  }

  void _handleChatScroll() {
    if (!_scrollController.hasClients) return;
    final shouldShow =
        _scrollController.offset > _showScrollToBottomAfterOffset;
    if (shouldShow == _showScrollToBottom) return;
    setState(() => _showScrollToBottom = shouldShow);
  }

  Future<void> _scrollToBottom() async {
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _scrollToBottomAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_scrollToBottom());
    });
  }

  Future<void> _connectSocket() async {
    final shipmentIdInt = int.tryParse(widget.shipmentId);
    if (shipmentIdInt == null) return;
    await _chatSocket.connect();
    _chatSocket.joinShipment(shipmentIdInt);
  }

  Future<void> _resolveUsers() async {
    if (widget.otherUserId != null) {
      _resolvedOtherUserId = widget.otherUserId;
    }
    final shipmentIdInt = int.tryParse(widget.shipmentId);
    if (shipmentIdInt == null) return;
    final shipment = await ApiService.getShipment(shipmentIdInt);
    final prefs = await SharedPreferences.getInstance();
    _myUserId = prefs.getInt('user_id');
    try {
      final profile = await ProfileRepository.getMe();
      final profileUserId = _intFromValue(profile['id']);
      if (profileUserId != null) {
        _myUserId = profileUserId;
        await prefs.setInt('user_id', profileUserId);
      }
    } catch (_) {
      // Keep the locally cached user id if the profile refresh fails.
    }
    final isDriver = prefs.getString('user_role') == 'driver';
    _otherUserRole = isDriver ? 'shipper' : 'driver';
    _resolvedOtherUserId ??= isDriver
        ? (shipment['shipper_id'] as num?)?.toInt()
        : (shipment['driver_id'] as num?)?.toInt();
  }

  Future<void> _loadOtherUserProfile() async {
    _otherUserProfileImageUrl = widget.otherUserProfileImageUrl;
    _otherUserProfileImageKey = widget.otherUserProfileImageKey;
    if (widget.otherUserRole != null) {
      _otherUserRole = widget.otherUserRole!;
    }
    final otherId = _resolvedOtherUserId;
    if ((_otherUserProfileImageUrl?.trim().isNotEmpty ?? false) ||
        otherId == null) {
      await ProfileRepository.preloadProfileImage(
        imageUrl: _otherUserProfileImageUrl,
        imageKey: _otherUserProfileImageKey,
      );
      return;
    }
    try {
      final profile = await ApiService.getProfile(otherId);
      _otherUserProfileImageUrl =
          profile['profileImageUrl']?.toString() ??
          profile['profile_image_url']?.toString();
      _otherUserProfileImageKey = profile['profileImageKey']?.toString();
      _otherUserRole = profile['role']?.toString() ?? _otherUserRole;
      await ProfileRepository.preloadProfileImage(
        imageUrl: _otherUserProfileImageUrl,
        imageKey: _otherUserProfileImageKey,
      );
    } catch (_) {
      // The chat still works if avatar metadata is unavailable.
    }
  }

  Future<void> _loadMessages() async {
    final shipmentIdInt = int.tryParse(widget.shipmentId);
    if (shipmentIdInt == null) return;
    try {
      final rows = await ApiService.getChatMessages(shipmentIdInt);
      final rowMaps = rows
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final normalizedRows = _stabilizeMessageAvatarUrls(
        rowMaps.map(ChatMessage.fromJson).toList(),
      );
      await ProfileRepository.preloadProfileImagesFromRows(
        rowMaps,
        urlField: 'sender_profile_image_url',
        keyField: 'sender_profile_image_key',
      );
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(normalizedRows);
        _loading = false;
      });
      _markIncomingDelivered();
      _markVisibleIncomingAsRead();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<ChatMessage> _stabilizeMessageAvatarUrls(List<ChatMessage> rows) {
    return rows.map((message) {
      final senderId = message.senderId;
      if (senderId <= 0) return message;

      final incomingKey = _cleanString(message.senderProfileImageKey);
      final incomingUrl = _cleanString(message.senderProfileImageUrl);

      if (incomingKey == null) {
        _senderProfileImageKeysByUserId.remove(senderId);
        _senderProfileImageUrlsByUserId.remove(senderId);
        return message.copyWith(senderProfileImageUrl: null);
      }

      final previousKey = _senderProfileImageKeysByUserId[senderId];
      final hasCachedUrl = _senderProfileImageUrlsByUserId.containsKey(
        senderId,
      );
      if (previousKey != incomingKey ||
          !hasCachedUrl ||
          (_senderProfileImageUrlsByUserId[senderId] == null &&
              incomingUrl != null)) {
        _senderProfileImageKeysByUserId[senderId] = incomingKey;
        _senderProfileImageUrlsByUserId[senderId] = incomingUrl;
      }

      return message.copyWith(
        senderProfileImageUrl: _senderProfileImageUrlsByUserId[senderId],
      );
    }).toList();
  }

  String? _cleanString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  void _handleIncomingMessage(ChatMessage message) {
    final shipmentIdInt = int.tryParse(widget.shipmentId);
    if (shipmentIdInt == null || message.shipmentId != shipmentIdInt) return;
    if (!mounted) return;
    setState(() => _upsertMessage(message));
    _markIncomingDelivered(messageIds: [if (message.id != null) message.id!]);
    _markVisibleIncomingAsRead();
  }

  void _handleSentMessage(ChatMessageSent sent) {
    final shipmentIdInt = int.tryParse(widget.shipmentId);
    if (shipmentIdInt == null || sent.message.shipmentId != shipmentIdInt) {
      return;
    }
    if (!mounted) return;
    setState(() {
      final index = _messages.indexWhere(
        (message) =>
            sent.clientMessageId != null &&
            message.clientMessageId == sent.clientMessageId,
      );
      final confirmed = sent.message.copyWith(
        clientMessageId: sent.clientMessageId,
        isPending: false,
        hasFailed: false,
      );
      if (index >= 0) {
        _messages[index] = confirmed;
      } else {
        _upsertMessage(confirmed);
      }
    });
  }

  void _handleStatusUpdate(ChatStatusUpdate update) {
    final shipmentIdInt = int.tryParse(widget.shipmentId);
    if (shipmentIdInt == null || update.shipmentId != shipmentIdInt) return;
    if (!mounted) return;
    setState(() {
      for (final receipt in update.messages) {
        final index = _messages.indexWhere(
          (message) => message.id == receipt.id,
        );
        if (index == -1) continue;
        final current = _messages[index];
        _messages[index] = current.copyWith(
          deliveredAt: receipt.deliveredAt ?? current.deliveredAt,
          readAt: receipt.readAt ?? current.readAt,
        );
      }
    });
  }

  void _handleSocketError(String message) {
    if (!mounted || message.trim().isEmpty) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _upsertMessage(ChatMessage message) {
    final id = message.id;
    final index = id == null
        ? -1
        : _messages.indexWhere((existing) => existing.id == id);
    if (index >= 0) {
      _messages[index] = message;
    } else {
      _messages.add(message);
      _messages.sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aDate.compareTo(bDate);
      });
    }
  }

  List<int> _incomingMessageIds({
    bool unreadOnly = false,
    bool undeliveredOnly = false,
    List<int> messageIds = const [],
  }) {
    if (_myUserId == null) return const [];
    final filter = messageIds.toSet();
    return _messages
        .where((message) {
          if (message.id == null || message.receiverId != _myUserId) {
            return false;
          }
          if (filter.isNotEmpty && !filter.contains(message.id)) return false;
          if (unreadOnly && message.isRead) return false;
          if (undeliveredOnly && message.isDelivered) return false;
          return true;
        })
        .map((message) => message.id!)
        .toList();
  }

  void _markIncomingDelivered({List<int> messageIds = const []}) {
    final shipmentIdInt = int.tryParse(widget.shipmentId);
    if (shipmentIdInt == null) return;
    final ids = _incomingMessageIds(
      undeliveredOnly: true,
      messageIds: messageIds,
    );
    if (ids.isEmpty) return;
    final now = DateTime.now();
    _applyLocalReceipt(ids, deliveredAt: now);
    if (_chatSocket.isConnected) {
      _chatSocket.markDelivered(shipmentId: shipmentIdInt, messageIds: ids);
    } else {
      unawaited(
        ApiService.markChatMessagesDelivered(shipmentIdInt, messageIds: ids),
      );
    }
  }

  void _markVisibleIncomingAsRead() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final shipmentIdInt = int.tryParse(widget.shipmentId);
      if (shipmentIdInt == null) return;
      final ids = _incomingMessageIds(unreadOnly: true);
      if (ids.isEmpty) return;
      final now = DateTime.now();
      _applyLocalReceipt(ids, deliveredAt: now, readAt: now);
      if (_chatSocket.isConnected) {
        _chatSocket.markRead(shipmentId: shipmentIdInt, messageIds: ids);
      } else {
        unawaited(
          ApiService.markChatMessagesRead(shipmentIdInt, messageIds: ids),
        );
      }
    });
  }

  void _applyLocalReceipt(
    List<int> messageIds, {
    DateTime? deliveredAt,
    DateTime? readAt,
  }) {
    if (!mounted) return;
    final idSet = messageIds.toSet();
    setState(() {
      for (var i = 0; i < _messages.length; i++) {
        final message = _messages[i];
        if (message.id == null || !idSet.contains(message.id)) continue;
        _messages[i] = message.copyWith(
          deliveredAt: deliveredAt ?? message.deliveredAt,
          readAt: readAt ?? message.readAt,
        );
      }
    });
  }

  Future<void> _showAttachmentSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_rounded),
                  title: const Text('التقاط صورة'),
                  onTap: () {
                    Navigator.pop(context);
                    unawaited(_pickAndSendImage(ImageSource.camera));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.videocam_rounded),
                  title: const Text('تسجيل فيديو'),
                  onTap: () {
                    Navigator.pop(context);
                    unawaited(_pickAndSendVideo(ImageSource.camera));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded),
                  title: const Text('اختيار صورة من المعرض'),
                  onTap: () {
                    Navigator.pop(context);
                    unawaited(_pickAndSendImage(ImageSource.gallery));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.video_library_rounded),
                  title: const Text('اختيار فيديو من المعرض'),
                  onTap: () {
                    Navigator.pop(context);
                    unawaited(_pickAndSendVideo(ImageSource.gallery));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.location_on_rounded),
                  title: const Text('مشاركة موقعي الحالي'),
                  onTap: () {
                    Navigator.pop(context);
                    unawaited(_sendCurrentLocation());
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.map_rounded),
                  title: const Text('اختيار موقع من الخريطة'),
                  onTap: () {
                    Navigator.pop(context);
                    unawaited(_pickAndSendLocation());
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final picked =
          await (widget.pickImage?.call(source) ??
              ChatMediaService.pickImage(source));
      if (picked == null) return;
      await _sendMediaMessage(picked);
    } catch (e) {
      _showChatSnack('تعذر إرسال الصورة: $e');
    }
  }

  Future<void> _pickAndSendVideo(ImageSource source) async {
    try {
      final picked =
          await (widget.pickVideo?.call(source) ??
              ChatMediaService.pickVideo(source));
      if (picked == null) return;
      await _sendMediaMessage(picked);
    } catch (e) {
      _showChatSnack('تعذر إرسال الفيديو: $e');
    }
  }

  Future<void> _sendMediaMessage(PickedChatMedia media) async {
    final shipmentIdInt = int.tryParse(widget.shipmentId);
    final senderId = _myUserId;
    if (shipmentIdInt == null ||
        senderId == null ||
        _resolvedOtherUserId == null) {
      return;
    }
    final clientMessageId = 'media-${DateTime.now().microsecondsSinceEpoch}';
    final optimisticMessage = ChatMessage(
      id: null,
      shipmentId: shipmentIdInt,
      senderId: senderId,
      receiverId: _resolvedOtherUserId!,
      message: '',
      messageType: media.messageType,
      mediaFileName: media.fileName,
      mediaSizeBytes: media.bytes.length,
      createdAt: DateTime.now(),
      clientMessageId: clientMessageId,
      isPending: true,
    );
    setState(() {
      _uploadProgressByClientId[clientMessageId] = 0;
      _messages.add(optimisticMessage);
    });
    _scrollToBottomAfterFrame();

    try {
      final created = await ApiService.sendChatMediaMessage(
        shipmentId: shipmentIdInt,
        receiverId: _resolvedOtherUserId!,
        fileName: media.fileName,
        bytes: media.bytes,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _uploadProgressByClientId[clientMessageId] = progress);
        },
      );
      if (!mounted) return;
      setState(() {
        _uploadProgressByClientId.remove(clientMessageId);
        final index = _messages.indexWhere(
          (message) => message.clientMessageId == clientMessageId,
        );
        final confirmed = ChatMessage.fromJson(
          created,
        ).copyWith(clientMessageId: clientMessageId);
        if (index >= 0) {
          _messages[index] = confirmed;
        } else {
          _upsertMessage(confirmed);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadProgressByClientId.remove(clientMessageId);
        final index = _messages.indexWhere(
          (message) => message.clientMessageId == clientMessageId,
        );
        if (index >= 0) {
          _messages[index] = _messages[index].copyWith(
            isPending: false,
            hasFailed: true,
          );
        }
      });
      _showChatSnack('تعذر إرسال الوسائط: $e');
    }
  }

  Future<void> _sendCurrentLocation() async {
    final shipmentIdInt = int.tryParse(widget.shipmentId);
    final senderId = _myUserId;
    if (shipmentIdInt == null ||
        senderId == null ||
        _resolvedOtherUserId == null) {
      return;
    }
    try {
      final position = await _currentPosition();
      await _sendLocationMessage(
        latitude: position.latitude,
        longitude: position.longitude,
        label: 'موقع حالي',
      );
    } catch (e) {
      _showChatSnack('تعذر مشاركة الموقع: $e');
    }
  }

  Future<void> _pickAndSendLocation() async {
    final shipmentIdInt = int.tryParse(widget.shipmentId);
    final senderId = _myUserId;
    if (shipmentIdInt == null ||
        senderId == null ||
        _resolvedOtherUserId == null) {
      return;
    }
    try {
      LatLng initialLocation = const LatLng(24.7136, 46.6753);
      try {
        final position = await _currentPosition();
        initialLocation = LatLng(position.latitude, position.longitude);
      } catch (_) {
        // The map picker can still work with a Riyadh default if GPS is unavailable.
      }

      if (!mounted) return;
      final result =
          await (widget.pickLocation?.call(context, initialLocation) ??
              Navigator.of(context).push<Map<String, dynamic>>(
                MaterialPageRoute(
                  builder: (_) => MapLocationPickerScreen(
                    title: 'اختيار موقع للمشاركة',
                    themeColor: DarbakColors.primaryGreen,
                    initialLocation: initialLocation,
                  ),
                ),
              ));
      if (!mounted || result == null) return;

      final latitude = _doubleFromValue(result['lat']);
      final longitude = _doubleFromValue(result['lng']);
      if (latitude == null || longitude == null) {
        throw DarbakException('إحداثيات الموقع غير صحيحة');
      }
      await _sendLocationMessage(
        latitude: latitude,
        longitude: longitude,
        label: 'موقع محدد',
      );
    } catch (e) {
      _showChatSnack('تعذر إرسال الموقع المحدد: $e');
    }
  }

  Future<void> _sendLocationMessage({
    required double latitude,
    required double longitude,
    required String label,
  }) async {
    final shipmentIdInt = int.tryParse(widget.shipmentId);
    if (shipmentIdInt == null || _resolvedOtherUserId == null) return;
    final created = await ApiService.sendChatLocationMessage(
      shipmentId: shipmentIdInt,
      receiverId: _resolvedOtherUserId!,
      latitude: latitude,
      longitude: longitude,
      label: label,
    );
    if (!mounted) return;
    setState(() => _upsertMessage(ChatMessage.fromJson(created)));
    _scrollToBottomAfterFrame();
  }

  Future<Position> _currentPosition() async {
    final provider = widget.currentPositionProvider;
    if (provider != null) return provider();

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw DarbakException('لم يتم منح صلاحية الموقع');
    }
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw DarbakException('خدمة الموقع غير مفعلة');
    }
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  double? _doubleFromValue(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  int? _intFromValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  void _showChatSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildMessageContent(ChatMessage message, bool isMe) {
    final textColor = isMe ? Colors.white : DarbakColors.dark;
    if (message.isImage) {
      return _ImageMessageContent(
        imageUrl: message.mediaUrl,
        caption: message.message,
        textColor: textColor,
        progress: _uploadProgressByClientId[message.clientMessageId],
        failed: message.hasFailed,
      );
    }
    if (message.isVideo) {
      return _VideoMessageContent(
        videoUrl: message.mediaUrl,
        fileName: message.mediaFileName,
        caption: message.message,
        textColor: textColor,
        progress: _uploadProgressByClientId[message.clientMessageId],
        failed: message.hasFailed,
      );
    }
    if (message.isLocation) {
      return _LocationMessageContent(
        latitude: message.locationLat,
        longitude: message.locationLng,
        label: message.locationLabel ?? message.message,
        textColor: textColor,
      );
    }
    return Text(message.message, style: TextStyle(color: textColor));
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final shipmentIdInt = int.tryParse(widget.shipmentId);
    if (shipmentIdInt == null || _resolvedOtherUserId == null) return;
    final senderId = _myUserId;
    if (senderId == null) return;
    final clientMessageId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final optimisticMessage = ChatMessage(
      id: null,
      shipmentId: shipmentIdInt,
      senderId: senderId,
      receiverId: _resolvedOtherUserId!,
      message: text,
      createdAt: DateTime.now(),
      clientMessageId: clientMessageId,
      isPending: true,
    );
    setState(() {
      _messages.add(optimisticMessage);
      _controller.clear();
    });
    _scrollToBottomAfterFrame();
    try {
      if (_chatSocket.isConnected) {
        _chatSocket.sendMessage(
          shipmentId: shipmentIdInt,
          receiverId: _resolvedOtherUserId!,
          message: text,
          clientMessageId: clientMessageId,
        );
      } else {
        final created = await ApiService.sendChatMessage(
          shipmentId: shipmentIdInt,
          receiverId: _resolvedOtherUserId!,
          message: text,
        );
        if (!mounted) return;
        setState(() {
          final index = _messages.indexWhere(
            (message) => message.clientMessageId == clientMessageId,
          );
          final confirmed = ChatMessage.fromJson(
            created,
          ).copyWith(clientMessageId: clientMessageId);
          if (index >= 0) {
            _messages[index] = confirmed;
          } else {
            _upsertMessage(confirmed);
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final index = _messages.indexWhere(
          (message) => message.clientMessageId == clientMessageId,
        );
        if (index >= 0) {
          _messages[index] = _messages[index].copyWith(
            isPending: false,
            hasFailed: true,
          );
        }
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تعذر إرسال الرسالة: $e')));
    }
  }

  @override
  void dispose() {
    _poller?.cancel();
    for (final subscription in _socketSubscriptions) {
      unawaited(subscription.cancel());
    }
    _chatSocket.dispose();
    _scrollController.removeListener(_handleChatScroll);
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ProfileImageState>(
      valueListenable: ProfileRepository.profileImageNotifier,
      builder: (context, myProfile, _) {
        return Scaffold(
          appBar: AppBar(
            title: const SizedBox.shrink(),
            actions: [
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: _ChatAppBarIdentity(
                  name: widget.otherUser,
                  imageUrl: _otherUserProfileImageUrl,
                  imageKey: _otherUserProfileImageKey,
                  role: _otherUserRole,
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : Stack(
                        children: [
                          ListView.builder(
                            controller: _scrollController,
                            reverse: true,
                            padding: const EdgeInsets.all(16),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final msg =
                                  _messages[_messages.length - 1 - index];
                              final isMe = msg.senderId == _myUserId;
                              final senderImageUrl = isMe
                                  ? myProfile.imageUrl
                                  : (msg.senderProfileImageUrl ??
                                        _otherUserProfileImageUrl);
                              final senderImageKey = isMe
                                  ? myProfile.imageKey
                                  : (msg.senderProfileImageKey ??
                                        _otherUserProfileImageKey);
                              final senderRole = isMe
                                  ? myProfile.role
                                  : (msg.senderRole ?? _otherUserRole);
                              String timeLabel = '';
                              final createdAt = msg.createdAt;
                              if (createdAt != null) {
                                timeLabel = DateFormat(
                                  'dd/MM HH:mm',
                                ).format(createdAt);
                              }
                              final bubble = Container(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.68,
                                ),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? DarbakColors.primaryGreen
                                      : DarbakColors.cardBackground,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildMessageContent(msg, isMe),
                                    if (timeLabel.isNotEmpty || isMe)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (timeLabel.isNotEmpty)
                                              Text(
                                                timeLabel,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: isMe
                                                      ? Colors.white70
                                                      : DarbakColors
                                                            .textSecondary,
                                                ),
                                              ),
                                            if (isMe) ...[
                                              const SizedBox(width: 4),
                                              _MessageStatusIcon(message: msg),
                                            ],
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              );
                              final avatar = ProfileAvatar(
                                imageUrl: senderImageUrl,
                                imageKey: senderImageKey,
                                role: senderRole,
                                radius: 16,
                              );

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  textDirection: TextDirection.ltr,
                                  mainAxisAlignment: isMe
                                      ? MainAxisAlignment.end
                                      : MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: isMe
                                      ? [
                                          bubble,
                                          const SizedBox(width: 8),
                                          avatar,
                                        ]
                                      : [
                                          avatar,
                                          const SizedBox(width: 8),
                                          bubble,
                                        ],
                                ),
                              );
                            },
                          ),
                          PositionedDirectional(
                            end: 16,
                            bottom: 16,
                            child: AnimatedOpacity(
                              opacity: _showScrollToBottom ? 1 : 0,
                              duration: const Duration(milliseconds: 180),
                              child: IgnorePointer(
                                ignoring: !_showScrollToBottom,
                                child: FloatingActionButton.small(
                                  heroTag: 'chat-scroll-to-bottom',
                                  backgroundColor: DarbakColors.primaryGreen,
                                  foregroundColor: Colors.white,
                                  shape: const CircleBorder(),
                                  onPressed: _scrollToBottom,
                                  child: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle_outline_rounded,
                          color: DarbakColors.primaryGreen,
                        ),
                        onPressed: _showAttachmentSheet,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(
                            hintText: 'اكتب رسالتك...',
                            border: InputBorder.none,
                          ),
                          textAlign: TextAlign.start,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.send_rounded,
                          color: DarbakColors.primaryGreen,
                        ),
                        onPressed: _sendMessage,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

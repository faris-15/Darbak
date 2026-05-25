class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.shipmentId,
    required this.senderId,
    required this.receiverId,
    required this.message,
    required this.createdAt,
    this.messageType = 'text',
    this.mediaKey,
    this.mediaUrl,
    this.mediaMimeType,
    this.mediaSizeBytes,
    this.mediaFileName,
    this.thumbnailKey,
    this.thumbnailUrl,
    this.locationLat,
    this.locationLng,
    this.locationLabel,
    this.deliveredAt,
    this.readAt,
    this.senderName,
    this.senderRole,
    this.senderProfileImageKey,
    this.senderProfileImageUrl,
    this.clientMessageId,
    this.isPending = false,
    this.hasFailed = false,
  });

  final int? id;
  final int shipmentId;
  final int senderId;
  final int receiverId;
  final String message;
  final DateTime? createdAt;
  final String messageType;
  final String? mediaKey;
  final String? mediaUrl;
  final String? mediaMimeType;
  final int? mediaSizeBytes;
  final String? mediaFileName;
  final String? thumbnailKey;
  final String? thumbnailUrl;
  final double? locationLat;
  final double? locationLng;
  final String? locationLabel;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final String? senderName;
  final String? senderRole;
  final String? senderProfileImageKey;
  final String? senderProfileImageUrl;
  final String? clientMessageId;
  final bool isPending;
  final bool hasFailed;

  bool get isSent => id != null && !isPending && !hasFailed;
  bool get isDelivered => deliveredAt != null || isRead;
  bool get isRead => readAt != null;
  bool get isText => messageType == 'text';
  bool get isVideo =>
      messageType == 'video' ||
      _looksLikeVideoMedia(
        mediaMimeType: mediaMimeType,
        mediaFileName: mediaFileName,
        mediaUrl: mediaUrl,
      );
  bool get isImage => messageType == 'image' && !isVideo;
  bool get isLocation => messageType == 'location';

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final mediaMimeType = _stringOrNull(json['media_mime_type']);
    final mediaFileName = _stringOrNull(json['media_file_name']);
    final mediaUrl = _stringOrNull(json['media_url']);
    final rawMessageType =
        _stringOrNull(json['message_type']) ??
        _stringOrNull(json['messageType']) ??
        'text';

    return ChatMessage(
      id: _intOrNull(json['id']),
      shipmentId: _intOrNull(json['shipment_id']) ?? 0,
      senderId: _intOrNull(json['sender_id']) ?? 0,
      receiverId: _intOrNull(json['receiver_id']) ?? 0,
      message: json['message']?.toString() ?? '',
      messageType: _normalizeMessageType(
        rawMessageType,
        mediaMimeType: mediaMimeType,
        mediaFileName: mediaFileName,
        mediaUrl: mediaUrl,
      ),
      mediaKey: _stringOrNull(json['media_key']),
      mediaUrl: mediaUrl,
      mediaMimeType: mediaMimeType,
      mediaSizeBytes: _intOrNull(json['media_size_bytes']),
      mediaFileName: mediaFileName,
      thumbnailKey: _stringOrNull(json['thumbnail_key']),
      thumbnailUrl: _stringOrNull(json['thumbnail_url']),
      locationLat: _doubleOrNull(json['location_lat']),
      locationLng: _doubleOrNull(json['location_lng']),
      locationLabel: _stringOrNull(json['location_label']),
      createdAt: _dateOrNull(json['created_at']),
      deliveredAt: _dateOrNull(json['delivered_at']),
      readAt: _dateOrNull(json['read_at']),
      senderName: _stringOrNull(json['sender_name']),
      senderRole: _stringOrNull(json['sender_role']),
      senderProfileImageKey: _stringOrNull(json['sender_profile_image_key']),
      senderProfileImageUrl: _stringOrNull(json['sender_profile_image_url']),
      clientMessageId: _stringOrNull(json['clientMessageId']),
    );
  }

  ChatMessage copyWith({
    int? id,
    int? shipmentId,
    int? senderId,
    int? receiverId,
    String? message,
    DateTime? createdAt,
    String? messageType,
    String? mediaKey,
    String? mediaUrl,
    String? mediaMimeType,
    int? mediaSizeBytes,
    String? mediaFileName,
    String? thumbnailKey,
    String? thumbnailUrl,
    double? locationLat,
    double? locationLng,
    String? locationLabel,
    DateTime? deliveredAt,
    DateTime? readAt,
    String? senderName,
    String? senderRole,
    String? senderProfileImageKey,
    String? senderProfileImageUrl,
    String? clientMessageId,
    bool? isPending,
    bool? hasFailed,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      shipmentId: shipmentId ?? this.shipmentId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      messageType: messageType ?? this.messageType,
      mediaKey: mediaKey ?? this.mediaKey,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaMimeType: mediaMimeType ?? this.mediaMimeType,
      mediaSizeBytes: mediaSizeBytes ?? this.mediaSizeBytes,
      mediaFileName: mediaFileName ?? this.mediaFileName,
      thumbnailKey: thumbnailKey ?? this.thumbnailKey,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      locationLat: locationLat ?? this.locationLat,
      locationLng: locationLng ?? this.locationLng,
      locationLabel: locationLabel ?? this.locationLabel,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      senderName: senderName ?? this.senderName,
      senderRole: senderRole ?? this.senderRole,
      senderProfileImageKey:
          senderProfileImageKey ?? this.senderProfileImageKey,
      senderProfileImageUrl:
          senderProfileImageUrl ?? this.senderProfileImageUrl,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      isPending: isPending ?? this.isPending,
      hasFailed: hasFailed ?? this.hasFailed,
    );
  }

  static int? _intOrNull(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static double? _doubleOrNull(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static DateTime? _dateOrNull(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final text = value.toString();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text)?.toLocal();
  }

  static String? _stringOrNull(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static String _normalizeMessageType(
    String rawType, {
    String? mediaMimeType,
    String? mediaFileName,
    String? mediaUrl,
  }) {
    final type = rawType.toLowerCase();
    if (type == 'location') return 'location';

    final lowerMime = mediaMimeType?.toLowerCase() ?? '';
    final lowerName = mediaFileName?.toLowerCase() ?? '';
    final lowerUrl = mediaUrl?.toLowerCase() ?? '';
    if (_looksLikeVideoMedia(
      mediaMimeType: mediaMimeType,
      mediaFileName: mediaFileName,
      mediaUrl: mediaUrl,
    )) {
      return 'video';
    }

    final isImage =
        lowerMime.startsWith('image/') ||
        lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.png') ||
        lowerName.endsWith('.webp') ||
        lowerName.endsWith('.gif') ||
        lowerUrl.contains('.jpg') ||
        lowerUrl.contains('.jpeg') ||
        lowerUrl.contains('.png') ||
        lowerUrl.contains('.webp') ||
        lowerUrl.contains('.gif');
    if (isImage) return 'image';

    if (type == 'image' || type == 'video') return type;
    return 'text';
  }

  static bool _looksLikeVideoMedia({
    String? mediaMimeType,
    String? mediaFileName,
    String? mediaUrl,
  }) {
    final lowerMime = mediaMimeType?.toLowerCase() ?? '';
    final lowerName = mediaFileName?.toLowerCase() ?? '';
    final lowerUrl = mediaUrl?.toLowerCase() ?? '';
    return lowerMime.startsWith('video/') ||
        lowerName.endsWith('.mp4') ||
        lowerName.endsWith('.mov') ||
        lowerName.endsWith('.m4v') ||
        lowerUrl.contains('.mp4') ||
        lowerUrl.contains('.mov') ||
        lowerUrl.contains('.m4v') ||
        lowerUrl.contains('response-content-type=video');
  }
}

class ChatMessageReceipt {
  const ChatMessageReceipt({
    required this.id,
    required this.shipmentId,
    required this.senderId,
    required this.receiverId,
    this.deliveredAt,
    this.readAt,
  });

  final int id;
  final int shipmentId;
  final int senderId;
  final int receiverId;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  factory ChatMessageReceipt.fromJson(Map<String, dynamic> json) {
    return ChatMessageReceipt(
      id: ChatMessage._intOrNull(json['id']) ?? 0,
      shipmentId: ChatMessage._intOrNull(json['shipment_id']) ?? 0,
      senderId: ChatMessage._intOrNull(json['sender_id']) ?? 0,
      receiverId: ChatMessage._intOrNull(json['receiver_id']) ?? 0,
      deliveredAt: ChatMessage._dateOrNull(json['delivered_at']),
      readAt: ChatMessage._dateOrNull(json['read_at']),
    );
  }
}

class ChatStatusUpdate {
  const ChatStatusUpdate({required this.shipmentId, required this.messages});

  final int shipmentId;
  final List<ChatMessageReceipt> messages;

  factory ChatStatusUpdate.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'];
    return ChatStatusUpdate(
      shipmentId:
          ChatMessage._intOrNull(json['shipmentId']) ??
          ChatMessage._intOrNull(json['shipment_id']) ??
          0,
      messages: rawMessages is List
          ? rawMessages
                .whereType<Map>()
                .map(
                  (item) => ChatMessageReceipt.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
    );
  }
}

class ChatMessageSent {
  const ChatMessageSent({required this.message, this.clientMessageId});

  final ChatMessage message;
  final String? clientMessageId;
}

import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../api_service.dart';
import '../models/chat_message.dart';

class ChatSocketService {
  io.Socket? _socket;
  bool _isConnecting = false;

  final _newMessageController = StreamController<ChatMessage>.broadcast();
  final _sentController = StreamController<ChatMessageSent>.broadcast();
  final _statusController = StreamController<ChatStatusUpdate>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  Stream<ChatMessage> get newMessages => _newMessageController.stream;
  Stream<ChatMessageSent> get sentMessages => _sentController.stream;
  Stream<ChatStatusUpdate> get statusUpdates => _statusController.stream;
  Stream<String> get errors => _errorController.stream;

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect() async {
    if (isConnected || _isConnecting) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) {
      _errorController.add('Missing auth token');
      return;
    }

    _isConnecting = true;
    final socket = io.io(
      ApiService.socketBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableReconnection()
          .disableAutoConnect()
          .build(),
    );

    socket.onConnect((_) {
      _isConnecting = false;
    });
    socket.onConnectError((error) {
      _isConnecting = false;
      _errorController.add(error.toString());
    });
    socket.onError((error) {
      _errorController.add(error.toString());
    });
    socket.onDisconnect((_) {
      _isConnecting = false;
    });

    socket.on('chat:newMessage', (payload) {
      final message = _messageFromPayload(payload);
      if (message != null) _newMessageController.add(message);
    });
    socket.on('chat:messageSent', (payload) {
      final data = _asMap(payload);
      final message = _messageFromPayload(data);
      if (message == null) return;
      _sentController.add(
        ChatMessageSent(
          clientMessageId: data?['clientMessageId']?.toString(),
          message: message,
        ),
      );
    });
    socket.on('chat:statusUpdated', (payload) {
      final data = _asMap(payload);
      if (data == null) return;
      _statusController.add(ChatStatusUpdate.fromJson(data));
    });
    socket.on('chat:error', (payload) {
      final data = _asMap(payload);
      _errorController.add(data?['message']?.toString() ?? payload.toString());
    });

    _socket = socket;
    socket.connect();
  }

  void joinShipment(int shipmentId) {
    _socket?.emit('chat:joinShipment', {'shipmentId': shipmentId});
  }

  void sendMessage({
    required int shipmentId,
    required int receiverId,
    required String message,
    required String clientMessageId,
  }) {
    if (!isConnected) {
      throw StateError('Socket is not connected');
    }
    _socket?.emit('chat:sendMessage', {
      'shipmentId': shipmentId,
      'receiverId': receiverId,
      'message': message,
      'clientMessageId': clientMessageId,
    });
  }

  void markDelivered({
    required int shipmentId,
    List<int> messageIds = const [],
  }) {
    if (!isConnected) return;
    _socket?.emit('chat:markDelivered', {
      'shipmentId': shipmentId,
      'messageIds': messageIds,
    });
  }

  void markRead({required int shipmentId, List<int> messageIds = const []}) {
    if (!isConnected) return;
    _socket?.emit('chat:markRead', {
      'shipmentId': shipmentId,
      'messageIds': messageIds,
    });
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
    unawaited(_newMessageController.close());
    unawaited(_sentController.close());
    unawaited(_statusController.close());
    unawaited(_errorController.close());
  }

  ChatMessage? _messageFromPayload(dynamic payload) {
    final data = _asMap(payload);
    final messageData = _asMap(data?['message']) ?? data;
    if (messageData == null) return null;
    return ChatMessage.fromJson(messageData);
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }
}

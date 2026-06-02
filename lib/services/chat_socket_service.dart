import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../api_service.dart';
import '../models/chat_message.dart';

class ChatSocketService {
  ChatSocketService({this.skipRealConnection = false});

  /// Test seam: when true, [connect] short-circuits and never opens a real
  /// socket. Used by widget tests where dart:io's HTTP overrides reject real
  /// network calls.
  final bool skipRealConnection;

  io.Socket? _socket;
  bool _isConnecting = false;
  bool _disposed = false;

  final _newMessageController = StreamController<ChatMessage>.broadcast();
  final _sentController = StreamController<ChatMessageSent>.broadcast();
  final _statusController = StreamController<ChatStatusUpdate>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  Stream<ChatMessage> get newMessages => _newMessageController.stream;
  Stream<ChatMessageSent> get sentMessages => _sentController.stream;
  Stream<ChatStatusUpdate> get statusUpdates => _statusController.stream;
  Stream<String> get errors => _errorController.stream;

  bool get isConnected => _socket?.connected ?? false;

  void _safeAddError(String message) {
    if (_disposed || _errorController.isClosed) return;
    _errorController.add(message);
  }

  void _safeAddMessage(ChatMessage message) {
    if (_disposed || _newMessageController.isClosed) return;
    _newMessageController.add(message);
  }

  void _safeAddSent(ChatMessageSent sent) {
    if (_disposed || _sentController.isClosed) return;
    _sentController.add(sent);
  }

  void _safeAddStatus(ChatStatusUpdate status) {
    if (_disposed || _statusController.isClosed) return;
    _statusController.add(status);
  }

  Future<void> connect() async {
    if (_disposed || isConnected || _isConnecting) return;
    if (skipRealConnection) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) {
      _safeAddError('Missing auth token');
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
      _safeAddError(error.toString());
    });
    socket.onError((error) {
      _safeAddError(error.toString());
    });
    socket.onDisconnect((_) {
      _isConnecting = false;
    });

    socket.on('chat:newMessage', (payload) {
      final message = _messageFromPayload(payload);
      if (message != null) _safeAddMessage(message);
    });
    socket.on('chat:messageSent', (payload) {
      final data = _asMap(payload);
      final message = _messageFromPayload(data);
      if (message == null) return;
      _safeAddSent(
        ChatMessageSent(
          clientMessageId: data?['clientMessageId']?.toString(),
          message: message,
        ),
      );
    });
    socket.on('chat:statusUpdated', (payload) {
      final data = _asMap(payload);
      if (data == null) return;
      _safeAddStatus(ChatStatusUpdate.fromJson(data));
    });
    socket.on('chat:error', (payload) {
      final data = _asMap(payload);
      _safeAddError(data?['message']?.toString() ?? payload.toString());
    });

    _socket = socket;
    // Wrap the connection attempt: in some environments (e.g. test runners
    // that block real network) the websocket can throw a synchronous platform
    // error during transport setup. Surface it through the error stream
    // instead of crashing the host app.
    try {
      socket.connect();
    } catch (e) {
      _isConnecting = false;
      _safeAddError(e.toString());
    }
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

  /// Test seam: push synthetic socket events without a live connection.
  @visibleForTesting
  void emitTestMessage(ChatMessage message) => _safeAddMessage(message);

  @visibleForTesting
  void emitTestSent(ChatMessageSent sent) => _safeAddSent(sent);

  @visibleForTesting
  void emitTestStatus(ChatStatusUpdate update) => _safeAddStatus(update);

  @visibleForTesting
  void emitTestError(String message) => _safeAddError(message);

  /// Test seam: exercise socket event handlers without a live connection.
  @visibleForTesting
  void dispatchTestSocketEvent(String event, dynamic payload) {
    switch (event) {
      case 'chat:newMessage':
        final message = _messageFromPayload(payload);
        if (message != null) _safeAddMessage(message);
        return;
      case 'chat:messageSent':
        final data = _asMap(payload);
        final message = _messageFromPayload(data);
        if (message == null) return;
        _safeAddSent(
          ChatMessageSent(
            clientMessageId: data?['clientMessageId']?.toString(),
            message: message,
          ),
        );
        return;
      case 'chat:statusUpdated':
        final statusData = _asMap(payload);
        if (statusData == null) return;
        _safeAddStatus(ChatStatusUpdate.fromJson(statusData));
        return;
      case 'chat:error':
        final errorData = _asMap(payload);
        _safeAddError(errorData?['message']?.toString() ?? payload.toString());
        return;
      default:
        return;
    }
  }

  void dispose() {
    _disposed = true;
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

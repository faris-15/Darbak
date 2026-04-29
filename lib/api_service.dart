import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/bid_model.dart';

/// خطأ موحّد من الخادم أو الشبكة؛ [toString] يعيد الرسالة فقط لعرضها في SnackBar.
class DarbakException implements Exception {
  DarbakException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ApiService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:5000/api';
    }
    return 'http://10.0.2.2:5000/api';
  }

  static dynamic _decodeJsonBody(http.Response response) {
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  /// يستخرج حقل [message] من JSON باستخدام UTF-8 ثم يرمي [DarbakException].
  static Never _handleError(http.Response response) {
    final body = utf8.decode(response.bodyBytes);
    var message = 'حدث خطأ';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        message = decoded['message']?.toString() ?? message;
      }
    } catch (_) {
      if (body.trim().isNotEmpty) {
        message = body;
      } else {
        message = 'حدث خطأ (${response.statusCode})';
      }
    }
    throw DarbakException(message);
  }

  static Never _rethrowAsDarbak(Object e) {
    if (e is DarbakException) {
      throw e;
    }
    final s = e.toString();
    if (s.contains('SocketException') ||
        s.contains('Connection refused') ||
        s.contains('Failed host lookup')) {
      throw DarbakException('تعذر الاتصال بالخادم');
    }
    throw DarbakException(s);
  }

  static Future<Map<String, String>> _authHeaders({
    bool jsonContentType = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final headers = <String, String>{};
    if (jsonContentType) {
      headers['Content-Type'] = 'application/json';
    }
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<Map<String, dynamic>> login(
    String identifier,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'identifier': identifier, 'password': password}),
      );
      if (response.statusCode == 200) {
        return _decodeJsonBody(response) as Map<String, dynamic>;
      }
      _handleError(response);
    } catch (e) {
      _rethrowAsDarbak(e);
    }
  }

  static Future<Map<String, dynamic>> register(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      if (response.statusCode == 201) {
        return _decodeJsonBody(response) as Map<String, dynamic>;
      }
      _handleError(response);
    } catch (e) {
      _rethrowAsDarbak(e);
    }
  }

  static Future<List<dynamic>> getShipments() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/shipments'),
        headers: await _authHeaders(jsonContentType: false),
      );
      if (response.statusCode == 200) {
        return _decodeJsonBody(response) as List<dynamic>;
      }
      _handleError(response);
    } catch (e) {
      _rethrowAsDarbak(e);
    }
  }

  static Future<Map<String, dynamic>> createShipment(
    Map<String, dynamic> data,
  ) async {
    try {
      print('[ApiService.createShipment] Payload: $data');
      final response = await http.post(
        Uri.parse('$baseUrl/shipments'),
        headers: await _authHeaders(),
        body: jsonEncode(data),
      );
      if (response.statusCode == 201) {
        return _decodeJsonBody(response) as Map<String, dynamic>;
      }
      _handleError(response);
    } catch (e) {
      print('[ApiService.createShipment] Error: $e');
      _rethrowAsDarbak(e);
    }
  }

  static Future<List<BidModel>> getBids(int shipmentId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bids/shipment/$shipmentId'),
      );
      if (response.statusCode == 200) {
        final rawData = _decodeJsonBody(response) as List<dynamic>;
        return rawData
            .map((item) => BidModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      _handleError(response);
    } catch (e) {
      print('[ApiService.getBids] Error: $e');
      _rethrowAsDarbak(e);
    }
  }

  static Future<Map<String, dynamic>> placeBid(Map<String, dynamic> data) async {
    try {
      print('[ApiService.placeBid] Payload: $data');
      final response = await http.post(
        Uri.parse('$baseUrl/bids'),
        headers: await _authHeaders(),
        body: jsonEncode(data),
      );
      if (response.statusCode == 201) {
        return _decodeJsonBody(response) as Map<String, dynamic>;
      }
      _handleError(response);
    } catch (e) {
      print('[ApiService.placeBid] Error: $e');
      _rethrowAsDarbak(e);
    }
  }

  static Future<Map<String, dynamic>> updateProfile(
    int userId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/auth/profile/$userId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      if (response.statusCode == 200) {
        return _decodeJsonBody(response) as Map<String, dynamic>;
      }
      _handleError(response);
    } catch (e) {
      print('[ApiService.updateProfile] Error: $e');
      _rethrowAsDarbak(e);
    }
  }

  static Future<Map<String, dynamic>> getProfile(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/profile/$userId'),
      );
      if (response.statusCode == 200) {
        return _decodeJsonBody(response) as Map<String, dynamic>;
      }
      _handleError(response);
    } catch (e) {
      print('[ApiService.getProfile] Error: $e');
      _rethrowAsDarbak(e);
    }
  }

  static Future<Map<String, dynamic>> enterBiddingRoom(
    int shipmentId,
    int driverId,
    double bidAmount,
    int estimatedDays,
  ) async {
    return placeBid({
      'shipmentId': shipmentId,
      'driverId': driverId,
      'bidAmount': bidAmount,
      'estimatedDays': estimatedDays,
    });
  }

  static Future<Map<String, dynamic>> exitBiddingRoom(
    int shipmentId,
    int driverId,
  ) async {
    try {
      print(
        '[ApiService.exitBiddingRoom] Input: shipmentId=$shipmentId, driverId=$driverId',
      );
      final response = await http.post(
        Uri.parse('$baseUrl/bidding-rooms/rooms/$shipmentId/exit'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'driverId': driverId}),
      );
      if (response.statusCode == 200) {
        final result = _decodeJsonBody(response) as Map<String, dynamic>;
        print('[ApiService.exitBiddingRoom] Success');
        return result;
      }
      _handleError(response);
    } catch (e) {
      print('[ApiService.exitBiddingRoom] Error: $e');
      _rethrowAsDarbak(e);
    }
  }

  static Future<Map<String, dynamic>> getRoomStatus(int shipmentId) async {
    try {
      print(
        '[ApiService.getRoomStatus] Fetching status for shipmentId=$shipmentId',
      );
      final response = await http.get(
        Uri.parse('$baseUrl/bidding-rooms/rooms/$shipmentId/status'),
      );
      if (response.statusCode == 200) {
        final result = _decodeJsonBody(response) as Map<String, dynamic>;
        print(
          '[ApiService.getRoomStatus] Success: ${result['total_bids']} bids',
        );
        return result;
      }
      _handleError(response);
    } catch (e) {
      print('[ApiService.getRoomStatus] Error: $e');
      _rethrowAsDarbak(e);
    }
  }

  static Future<Map<String, dynamic>> registerTruck(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/trucks/add'),
        headers: await _authHeaders(),
        body: jsonEncode(data),
      );
      if (response.statusCode == 201) {
        return _decodeJsonBody(response) as Map<String, dynamic>;
      }
      _handleError(response);
    } catch (e) {
      print('[ApiService.registerTruck] Error: $e');
      _rethrowAsDarbak(e);
    }
  }

  static Future<List<dynamic>> getMyTrucks() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/trucks/my'),
        headers: await _authHeaders(jsonContentType: false),
      );
      if (response.statusCode == 200) {
        return _decodeJsonBody(response) as List<dynamic>;
      }
      _handleError(response);
    } catch (e) {
      print('[ApiService.getMyTrucks] Error: $e');
      _rethrowAsDarbak(e);
    }
  }

  static Future<Map<String, dynamic>> updateTruck(
    int truckId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/trucks/$truckId'),
        headers: await _authHeaders(),
        body: jsonEncode(data),
      );
      if (response.statusCode == 200) {
        return _decodeJsonBody(response) as Map<String, dynamic>;
      }
      _handleError(response);
    } catch (e) {
      print('[ApiService.updateTruck] Error: $e');
      _rethrowAsDarbak(e);
    }
  }

  static Future<void> deleteTruck(int truckId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/trucks/$truckId'),
        headers: await _authHeaders(jsonContentType: false),
      );
      if (response.statusCode == 200) {
        return;
      }
      _handleError(response);
    } catch (e) {
      print('[ApiService.deleteTruck] Error: $e');
      _rethrowAsDarbak(e);
    }
  }

  static Future<Map<String, dynamic>> addRating(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ratings'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      if (response.statusCode == 201) {
        return _decodeJsonBody(response) as Map<String, dynamic>;
      }
      _handleError(response);
    } catch (e) {
      _rethrowAsDarbak(e);
    }
  }

  static Future<Map<String, dynamic>> getUserRatings(int userId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/ratings/user/$userId'));
      if (response.statusCode == 200) {
        return _decodeJsonBody(response) as Map<String, dynamic>;
      }
      _handleError(response);
    } catch (e) {
      _rethrowAsDarbak(e);
    }
  }

  static Future<Map<String, dynamic>> getNotifications(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notifications/user/$userId'),
      );
      if (response.statusCode == 200) {
        return _decodeJsonBody(response) as Map<String, dynamic>;
      }
      _handleError(response);
    } catch (e) {
      _rethrowAsDarbak(e);
    }
  }

  static Future<void> markNotificationAsRead(int notificationId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/notifications/$notificationId/read'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        return;
      }
      _handleError(response);
    } catch (e) {
      _rethrowAsDarbak(e);
    }
  }

  static Future<Map<String, dynamic>> getShipment(int shipmentId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/shipments/$shipmentId'),
      );
      if (response.statusCode == 200) {
        return _decodeJsonBody(response) as Map<String, dynamic>;
      }
      _handleError(response);
    } catch (e) {
      _rethrowAsDarbak(e);
    }
  }

  static Future<List<dynamic>> getDriverActiveShipments() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/shipments/driver/active'),
        headers: await _authHeaders(jsonContentType: false),
      );
      if (response.statusCode == 200) {
        return _decodeJsonBody(response) as List<dynamic>;
      }
      _handleError(response);
    } catch (e) {
      _rethrowAsDarbak(e);
    }
  }

  static Future<List<dynamic>> getDriverShipments() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/shipments/driver'),
        headers: await _authHeaders(jsonContentType: false),
      );
      if (response.statusCode == 200) {
        return _decodeJsonBody(response) as List<dynamic>;
      }
      _handleError(response);
    } catch (e) {
      _rethrowAsDarbak(e);
    }
  }

  static Future<Map<String, dynamic>> updateShipmentStatus({
    required int shipmentId,
    required String status,
    double? locationLat,
    double? locationLng,
    XFile? epodPhoto,
  }) async {
    try {
      final request = http.MultipartRequest(
        'PATCH',
        Uri.parse('$baseUrl/shipments/$shipmentId/status'),
      );
      request.headers.addAll(await _authHeaders(jsonContentType: false));
      request.fields['status'] = status;
      if (locationLat != null) {
        request.fields['location_lat'] = locationLat.toString();
      }
      if (locationLng != null) {
        request.fields['location_lng'] = locationLng.toString();
      }
      if (epodPhoto != null) {
        request.files.add(
          await http.MultipartFile.fromPath('epodPhoto', epodPhoto.path),
        );
      }

      final streamedResponse = await request.send();
      final responseBytes = await streamedResponse.stream.toBytes();
      final responseBody = utf8.decode(responseBytes);
      if (streamedResponse.statusCode == 200) {
        return jsonDecode(responseBody) as Map<String, dynamic>;
      }
      final synthetic = http.Response(
        responseBody,
        streamedResponse.statusCode,
      );
      _handleError(synthetic);
    } catch (e) {
      _rethrowAsDarbak(e);
    }
  }

  static Future<Map<String, dynamic>> recordShipmentStatus(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/shipment-status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      if (response.statusCode == 201) {
        return _decodeJsonBody(response) as Map<String, dynamic>;
      }
      _handleError(response);
    } catch (e) {
      _rethrowAsDarbak(e);
    }
  }

  static Future<Map<String, dynamic>> getShipmentStatusHistory(
    int shipmentId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/shipment-status/$shipmentId/history'),
      );
      if (response.statusCode == 200) {
        return _decodeJsonBody(response) as Map<String, dynamic>;
      }
      _handleError(response);
    } catch (e) {
      _rethrowAsDarbak(e);
    }
  }

  static Future<Map<String, dynamic>> acceptBid(int bidId) async {
    try {
      print('[ApiService.acceptBid] Accepting bid: $bidId');
      print('[ApiService.acceptBid] URL: $baseUrl/bids/$bidId/accept');
      final response = await http.post(
        Uri.parse('$baseUrl/bids/$bidId/accept'),
        headers: await _authHeaders(),
      );
      print('[ApiService.acceptBid] Status Code: ${response.statusCode}');
      print('[ApiService.acceptBid] Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final result = _decodeJsonBody(response) as Map<String, dynamic>;
        print('[ApiService.acceptBid] Success: $result');
        return result;
      }
      _handleError(response);
    } catch (e) {
      print('[ApiService.acceptBid] Error: $e');
      _rethrowAsDarbak(e);
    }
  }

  static Future<List<dynamic>> getChatMessages(int shipmentId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chat/$shipmentId'),
        headers: await _authHeaders(jsonContentType: false),
      );
      if (response.statusCode == 200) {
        return _decodeJsonBody(response) as List<dynamic>;
      }
      _handleError(response);
    } catch (e) {
      _rethrowAsDarbak(e);
    }
  }

  static Future<Map<String, dynamic>> sendChatMessage({
    required int shipmentId,
    required int receiverId,
    required String message,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat/send'),
        headers: await _authHeaders(),
        body: jsonEncode({
          'shipmentId': shipmentId,
          'receiverId': receiverId,
          'message': message,
        }),
      );
      if (response.statusCode == 201) {
        return _decodeJsonBody(response) as Map<String, dynamic>;
      }
      _handleError(response);
    } catch (e) {
      _rethrowAsDarbak(e);
    }
  }
}

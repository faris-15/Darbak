import 'dart:convert';
// خدمة HTTP للتطبيق؛ [DarbakException.httpStatus] يُستخدم بعد فشل تسجيل الدخول لتجربة مسار Firebase.
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ValueChanged, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/bid_model.dart';
import 'models/review_target_profile.dart';

/// خطأ موحّد من الخادم أو الشبكة؛ [toString] يعيد الرسالة فقط لعرضها في SnackBar.
/// [httpStatus] يُملأ عند رد HTTP من الخادم (مثل 401 لتجربة مسار Firebase بعد فشل تسجيل الدخول).
class DarbakException implements Exception {
  DarbakException(this.message, {this.httpStatus});
  final String message;
  final int? httpStatus;

  @override
  String toString() => message;
}

class ShipmentListQuery {
  final String? status;
  final String? pickupCity;
  final String? dropoffCity;
  final String? cargoCategory;
  final double? minWeight;
  final double? maxWeight;
  final double? minPrice;
  final double? maxPrice;
  final String? truckGroup;
  final String? truckCategory;
  final bool matchMyTruck;
  final int? page;
  final int? limit;

  const ShipmentListQuery({
    this.status,
    this.pickupCity,
    this.dropoffCity,
    this.cargoCategory,
    this.minWeight,
    this.maxWeight,
    this.minPrice,
    this.maxPrice,
    this.truckGroup,
    this.truckCategory,
    this.matchMyTruck = false,
    this.page,
    this.limit,
  });

  Map<String, String> toQueryParameters() {
    String? cleanText(String? value) {
      final trimmed = value?.trim();
      return trimmed == null || trimmed.isEmpty ? null : trimmed;
    }

    String money(double value) =>
        value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);

    return <String, String>{
      if (cleanText(status) != null) 'status': cleanText(status)!,
      if (cleanText(pickupCity) != null) 'pickupCity': cleanText(pickupCity)!,
      if (cleanText(dropoffCity) != null)
        'dropoffCity': cleanText(dropoffCity)!,
      if (cleanText(cargoCategory) != null)
        'cargoCategory': cleanText(cargoCategory)!,
      if (minWeight != null) 'minWeight': money(minWeight!),
      if (maxWeight != null) 'maxWeight': money(maxWeight!),
      if (minPrice != null) 'minPrice': money(minPrice!),
      if (maxPrice != null) 'maxPrice': money(maxPrice!),
      if (cleanText(truckGroup) != null) 'truckGroup': cleanText(truckGroup)!,
      if (cleanText(truckCategory) != null)
        'truckCategory': cleanText(truckCategory)!,
      if (matchMyTruck) 'matchMyTruck': 'true',
      if (page != null) 'page': page.toString(),
      if (limit != null) 'limit': limit.toString(),
    };
  }
}

class PaginatedShipmentsResponse {
  final List<dynamic> data;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  const PaginatedShipmentsResponse({
    required this.data,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  bool get hasMore => page < totalPages;

  factory PaginatedShipmentsResponse.fromDecoded(
    dynamic decoded, {
    required int fallbackPage,
    required int fallbackLimit,
  }) {
    if (decoded is List) {
      return PaginatedShipmentsResponse(
        data: decoded,
        page: fallbackPage,
        limit: fallbackLimit,
        total: decoded.length,
        totalPages: 1,
      );
    }

    if (decoded is Map) {
      final rawData = decoded['data'];
      final pagination = decoded['pagination'];
      final data = rawData is List ? rawData : <dynamic>[];

      int readInt(dynamic value, int fallback) {
        if (value is int) return value;
        if (value is num) return value.toInt();
        return int.tryParse(value?.toString() ?? '') ?? fallback;
      }

      return PaginatedShipmentsResponse(
        data: data,
        page: readInt(
          pagination is Map ? pagination['page'] : null,
          fallbackPage,
        ),
        limit: readInt(
          pagination is Map ? pagination['limit'] : null,
          fallbackLimit,
        ),
        total: readInt(
          pagination is Map ? pagination['total'] : null,
          data.length,
        ),
        totalPages: readInt(
          pagination is Map ? pagination['totalPages'] : null,
          1,
        ),
      );
    }

    throw DarbakException('استجابة الشحنات غير صحيحة');
  }
}

class ApiService {
  static const int maxInsuranceFileBytes = 10 * 1024 * 1024;
  static const int maxProfileImageBytes = 5 * 1024 * 1024;
  static const int maxChatImageBytes = 10 * 1024 * 1024;
  static const int maxChatVideoBytes = 50 * 1024 * 1024;

  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:5000/api';
    }
    return 'http://10.0.2.2:5000/api';
  }

  static String get socketBaseUrl {
    final uri = Uri.parse(baseUrl);
    final path = uri.path.endsWith('/api')
        ? uri.path.substring(0, uri.path.length - 4)
        : uri.path;
    return uri.replace(path: path, query: '', fragment: '').toString();
  }

  static dynamic _decodeJsonBody(http.Response response) {
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  static dynamic _decodeJsonBytes(List<int> bytes) {
    return jsonDecode(utf8.decode(bytes));
  }

  /// يستخرج حقل [message] من JSON باستخدام UTF-8 ثم يرمي [DarbakException].
  static Never _handleError(http.Response response) {
    final body = utf8.decode(response.bodyBytes);
    var message = 'حدث خطأ';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        message = decoded['message']?.toString() ?? message;
        final errors = decoded['errors'];
        if (message == 'حدث خطأ' && errors is List && errors.isNotEmpty) {
          final first = errors.first;
          if (first is Map) {
            message = first['msg']?.toString() ?? 'بيانات الطلب غير صحيحة';
          } else {
            message = first.toString();
          }
        }
      }
    } catch (_) {
      final trimmed = body.trim();
      if (trimmed.isNotEmpty) {
        if (trimmed.toLowerCase().contains('<html') ||
            trimmed.toLowerCase().contains('<!doctype html')) {
          // لا تعرض تفاصيل تقنية (404 HTML، وكيل، إلخ) للمستخدم النهائي.
          message = 'تعذّر إكمال الطلب.';
        } else {
          message = trimmed;
        }
      } else {
        message = 'حدث خطأ (${response.statusCode})';
      }
    }
    throw DarbakException(message, httpStatus: response.statusCode);
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

  static bool _isAllowedOperatingCardFileName(String fileName) {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.pdf') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp');
  }

  static bool _isAllowedInsuranceFileName(String fileName) {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.pdf') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.heic') ||
        lower.endsWith('.heif');
  }

  static bool _isAllowedProfileImageFileName(String fileName) {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp');
  }

  static bool _isAllowedChatImageFileName(String fileName) {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  static bool _isAllowedChatVideoFileName(String fileName) {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v');
  }

  static Stream<List<int>> _trackedByteStream(
    Uint8List bytes,
    ValueChanged<double>? onProgress,
  ) async* {
    const chunkSize = 64 * 1024;
    final total = bytes.length;
    var offset = 0;
    onProgress?.call(0);

    while (offset < total) {
      final end = offset + chunkSize > total ? total : offset + chunkSize;
      yield Uint8List.sublistView(bytes, offset, end);
      offset = end;
      onProgress?.call(offset / total);
    }
  }

  static Future<Map<String, String>> authHeaders({
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

  /// تسجيل دخول التطبيق بعد التحقق من Firebase (انظر POST /api/auth/login-firebase في الخادم).
  /// يُرسل [password] اختيارياً لمزامنة hash كلمة المرور في MySQL مع كلمة مرور Firebase.
  static Future<Map<String, dynamic>> loginWithFirebaseIdToken(
    String idToken, {
    String? password,
  }) async {
    try {
      final body = <String, dynamic>{'idToken': idToken.trim()};
      if (password != null && password.isNotEmpty) {
        body['password'] = password;
      }
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login-firebase'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        return _decodeJsonBody(response) as Map<String, dynamic>;
      }
      _handleError(response);
    } catch (e) {
      _rethrowAsDarbak(e);
    }
  }

  /// طلب إعادة تعيين كلمة المرور: الخادم يتحقق من وجود المستخدم في Firebase ثم يستدعي Google `sendOobCode`.
  static Future<void> requestFirebasePasswordReset(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/password-reset-request'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim().toLowerCase()}),
      );
      if (response.statusCode == 200) return;
      _handleError(response);
    } catch (e) {
      _rethrowAsDarbak(e);
    }
  }

  static Future<Map<String, dynamic>> register(
    Map<String, dynamic> data,
  ) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/auth/register'),
      );

      // Fields
      data.forEach((key, value) {
        if (value != null && key != 'documentPath') {
          request.fields[key] = value.toString();
        }
      });

      // File
      if (data['documentPath'] != null) {
        request.files.add(
          await http.MultipartFile.fromPath('document', data['documentPath']),
        );
      }

      final streamedResponse = await request.send();
      final responseBytes = await streamedResponse.stream.toBytes();
      final responseBody = utf8.decode(responseBytes);

      if (streamedResponse.statusCode == 201) {
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

  static Future<List<dynamic>> getShipments() async {
    final response = await getShipmentPage();
    return response.data;
  }

  static Future<PaginatedShipmentsResponse> getShipmentPage([
    ShipmentListQuery query = const ShipmentListQuery(),
  ]) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/shipments',
      ).replace(queryParameters: query.toQueryParameters());
      final response = await http.get(
        uri,
        headers: await authHeaders(jsonContentType: false),
      );
      if (response.statusCode == 200) {
        return PaginatedShipmentsResponse.fromDecoded(
          _decodeJsonBody(response),
          fallbackPage: query.page ?? 1,
          fallbackLimit: query.limit ?? 20,
        );
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
        headers: await authHeaders(),
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
        headers: await authHeaders(jsonContentType: false),
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

  static Future<Map<String, dynamic>> placeBid(
    Map<String, dynamic> data,
  ) async {
    try {
      print('[ApiService.placeBid] Payload: $data');
      final response = await http.post(
        Uri.parse('$baseUrl/bids'),
        headers: await authHeaders(),
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

  static Future<Map<String, dynamic>> getMyActiveBid() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bids/me/active'),
        headers: await authHeaders(jsonContentType: false),
      );
      if (response.statusCode == 200) {
        return _decodeJsonBody(response) as Map<String, dynamic>;
      }
      _handleError(response);
    } catch (e) {
      _rethrowAsDarbak(e);
    }
  }

  static Future<Map<String, dynamic>> withdrawMyPendingBid({
    int? shipmentId,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (shipmentId != null) body['shipmentId'] = shipmentId;
      final response = await http.post(
        Uri.parse('$baseUrl/bids/me/withdraw'),
        headers: await authHeaders(),
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        return _decodeJsonBody(response) as Map<String, dynamic>;
      }
      _handleError(response);
    } catch (e) {
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
        headers: await authHeaders(),
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
        headers: await authHeaders(jsonContentType: false),
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

  static Future<Map<String, dynamic>> getMyProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/profile/me'),
        headers: await authHeaders(jsonContentType: false),
      );
      if (response.statusCode == 200) {
        final decoded = _decodeJsonBody(response);
        if (decoded is Map && decoded['data'] is Map) {
          return Map<String, dynamic>.from(decoded['data'] as Map);
        }
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
        throw DarbakException('استجابة الملف الشخصي غير صحيحة');
      }
      _handleError(response);
    } catch (e) {
      _rethrowAsDarbak(e);
    }
  }

  static Future<Map<String, dynamic>> updateCurrentProfile(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/profile/update'),
        headers: await authHeaders(),
        body: jsonEncode(data),
      );
      if (response.statusCode == 200) {
        final decoded = _decodeJsonBody(response);
        if (decoded is Map && decoded['data'] is Map) {
          return Map<String, dynamic>.from(decoded['data'] as Map);
        }
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
        throw DarbakException('استجابة تحديث الملف غير صحيحة');
      }
      _handleError(response);
    } catch (e) {
      _rethrowAsDarbak(e);
    }
  }

  static Future<Map<String, dynamic>> uploadProfileImage({
    required String fileName,
    required Uint8List bytes,
    ValueChanged<double>? onProgress,
  }) async {
    final size = bytes.length;
    if (size <= 0) {
      throw DarbakException('الصورة فارغة');
    }
    if (size > maxProfileImageBytes) {
      throw DarbakException('حجم الصورة يجب ألا يتجاوز 5 ميجابايت');
    }
    if (!_isAllowedProfileImageFileName(fileName)) {
      throw DarbakException(
        'نوع الصورة غير مدعوم. الصيغ المسموحة: jpg, jpeg, png, webp',
      );
    }

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/profile/upload-image'),
      );
      request.headers.addAll(await authHeaders(jsonContentType: false));
      request.files.add(
        http.MultipartFile(
          'profileImage',
          _trackedByteStream(bytes, onProgress),
          size,
          filename: fileName,
        ),
      );

      final streamedResponse = await request.send();
      final responseBytes = await streamedResponse.stream.toBytes();

      if (streamedResponse.statusCode == 200 ||
          streamedResponse.statusCode == 201) {
        final decoded = _decodeJsonBytes(responseBytes);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        throw DarbakException('استجابة رفع الصورة غير صحيحة');
      }
      final response = http.Response.bytes(
        responseBytes,
        streamedResponse.statusCode,
      );
      _handleError(response);
    } catch (e) {
      _rethrowAsDarbak(e);
    }
  }

  static Future<Map<String, dynamic>> removeProfileImage() async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/profile/remove-image'),
        headers: await authHeaders(jsonContentType: false),
      );
      if (response.statusCode == 200) {
        return _decodeJsonBody(response) as Map<String, dynamic>;
      }
      _handleError(response);
    } catch (e) {
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

  static Future<Map<String, dynamic>> registerTruck(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/trucks/add'),
        headers: await authHeaders(),
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
        headers: await authHeaders(jsonContentType: false),
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

  static Future<Map<String, dynamic>> uploadTruckInsurance({
    int? truckId,
    required String fileName,
    required Uint8List bytes,
    ValueChanged<double>? onProgress,
  }) async {
    final size = bytes.length;
    if (size <= 0) {
      throw DarbakException('الملف فارغ');
    }
    if (size > maxInsuranceFileBytes) {
      throw DarbakException('حجم الملف يجب ألا يتجاوز 10 ميجابايت');
    }
    if (!_isAllowedInsuranceFileName(fileName)) {
      throw DarbakException('نوع الملف غير مدعوم. ارفع PDF أو صورة فقط');
    }

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
          truckId == null
              ? '$baseUrl/trucks/insurance'
              : '$baseUrl/trucks/$truckId/insurance',
        ),
      );
      request.headers.addAll(await authHeaders(jsonContentType: false));
      request.files.add(
        http.MultipartFile(
          'insurance',
          _trackedByteStream(bytes, onProgress),
          size,
          filename: fileName,
        ),
      );

      final streamedResponse = await request.send();
      final responseBytes = await streamedResponse.stream.toBytes();

      if (streamedResponse.statusCode == 200 ||
          streamedResponse.statusCode == 201) {
        final decoded = _decodeJsonBytes(responseBytes);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
        throw DarbakException('استجابة الخادم غير صحيحة');
      }
      final response = http.Response.bytes(
        responseBytes,
        streamedResponse.statusCode,
      );
      _handleError(response);
    } catch (e) {
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
        headers: await authHeaders(),
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

  static Future<List<dynamic>> setActiveTruck(int truckId) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/trucks/$truckId/active'),
        headers: await authHeaders(jsonContentType: false),
      );
      if (response.statusCode == 200) {
        final decoded = _decodeJsonBody(response);
        if (decoded is Map && decoded['data'] is List) {
          return decoded['data'] as List<dynamic>;
        }
        if (decoded is List) {
          return decoded;
        }
        return getMyTrucks();
      }
      _handleError(response);
    } catch (e) {
      _rethrowAsDarbak(e);
    }
  }

  static Future<void> deleteTruck(int truckId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/trucks/$truckId'),
        headers: await authHeaders(jsonContentType: false),
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
      final payload = Map<String, dynamic>.from(data)..remove('rater_id');
      final response = await http.post(
        Uri.parse('$baseUrl/ratings'),
        headers: await authHeaders(),
        body: jsonEncode(payload),
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
      final response = await http.get(
        Uri.parse('$baseUrl/ratings/user/$userId'),
        headers: await authHeaders(jsonContentType: false),
      );
      if (response.statusCode == 200) {
        return _decodeJsonBody(response) as Map<String, dynamic>;
      }
      _handleError(response);
    } catch (e) {
      _rethrowAsDarbak(e);
    }
  }

  /// ملخص المستخدم لبطاقة شاشة التقييم (`GET /api/users/:id/profile`).
  static Future<ReviewTargetProfile> getUserProfileForReview(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId/profile'),
        headers: await authHeaders(jsonContentType: false),
      );
      if (response.statusCode == 200) {
        final decoded = _decodeJsonBody(response);
        if (decoded is Map) {
          final data = decoded['data'];
          if (data is Map) {
            return ReviewTargetProfile.fromJson(
              Map<String, dynamic>.from(data),
            );
          }
        }
        throw DarbakException('استجابة بيانات المستخدم غير صحيحة');
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
        headers: await authHeaders(jsonContentType: false),
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
        headers: await authHeaders(),
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
        headers: await authHeaders(jsonContentType: false),
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
        headers: await authHeaders(jsonContentType: false),
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
        headers: await authHeaders(jsonContentType: false),
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
      if (epodPhoto != null) {
        final request = http.MultipartRequest(
          'PATCH',
          Uri.parse('$baseUrl/shipments/$shipmentId/status'),
        );
        request.headers.addAll(await authHeaders(jsonContentType: false));
        request.fields['status'] = status;
        if (locationLat != null) {
          request.fields['location_lat'] = locationLat.toString();
        }
        if (locationLng != null) {
          request.fields['location_lng'] = locationLng.toString();
        }
        request.files.add(
          await http.MultipartFile.fromPath('epodPhoto', epodPhoto.path),
        );

        final streamedResponse = await request.send();
        final responseBytes = await streamedResponse.stream.toBytes();
        final responseBody = utf8.decode(responseBytes);
        if (streamedResponse.statusCode == 200) {
          final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
          return decoded;
        }
        final synthetic = http.Response(
          responseBody,
          streamedResponse.statusCode,
        );
        _handleError(synthetic);
      }

      final response = await http.patch(
        Uri.parse('$baseUrl/shipments/$shipmentId/status'),
        headers: await authHeaders(),
        body: jsonEncode({
          'status': status,
          if (locationLat != null) 'location_lat': locationLat,
          if (locationLng != null) 'location_lng': locationLng,
        }),
      );
      if (response.statusCode == 200) {
        return _decodeJsonBody(response) as Map<String, dynamic>;
      }
      _handleError(response);
    } catch (e) {
      _rethrowAsDarbak(e);
    }
  }

  static Future<void> recordShipmentLiveLocation({
    required int shipmentId,
    required double lat,
    required double lng,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/shipments/$shipmentId/live-location'),
        headers: await authHeaders(),
        body: jsonEncode({'location_lat': lat, 'location_lng': lng}),
      );
      if (response.statusCode == 200) {
        return;
      }
      _handleError(response);
    } catch (e) {
      _rethrowAsDarbak(e);
    }
  }

  static Future<String?> getShipmentContractSignedUrl(int shipmentId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/shipments/$shipmentId/contract'),
        headers: await authHeaders(jsonContentType: false),
      );
      if (response.statusCode == 200) {
        final m = _decodeJsonBody(response) as Map<String, dynamic>;
        return m['url']?.toString();
      }
      _handleError(response);
    } catch (e) {
      _rethrowAsDarbak(e);
    }
  }

  static Future<List<dynamic>> getMyChatConversations() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chat/conversations/me'),
        headers: await authHeaders(jsonContentType: false),
      );
      if (response.statusCode == 200) {
        return _decodeJsonBody(response) as List<dynamic>;
      }
      _handleError(response);
    } catch (e) {
      _rethrowAsDarbak(e);
    }
  }

  static Future<void> registerDevicePushToken(String token) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/device-token'),
        headers: await authHeaders(),
        body: jsonEncode({'token': token}),
      );
      if (response.statusCode == 200) {
        return;
      }
      _handleError(response);
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
        headers: await authHeaders(),
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
        headers: await authHeaders(jsonContentType: false),
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
        headers: await authHeaders(),
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

  static Future<Map<String, dynamic>> sendChatMediaMessage({
    required int shipmentId,
    required int receiverId,
    required String fileName,
    required Uint8List bytes,
    String? caption,
    ValueChanged<double>? onProgress,
  }) async {
    final isImage = _isAllowedChatImageFileName(fileName);
    final isVideo = _isAllowedChatVideoFileName(fileName);
    if (!isImage && !isVideo) {
      throw DarbakException('نوع الوسائط غير مدعوم');
    }
    final maxBytes = isVideo ? maxChatVideoBytes : maxChatImageBytes;
    if (bytes.isEmpty) {
      throw DarbakException('ملف الوسائط فارغ');
    }
    if (bytes.length > maxBytes) {
      throw DarbakException(
        isVideo
            ? 'حجم الفيديو يجب ألا يتجاوز 50 ميجابايت'
            : 'حجم الصورة يجب ألا يتجاوز 10 ميجابايت',
      );
    }

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/chat/$shipmentId/media'),
      );
      request.headers.addAll(await authHeaders(jsonContentType: false));
      request.fields['receiverId'] = receiverId.toString();
      request.fields['messageType'] = isVideo ? 'video' : 'image';
      final cleanCaption = caption?.trim();
      if (cleanCaption != null && cleanCaption.isNotEmpty) {
        request.fields['caption'] = cleanCaption;
      }
      request.files.add(
        http.MultipartFile(
          'media',
          _trackedByteStream(bytes, onProgress),
          bytes.length,
          filename: fileName,
        ),
      );

      final streamedResponse = await request.send();
      final responseBytes = await streamedResponse.stream.toBytes();
      if (streamedResponse.statusCode == 201) {
        final decoded = _decodeJsonBytes(responseBytes);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
        throw DarbakException('استجابة إرسال الوسائط غير صحيحة');
      }
      final response = http.Response.bytes(
        responseBytes,
        streamedResponse.statusCode,
        headers: streamedResponse.headers,
        request: streamedResponse.request,
      );
      _handleError(response);
    } catch (e) {
      _rethrowAsDarbak(e);
    }
  }

  static Future<Map<String, dynamic>> sendChatLocationMessage({
    required int shipmentId,
    required int receiverId,
    required double latitude,
    required double longitude,
    String? label,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat/$shipmentId/location'),
        headers: await authHeaders(),
        body: jsonEncode({
          'receiverId': receiverId,
          'latitude': latitude,
          'longitude': longitude,
          if (label != null && label.trim().isNotEmpty) 'label': label.trim(),
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

  static Future<Map<String, dynamic>> markChatMessagesDelivered(
    int shipmentId, {
    List<int> messageIds = const [],
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat/$shipmentId/delivered'),
        headers: await authHeaders(),
        body: jsonEncode({'messageIds': messageIds}),
      );
      if (response.statusCode == 200) {
        return _decodeJsonBody(response) as Map<String, dynamic>;
      }
      _handleError(response);
    } catch (e) {
      _rethrowAsDarbak(e);
    }
  }

  static Future<Map<String, dynamic>> markChatMessagesRead(
    int shipmentId, {
    List<int> messageIds = const [],
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat/$shipmentId/read'),
        headers: await authHeaders(),
        body: jsonEncode({'messageIds': messageIds}),
      );
      if (response.statusCode == 200) {
        return _decodeJsonBody(response) as Map<String, dynamic>;
      }
      _handleError(response);
    } catch (e) {
      _rethrowAsDarbak(e);
    }
  }

  // --- Operating Card ---

  static Future<Map<String, dynamic>?> getOperatingCard() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/operating-card'),
        headers: await authHeaders(jsonContentType: false),
      );
      if (response.statusCode == 200) {
        final decoded = _decodeJsonBody(response);
        return (decoded['data'] as Map?)?.cast<String, dynamic>();
      }
      _handleError(response);
    } catch (e) {
      _rethrowAsDarbak(e);
    }
  }

  static Future<Map<String, dynamic>> uploadOperatingCard({
    required String fileName,
    required Uint8List bytes,
    required String expiryDate,
    ValueChanged<double>? onProgress,
  }) async {
    final size = bytes.length;
    if (size <= 0) throw DarbakException('الملف فارغ');
    if (size > 10 * 1024 * 1024) {
      throw DarbakException('حجم الملف يجب ألا يتجاوز 10 ميجابايت');
    }
    if (!_isAllowedOperatingCardFileName(fileName)) {
      throw DarbakException('نوع الملف غير مدعوم. ارفع PDF أو صورة فقط');
    }

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/operating-card/upload'),
      );
      request.headers.addAll(await authHeaders(jsonContentType: false));
      request.fields['expiry_date'] = expiryDate;
      request.files.add(
        http.MultipartFile(
          'operatingCard',
          _trackedByteStream(bytes, onProgress),
          size,
          filename: fileName,
        ),
      );

      final streamedResponse = await request.send();
      final responseBytes = await streamedResponse.stream.toBytes();

      if (streamedResponse.statusCode == 200 ||
          streamedResponse.statusCode == 201) {
        final decoded = _decodeJsonBytes(responseBytes);
        return Map<String, dynamic>.from(decoded as Map);
      }
      _handleError(http.Response.bytes(responseBytes, streamedResponse.statusCode));
    } catch (e) {
      _rethrowAsDarbak(e);
    }
  }

  static Future<void> deleteOperatingCard() async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/operating-card'),
        headers: await authHeaders(jsonContentType: false),
      );
      if (response.statusCode == 200) return;
      _handleError(response);
    } catch (e) {
      _rethrowAsDarbak(e);
    }
  }
}

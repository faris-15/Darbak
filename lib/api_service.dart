import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'models/bid_model.dart';

class ApiService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:5000/api';
    }
    return 'http://10.0.2.2:5000/api';
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
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Login failed');
      }
    } catch (e) {
      print('[ApiService.login] Error: $e');
      throw Exception(e.toString());
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
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Registration failed');
      }
    } catch (e) {
      print('[ApiService.register] Error: $e');
      throw Exception(e.toString());
    }
  }

  static Future<List<dynamic>> getShipments() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/shipments'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load shipments');
      }
    } catch (e) {
      print('[ApiService.getShipments] Error: $e');
      throw Exception(e.toString());
    }
  }

  static Future<Map<String, dynamic>> createShipment(
    Map<String, dynamic> data,
  ) async {
    try {
      print('[ApiService.createShipment] Payload: $data');
      final response = await http.post(
        Uri.parse('$baseUrl/shipments'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to create shipment');
      }
    } catch (e) {
      print('[ApiService.createShipment] Error: $e');
      throw Exception(e.toString());
    }
  }

  static Future<List<BidModel>> getBids(int shipmentId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/bids/shipment/$shipmentId'),
      );
      if (response.statusCode == 200) {
        final rawData = jsonDecode(response.body) as List<dynamic>;
        return rawData
            .map((item) => BidModel.fromJson(item as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to load bids');
      }
    } catch (e) {
      print('[ApiService.getBids] Error: $e');
      throw Exception(e.toString());
    }
  }

  static Future<Map<String, dynamic>> placeBid(
    Map<String, dynamic> data,
  ) async {
    try {
      print('[ApiService.placeBid] Payload: $data');
      final response = await http.post(
        Uri.parse('$baseUrl/bids'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to place bid');
      }
    } catch (e) {
      print('[ApiService.placeBid] Error: $e');
      throw Exception(e.toString());
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
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to update profile');
      }
    } catch (e) {
      print('[ApiService.updateProfile] Error: $e');
      throw Exception(e.toString());
    }
  }

  static Future<Map<String, dynamic>> getProfile(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/profile/$userId'),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load profile');
      }
    } catch (e) {
      print('[ApiService.getProfile] Error: $e');
      throw Exception(e.toString());
    }
  }

  // Bidding Room APIs
  static Future<Map<String, dynamic>> enterBiddingRoom(
    int shipmentId,
    int driverId,
    double bidAmount,
    int estimatedDays,
  ) async {
    try {
      print(
        '[ApiService.enterBiddingRoom] Input: shipmentId=$shipmentId, driverId=$driverId, bidAmount=$bidAmount, estimatedDays=$estimatedDays',
      );
      final response = await http.post(
        Uri.parse('$baseUrl/bidding-rooms/rooms/$shipmentId/enter'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'driverId': driverId,
          'bidAmount': bidAmount,
          'estimatedDays': estimatedDays,
        }),
      );
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        print('[ApiService.enterBiddingRoom] Success');
        return result;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to place bid');
      }
    } catch (e) {
      print('[ApiService.enterBiddingRoom] Error: $e');
      throw Exception(e.toString());
    }
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
        final result = jsonDecode(response.body);
        print('[ApiService.exitBiddingRoom] Success');
        return result;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to withdraw bid');
      }
    } catch (e) {
      print('[ApiService.exitBiddingRoom] Error: $e');
      throw Exception(e.toString());
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
        final result = jsonDecode(response.body);
        print(
          '[ApiService.getRoomStatus] Success: ${result['total_bids']} bids',
        );
        return result;
      } else {
        throw Exception('Failed to get room status');
      }
    } catch (e) {
      print('[ApiService.getRoomStatus] Error: $e');
      throw Exception(e.toString());
    }
  }

  // Truck APIs
  static Future<Map<String, dynamic>> registerTruck(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/trucks/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to register truck');
      }
    } catch (e) {
      print('[ApiService.registerTruck] Error: $e');
      throw Exception(e.toString());
    }
  }

  static Future<Map<String, dynamic>> getTruckByDriver(int driverId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/trucks/$driverId'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Truck not found');
      }
    } catch (e) {
      print('[ApiService.getTruckByDriver] Error: $e');
      throw Exception(e.toString());
    }
  }

  static Future<Map<String, dynamic>> updateTruck(
    int truckId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/trucks/$truckId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to update truck');
      }
    } catch (e) {
      print('[ApiService.updateTruck] Error: $e');
      throw Exception(e.toString());
    }
  }

  static Future<void> deleteTruck(int truckId) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/trucks/$truckId'));
      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to delete truck');
      }
    } catch (e) {
      print('[ApiService.deleteTruck] Error: $e');
      throw Exception(e.toString());
    }
  }

  // Rating APIs
  static Future<Map<String, dynamic>> addRating(
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ratings'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        jsonDecode(response.body)['message'] ?? 'Failed to add rating',
      );
    }
  }

  static Future<Map<String, dynamic>> getUserRatings(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/ratings/user/$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load ratings');
    }
  }

  // Notification APIs
  static Future<Map<String, dynamic>> getNotifications(int userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/notifications/user/$userId'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load notifications');
    }
  }

  static Future<void> markNotificationAsRead(int notificationId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/notifications/$notificationId/read'),
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to mark notification as read');
    }
  }

  static Future<Map<String, dynamic>> getShipment(int shipmentId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/shipments/$shipmentId'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load shipment');
    }
  }

  // Shipment Status History APIs
  static Future<Map<String, dynamic>> recordShipmentStatus(
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/shipment-status'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to record shipment status');
    }
  }

  static Future<Map<String, dynamic>> getShipmentStatusHistory(
    int shipmentId,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/shipment-status/$shipmentId/history'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load shipment status history');
    }
  }

  // Shipper Bid Management APIs
  static Future<Map<String, dynamic>> acceptBid(int bidId) async {
    try {
      print('[ApiService.acceptBid] Accepting bid: $bidId');
      print('[ApiService.acceptBid] URL: $baseUrl/bids/$bidId/accept');
      final response = await http.post(
        Uri.parse('$baseUrl/bids/$bidId/accept'),
        headers: {'Content-Type': 'application/json'},
      );
      print('[ApiService.acceptBid] Status Code: ${response.statusCode}');
      print('[ApiService.acceptBid] Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        print('[ApiService.acceptBid] Success: $result');
        return result;
      } else {
        try {
          final error = jsonDecode(response.body);
          throw Exception(
            error['message'] ??
                'Failed to accept bid (Status: ${response.statusCode})',
          );
        } catch (parseError) {
          throw Exception(
            'Server error (Status: ${response.statusCode}): ${response.body}',
          );
        }
      }
    } catch (e) {
      print('[ApiService.acceptBid] Error: $e');
      throw Exception(e.toString());
    }
  }
}

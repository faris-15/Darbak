import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://localhost:5000/api';

  static Future<Map<String, dynamic>> login(
    String identifier,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'identifier': identifier, 'password': password}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Login failed');
    }
  }

  static Future<Map<String, dynamic>> register(
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        jsonDecode(response.body)['message'] ?? 'Registration failed',
      );
    }
  }

  static Future<List<dynamic>> getShipments() async {
    final response = await http.get(Uri.parse('$baseUrl/shipments'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load shipments');
    }
  }

  static Future<Map<String, dynamic>> createShipment(
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/shipments'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create shipment');
    }
  }

  static Future<List<dynamic>> getBids(int shipmentId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/bids/shipment/$shipmentId'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load bids');
    }
  }

  static Future<Map<String, dynamic>> placeBid(
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/bids'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        jsonDecode(response.body)['message'] ?? 'Failed to place bid',
      );
    }
  }

  static Future<Map<String, dynamic>> updateProfile(
    int userId,
    Map<String, dynamic> data,
  ) async {
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
  }

  static Future<Map<String, dynamic>> getProfile(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/auth/profile/$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load profile');
    }
  }

  // Bidding Room APIs
  static Future<Map<String, dynamic>> enterBiddingRoom(
    int shipmentId,
    int driverId,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/bidding-rooms/rooms/$shipmentId/enter'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'driverId': driverId}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        jsonDecode(response.body)['message'] ?? 'Failed to enter room',
      );
    }
  }

  static Future<Map<String, dynamic>> exitBiddingRoom(
    int shipmentId,
    int driverId,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/bidding-rooms/rooms/$shipmentId/exit'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'driverId': driverId}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        jsonDecode(response.body)['message'] ?? 'Failed to exit room',
      );
    }
  }

  static Future<Map<String, dynamic>> getRoomStatus(int shipmentId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/bidding-rooms/rooms/$shipmentId/status'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get room status');
    }
  }

  // Truck APIs
  static Future<Map<String, dynamic>> registerTruck(
    Map<String, dynamic> data,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/trucks/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        jsonDecode(response.body)['message'] ?? 'Failed to register truck',
      );
    }
  }

  static Future<Map<String, dynamic>> getTruckByDriver(int driverId) async {
    final response = await http.get(Uri.parse('$baseUrl/trucks/$driverId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Truck not found');
    }
  }

  static Future<Map<String, dynamic>> updateTruck(
    int truckId,
    Map<String, dynamic> data,
  ) async {
    final response = await http.put(
      Uri.parse('$baseUrl/trucks/$truckId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        jsonDecode(response.body)['message'] ?? 'Failed to update truck',
      );
    }
  }

  static Future<void> deleteTruck(int truckId) async {
    final response = await http.delete(Uri.parse('$baseUrl/trucks/$truckId'));
    if (response.statusCode != 200) {
      throw Exception(
        jsonDecode(response.body)['message'] ?? 'Failed to delete truck',
      );
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

  static Future<Map<String, dynamic>> getShipmentStatusHistory(int shipmentId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/shipment-status/$shipmentId/history'),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load shipment status history');
    }
  }
}

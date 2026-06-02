import 'dart:typed_data';

import 'package:darbak/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ShipmentListQuery', () {
    test('omits blank filters and formats numeric values for the API', () {
      const query = ShipmentListQuery(
        status: ' bidding ',
        pickupCity: '   ',
        dropoffCity: 'Jeddah',
        cargoCategory: 'food',
        minWeight: 10,
        maxWeight: 12.5,
        minPrice: 100,
        maxPrice: 125.75,
        truckGroup: 'medium',
        truckCategory: 'box',
        matchMyTruck: true,
        page: 2,
        limit: 25,
      );

      expect(query.toQueryParameters(), {
        'status': 'bidding',
        'dropoffCity': 'Jeddah',
        'cargoCategory': 'food',
        'minWeight': '10',
        'maxWeight': '12.50',
        'minPrice': '100',
        'maxPrice': '125.75',
        'truckGroup': 'medium',
        'truckCategory': 'box',
        'matchMyTruck': 'true',
        'page': '2',
        'limit': '25',
      });
    });

    test('does not include matchMyTruck when disabled', () {
      const query = ShipmentListQuery(matchMyTruck: false);
      expect(query.toQueryParameters(), isEmpty);
    });
  });

  group('PaginatedShipmentsResponse', () {
    test('hydrates legacy list response with fallback pagination', () {
      final response = PaginatedShipmentsResponse.fromDecoded(
        [
          {'id': 1},
          {'id': 2},
        ],
        fallbackPage: 3,
        fallbackLimit: 20,
      );

      expect(response.data, hasLength(2));
      expect(response.page, 3);
      expect(response.limit, 20);
      expect(response.total, 2);
      expect(response.totalPages, 1);
      expect(response.hasMore, isFalse);
    });

    test('hydrates paginated map response and parses numeric strings', () {
      final response = PaginatedShipmentsResponse.fromDecoded(
        {
          'data': [
            {'id': 1},
          ],
          'pagination': {
            'page': '2',
            'limit': '10',
            'total': '21',
            'totalPages': '3',
          },
        },
        fallbackPage: 1,
        fallbackLimit: 20,
      );

      expect(response.page, 2);
      expect(response.limit, 10);
      expect(response.total, 21);
      expect(response.totalPages, 3);
      expect(response.hasMore, isTrue);
    });

    test('uses safe fallbacks when map response has malformed pagination', () {
      final response = PaginatedShipmentsResponse.fromDecoded(
        {'data': 'not-a-list', 'pagination': 'not-a-map'},
        fallbackPage: 4,
        fallbackLimit: 15,
      );

      expect(response.data, isEmpty);
      expect(response.page, 4);
      expect(response.limit, 15);
      expect(response.total, 0);
      expect(response.totalPages, 1);
    });

    test('throws DarbakException for unsupported response shape', () {
      expect(
        () => PaginatedShipmentsResponse.fromDecoded(
          'bad',
          fallbackPage: 1,
          fallbackLimit: 20,
        ),
        throwsA(isA<DarbakException>()),
      );
    });
  });

  group('ApiService.authHeaders', () {
    test('adds JSON content type and bearer token by default', () async {
      SharedPreferences.setMockInitialValues({'auth_token': 'token-123'});

      final headers = await ApiService.authHeaders();

      expect(headers['Content-Type'], 'application/json');
      expect(headers['Authorization'], 'Bearer token-123');
    });

    test('can omit JSON content type and skips empty tokens', () async {
      SharedPreferences.setMockInitialValues({'auth_token': ''});

      final headers = await ApiService.authHeaders(jsonContentType: false);

      expect(headers.containsKey('Content-Type'), isFalse);
      expect(headers.containsKey('Authorization'), isFalse);
    });
  });

  test('DarbakException.toString returns user-facing message only', () {
    final error = DarbakException('تعذر الاتصال', httpStatus: 503);
    expect(error.toString(), 'تعذر الاتصال');
    expect(error.httpStatus, 503);
  });

  test('socketBaseUrl strips /api path from the HTTP base URL', () {
    expect(ApiService.socketBaseUrl.endsWith('/api'), isFalse);
  });

  group('ApiService upload preflight validation', () {
    test('uploadProfileImage rejects empty bytes before network', () async {
      await expectLater(
        ApiService.uploadProfileImage(
          fileName: 'avatar.png',
          bytes: Uint8List(0),
        ),
        throwsA(
          isA<DarbakException>().having(
            (e) => e.message,
            'message',
            'الصورة فارغة',
          ),
        ),
      );
    });

    test('uploadProfileImage rejects oversized images', () async {
      await expectLater(
        ApiService.uploadProfileImage(
          fileName: 'avatar.png',
          bytes: Uint8List(ApiService.maxProfileImageBytes + 1),
        ),
        throwsA(
          isA<DarbakException>().having(
            (e) => e.message,
            'message',
            contains('5 ميجابايت'),
          ),
        ),
      );
    });

    test('uploadProfileImage rejects unsupported file extensions', () async {
      await expectLater(
        ApiService.uploadProfileImage(
          fileName: 'avatar.gif',
          bytes: Uint8List.fromList([1]),
        ),
        throwsA(
          isA<DarbakException>().having(
            (e) => e.message,
            'message',
            contains('نوع الصورة غير مدعوم'),
          ),
        ),
      );
    });

    test('uploadTruckInsurance rejects empty, oversized, and unsupported files', () async {
      await expectLater(
        ApiService.uploadTruckInsurance(
          fileName: 'insurance.pdf',
          bytes: Uint8List(0),
        ),
        throwsA(isA<DarbakException>()),
      );

      await expectLater(
        ApiService.uploadTruckInsurance(
          fileName: 'insurance.pdf',
          bytes: Uint8List(ApiService.maxInsuranceFileBytes + 1),
        ),
        throwsA(
          isA<DarbakException>().having(
            (e) => e.message,
            'message',
            contains('10 ميجابايت'),
          ),
        ),
      );

      await expectLater(
        ApiService.uploadTruckInsurance(
          fileName: 'insurance.exe',
          bytes: Uint8List.fromList([1]),
        ),
        throwsA(
          isA<DarbakException>().having(
            (e) => e.message,
            'message',
            contains('نوع الملف غير مدعوم'),
          ),
        ),
      );
    });

    test('sendChatMediaMessage rejects unsupported, empty, and oversized media', () async {
      await expectLater(
        ApiService.sendChatMediaMessage(
          shipmentId: 1,
          receiverId: 2,
          fileName: 'media.pdf',
          bytes: Uint8List.fromList([1]),
        ),
        throwsA(
          isA<DarbakException>().having(
            (e) => e.message,
            'message',
            contains('نوع الوسائط غير مدعوم'),
          ),
        ),
      );

      await expectLater(
        ApiService.sendChatMediaMessage(
          shipmentId: 1,
          receiverId: 2,
          fileName: 'photo.jpg',
          bytes: Uint8List(0),
        ),
        throwsA(
          isA<DarbakException>().having(
            (e) => e.message,
            'message',
            'ملف الوسائط فارغ',
          ),
        ),
      );

      await expectLater(
        ApiService.sendChatMediaMessage(
          shipmentId: 1,
          receiverId: 2,
          fileName: 'photo.jpg',
          bytes: Uint8List(ApiService.maxChatImageBytes + 1),
        ),
        throwsA(
          isA<DarbakException>().having(
            (e) => e.message,
            'message',
            contains('10 ميجابايت'),
          ),
        ),
      );

      await expectLater(
        ApiService.sendChatMediaMessage(
          shipmentId: 1,
          receiverId: 2,
          fileName: 'clip.mp4',
          bytes: Uint8List(ApiService.maxChatVideoBytes + 1),
        ),
        throwsA(
          isA<DarbakException>().having(
            (e) => e.message,
            'message',
            contains('50 ميجابايت'),
          ),
        ),
      );
    });

    test('uploadOperatingCard rejects invalid local file candidates', () async {
      await expectLater(
        ApiService.uploadOperatingCard(
          fileName: 'card.pdf',
          bytes: Uint8List(0),
          expiryDate: '2030-01-01',
        ),
        throwsA(isA<DarbakException>()),
      );

      await expectLater(
        ApiService.uploadOperatingCard(
          fileName: 'card.pdf',
          bytes: Uint8List(10 * 1024 * 1024 + 1),
          expiryDate: '2030-01-01',
        ),
        throwsA(
          isA<DarbakException>().having(
            (e) => e.message,
            'message',
            contains('10 ميجابايت'),
          ),
        ),
      );

      await expectLater(
        ApiService.uploadOperatingCard(
          fileName: 'card.exe',
          bytes: Uint8List.fromList([1]),
          expiryDate: '2030-01-01',
        ),
        throwsA(
          isA<DarbakException>().having(
            (e) => e.message,
            'message',
            contains('نوع الملف غير مدعوم'),
          ),
        ),
      );
    });
  });
}

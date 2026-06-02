import 'dart:typed_data';

import 'package:darbak/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/http_mock.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'auth_token': 't'});
  });

  group('utility paths', () {
    test('socketBaseUrl strips the /api suffix when present', () {
      // baseUrl ends with /api, so socketBaseUrl should strip it.
      expect(ApiService.socketBaseUrl, isNot(contains('/api')));
      expect(ApiService.socketBaseUrl, contains('5000'));
    });

    test('error decoder falls back to first stringified entry when '
        'errors[].msg is missing', () async {
      await withMockedHttp(
        setup: (r) => r.respond(
          'POST',
          '/api/auth/login',
          statusCode: 400,
          body: {
            'errors': ['oops'],
          },
        ),
        callback: (_) async {
          await expectLater(
            ApiService.login('u', 'p'),
            throwsA(isA<DarbakException>()
                .having((e) => e.message, 'message', 'oops')),
          );
        },
      );
    });

    test('errors array with empty list keeps default message', () async {
      await withMockedHttp(
        setup: (r) => r.respond('POST', '/api/auth/login',
            statusCode: 500, body: {'errors': []}),
        callback: (_) async {
          await expectLater(
            ApiService.login('u', 'p'),
            throwsA(isA<DarbakException>()
                .having((e) => e.message, 'message', 'حدث خطأ')),
          );
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // Error paths — every endpoint surfaces a DarbakException on non-success
  // ------------------------------------------------------------------

  group('error paths bubble up DarbakException', () {
    Future<void> _expectError(
      Future<dynamic> Function() invoke, {
      required String method,
      required String path,
      int statusCode = 500,
      Object body = const {'message': 'oops'},
    }) async {
      await withMockedHttp(
        setup: (r) => r.respond(method, path,
            statusCode: statusCode, body: body),
        callback: (_) async {
          await expectLater(invoke(), throwsA(isA<DarbakException>()));
        },
      );
    }

    test('updateCurrentProfile error + invalid payloads', () async {
      await _expectError(
        () => ApiService.updateCurrentProfile({'fullName': 'X'}),
        method: 'PUT',
        path: '/api/profile/update',
      );

      await withMockedHttp(
        setup: (r) => r.respond('PUT', '/api/profile/update',
            body: {'data': 'not-map'}),
        callback: (_) async {
          // decoded is Map but data isn't Map → returns full map fallback
          final out = await ApiService.updateCurrentProfile({});
          expect(out['data'], 'not-map');
        },
      );
    });

    test('uploadProfileImage rejects empty / oversize / bad-extension', () {
      expect(
        () => ApiService.uploadProfileImage(
          fileName: 'a.png',
          bytes: Uint8List(0),
        ),
        throwsA(isA<DarbakException>()),
      );
      expect(
        () => ApiService.uploadProfileImage(
          fileName: 'a.png',
          bytes: Uint8List(ApiService.maxProfileImageBytes + 1),
        ),
        throwsA(isA<DarbakException>()),
      );
      expect(
        () => ApiService.uploadProfileImage(
          fileName: 'a.exe',
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
        throwsA(isA<DarbakException>()),
      );
    });

    test('uploadProfileImage non-map decoded response throws', () async {
      await withMockedHttp(
        setup: (r) => r.respond(
          'POST',
          '/api/profile/upload-image',
          body: ['not', 'a', 'map'],
        ),
        callback: (_) async {
          await expectLater(
            ApiService.uploadProfileImage(
              fileName: 'a.png',
              bytes: Uint8List.fromList(List.filled(8, 1)),
            ),
            throwsA(isA<DarbakException>()),
          );
        },
      );
    });

    test('removeProfileImage 500 throws', () => _expectError(
          () => ApiService.removeProfileImage(),
          method: 'DELETE',
          path: '/api/profile/remove-image',
        ));

    test('exitBiddingRoom 500 throws', () => _expectError(
          () => ApiService.exitBiddingRoom(3, 1),
          method: 'POST',
          path: '/api/bidding-rooms/rooms/3/exit',
        ));

    test('getRoomStatus 500 throws', () => _expectError(
          () => ApiService.getRoomStatus(3),
          method: 'GET',
          path: '/api/bidding-rooms/rooms/3/status',
        ));

    test('registerTruck error', () => _expectError(
          () => ApiService.registerTruck({'a': 1}),
          method: 'POST',
          path: '/api/trucks/add',
        ));

    test('uploadTruckInsurance non-map decoded throws', () async {
      await withMockedHttp(
        setup: (r) => r.respond('POST', '/api/trucks/insurance',
            body: ['not', 'a', 'map']),
        callback: (_) async {
          await expectLater(
            ApiService.uploadTruckInsurance(
              fileName: 'doc.pdf',
              bytes: Uint8List.fromList(List.filled(16, 1)),
            ),
            throwsA(isA<DarbakException>()),
          );
        },
      );
    });

    test('uploadTruckInsurance validation: empty / oversize / bad ext', () {
      expect(
        () => ApiService.uploadTruckInsurance(
          fileName: 'doc.pdf',
          bytes: Uint8List(0),
        ),
        throwsA(isA<DarbakException>()),
      );
      expect(
        () => ApiService.uploadTruckInsurance(
          fileName: 'doc.pdf',
          bytes: Uint8List(ApiService.maxInsuranceFileBytes + 1),
        ),
        throwsA(isA<DarbakException>()),
      );
      expect(
        () => ApiService.uploadTruckInsurance(
          fileName: 'doc.exe',
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
        throwsA(isA<DarbakException>()),
      );
    });

    test('updateTruck error', () => _expectError(
          () => ApiService.updateTruck(7, {'x': 1}),
          method: 'PUT',
          path: '/api/trucks/7',
        ));

    test('setActiveTruck error', () => _expectError(
          () => ApiService.setActiveTruck(7),
          method: 'PATCH',
          path: '/api/trucks/7/active',
        ));

    test('deleteTruck error', () => _expectError(
          () => ApiService.deleteTruck(7),
          method: 'DELETE',
          path: '/api/trucks/7',
        ));

    test('addRating error', () => _expectError(
          () => ApiService.addRating({'stars': 5}),
          method: 'POST',
          path: '/api/ratings',
        ));

    test('getUserRatings error', () => _expectError(
          () => ApiService.getUserRatings(1),
          method: 'GET',
          path: '/api/ratings/user/1',
        ));

    test('getUserProfileForReview 500 throws', () => _expectError(
          () => ApiService.getUserProfileForReview(5),
          method: 'GET',
          path: '/api/users/5/profile',
        ));

    test('getNotifications error', () => _expectError(
          () => ApiService.getNotifications(1),
          method: 'GET',
          path: '/api/notifications/user/1',
        ));

    test('markNotificationAsRead error', () => _expectError(
          () => ApiService.markNotificationAsRead(7),
          method: 'POST',
          path: '/api/notifications/7/read',
        ));

    test('getShipment error', () => _expectError(
          () => ApiService.getShipment(9),
          method: 'GET',
          path: '/api/shipments/9',
        ));

    test('getDriverActiveShipments error', () => _expectError(
          () => ApiService.getDriverActiveShipments(),
          method: 'GET',
          path: '/api/shipments/driver/active',
        ));

    test('getDriverShipments error', () => _expectError(
          () => ApiService.getDriverShipments(),
          method: 'GET',
          path: '/api/shipments/driver',
        ));

    test('updateShipmentStatus json error', () => _expectError(
          () => ApiService.updateShipmentStatus(
              shipmentId: 1, status: 'delivered'),
          method: 'PATCH',
          path: '/api/shipments/1/status',
        ));

    test('recordShipmentLiveLocation error', () => _expectError(
          () => ApiService.recordShipmentLiveLocation(
              shipmentId: 1, lat: 0, lng: 0),
          method: 'POST',
          path: '/api/shipments/1/live-location',
        ));

    test('getShipmentContractSignedUrl error', () => _expectError(
          () => ApiService.getShipmentContractSignedUrl(1),
          method: 'GET',
          path: '/api/shipments/1/contract',
        ));

    test('getMyChatConversations error', () => _expectError(
          () => ApiService.getMyChatConversations(),
          method: 'GET',
          path: '/api/chat/conversations/me',
        ));

    test('registerDevicePushToken error', () => _expectError(
          () => ApiService.registerDevicePushToken('fcm-x'),
          method: 'POST',
          path: '/api/auth/device-token',
        ));

    test('recordShipmentStatus error', () => _expectError(
          () => ApiService.recordShipmentStatus({'shipment_id': 1}),
          method: 'POST',
          path: '/api/shipment-status',
        ));

    test('getShipmentStatusHistory error', () => _expectError(
          () => ApiService.getShipmentStatusHistory(5),
          method: 'GET',
          path: '/api/shipment-status/5/history',
        ));

    test('acceptBid error', () => _expectError(
          () => ApiService.acceptBid(7),
          method: 'POST',
          path: '/api/bids/7/accept',
        ));

    test('getChatMessages error', () => _expectError(
          () => ApiService.getChatMessages(1),
          method: 'GET',
          path: '/api/chat/1',
        ));

    test('sendChatMessage error', () => _expectError(
          () => ApiService.sendChatMessage(
              shipmentId: 1, receiverId: 2, message: 'hi'),
          method: 'POST',
          path: '/api/chat/send',
        ));

    test('sendChatMediaMessage rejects unsupported extension', () {
      expect(
        () => ApiService.sendChatMediaMessage(
          shipmentId: 1,
          receiverId: 2,
          fileName: 'bad.exe',
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
        throwsA(isA<DarbakException>()),
      );
    });

    test('sendChatMediaMessage rejects empty / oversize image / video', () {
      expect(
        () => ApiService.sendChatMediaMessage(
          shipmentId: 1,
          receiverId: 2,
          fileName: 'photo.jpg',
          bytes: Uint8List(0),
        ),
        throwsA(isA<DarbakException>()),
      );
      expect(
        () => ApiService.sendChatMediaMessage(
          shipmentId: 1,
          receiverId: 2,
          fileName: 'photo.jpg',
          bytes: Uint8List(ApiService.maxChatImageBytes + 1),
        ),
        throwsA(isA<DarbakException>()),
      );
      expect(
        () => ApiService.sendChatMediaMessage(
          shipmentId: 1,
          receiverId: 2,
          fileName: 'clip.mp4',
          bytes: Uint8List(ApiService.maxChatVideoBytes + 1),
        ),
        throwsA(isA<DarbakException>()),
      );
    });

    test('sendChatMediaMessage non-map decoded response throws', () async {
      await withMockedHttp(
        setup: (r) => r.respond(
          'POST',
          '/api/chat/2/media',
          statusCode: 201,
          body: ['not', 'a', 'map'],
        ),
        callback: (_) async {
          await expectLater(
            ApiService.sendChatMediaMessage(
              shipmentId: 2,
              receiverId: 3,
              fileName: 'p.jpg',
              bytes: Uint8List.fromList(List.filled(16, 1)),
            ),
            throwsA(isA<DarbakException>()),
          );
        },
      );
    });

    test('sendChatLocationMessage error', () => _expectError(
          () => ApiService.sendChatLocationMessage(
              shipmentId: 1, receiverId: 2, latitude: 1, longitude: 2),
          method: 'POST',
          path: '/api/chat/1/location',
        ));

    test('markChatMessagesDelivered error', () => _expectError(
          () => ApiService.markChatMessagesDelivered(1),
          method: 'POST',
          path: '/api/chat/1/delivered',
        ));

    test('markChatMessagesRead error', () => _expectError(
          () => ApiService.markChatMessagesRead(1),
          method: 'POST',
          path: '/api/chat/1/read',
        ));

    test('getOperatingCard error', () => _expectError(
          () => ApiService.getOperatingCard(),
          method: 'GET',
          path: '/api/operating-card',
        ));

    test('uploadOperatingCard validation', () {
      expect(
        () => ApiService.uploadOperatingCard(
          fileName: 'card.pdf',
          bytes: Uint8List(0),
          expiryDate: '2030',
        ),
        throwsA(isA<DarbakException>()),
      );
      expect(
        () => ApiService.uploadOperatingCard(
          fileName: 'card.pdf',
          bytes: Uint8List(10 * 1024 * 1024 + 1),
          expiryDate: '2030',
        ),
        throwsA(isA<DarbakException>()),
      );
      expect(
        () => ApiService.uploadOperatingCard(
          fileName: 'card.exe',
          bytes: Uint8List.fromList([1, 2, 3]),
          expiryDate: '2030',
        ),
        throwsA(isA<DarbakException>()),
      );
    });

    test('deleteOperatingCard error', () => _expectError(
          () => ApiService.deleteOperatingCard(),
          method: 'DELETE',
          path: '/api/operating-card',
        ));
  });

  // ------------------------------------------------------------------
  // updateShipmentStatus multipart path with epodPhoto
  // ------------------------------------------------------------------

  group('updateShipmentStatus multipart', () {
    test('happy path sends multipart with epod file + location', () async {
      await withMockedHttp(
        setup: (r) => r.respond(
          'PATCH',
          '/api/shipments/5/status',
          body: {'id': 5, 'status': 'delivered'},
        ),
        callback: (r) async {
          // Use any existing file path; the test client never reads bytes.
          final epod = XFile('pubspec.yaml');
          final result = await ApiService.updateShipmentStatus(
            shipmentId: 5,
            status: 'delivered',
            locationLat: 24.7,
            locationLng: 46.7,
            epodPhoto: epod,
          );
          expect(result['status'], 'delivered');
          final raw = r.requests.single.body;
          expect(raw, contains('delivered'));
          expect(raw, contains('24.7'));
          expect(raw, contains('46.7'));
        },
      );
    });

    test('multipart server error propagates as DarbakException', () async {
      await withMockedHttp(
        setup: (r) => r.respond(
          'PATCH',
          '/api/shipments/5/status',
          statusCode: 500,
          body: {'message': 'fail'},
        ),
        callback: (_) async {
          await expectLater(
            ApiService.updateShipmentStatus(
              shipmentId: 5,
              status: 'delivered',
              epodPhoto: XFile('pubspec.yaml'),
            ),
            throwsA(isA<DarbakException>()),
          );
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // register multipart upload with documentPath
  // ------------------------------------------------------------------

  group('register multipart with documentPath', () {
    test('attaches multipart file when documentPath is present', () async {
      await withMockedHttp(
        setup: (r) => r.respond(
          'POST',
          '/api/auth/register',
          statusCode: 201,
          body: {'id': 1, 'token': 't'},
        ),
        callback: (r) async {
          final result = await ApiService.register({
            'full_name': 'Tester',
            'phone': '0500000000',
            'documentPath': 'pubspec.yaml',
          });
          expect(result['id'], 1);
          expect(r.requests.single.method, 'POST');
        },
      );
    });
  });
}

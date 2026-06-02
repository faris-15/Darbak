import 'dart:convert';
import 'dart:typed_data';

import 'package:darbak/api_service.dart';
import 'package:darbak/models/review_target_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/http_mock.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'auth_token': 'token-XYZ'});
  });

  // ------------------------------------------------------------------
  // Auth — login / firebase / password reset / register
  // ------------------------------------------------------------------

  group('login', () {
    test('returns decoded JSON on 200', () async {
      await withMockedHttp(
        setup: (r) {
          r.respond('POST', '/api/auth/login',
              body: {'token': 't', 'user': {'id': 1}});
        },
        callback: (r) async {
          final result =
              await ApiService.login('user@test.io', 'p@ssword');
          expect(result['token'], 't');
          expect(r.requests.single.method, 'POST');
          expect(r.requests.single.decodedJson(), {
            'identifier': 'user@test.io',
            'password': 'p@ssword',
          });
        },
      );
    });

    test('throws DarbakException with httpStatus on 401', () async {
      await withMockedHttp(
        setup: (r) => r.respond('POST', '/api/auth/login',
            statusCode: 401, body: {'message': 'بيانات غير صحيحة'}),
        callback: (_) async {
          await expectLater(
            ApiService.login('u', 'p'),
            throwsA(isA<DarbakException>()
                .having((e) => e.message, 'message', contains('بيانات'))
                .having((e) => e.httpStatus, 'httpStatus', 401)),
          );
        },
      );
    });

    test('extracts first error message from errors array', () async {
      await withMockedHttp(
        setup: (r) => r.respond('POST', '/api/auth/login',
            statusCode: 400,
            body: {
              'errors': [
                {'msg': 'حقل ناقص'}
              ]
            }),
        callback: (_) async {
          await expectLater(
            ApiService.login('u', 'p'),
            throwsA(isA<DarbakException>()
                .having((e) => e.message, 'message', 'حقل ناقص')),
          );
        },
      );
    });

    test('falls back to "حدث خطأ" when JSON has no message', () async {
      await withMockedHttp(
        setup: (r) => r.respond('POST', '/api/auth/login',
            statusCode: 500, body: {}),
        callback: (_) async {
          await expectLater(
            ApiService.login('u', 'p'),
            throwsA(isA<DarbakException>()
                .having((e) => e.message, 'message', 'حدث خطأ')),
          );
        },
      );
    });

    test('hides HTML error bodies', () async {
      await withMockedHttp(
        setup: (r) => r.respond('POST', '/api/auth/login',
            statusCode: 502, body: '<!DOCTYPE html><html>boom</html>'),
        callback: (_) async {
          await expectLater(
            ApiService.login('u', 'p'),
            throwsA(isA<DarbakException>()
                .having((e) => e.message, 'message', 'تعذّر إكمال الطلب.')),
          );
        },
      );
    });

    test('returns plain text body when not JSON and not HTML', () async {
      await withMockedHttp(
        setup: (r) => r.respond('POST', '/api/auth/login',
            statusCode: 502, body: 'service down'),
        callback: (_) async {
          await expectLater(
            ApiService.login('u', 'p'),
            throwsA(isA<DarbakException>()
                .having((e) => e.message, 'message', 'service down')),
          );
        },
      );
    });

    test('returns "حدث خطأ (code)" for empty body', () async {
      await withMockedHttp(
        setup: (r) => r.respond('POST', '/api/auth/login',
            statusCode: 418, body: ''),
        callback: (_) async {
          await expectLater(
            ApiService.login('u', 'p'),
            throwsA(isA<DarbakException>()
                .having((e) => e.message, 'message', 'حدث خطأ (418)')),
          );
        },
      );
    });
  });

  group('loginWithFirebaseIdToken', () {
    test('sends idToken and optional password', () async {
      await withMockedHttp(
        setup: (r) =>
            r.respond('POST', '/api/auth/login-firebase', body: {'ok': true}),
        callback: (r) async {
          await ApiService.loginWithFirebaseIdToken(' ABC ',
              password: 'pw');
          expect(r.requests.single.decodedJson(),
              {'idToken': 'ABC', 'password': 'pw'});
        },
      );
    });

    test('omits password when empty', () async {
      await withMockedHttp(
        setup: (r) =>
            r.respond('POST', '/api/auth/login-firebase', body: {'ok': true}),
        callback: (r) async {
          await ApiService.loginWithFirebaseIdToken('TOKEN');
          expect(r.requests.single.decodedJson(), {'idToken': 'TOKEN'});
        },
      );
    });

    test('throws on non-200', () async {
      await withMockedHttp(
        setup: (r) => r.respond('POST', '/api/auth/login-firebase',
            statusCode: 500, body: {'message': 'oops'}),
        callback: (_) async {
          await expectLater(
            ApiService.loginWithFirebaseIdToken('x'),
            throwsA(isA<DarbakException>()),
          );
        },
      );
    });
  });

  group('requestFirebasePasswordReset', () {
    test('lowercases and trims the email', () async {
      await withMockedHttp(
        setup: (r) =>
            r.respond('POST', '/api/auth/password-reset-request', body: {}),
        callback: (r) async {
          await ApiService.requestFirebasePasswordReset(' UPPER@TEST.io ');
          expect(r.requests.single.decodedJson(),
              {'email': 'upper@test.io'});
        },
      );
    });

    test('throws DarbakException on 429', () async {
      await withMockedHttp(
        setup: (r) => r.respond('POST', '/api/auth/password-reset-request',
            statusCode: 429, body: {'message': 'too many'}),
        callback: (_) async {
          await expectLater(
            ApiService.requestFirebasePasswordReset('x@y.io'),
            throwsA(isA<DarbakException>()),
          );
        },
      );
    });
  });

  group('register', () {
    test('sends multipart fields and decodes 201', () async {
      await withMockedHttp(
        setup: (r) => r.respond('POST', '/api/auth/register',
            statusCode: 201, body: {'id': 1, 'token': 't'}),
        callback: (r) async {
          final result = await ApiService.register({
            'full_name': 'Tester',
            'phone': '0500000000',
            'documentPath': null,
            'nullSkipped': null,
          });
          expect(result['id'], 1);
          expect(r.requests.single.method, 'POST');
          final raw = r.requests.single.body;
          expect(raw, contains('Tester'));
          expect(raw, contains('0500000000'));
        },
      );
    });

    test('throws DarbakException on non-201', () async {
      await withMockedHttp(
        setup: (r) => r.respond('POST', '/api/auth/register',
            statusCode: 400, body: {'message': 'phone already exists'}),
        callback: (_) async {
          await expectLater(
            ApiService.register({'phone': '050'}),
            throwsA(isA<DarbakException>()),
          );
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // Shipments / Bids
  // ------------------------------------------------------------------

  group('shipments', () {
    test('getShipments returns paginated list payload', () async {
      await withMockedHttp(
        setup: (r) => r.respond('GET', '/api/shipments', body: [
          {'id': 1}
        ]),
        callback: (_) async {
          final list = await ApiService.getShipments();
          expect(list, hasLength(1));
        },
      );
    });

    test('getShipmentPage forwards query params', () async {
      await withMockedHttp(
        setup: (r) => r.respond('GET', '/api/shipments', body: {
          'data': [],
          'pagination': {
            'page': 2,
            'limit': 10,
            'total': 0,
            'totalPages': 0
          }
        }),
        callback: (r) async {
          await ApiService.getShipmentPage(
            const ShipmentListQuery(
              status: 'bidding',
              minWeight: 10,
              page: 2,
              limit: 10,
              matchMyTruck: true,
            ),
          );
          final qp = r.requests.single.url.queryParameters;
          expect(qp['status'], 'bidding');
          expect(qp['minWeight'], '10');
          expect(qp['page'], '2');
          expect(qp['matchMyTruck'], 'true');
        },
      );
    });

    test('createShipment returns 201 payload', () async {
      await withMockedHttp(
        setup: (r) => r.respond('POST', '/api/shipments',
            statusCode: 201, body: {'id': 99}),
        callback: (_) async {
          final out = await ApiService.createShipment({'foo': 'bar'});
          expect(out['id'], 99);
        },
      );
    });

    test('createShipment throws on non-201', () async {
      await withMockedHttp(
        setup: (r) => r.respond('POST', '/api/shipments',
            statusCode: 422, body: {'message': 'مرفوض'}),
        callback: (_) async {
          await expectLater(
              ApiService.createShipment({}), throwsA(isA<DarbakException>()));
        },
      );
    });

    test('getShipment / getDriverActiveShipments / getDriverShipments', () async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/shipments/7', body: {'id': 7});
          r.respond('GET', '/api/shipments/driver/active', body: [
            {'id': 1},
            {'id': 2}
          ]);
          r.respond('GET', '/api/shipments/driver', body: []);
        },
        callback: (_) async {
          expect((await ApiService.getShipment(7))['id'], 7);
          expect(await ApiService.getDriverActiveShipments(), hasLength(2));
          expect(await ApiService.getDriverShipments(), isEmpty);
        },
      );
    });

    test('updateShipmentStatus JSON path', () async {
      await withMockedHttp(
        setup: (r) => r.respond('PATCH', '/api/shipments/5/status',
            body: {'id': 5, 'status': 'delivered'}),
        callback: (r) async {
          final out = await ApiService.updateShipmentStatus(
            shipmentId: 5,
            status: 'delivered',
            locationLat: 24.7,
            locationLng: 46.7,
          );
          expect(out['status'], 'delivered');
          final body = r.requests.single.decodedJson() as Map;
          expect(body['status'], 'delivered');
          expect(body['location_lat'], 24.7);
        },
      );
    });

    test('recordShipmentLiveLocation posts location payload', () async {
      await withMockedHttp(
        setup: (r) =>
            r.respond('POST', '/api/shipments/3/live-location', body: {}),
        callback: (r) async {
          await ApiService.recordShipmentLiveLocation(
            shipmentId: 3,
            lat: 1.0,
            lng: 2.0,
          );
          final body = r.requests.single.decodedJson() as Map;
          expect(body, {'location_lat': 1.0, 'location_lng': 2.0});
        },
      );
    });

    test('getShipmentContractSignedUrl returns the url field', () async {
      await withMockedHttp(
        setup: (r) => r.respond('GET', '/api/shipments/3/contract',
            body: {'url': 'https://cdn.test/c.pdf'}),
        callback: (_) async {
          expect(await ApiService.getShipmentContractSignedUrl(3),
              'https://cdn.test/c.pdf');
        },
      );
    });

    test('recordShipmentStatus posts to shipment-status', () async {
      await withMockedHttp(
        setup: (r) => r.respond('POST', '/api/shipment-status',
            statusCode: 201, body: {'id': 1}),
        callback: (_) async {
          final out = await ApiService.recordShipmentStatus({'status': 'p'});
          expect(out['id'], 1);
        },
      );
    });

    test('getShipmentStatusHistory returns history map', () async {
      await withMockedHttp(
        setup: (r) =>
            r.respond('GET', '/api/shipment-status/5/history', body: {'rows': []}),
        callback: (_) async {
          expect((await ApiService.getShipmentStatusHistory(5))['rows'],
              isEmpty);
        },
      );
    });
  });

  group('bids and bidding-room', () {
    test('getBids parses BidModel list', () async {
      await withMockedHttp(
        setup: (r) => r.respond('GET', '/api/bids/shipment/7', body: [
          {
            'id': 1,
            'shipment_id': 7,
            'driver_id': 5,
            'bid_amount': '100',
            'estimated_days': 2,
            'bid_status': 'pending',
            'driver_name': 'علي',
          }
        ]),
        callback: (_) async {
          final bids = await ApiService.getBids(7);
          expect(bids, hasLength(1));
          expect(bids.first.driverName, 'علي');
        },
      );
    });

    test('placeBid + enterBiddingRoom share path', () async {
      await withMockedHttp(
        setup: (r) {
          r.when('POST', '/api/bids', handler: (req) async {
            return _jsonResponse(req, 201, {'ok': true});
          });
        },
        callback: (r) async {
          await ApiService.placeBid({'shipmentId': 1});
          await ApiService.enterBiddingRoom(1, 2, 100.0, 3);
          expect(r.requests, hasLength(2));
        },
      );
    });

    test('getMyActiveBid / withdrawMyPendingBid', () async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/bids/me/active', body: {'id': 11});
          r.respond('POST', '/api/bids/me/withdraw', body: {'ok': true});
        },
        callback: (_) async {
          expect((await ApiService.getMyActiveBid())['id'], 11);
          expect(
              (await ApiService.withdrawMyPendingBid(shipmentId: 5))['ok'],
              isTrue);
        },
      );
    });

    test('acceptBid posts to /bids/:id/accept', () async {
      await withMockedHttp(
        setup: (r) => r.respond('POST', '/api/bids/55/accept', body: {'id': 55}),
        callback: (_) async {
          expect((await ApiService.acceptBid(55))['id'], 55);
        },
      );
    });

    test('exitBiddingRoom + getRoomStatus', () async {
      await withMockedHttp(
        setup: (r) {
          r.respond('POST', '/api/bidding-rooms/rooms/3/exit',
              body: {'left': true});
          r.respond('GET', '/api/bidding-rooms/rooms/3/status',
              body: {'total_bids': 4});
        },
        callback: (_) async {
          expect((await ApiService.exitBiddingRoom(3, 7))['left'], isTrue);
          expect((await ApiService.getRoomStatus(3))['total_bids'], 4);
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // Profile
  // ------------------------------------------------------------------

  group('profile endpoints', () {
    test('updateProfile sends JSON body and returns map', () async {
      await withMockedHttp(
        setup: (r) =>
            r.respond('PUT', '/api/auth/profile/1', body: {'id': 1}),
        callback: (_) async {
          final out = await ApiService.updateProfile(1, {'full_name': 't'});
          expect(out['id'], 1);
        },
      );
    });

    test('getProfile returns 200 map', () async {
      await withMockedHttp(
        setup: (r) => r.respond('GET', '/api/auth/profile/9', body: {'id': 9}),
        callback: (_) async {
          expect((await ApiService.getProfile(9))['id'], 9);
        },
      );
    });

    test('getMyProfile unwraps data envelope', () async {
      await withMockedHttp(
        setup: (r) => r.respond('GET', '/api/profile/me',
            body: {'data': {'id': 2, 'role': 'driver'}}),
        callback: (_) async {
          expect((await ApiService.getMyProfile())['id'], 2);
        },
      );
    });

    test('getMyProfile returns flat map when no data wrapper', () async {
      await withMockedHttp(
        setup: (r) =>
            r.respond('GET', '/api/profile/me', body: {'id': 4}),
        callback: (_) async {
          expect((await ApiService.getMyProfile())['id'], 4);
        },
      );
    });

    test('getMyProfile throws when payload is not a map', () async {
      await withMockedHttp(
        setup: (r) =>
            r.respond('GET', '/api/profile/me', body: ['not', 'a', 'map']),
        callback: (_) async {
          await expectLater(ApiService.getMyProfile(),
              throwsA(isA<DarbakException>()));
        },
      );
    });

    test('updateCurrentProfile happy path and invalid response', () async {
      await withMockedHttp(
        setup: (r) {
          r.respond('PUT', '/api/profile/update',
              body: {'data': {'id': 1}});
        },
        callback: (_) async {
          expect((await ApiService.updateCurrentProfile({}))['id'], 1);
        },
      );

      await withMockedHttp(
        setup: (r) =>
            r.respond('PUT', '/api/profile/update', body: 'plain-text'),
        callback: (_) async {
          await expectLater(ApiService.updateCurrentProfile({}),
              throwsA(isA<DarbakException>()));
        },
      );
    });

    test('uploadProfileImage multipart returns map', () async {
      final bytes = Uint8List.fromList(List.filled(64, 7));
      double? lastProgress;
      await withMockedHttp(
        setup: (r) => r.respond('POST', '/api/profile/upload-image',
            body: {'profileImageUrl': 'u', 'profileImageKey': 'k'}),
        callback: (r) async {
          final out = await ApiService.uploadProfileImage(
            fileName: 'avatar.png',
            bytes: bytes,
            onProgress: (p) => lastProgress = p,
          );
          expect(out['profileImageUrl'], 'u');
          expect(lastProgress, isNotNull);
          expect(r.requests.single.method, 'POST');
        },
      );
    });

    test('uploadProfileImage failure non-2xx throws', () async {
      await withMockedHttp(
        setup: (r) => r.respond('POST', '/api/profile/upload-image',
            statusCode: 500, body: {'message': 'fail'}),
        callback: (_) async {
          await expectLater(
            ApiService.uploadProfileImage(
              fileName: 'a.png',
              bytes: Uint8List.fromList([1, 2, 3]),
            ),
            throwsA(isA<DarbakException>()),
          );
        },
      );
    });

    test('removeProfileImage DELETE returns map', () async {
      await withMockedHttp(
        setup: (r) =>
            r.respond('DELETE', '/api/profile/remove-image', body: {'ok': true}),
        callback: (_) async {
          expect((await ApiService.removeProfileImage())['ok'], isTrue);
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // Trucks
  // ------------------------------------------------------------------

  group('trucks', () {
    test('registerTruck + getMyTrucks + setActiveTruck + deleteTruck + updateTruck', () async {
      await withMockedHttp(
        setup: (r) {
          r.respond('POST', '/api/trucks/add',
              statusCode: 201, body: {'id': 1});
          r.respond('GET', '/api/trucks/my', body: [
            {'id': 1}
          ]);
          r.respond('PATCH', '/api/trucks/1/active', body: {
            'data': [
              {'id': 1, 'is_active': 1}
            ]
          });
          r.respond('DELETE', '/api/trucks/1', body: {});
          r.respond('PUT', '/api/trucks/1', body: {'id': 1, 'truck_type': 'x'});
        },
        callback: (_) async {
          expect((await ApiService.registerTruck({}))['id'], 1);
          expect(await ApiService.getMyTrucks(), hasLength(1));
          expect((await ApiService.setActiveTruck(1)), hasLength(1));
          await ApiService.deleteTruck(1);
          expect((await ApiService.updateTruck(1, {'x': 1}))['truck_type'], 'x');
        },
      );
    });

    test('setActiveTruck falls back to getMyTrucks when payload shape unknown', () async {
      await withMockedHttp(
        setup: (r) {
          r.respond('PATCH', '/api/trucks/9/active', body: {'unexpected': true});
          r.respond('GET', '/api/trucks/my', body: [
            {'id': 9}
          ]);
        },
        callback: (_) async {
          final result = await ApiService.setActiveTruck(9);
          expect(result, hasLength(1));
        },
      );
    });

    test('setActiveTruck accepts top-level list response', () async {
      await withMockedHttp(
        setup: (r) => r.respond('PATCH', '/api/trucks/9/active', body: [
          {'id': 9}
        ]),
        callback: (_) async {
          expect(await ApiService.setActiveTruck(9), hasLength(1));
        },
      );
    });

    test('uploadTruckInsurance happy + missing truckId branches', () async {
      await withMockedHttp(
        setup: (r) {
          r.respond('POST', '/api/trucks/insurance', body: {'ok': true});
          r.respond('POST', '/api/trucks/5/insurance', body: {'ok': true});
        },
        callback: (_) async {
          await ApiService.uploadTruckInsurance(
            fileName: 'doc.pdf',
            bytes: Uint8List.fromList(List.filled(32, 1)),
          );
          await ApiService.uploadTruckInsurance(
            truckId: 5,
            fileName: 'doc.pdf',
            bytes: Uint8List.fromList(List.filled(32, 1)),
          );
        },
      );
    });

    test('uploadTruckInsurance throws when server fails', () async {
      await withMockedHttp(
        setup: (r) => r.respond('POST', '/api/trucks/insurance',
            statusCode: 500, body: {'message': 'err'}),
        callback: (_) async {
          await expectLater(
            ApiService.uploadTruckInsurance(
              fileName: 'doc.pdf',
              bytes: Uint8List.fromList([1, 2, 3]),
            ),
            throwsA(isA<DarbakException>()),
          );
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // Ratings + Notifications
  // ------------------------------------------------------------------

  group('ratings', () {
    test('addRating strips rater_id and posts payload', () async {
      await withMockedHttp(
        setup: (r) =>
            r.respond('POST', '/api/ratings', statusCode: 201, body: {'id': 1}),
        callback: (r) async {
          await ApiService.addRating({'rater_id': 7, 'stars': 5});
          final body = r.requests.single.decodedJson() as Map;
          expect(body.containsKey('rater_id'), isFalse);
          expect(body['stars'], 5);
        },
      );
    });

    test('getUserRatings returns the payload', () async {
      await withMockedHttp(
        setup: (r) =>
            r.respond('GET', '/api/ratings/user/1', body: {'avg': 4.2}),
        callback: (_) async {
          expect((await ApiService.getUserRatings(1))['avg'], 4.2);
        },
      );
    });

    test('getUserProfileForReview parses data envelope', () async {
      await withMockedHttp(
        setup: (r) => r.respond('GET', '/api/users/1/profile', body: {
          'data': {
            'id': 1,
            'name': 'تجريبي',
            'role': 'driver',
          }
        }),
        callback: (_) async {
          final profile = await ApiService.getUserProfileForReview(1);
          expect(profile, isA<ReviewTargetProfile>());
          expect(profile.name, 'تجريبي');
        },
      );
    });

    test('getUserProfileForReview throws when payload is wrong shape', () async {
      await withMockedHttp(
        setup: (r) =>
            r.respond('GET', '/api/users/2/profile', body: {'unexpected': true}),
        callback: (_) async {
          await expectLater(ApiService.getUserProfileForReview(2),
              throwsA(isA<DarbakException>()));
        },
      );
    });
  });

  group('notifications', () {
    test('getNotifications + markNotificationAsRead', () async {
      await withMockedHttp(
        setup: (r) {
          r.respond('GET', '/api/notifications/user/1', body: {'rows': []});
          r.respond('POST', '/api/notifications/2/read', body: {});
        },
        callback: (_) async {
          expect((await ApiService.getNotifications(1))['rows'], isEmpty);
          await ApiService.markNotificationAsRead(2);
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // Device push token + chat conversations
  // ------------------------------------------------------------------

  group('device tokens and chat conversations', () {
    test('registerDevicePushToken posts token', () async {
      await withMockedHttp(
        setup: (r) =>
            r.respond('POST', '/api/auth/device-token', body: {}),
        callback: (r) async {
          await ApiService.registerDevicePushToken('fcm-x');
          expect(r.requests.single.decodedJson(), {'token': 'fcm-x'});
        },
      );
    });

    test('getMyChatConversations returns a list', () async {
      await withMockedHttp(
        setup: (r) =>
            r.respond('GET', '/api/chat/conversations/me', body: [
          {'id': 1}
        ]),
        callback: (_) async {
          expect(await ApiService.getMyChatConversations(), hasLength(1));
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // Chat messages (text + media + location + delivered/read)
  // ------------------------------------------------------------------

  group('chat messages', () {
    test('getChatMessages returns list', () async {
      await withMockedHttp(
        setup: (r) =>
            r.respond('GET', '/api/chat/1', body: [{'id': 1}]),
        callback: (_) async {
          expect(await ApiService.getChatMessages(1), hasLength(1));
        },
      );
    });

    test('sendChatMessage posts text payload', () async {
      await withMockedHttp(
        setup: (r) => r.respond('POST', '/api/chat/send',
            statusCode: 201, body: {'id': 1}),
        callback: (r) async {
          await ApiService.sendChatMessage(
            shipmentId: 1,
            receiverId: 2,
            message: 'مرحبا',
          );
          expect(r.requests.single.decodedJson(), {
            'shipmentId': 1,
            'receiverId': 2,
            'message': 'مرحبا',
          });
        },
      );
    });

    test('sendChatMediaMessage image happy path with caption', () async {
      await withMockedHttp(
        setup: (r) => r.respond('POST', '/api/chat/1/media',
            statusCode: 201, body: {'id': 1, 'message_type': 'image'}),
        callback: (_) async {
          final res = await ApiService.sendChatMediaMessage(
            shipmentId: 1,
            receiverId: 2,
            fileName: 'photo.jpg',
            bytes: Uint8List.fromList(List.filled(128, 9)),
            caption: '   تصوير الشحنة   ',
          );
          expect(res['message_type'], 'image');
        },
      );
    });

    test('sendChatMediaMessage video path with progress callback', () async {
      double? lastProgress;
      await withMockedHttp(
        setup: (r) => r.respond('POST', '/api/chat/3/media',
            statusCode: 201, body: {'id': 1, 'message_type': 'video'}),
        callback: (_) async {
          await ApiService.sendChatMediaMessage(
            shipmentId: 3,
            receiverId: 4,
            fileName: 'clip.mp4',
            bytes: Uint8List.fromList(List.filled(2048, 1)),
            onProgress: (p) => lastProgress = p,
          );
          expect(lastProgress, isNotNull);
        },
      );
    });

    test('sendChatMediaMessage propagates server errors', () async {
      await withMockedHttp(
        setup: (r) => r.respond('POST', '/api/chat/9/media',
            statusCode: 500, body: {'message': 'oops'}),
        callback: (_) async {
          await expectLater(
            ApiService.sendChatMediaMessage(
              shipmentId: 9,
              receiverId: 1,
              fileName: 'photo.jpg',
              bytes: Uint8List.fromList([1, 2, 3]),
            ),
            throwsA(isA<DarbakException>()),
          );
        },
      );
    });

    test('sendChatLocationMessage includes label when present', () async {
      await withMockedHttp(
        setup: (r) => r.respond('POST', '/api/chat/2/location',
            statusCode: 201, body: {'id': 1}),
        callback: (r) async {
          await ApiService.sendChatLocationMessage(
            shipmentId: 2,
            receiverId: 3,
            latitude: 24.7,
            longitude: 46.7,
            label: '  مكتب الشركة  ',
          );
          final body = r.requests.single.decodedJson() as Map;
          expect(body['label'], 'مكتب الشركة');
          expect(body['latitude'], 24.7);
        },
      );
    });

    test('sendChatLocationMessage omits empty label', () async {
      await withMockedHttp(
        setup: (r) => r.respond('POST', '/api/chat/2/location',
            statusCode: 201, body: {'id': 1}),
        callback: (r) async {
          await ApiService.sendChatLocationMessage(
            shipmentId: 2,
            receiverId: 3,
            latitude: 1,
            longitude: 2,
            label: '   ',
          );
          final body = r.requests.single.decodedJson() as Map;
          expect(body.containsKey('label'), isFalse);
        },
      );
    });

    test('markChatMessagesDelivered + markChatMessagesRead', () async {
      await withMockedHttp(
        setup: (r) {
          r.respond('POST', '/api/chat/1/delivered', body: {'ok': true});
          r.respond('POST', '/api/chat/1/read', body: {'ok': true});
        },
        callback: (_) async {
          await ApiService.markChatMessagesDelivered(1, messageIds: [1, 2]);
          await ApiService.markChatMessagesRead(1);
        },
      );
    });
  });

  // ------------------------------------------------------------------
  // Operating card
  // ------------------------------------------------------------------

  group('operating card', () {
    test('getOperatingCard unwraps data envelope', () async {
      await withMockedHttp(
        setup: (r) => r.respond('GET', '/api/operating-card',
            body: {'data': {'id': 1, 'status': 'pending'}}),
        callback: (_) async {
          final card = await ApiService.getOperatingCard();
          expect(card!['status'], 'pending');
        },
      );
    });

    test('uploadOperatingCard happy path with progress', () async {
      double? lastProgress;
      await withMockedHttp(
        setup: (r) => r.respond('POST', '/api/operating-card/upload',
            statusCode: 201, body: {'id': 1}),
        callback: (_) async {
          await ApiService.uploadOperatingCard(
            fileName: 'card.pdf',
            bytes: Uint8List.fromList(List.filled(256, 8)),
            expiryDate: '2030-12-31',
            onProgress: (p) => lastProgress = p,
          );
          expect(lastProgress, isNotNull);
        },
      );
    });

    test('uploadOperatingCard server error', () async {
      await withMockedHttp(
        setup: (r) => r.respond('POST', '/api/operating-card/upload',
            statusCode: 500, body: {'message': 'failed'}),
        callback: (_) async {
          await expectLater(
            ApiService.uploadOperatingCard(
              fileName: 'card.pdf',
              bytes: Uint8List.fromList([1, 2, 3]),
              expiryDate: '2030',
            ),
            throwsA(isA<DarbakException>()),
          );
        },
      );
    });

    test('deleteOperatingCard returns normally', () async {
      await withMockedHttp(
        setup: (r) => r.respond('DELETE', '/api/operating-card', body: {}),
        callback: (_) async {
          await ApiService.deleteOperatingCard();
        },
      );
    });
  });

  group('HTTP error paths', () {
    test('getBids throws on non-200', () async {
      await withMockedHttp(
        setup: (r) => r.respond('GET', '/api/bids/shipment/1',
            statusCode: 404, body: {'message': 'missing'}),
        callback: (_) async {
          await expectLater(
            ApiService.getBids(1),
            throwsA(isA<DarbakException>()),
          );
        },
      );
    });

    test('placeBid throws on non-201', () async {
      await withMockedHttp(
        setup: (r) => r.respond('POST', '/api/bids',
            statusCode: 400, body: {'message': 'bad'}),
        callback: (_) async {
          await expectLater(
            ApiService.placeBid({'shipmentId': 1, 'bidAmount': 100}),
            throwsA(isA<DarbakException>()),
          );
        },
      );
    });

    test('getMyActiveBid throws on non-200', () async {
      await withMockedHttp(
        setup: (r) => r.respond('GET', '/api/bids/me/active',
            statusCode: 500, body: {'message': 'err'}),
        callback: (_) async {
          await expectLater(
            ApiService.getMyActiveBid(),
            throwsA(isA<DarbakException>()),
          );
        },
      );
    });

    test('withdrawMyPendingBid throws on non-200', () async {
      await withMockedHttp(
        setup: (r) => r.respond('POST', '/api/bids/me/withdraw',
            statusCode: 409, body: {'message': 'conflict'}),
        callback: (_) async {
          await expectLater(
            ApiService.withdrawMyPendingBid(shipmentId: 3),
            throwsA(isA<DarbakException>()),
          );
        },
      );
    });

    test('updateProfile throws on non-200', () async {
      await withMockedHttp(
        setup: (r) => r.respond('PUT', '/api/auth/profile/1',
            statusCode: 403, body: {'message': 'forbidden'}),
        callback: (_) async {
          await expectLater(
            ApiService.updateProfile(1, {'fullName': 'X'}),
            throwsA(isA<DarbakException>()),
          );
        },
      );
    });

    test('createShipment throws on non-201', () async {
      await withMockedHttp(
        setup: (r) => r.respond('POST', '/api/shipments',
            statusCode: 422, body: {'message': 'invalid'}),
        callback: (_) async {
          await expectLater(
            ApiService.createShipment({'pickupCity': 'الرياض'}),
            throwsA(isA<DarbakException>()),
          );
        },
      );
    });
  });
}

/// Helper for routes that need to inspect/decode the incoming request.
http.Response _jsonResponse(
  http.BaseRequest req,
  int status,
  Object body,
) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: const {'content-type': 'application/json'},
    request: req,
  );
}

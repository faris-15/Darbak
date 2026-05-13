import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:darbak/api_service.dart';
import 'package:darbak/models/bid_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service_test.mocks.dart';

@GenerateMocks([http.Client])
void main() {
  const base = 'http://10.0.2.2:5000/api';
  late MockClient mockClient;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockClient = MockClient();
    ApiService.setHttpClientForTests(mockClient);
  });

  tearDown(() {
    reset(mockClient);
    ApiService.resetHttpClientForTests();
  });

  void stubPost(
    String path, {
    required int statusCode,
    String body = '{}',
  }) {
    when(
      mockClient.post(
        Uri.parse('$base$path'),
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      ),
    ).thenAnswer((_) async => http.Response(body, statusCode));
  }

  void stubGet(
    String path, {
    required int statusCode,
    String body = '{}',
  }) {
    when(
      mockClient.get(
        Uri.parse('$base$path'),
        headers: anyNamed('headers'),
      ),
    ).thenAnswer((_) async => http.Response(body, statusCode));
  }

  group('ApiService.login', () {
    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: returns map on 200
    /// 📥 المدخلات: تهيئة Mock للاستجابة الناجحة مع مدخلات صالحة للدالة
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Happy Path — الحالة الطبيعية الناجحة
    /// ========================================
    test('returns map on 200', () async {
      when(
        mockClient.post(
          Uri.parse('$base/auth/login'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          '{"user":{"id":1,"role":"driver","email":"a@b.c","full_name":"U"},"token":"abc"}',
          200,
        ),
      );

      final r = await ApiService.login('u', 'p');
      expect(r['token'], 'abc');
      expect(r['user']['role'], 'driver');
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: throws DarbakException on 401 with message
    /// 📥 المدخلات: تهيئة Mock لإرجاع كود حالة خطأ مع استدعاء الدالة ببيانات مناسبة للحالة
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('throws DarbakException on 401 with message', () async {
      when(
        mockClient.post(
          Uri.parse('$base/auth/login'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('{"message":"خطأ"}', 401));

      await expectLater(
        ApiService.login('u', 'p'),
        throwsA(isA<DarbakException>()),
      );
    });
  });

  group('ApiService.register', () {
    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: returns map on 201 multipart success
    /// 📥 المدخلات: تهيئة Mock للاستجابة الناجحة مع مدخلات صالحة للدالة
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Happy Path — الحالة الطبيعية الناجحة
    /// ========================================
    test('returns map on 201 multipart success', () async {
      final dir = Directory.systemTemp.createTempSync();
      final f = File('${dir.path}/doc.pdf')..writeAsStringSync('%PDF-1.1');

      when(mockClient.send(any)).thenAnswer(
        (_) async => http.StreamedResponse(
          Stream.value(utf8.encode('{"id":1}')),
          201,
        ),
      );

      final r = await ApiService.register({
        'fullName': 'Test User',
        'email': 't@t.com',
        'phone': '0511111111',
        'password': 'secret12',
        'role': 'shipper',
        'documentPath': f.path,
      });
      expect(r['id'], 1);
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: throws on non-201
    /// 📥 المدخلات: تهيئة Mock للاستجابة الناجحة مع مدخلات صالحة للدالة
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('throws on non-201', () async {
      final dir = Directory.systemTemp.createTempSync();
      final f = File('${dir.path}/doc.pdf')..writeAsStringSync('x');

      when(mockClient.send(any)).thenAnswer(
        (_) async => http.StreamedResponse(
          Stream.value(utf8.encode('{"message":"فشل"}')),
          400,
        ),
      );

      await expectLater(
        ApiService.register({
          'fullName': 'Test User',
          'email': 't@t.com',
          'phone': '0511111111',
          'password': 'secret12',
          'role': 'shipper',
          'documentPath': f.path,
        }),
        throwsA(isA<DarbakException>()),
      );
    });
  });

  group('ApiService.getShipments', () {
    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 200 returns list
    /// 📥 المدخلات: تهيئة Mock للاستجابة الناجحة مع مدخلات صالحة للدالة
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Happy Path — الحالة الطبيعية الناجحة
    /// ========================================
    test('200 returns list', () async {
      when(
        mockClient.get(
          Uri.parse('$base/shipments'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => http.Response('[]', 200));

      expect(await ApiService.getShipments(), isEmpty);
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 500 throws
    /// 📥 المدخلات: تهيئة Mock لإرجاع كود حالة خطأ مع استدعاء الدالة ببيانات مناسبة للحالة
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('500 throws', () async {
      when(
        mockClient.get(
          Uri.parse('$base/shipments'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => http.Response('{"message":"srv"}', 500));

      await expectLater(
        ApiService.getShipments(),
        throwsA(isA<DarbakException>()),
      );
    });
  });

  group('ApiService.createShipment', () {
    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 201 success
    /// 📥 المدخلات: تهيئة Mock للاستجابة الناجحة مع مدخلات صالحة للدالة
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Happy Path — الحالة الطبيعية الناجحة
    /// ========================================
    test('201 success', () async {
      when(
        mockClient.post(
          Uri.parse('$base/shipments'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('{"id":9}', 201));

      final r = await ApiService.createShipment({'weightKg': 1.0});
      expect(r['id'], 9);
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 400 failure
    /// 📥 المدخلات: تهيئة Mock لإرجاع كود حالة خطأ مع استدعاء الدالة ببيانات مناسبة للحالة
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('400 failure', () async {
      when(
        mockClient.post(
          Uri.parse('$base/shipments'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('{"message":"bad"}', 400));

      await expectLater(
        ApiService.createShipment({'weightKg': 1.0}),
        throwsA(isA<DarbakException>()),
      );
    });
  });

  group('ApiService.getBids', () {
    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 200 parses BidModel list
    /// 📥 المدخلات: تهيئة Mock للاستجابة الناجحة مع مدخلات صالحة للدالة
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Happy Path — الحالة الطبيعية الناجحة
    /// ========================================
    test('200 parses BidModel list', () async {
      when(
        mockClient.get(
          Uri.parse('$base/bids/shipment/7'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode([
            {
              'id': 1,
              'shipment_id': 7,
              'driver_id': 2,
              'bid_amount': 100,
              'estimated_days': 3,
              'bid_status': 'pending',
              'driver_name': 'D',
              'driver_rating': 0,
              'rating_count': 0,
            },
          ]),
          200,
        ),
      );

      final bids = await ApiService.getBids(7);
      expect(bids, hasLength(1));
      expect(bids.first, isA<BidModel>());
      expect(bids.first.bidAmount, 100.0);
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 404 failure
    /// 📥 المدخلات: تهيئة Mock لإرجاع كود حالة خطأ مع استدعاء الدالة ببيانات مناسبة للحالة
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('404 failure', () async {
      when(
        mockClient.get(
          Uri.parse('$base/bids/shipment/7'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => http.Response('{}', 404));

      await expectLater(
        ApiService.getBids(7),
        throwsA(isA<DarbakException>()),
      );
    });
  });

  group('ApiService.placeBid', () {
    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 201 success
    /// 📥 المدخلات: تهيئة Mock للاستجابة الناجحة مع مدخلات صالحة للدالة
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Happy Path — الحالة الطبيعية الناجحة
    /// ========================================
    test('201 success', () async {
      when(
        mockClient.post(
          Uri.parse('$base/bids'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('{"ok":true}', 201));

      final r = await ApiService.placeBid({'shipmentId': 1, 'driverId': 2, 'bidAmount': 10.0});
      expect(r['ok'], isTrue);
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 409 failure
    /// 📥 المدخلات: تهيئة Mock لإرجاع كود حالة خطأ مع استدعاء الدالة ببيانات مناسبة للحالة
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('409 failure', () async {
      when(
        mockClient.post(
          Uri.parse('$base/bids'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('{"message":"conflict"}', 409));

      await expectLater(
        ApiService.placeBid({}),
        throwsA(isA<DarbakException>()),
      );
    });
  });

  group('ApiService.enterBiddingRoom', () {
    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: delegates to placeBid on success
    /// 📥 المدخلات: استدعاء الدالة بمدخلات الاختبار المحددة مع تهيئة MockClient
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Happy Path — الحالة الطبيعية الناجحة
    /// ========================================
    test('delegates to placeBid on success', () async {
      when(
        mockClient.post(
          Uri.parse('$base/bids'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('{}', 201));

      await ApiService.enterBiddingRoom(1, 2, 99.0, 5);
      verify(
        mockClient.post(
          Uri.parse('$base/bids'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).called(1);
    });
  });

  group('ApiService.updateProfile', () {
    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 200
    /// 📥 المدخلات: تهيئة Mock للاستجابة الناجحة مع مدخلات صالحة للدالة
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Happy Path — الحالة الطبيعية الناجحة
    /// ========================================
    test('200', () async {
      when(
        mockClient.put(
          Uri.parse('$base/auth/profile/3'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('{}', 200));

      await ApiService.updateProfile(3, {'full_name': 'x'});
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 422
    /// 📥 المدخلات: تهيئة Mock لإرجاع كود حالة خطأ مع استدعاء الدالة ببيانات مناسبة للحالة
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Negative Testing — اختبار الحالات الخاطئة
    /// ========================================
    test('422', () async {
      when(
        mockClient.put(
          Uri.parse('$base/auth/profile/3'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('{"message":"invalid"}', 422));

      await expectLater(
        ApiService.updateProfile(3, {}),
        throwsA(isA<DarbakException>()),
      );
    });
  });

  group('ApiService.getProfile', () {
    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 200
    /// 📥 المدخلات: تهيئة Mock للاستجابة الناجحة مع مدخلات صالحة للدالة
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Happy Path — الحالة الطبيعية الناجحة
    /// ========================================
    test('200', () async {
      when(
        mockClient.get(
          Uri.parse('$base/auth/profile/3'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => http.Response('{"id":3}', 200));

      expect((await ApiService.getProfile(3))['id'], 3);
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 500
    /// 📥 المدخلات: تهيئة Mock لإرجاع كود حالة خطأ مع استدعاء الدالة ببيانات مناسبة للحالة
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('500', () async {
      when(
        mockClient.get(
          Uri.parse('$base/auth/profile/3'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => http.Response('{}', 500));

      await expectLater(
        ApiService.getProfile(3),
        throwsA(isA<DarbakException>()),
      );
    });
  });

  group('ApiService.exitBiddingRoom', () {
    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 200
    /// 📥 المدخلات: تهيئة Mock للاستجابة الناجحة مع مدخلات صالحة للدالة
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Happy Path — الحالة الطبيعية الناجحة
    /// ========================================
    test('200', () async {
      when(
        mockClient.post(
          Uri.parse('$base/bidding-rooms/rooms/9/exit'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('{}', 200));

      await ApiService.exitBiddingRoom(9, 2);
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 400
    /// 📥 المدخلات: تهيئة Mock لإرجاع كود حالة خطأ مع استدعاء الدالة ببيانات مناسبة للحالة
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Negative Testing — اختبار الحالات الخاطئة
    /// ========================================
    test('400', () async {
      when(
        mockClient.post(
          Uri.parse('$base/bidding-rooms/rooms/9/exit'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('{"message":"no"}', 400));

      await expectLater(
        ApiService.exitBiddingRoom(9, 2),
        throwsA(isA<DarbakException>()),
      );
    });
  });

  group('ApiService.getRoomStatus', () {
    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 200
    /// 📥 المدخلات: تهيئة Mock للاستجابة الناجحة مع مدخلات صالحة للدالة
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Happy Path — الحالة الطبيعية الناجحة
    /// ========================================
    test('200', () async {
      when(
        mockClient.get(Uri.parse('$base/bidding-rooms/rooms/9/status')),
      ).thenAnswer((_) async => http.Response('{"total_bids":0}', 200));

      final m = await ApiService.getRoomStatus(9);
      expect(m['total_bids'], 0);
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 503
    /// 📥 المدخلات: تهيئة Mock لإرجاع كود حالة خطأ مع استدعاء الدالة ببيانات مناسبة للحالة
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('503', () async {
      when(
        mockClient.get(Uri.parse('$base/bidding-rooms/rooms/9/status')),
      ).thenAnswer((_) async => http.Response('{}', 503));

      await expectLater(
        ApiService.getRoomStatus(9),
        throwsA(isA<DarbakException>()),
      );
    });
  });

  group('ApiService.registerTruck', () {
    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 201
    /// 📥 المدخلات: تهيئة Mock للاستجابة الناجحة مع مدخلات صالحة للدالة
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Happy Path — الحالة الطبيعية الناجحة
    /// ========================================
    test('201', () async {
      when(
        mockClient.post(
          Uri.parse('$base/trucks/add'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('{}', 201));

      await ApiService.registerTruck({'plate': 'x'});
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 400
    /// 📥 المدخلات: تهيئة Mock لإرجاع كود حالة خطأ مع استدعاء الدالة ببيانات مناسبة للحالة
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Negative Testing — اختبار الحالات الخاطئة
    /// ========================================
    test('400', () async {
      when(
        mockClient.post(
          Uri.parse('$base/trucks/add'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('{}', 400));

      await expectLater(
        ApiService.registerTruck({}),
        throwsA(isA<DarbakException>()),
      );
    });
  });

  group('ApiService.getMyTrucks', () {
    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 200
    /// 📥 المدخلات: تهيئة Mock للاستجابة الناجحة مع مدخلات صالحة للدالة
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Happy Path — الحالة الطبيعية الناجحة
    /// ========================================
    test('200', () async {
      when(
        mockClient.get(
          Uri.parse('$base/trucks/my'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => http.Response('[]', 200));

      expect(await ApiService.getMyTrucks(), isEmpty);
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 401
    /// 📥 المدخلات: تهيئة Mock لإرجاع كود حالة خطأ مع استدعاء الدالة ببيانات مناسبة للحالة
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Negative Testing — اختبار الحالات الخاطئة
    /// ========================================
    test('401', () async {
      when(
        mockClient.get(
          Uri.parse('$base/trucks/my'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => http.Response('{}', 401));

      await expectLater(
        ApiService.getMyTrucks(),
        throwsA(isA<DarbakException>()),
      );
    });
  });

  group('ApiService.updateTruck', () {
    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 200
    /// 📥 المدخلات: تهيئة Mock للاستجابة الناجحة مع مدخلات صالحة للدالة
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Happy Path — الحالة الطبيعية الناجحة
    /// ========================================
    test('200', () async {
      when(
        mockClient.put(
          Uri.parse('$base/trucks/4'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('{}', 200));

      await ApiService.updateTruck(4, {});
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 404
    /// 📥 المدخلات: تهيئة Mock لإرجاع كود حالة خطأ مع استدعاء الدالة ببيانات مناسبة للحالة
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Negative Testing — اختبار الحالات الخاطئة
    /// ========================================
    test('404', () async {
      when(
        mockClient.put(
          Uri.parse('$base/trucks/4'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('{}', 404));

      await expectLater(
        ApiService.updateTruck(4, {}),
        throwsA(isA<DarbakException>()),
      );
    });
  });

  group('ApiService.deleteTruck', () {
    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 200
    /// 📥 المدخلات: تهيئة Mock للاستجابة الناجحة مع مدخلات صالحة للدالة
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Happy Path — الحالة الطبيعية الناجحة
    /// ========================================
    test('200', () async {
      when(
        mockClient.delete(
          Uri.parse('$base/trucks/4'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => http.Response('', 200));

      await ApiService.deleteTruck(4);
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 500
    /// 📥 المدخلات: تهيئة Mock لإرجاع كود حالة خطأ مع استدعاء الدالة ببيانات مناسبة للحالة
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('500', () async {
      when(
        mockClient.delete(
          Uri.parse('$base/trucks/4'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => http.Response('{}', 500));

      await expectLater(
        ApiService.deleteTruck(4),
        throwsA(isA<DarbakException>()),
      );
    });
  });

  group('ApiService.addRating', () {
    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 201
    /// 📥 المدخلات: تهيئة Mock للاستجابة الناجحة مع مدخلات صالحة للدالة
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Happy Path — الحالة الطبيعية الناجحة
    /// ========================================
    test('201', () async {
      when(
        mockClient.post(
          Uri.parse('$base/ratings'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('{}', 201));

      await ApiService.addRating({'x': 1, 'rater_id': 9});
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 400
    /// 📥 المدخلات: تهيئة Mock لإرجاع كود حالة خطأ مع استدعاء الدالة ببيانات مناسبة للحالة
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Negative Testing — اختبار الحالات الخاطئة
    /// ========================================
    test('400', () async {
      when(
        mockClient.post(
          Uri.parse('$base/ratings'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('{}', 400));

      await expectLater(
        ApiService.addRating({}),
        throwsA(isA<DarbakException>()),
      );
    });
  });

  group('ApiService.getUserRatings', () {
    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 200
    /// 📥 المدخلات: تهيئة Mock للاستجابة الناجحة مع مدخلات صالحة للدالة
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Happy Path — الحالة الطبيعية الناجحة
    /// ========================================
    test('200', () async {
      when(
        mockClient.get(
          Uri.parse('$base/ratings/user/2'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => http.Response('{"avg":5}', 200));

      expect((await ApiService.getUserRatings(2))['avg'], 5);
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 404
    /// 📥 المدخلات: تهيئة Mock لإرجاع كود حالة خطأ مع استدعاء الدالة ببيانات مناسبة للحالة
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Negative Testing — اختبار الحالات الخاطئة
    /// ========================================
    test('404', () async {
      when(
        mockClient.get(
          Uri.parse('$base/ratings/user/2'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => http.Response('{}', 404));

      await expectLater(
        ApiService.getUserRatings(2),
        throwsA(isA<DarbakException>()),
      );
    });
  });

  group('ApiService.getNotifications', () {
    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 200
    /// 📥 المدخلات: تهيئة Mock للاستجابة الناجحة مع مدخلات صالحة للدالة
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Happy Path — الحالة الطبيعية الناجحة
    /// ========================================
    test('200', () async {
      when(
        mockClient.get(
          Uri.parse('$base/notifications/user/2'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => http.Response('{"items":[]}', 200));

      await ApiService.getNotifications(2);
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 500
    /// 📥 المدخلات: تهيئة Mock لإرجاع كود حالة خطأ مع استدعاء الدالة ببيانات مناسبة للحالة
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('500', () async {
      when(
        mockClient.get(
          Uri.parse('$base/notifications/user/2'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => http.Response('{}', 500));

      await expectLater(
        ApiService.getNotifications(2),
        throwsA(isA<DarbakException>()),
      );
    });
  });

  group('ApiService.markNotificationAsRead', () {
    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 200
    /// 📥 المدخلات: تهيئة Mock للاستجابة الناجحة مع مدخلات صالحة للدالة
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Happy Path — الحالة الطبيعية الناجحة
    /// ========================================
    test('200', () async {
      when(
        mockClient.post(
          Uri.parse('$base/notifications/88/read'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => http.Response('', 200));

      await ApiService.markNotificationAsRead(88);
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 404
    /// 📥 المدخلات: تهيئة Mock لإرجاع كود حالة خطأ مع استدعاء الدالة ببيانات مناسبة للحالة
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Negative Testing — اختبار الحالات الخاطئة
    /// ========================================
    test('404', () async {
      when(
        mockClient.post(
          Uri.parse('$base/notifications/88/read'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => http.Response('{}', 404));

      await expectLater(
        ApiService.markNotificationAsRead(88),
        throwsA(isA<DarbakException>()),
      );
    });
  });

  group('ApiService.getShipment', () {
    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 200
    /// 📥 المدخلات: تهيئة Mock للاستجابة الناجحة مع مدخلات صالحة للدالة
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Happy Path — الحالة الطبيعية الناجحة
    /// ========================================
    test('200', () async {
      when(
        mockClient.get(
          Uri.parse('$base/shipments/12'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => http.Response('{"id":12}', 200));

      expect((await ApiService.getShipment(12))['id'], 12);
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 404
    /// 📥 المدخلات: تهيئة Mock لإرجاع كود حالة خطأ مع استدعاء الدالة ببيانات مناسبة للحالة
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Negative Testing — اختبار الحالات الخاطئة
    /// ========================================
    test('404', () async {
      when(
        mockClient.get(
          Uri.parse('$base/shipments/12'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => http.Response('{}', 404));

      await expectLater(
        ApiService.getShipment(12),
        throwsA(isA<DarbakException>()),
      );
    });
  });

  group('ApiService.getDriverActiveShipments', () {
    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 200
    /// 📥 المدخلات: تهيئة Mock للاستجابة الناجحة مع مدخلات صالحة للدالة
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Happy Path — الحالة الطبيعية الناجحة
    /// ========================================
    test('200', () async {
      when(
        mockClient.get(
          Uri.parse('$base/shipments/driver/active'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => http.Response('[]', 200));

      expect(await ApiService.getDriverActiveShipments(), isEmpty);
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 403
    /// 📥 المدخلات: تهيئة Mock لإرجاع كود حالة خطأ مع استدعاء الدالة ببيانات مناسبة للحالة
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Negative Testing — اختبار الحالات الخاطئة
    /// ========================================
    test('403', () async {
      when(
        mockClient.get(
          Uri.parse('$base/shipments/driver/active'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => http.Response('{}', 403));

      await expectLater(
        ApiService.getDriverActiveShipments(),
        throwsA(isA<DarbakException>()),
      );
    });
  });

  group('ApiService.getDriverShipments', () {
    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 200
    /// 📥 المدخلات: تهيئة Mock للاستجابة الناجحة مع مدخلات صالحة للدالة
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Happy Path — الحالة الطبيعية الناجحة
    /// ========================================
    test('200', () async {
      when(
        mockClient.get(
          Uri.parse('$base/shipments/driver'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => http.Response('[]', 200));

      expect(await ApiService.getDriverShipments(), isEmpty);
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 500
    /// 📥 المدخلات: تهيئة Mock لإرجاع كود حالة خطأ مع استدعاء الدالة ببيانات مناسبة للحالة
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('500', () async {
      when(
        mockClient.get(
          Uri.parse('$base/shipments/driver'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => http.Response('{}', 500));

      await expectLater(
        ApiService.getDriverShipments(),
        throwsA(isA<DarbakException>()),
      );
    });
  });

  group('ApiService.updateShipmentStatus (JSON branch)', () {
    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 200 without epodPhoto uses PATCH
    /// 📥 المدخلات: تهيئة Mock للاستجابة الناجحة مع مدخلات صالحة للدالة
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Happy Path — الحالة الطبيعية الناجحة
    /// ========================================
    test('200 without epodPhoto uses PATCH', () async {
      when(
        mockClient.patch(
          Uri.parse('$base/shipments/1/status'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('{"status":"x"}', 200));

      final r = await ApiService.updateShipmentStatus(
        shipmentId: 1,
        status: 'picked_up',
      );
      expect(r['status'], 'x');
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 400 without epodPhoto
    /// 📥 المدخلات: تهيئة Mock لإرجاع كود حالة خطأ مع استدعاء الدالة ببيانات مناسبة للحالة
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Negative Testing — اختبار الحالات الخاطئة
    /// ========================================
    test('400 without epodPhoto', () async {
      when(
        mockClient.patch(
          Uri.parse('$base/shipments/1/status'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('{"message":"bad"}', 400));

      await expectLater(
        ApiService.updateShipmentStatus(shipmentId: 1, status: 'x'),
        throwsA(isA<DarbakException>()),
      );
    });
  });

  group('ApiService.updateShipmentStatus (multipart / S3-related path)', () {
    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 200 when epodPhoto is set uses client.send
    /// 📥 المدخلات: تهيئة Mock للاستجابة الناجحة مع مدخلات صالحة للدالة
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Happy Path — الحالة الطبيعية الناجحة
    /// ========================================
    test('200 when epodPhoto is set uses client.send', () async {
      final dir = Directory.systemTemp.createTempSync();
      final img = File('${dir.path}/epod.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF]);

      when(mockClient.send(any)).thenAnswer(
        (_) async => http.StreamedResponse(
          Stream.value(utf8.encode('{"history":{"photo_path":"s3://bucket/key"}}')),
          200,
        ),
      );

      final r = await ApiService.updateShipmentStatus(
        shipmentId: 1,
        status: 'delivered',
        epodPhoto: XFile(img.path),
      );
      expect(r['history'], isNotNull);
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 413 failure on multipart upload
    /// 📥 المدخلات: تجهيز ملف مؤقت ومسار multipart مع تهيئة send في MockClient
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('413 failure on multipart upload', () async {
      final dir = Directory.systemTemp.createTempSync();
      final img = File('${dir.path}/epod.jpg')..writeAsBytesSync([1, 2, 3]);

      when(mockClient.send(any)).thenAnswer(
        (_) async => http.StreamedResponse(
          Stream.value(utf8.encode('{"message":"too large"}')),
          413,
        ),
      );

      await expectLater(
        ApiService.updateShipmentStatus(
          shipmentId: 1,
          status: 'delivered',
          epodPhoto: XFile(img.path),
        ),
        throwsA(isA<DarbakException>()),
      );
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 200 multipart preserves nested history.photo_path from S3 upload response
    /// 📥 المدخلات: تهيئة Mock للاستجابة الناجحة مع مدخلات صالحة للدالة
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Happy Path — الحالة الطبيعية الناجحة
    /// ========================================
    test('200 multipart preserves nested history.photo_path from S3 upload response', () async {
      final dir = Directory.systemTemp.createTempSync();
      final img = File('${dir.path}/epod.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF]);

      when(mockClient.send(any)).thenAnswer(
        (_) async => http.StreamedResponse(
          Stream.value(
            utf8.encode(
              jsonEncode({
                'history': {'photo_path': 'epod/shipments/9-delivered.jpg'},
              }),
            ),
          ),
          200,
        ),
      );

      final r = await ApiService.updateShipmentStatus(
        shipmentId: 9,
        status: 'delivered',
        epodPhoto: XFile(img.path),
      );
      final h = r['history'];
      expect(h, isA<Map<String, dynamic>>());
      expect((h as Map)['photo_path'], 'epod/shipments/9-delivered.jpg');
    });
  });

  group('ApiService.recordShipmentLiveLocation', () {
    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 200
    /// 📥 المدخلات: تهيئة Mock للاستجابة الناجحة مع مدخلات صالحة للدالة
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Happy Path — الحالة الطبيعية الناجحة
    /// ========================================
    test('200', () async {
      when(
        mockClient.post(
          Uri.parse('$base/shipments/1/live-location'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('', 200));

      await ApiService.recordShipmentLiveLocation(shipmentId: 1, lat: 1, lng: 2);
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 500
    /// 📥 المدخلات: تهيئة Mock لإرجاع كود حالة خطأ مع استدعاء الدالة ببيانات مناسبة للحالة
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('500', () async {
      when(
        mockClient.post(
          Uri.parse('$base/shipments/1/live-location'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('{}', 500));

      await expectLater(
        ApiService.recordShipmentLiveLocation(shipmentId: 1, lat: 1, lng: 2),
        throwsA(isA<DarbakException>()),
      );
    });
  });

  group('ApiService.getShipmentContractSignedUrl (S3 presigned)', () {
    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 200 returns url string
    /// 📥 المدخلات: تهيئة Mock للاستجابة الناجحة مع مدخلات صالحة للدالة
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Happy Path — الحالة الطبيعية الناجحة
    /// ========================================
    test('200 returns url string', () async {
      when(
        mockClient.get(
          Uri.parse('$base/shipments/5/contract'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          '{"url":"https://example-bucket.s3.amazonaws.com/contracts/5.pdf?X-Amz-Algorithm=AWS4-HMAC-SHA256"}',
          200,
        ),
      );

      final url = await ApiService.getShipmentContractSignedUrl(5);
      expect(url, contains('s3.amazonaws.com'));
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 403 failure
    /// 📥 المدخلات: تهيئة Mock لإرجاع كود حالة خطأ مع استدعاء الدالة ببيانات مناسبة للحالة
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('403 failure', () async {
      when(
        mockClient.get(
          Uri.parse('$base/shipments/5/contract'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => http.Response('{"message":"denied"}', 403));

      await expectLater(
        ApiService.getShipmentContractSignedUrl(5),
        throwsA(isA<DarbakException>()),
      );
    });
  });

  group('ApiService.getMyChatConversations', () {
    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 200
    /// 📥 المدخلات: تهيئة Mock للاستجابة الناجحة مع مدخلات صالحة للدالة
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Happy Path — الحالة الطبيعية الناجحة
    /// ========================================
    test('200', () async {
      when(
        mockClient.get(
          Uri.parse('$base/chat/conversations/me'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => http.Response('[]', 200));

      expect(await ApiService.getMyChatConversations(), isEmpty);
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 401
    /// 📥 المدخلات: تهيئة Mock لإرجاع كود حالة خطأ مع استدعاء الدالة ببيانات مناسبة للحالة
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Negative Testing — اختبار الحالات الخاطئة
    /// ========================================
    test('401', () async {
      when(
        mockClient.get(
          Uri.parse('$base/chat/conversations/me'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => http.Response('{}', 401));

      await expectLater(
        ApiService.getMyChatConversations(),
        throwsA(isA<DarbakException>()),
      );
    });
  });

  group('ApiService.registerDevicePushToken', () {
    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 200
    /// 📥 المدخلات: تهيئة Mock للاستجابة الناجحة مع مدخلات صالحة للدالة
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Happy Path — الحالة الطبيعية الناجحة
    /// ========================================
    test('200', () async {
      when(
        mockClient.post(
          Uri.parse('$base/auth/device-token'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('', 200));

      await ApiService.registerDevicePushToken('tok');
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 422
    /// 📥 المدخلات: تهيئة Mock لإرجاع كود حالة خطأ مع استدعاء الدالة ببيانات مناسبة للحالة
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Negative Testing — اختبار الحالات الخاطئة
    /// ========================================
    test('422', () async {
      when(
        mockClient.post(
          Uri.parse('$base/auth/device-token'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('{}', 422));

      await expectLater(
        ApiService.registerDevicePushToken(''),
        throwsA(isA<DarbakException>()),
      );
    });
  });

  group('ApiService.recordShipmentStatus', () {
    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 201
    /// 📥 المدخلات: تهيئة Mock للاستجابة الناجحة مع مدخلات صالحة للدالة
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Happy Path — الحالة الطبيعية الناجحة
    /// ========================================
    test('201', () async {
      when(
        mockClient.post(
          Uri.parse('$base/shipment-status'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('{}', 201));

      await ApiService.recordShipmentStatus({'a': 1});
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 500
    /// 📥 المدخلات: تهيئة Mock لإرجاع كود حالة خطأ مع استدعاء الدالة ببيانات مناسبة للحالة
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('500', () async {
      when(
        mockClient.post(
          Uri.parse('$base/shipment-status'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('{}', 500));

      await expectLater(
        ApiService.recordShipmentStatus({}),
        throwsA(isA<DarbakException>()),
      );
    });
  });

  group('ApiService.getShipmentStatusHistory', () {
    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 200
    /// 📥 المدخلات: تهيئة Mock للاستجابة الناجحة مع مدخلات صالحة للدالة
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Happy Path — الحالة الطبيعية الناجحة
    /// ========================================
    test('200', () async {
      when(
        mockClient.get(Uri.parse('$base/shipment-status/3/history')),
      ).thenAnswer((_) async => http.Response('{}', 200));

      await ApiService.getShipmentStatusHistory(3);
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 404
    /// 📥 المدخلات: تهيئة Mock لإرجاع كود حالة خطأ مع استدعاء الدالة ببيانات مناسبة للحالة
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Negative Testing — اختبار الحالات الخاطئة
    /// ========================================
    test('404', () async {
      when(
        mockClient.get(Uri.parse('$base/shipment-status/3/history')),
      ).thenAnswer((_) async => http.Response('{}', 404));

      await expectLater(
        ApiService.getShipmentStatusHistory(3),
        throwsA(isA<DarbakException>()),
      );
    });
  });

  group('ApiService.acceptBid', () {
    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 200
    /// 📥 المدخلات: تهيئة Mock للاستجابة الناجحة مع مدخلات صالحة للدالة
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Happy Path — الحالة الطبيعية الناجحة
    /// ========================================
    test('200', () async {
      when(
        mockClient.post(
          Uri.parse('$base/bids/10/accept'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => http.Response('{}', 200));

      await ApiService.acceptBid(10);
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 409
    /// 📥 المدخلات: تهيئة Mock لإرجاع كود حالة خطأ مع استدعاء الدالة ببيانات مناسبة للحالة
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Negative Testing — اختبار الحالات الخاطئة
    /// ========================================
    test('409', () async {
      when(
        mockClient.post(
          Uri.parse('$base/bids/10/accept'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => http.Response('{}', 409));

      await expectLater(
        ApiService.acceptBid(10),
        throwsA(isA<DarbakException>()),
      );
    });
  });

  group('ApiService.getChatMessages', () {
    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 200
    /// 📥 المدخلات: تهيئة Mock للاستجابة الناجحة مع مدخلات صالحة للدالة
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Happy Path — الحالة الطبيعية الناجحة
    /// ========================================
    test('200', () async {
      when(
        mockClient.get(
          Uri.parse('$base/chat/1'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => http.Response('[]', 200));

      expect(await ApiService.getChatMessages(1), isEmpty);
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 500
    /// 📥 المدخلات: تهيئة Mock لإرجاع كود حالة خطأ مع استدعاء الدالة ببيانات مناسبة للحالة
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('500', () async {
      when(
        mockClient.get(
          Uri.parse('$base/chat/1'),
          headers: anyNamed('headers'),
        ),
      ).thenAnswer((_) async => http.Response('{}', 500));

      await expectLater(
        ApiService.getChatMessages(1),
        throwsA(isA<DarbakException>()),
      );
    });
  });

  group('ApiService.sendChatMessage', () {
    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 201
    /// 📥 المدخلات: تهيئة Mock للاستجابة الناجحة مع مدخلات صالحة للدالة
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Happy Path — الحالة الطبيعية الناجحة
    /// ========================================
    test('201', () async {
      when(
        mockClient.post(
          Uri.parse('$base/chat/send'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('{}', 201));

      await ApiService.sendChatMessage(
        shipmentId: 1,
        receiverId: 2,
        message: 'hi',
      );
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 400
    /// 📥 المدخلات: تهيئة Mock لإرجاع كود حالة خطأ مع استدعاء الدالة ببيانات مناسبة للحالة
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Negative Testing — اختبار الحالات الخاطئة
    /// ========================================
    test('400', () async {
      when(
        mockClient.post(
          Uri.parse('$base/chat/send'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer((_) async => http.Response('{}', 400));

      await expectLater(
        ApiService.sendChatMessage(
          shipmentId: 1,
          receiverId: 2,
          message: '',
        ),
        throwsA(isA<DarbakException>()),
      );
    });
  });

  group('ApiService.login exhaustive scenarios', () {
    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: empty identifier and password forwards backend validation message
    /// 📥 المدخلات: استدعاء الدالة بمدخلات فارغة أو Payload فارغ
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Negative Testing — اختبار الحالات الخاطئة
    /// ========================================
    test('empty identifier and password forwards backend validation message', () async {
      stubPost(
        '/auth/login',
        statusCode: 400,
        body: '{"message":"الرجاء تعبئة جميع الحقول"}',
      );
      await expectLater(
        ApiService.login('', ''),
        throwsA(
          isA<DarbakException>().having(
            (e) => e.toString(),
            'message',
            contains('الرجاء تعبئة جميع الحقول'),
          ),
        ),
      );
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: null parameters through dynamic call throw TypeError
    /// 📥 المدخلات: استدعاء الدالة بقيم null (عبر dynamic عند الحاجة)
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('null parameters through dynamic call throw TypeError', () {
      final dynamic loginFn = ApiService.login;
      expect(() => Function.apply(loginFn, [null, 'pass']), throwsA(isA<TypeError>()));
      expect(() => Function.apply(loginFn, ['identifier', null]), throwsA(isA<TypeError>()));
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: timeout exception is wrapped as DarbakException
    /// 📥 المدخلات: تهيئة Mock لرمي TimeoutException أثناء استدعاء الشبكة
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('timeout exception is wrapped as DarbakException', () async {
      when(
        mockClient.post(
          Uri.parse('$base/auth/login'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenThrow(TimeoutException('request timeout'));

      await expectLater(
        ApiService.login('u', 'p'),
        throwsA(
          isA<DarbakException>().having(
            (e) => e.toString(),
            'message',
            contains('TimeoutException'),
          ),
        ),
      );
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: socket exception is mapped to Arabic connectivity error
    /// 📥 المدخلات: تهيئة Mock لرمي SocketException لمحاكاة انقطاع الاتصال
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('socket exception is mapped to Arabic connectivity error', () async {
      when(
        mockClient.post(
          Uri.parse('$base/auth/login'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenThrow(const SocketException('Failed host lookup'));

      await expectLater(
        ApiService.login('u', 'p'),
        throwsA(
          isA<DarbakException>().having(
            (e) => e.toString(),
            'message',
            contains('تعذر الاتصال بالخادم'),
          ),
        ),
      );
    });

    for (final status in [401, 403, 404, 500, 503]) {
      /// ========================================
      /// 🧪 الهدف: التحقق من سيناريو: HTTP $status returns DarbakException
      /// 📥 المدخلات: استدعاء الدالة بمدخلات الاختبار المحددة مع تهيئة MockClient
      /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
      /// 🔍 التقنية: Equivalence Partitioning — تقسيم التكافؤ
      /// ========================================
      test('HTTP $status returns DarbakException', () async {
        stubPost('/auth/login', statusCode: status, body: '{"message":"e$status"}');
        await expectLater(ApiService.login('u', 'p'), throwsA(isA<DarbakException>()));
      });
    }
  });

  group('Login Screen', () {
    Future<void> _expectLoginRequestWith({
      required String identifier,
      required String password,
    }) async {
      when(
        mockClient.post(
          Uri.parse('$base/auth/login'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          '{"user":{"id":1,"role":"shipper","email":"$identifier","full_name":"U"},"token":"abc"}',
          200,
        ),
      );

      await ApiService.login(identifier, password);
      final captured = verify(
        mockClient.post(
          Uri.parse('$base/auth/login'),
          headers: anyNamed('headers'),
          body: captureAnyNamed('body'),
        ),
      ).captured.single as String;
      final payload = jsonDecode(captured) as Map<String, dynamic>;
      expect(payload['identifier'], identifier);
      expect(payload['password'], password);
    }

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: valid email + valid password passes validation path
    /// 📥 المدخلات: استدعاء الدالة بمدخلات الاختبار المحددة مع تهيئة MockClient
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Equivalence Partitioning — تقسيم التكافؤ
    /// ========================================
    test('valid email + valid password passes validation path', () async {
      await _expectLoginRequestWith(identifier: 'user@gmail.com', password: '123456');
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: empty email shows error from API
    /// 📥 المدخلات: استدعاء الدالة بمدخلات فارغة أو Payload فارغ
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('empty email shows error from API', () async {
      stubPost('/auth/login', statusCode: 400, body: '{"message":"البريد الإلكتروني مطلوب"}');
      await expectLater(
        ApiService.login('', '123456'),
        throwsA(
          isA<DarbakException>().having(
            (e) => e.message,
            'message',
            contains('البريد الإلكتروني مطلوب'),
          ),
        ),
      );
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: empty password shows error from API
    /// 📥 المدخلات: استدعاء الدالة بمدخلات فارغة أو Payload فارغ
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('empty password shows error from API', () async {
      stubPost('/auth/login', statusCode: 400, body: '{"message":"كلمة المرور مطلوبة"}');
      await expectLater(
        ApiService.login('user@gmail.com', ''),
        throwsA(isA<DarbakException>()),
      );
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: both empty shows both errors from API
    /// 📥 المدخلات: استدعاء الدالة بمدخلات فارغة أو Payload فارغ
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('both empty shows both errors from API', () async {
      stubPost('/auth/login', statusCode: 400, body: '{"message":"البريد وكلمة المرور مطلوبان"}');
      await expectLater(
        ApiService.login('', ''),
        throwsA(
          isA<DarbakException>().having(
            (e) => e.message,
            'message',
            contains('مطلوبان'),
          ),
        ),
      );
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: email without @ shows format error
    /// 📥 المدخلات: استدعاء الدالة بمدخلات الاختبار المحددة مع تهيئة MockClient
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('email without @ shows format error', () async {
      stubPost('/auth/login', statusCode: 400, body: '{"message":"صيغة البريد الإلكتروني غير صحيحة"}');
      await expectLater(
        ApiService.login('testgmail.com', '123456'),
        throwsA(isA<DarbakException>()),
      );
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: email with spaces shows format error
    /// 📥 المدخلات: استدعاء الدالة بمدخلات الاختبار المحددة مع تهيئة MockClient
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('email with spaces shows format error', () async {
      stubPost('/auth/login', statusCode: 400, body: '{"message":"صيغة البريد الإلكتروني غير صحيحة"}');
      await expectLater(
        ApiService.login('test @gmail.com', '123456'),
        throwsA(isA<DarbakException>()),
      );
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: password exactly 5 chars below min shows error
    /// 📥 المدخلات: استدعاء الدالة بمدخلات الاختبار المحددة مع تهيئة MockClient
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Boundary Value Analysis — اختبار الحدود
    /// ========================================
    test('password exactly 5 chars below min shows error', () async {
      stubPost('/auth/login', statusCode: 400, body: '{"message":"كلمة المرور قصيرة جدا"}');
      await expectLater(
        ApiService.login('user@gmail.com', '12345'),
        throwsA(isA<DarbakException>()),
      );
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: password exactly 6 chars min boundary passes
    /// 📥 المدخلات: استدعاء الدالة بمدخلات الاختبار المحددة مع تهيئة MockClient
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Boundary Value Analysis — اختبار الحدود
    /// ========================================
    test('password exactly 6 chars min boundary passes', () async {
      await _expectLoginRequestWith(identifier: 'user@gmail.com', password: '123456');
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: uppercase email TEST@gmail.com passes case-insensitive flow
    /// 📥 المدخلات: استدعاء الدالة بمدخلات الاختبار المحددة مع تهيئة MockClient
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Equivalence Partitioning — تقسيم التكافؤ
    /// ========================================
    test('uppercase email TEST@gmail.com passes case-insensitive flow', () async {
      await _expectLoginRequestWith(identifier: 'TEST@gmail.com', password: '123456');
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: SQL injection in email field rejected safely
    /// 📥 المدخلات: استدعاء الدالة بمدخلات الاختبار المحددة مع تهيئة MockClient
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Security Testing — اختبار الأمان (SQL, XSS)
    /// ========================================
    test('SQL injection in email field rejected safely', () async {
      stubPost('/auth/login', statusCode: 400, body: '{"message":"صيغة البريد الإلكتروني غير صحيحة"}');
      await expectLater(
        ApiService.login("' OR 1=1 --@gmail.com", '123456'),
        throwsA(isA<DarbakException>()),
      );
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 200 success returns map for navigation flow
    /// 📥 المدخلات: تهيئة Mock للاستجابة الناجحة مع مدخلات صالحة للدالة
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Happy Path — الحالة الطبيعية الناجحة
    /// ========================================
    test('200 success returns map for navigation flow', () async {
      stubPost(
        '/auth/login',
        statusCode: 200,
        body: '{"user":{"id":1,"role":"driver","email":"a@b.c","full_name":"U"},"token":"abc"}',
      );
      final res = await ApiService.login('u', 'p');
      expect(res['user'], isA<Map<String, dynamic>>());
      expect(res['token'], 'abc');
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 401 wrong credentials throws بيانات خاطئة message
    /// 📥 المدخلات: تهيئة Mock لإرجاع كود حالة خطأ مع استدعاء الدالة ببيانات مناسبة للحالة
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('401 wrong credentials throws بيانات خاطئة message', () async {
      stubPost('/auth/login', statusCode: 401, body: '{"message":"بيانات خاطئة"}');
      await expectLater(
        ApiService.login('u', 'bad'),
        throwsA(
          isA<DarbakException>().having((e) => e.message, 'message', contains('بيانات خاطئة')),
        ),
      );
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 404 user not found throws proper message
    /// 📥 المدخلات: تهيئة Mock لإرجاع كود حالة خطأ مع استدعاء الدالة ببيانات مناسبة للحالة
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('404 user not found throws proper message', () async {
      stubPost('/auth/login', statusCode: 404, body: '{"message":"المستخدم غير موجود"}');
      await expectLater(
        ApiService.login('missing@x.com', 'p'),
        throwsA(
          isA<DarbakException>().having((e) => e.message, 'message', contains('المستخدم غير موجود')),
        ),
      );
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: 500 server error throws خطأ في السيرفر message
    /// 📥 المدخلات: تهيئة Mock لإرجاع كود حالة خطأ مع استدعاء الدالة ببيانات مناسبة للحالة
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('500 server error throws خطأ في السيرفر message', () async {
      stubPost('/auth/login', statusCode: 500, body: '{"message":"خطأ في السيرفر"}');
      await expectLater(
        ApiService.login('u', 'p'),
        throwsA(
          isA<DarbakException>().having((e) => e.message, 'message', contains('خطأ في السيرفر')),
        ),
      );
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: SocketException no internet maps to connectivity error
    /// 📥 المدخلات: تهيئة Mock لرمي SocketException لمحاكاة انقطاع الاتصال
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('SocketException no internet maps to connectivity error', () async {
      when(
        mockClient.post(
          Uri.parse('$base/auth/login'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenThrow(const SocketException('Failed host lookup'));
      await expectLater(
        ApiService.login('u', 'p'),
        throwsA(
          isA<DarbakException>().having(
            (e) => e.message,
            'message',
            contains('تعذر الاتصال بالخادم'),
          ),
        ),
      );
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: Timeout exception throws timeout error message
    /// 📥 المدخلات: تهيئة Mock لرمي TimeoutException أثناء استدعاء الشبكة
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('Timeout exception throws timeout error message', () async {
      when(
        mockClient.post(
          Uri.parse('$base/auth/login'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenThrow(TimeoutException('request timeout'));
      await expectLater(
        ApiService.login('u', 'p'),
        throwsA(
          isA<DarbakException>().having(
            (e) => e.message,
            'message',
            contains('TimeoutException'),
          ),
        ),
      );
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: Saudi phone number 05XXXXXXXX accepted as identifier
    /// 📥 المدخلات: استدعاء الدالة بمدخلات الاختبار المحددة مع تهيئة MockClient
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Equivalence Partitioning — تقسيم التكافؤ
    /// ========================================
    test('Saudi phone number 05XXXXXXXX accepted as identifier', () async {
      await _expectLoginRequestWith(identifier: '0512345678', password: '123456');
    });
  });

  group('ApiService.createShipment exhaustive scenarios', () {
    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: empty payload can return backend validation error
    /// 📥 المدخلات: استدعاء الدالة بمدخلات فارغة أو Payload فارغ
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('empty payload can return backend validation error', () async {
      stubPost('/shipments', statusCode: 400, body: '{"message":"invalid payload"}');
      await expectLater(
        ApiService.createShipment({}),
        throwsA(isA<DarbakException>()),
      );
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: null payload through dynamic call throws TypeError
    /// 📥 المدخلات: استدعاء الدالة بقيم null (عبر dynamic عند الحاجة)
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('null payload through dynamic call throws TypeError', () {
      final dynamic fn = ApiService.createShipment;
      expect(() => Function.apply(fn, [null]), throwsA(isA<TypeError>()));
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: timeout exception wrapped as DarbakException
    /// 📥 المدخلات: تهيئة Mock لرمي TimeoutException أثناء استدعاء الشبكة
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('timeout exception wrapped as DarbakException', () async {
      when(
        mockClient.post(
          Uri.parse('$base/shipments'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenThrow(TimeoutException('timeout'));
      await expectLater(
        ApiService.createShipment({'weightKg': 1.0}),
        throwsA(isA<DarbakException>()),
      );
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: socket exception wrapped as connectivity DarbakException
    /// 📥 المدخلات: تهيئة Mock لرمي SocketException لمحاكاة انقطاع الاتصال
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('socket exception wrapped as connectivity DarbakException', () async {
      when(
        mockClient.post(
          Uri.parse('$base/shipments'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenThrow(const SocketException('Connection refused'));
      await expectLater(
        ApiService.createShipment({'weightKg': 1.0}),
        throwsA(
          isA<DarbakException>().having(
            (e) => e.toString(),
            'message',
            contains('تعذر الاتصال بالخادم'),
          ),
        ),
      );
    });

    for (final status in [400, 401, 403, 404, 500, 503]) {
      /// ========================================
      /// 🧪 الهدف: التحقق من سيناريو: HTTP $status throws for createShipment
      /// 📥 المدخلات: استدعاء الدالة بمدخلات الاختبار المحددة مع تهيئة MockClient
      /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
      /// 🔍 التقنية: Error Handling — معالجة الأخطاء
      /// ========================================
      test('HTTP $status throws for createShipment', () async {
        stubPost('/shipments', statusCode: status, body: '{"message":"s$status"}');
        await expectLater(
          ApiService.createShipment({'weightKg': 1.0}),
          throwsA(isA<DarbakException>()),
        );
      });
    }
  });

  group('ApiService.placeBid exhaustive scenarios', () {
    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: empty payload returns validation error
    /// 📥 المدخلات: استدعاء الدالة بمدخلات فارغة أو Payload فارغ
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('empty payload returns validation error', () async {
      stubPost('/bids', statusCode: 400, body: '{"message":"required fields missing"}');
      await expectLater(ApiService.placeBid({}), throwsA(isA<DarbakException>()));
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: null payload through dynamic call throws TypeError
    /// 📥 المدخلات: استدعاء الدالة بقيم null (عبر dynamic عند الحاجة)
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('null payload through dynamic call throws TypeError', () {
      final dynamic fn = ApiService.placeBid;
      expect(() => Function.apply(fn, [null]), throwsA(isA<TypeError>()));
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: timeout exception wrapped as DarbakException
    /// 📥 المدخلات: تهيئة Mock لرمي TimeoutException أثناء استدعاء الشبكة
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('timeout exception wrapped as DarbakException', () async {
      when(
        mockClient.post(
          Uri.parse('$base/bids'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenThrow(TimeoutException('timeout'));
      await expectLater(
        ApiService.placeBid({'shipmentId': 1, 'driverId': 2, 'bidAmount': 10.0}),
        throwsA(isA<DarbakException>()),
      );
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: socket exception wrapped as connectivity DarbakException
    /// 📥 المدخلات: تهيئة Mock لرمي SocketException لمحاكاة انقطاع الاتصال
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('socket exception wrapped as connectivity DarbakException', () async {
      when(
        mockClient.post(
          Uri.parse('$base/bids'),
          headers: anyNamed('headers'),
          body: anyNamed('body'),
        ),
      ).thenThrow(const SocketException('SocketException: Failed host lookup'));
      await expectLater(
        ApiService.placeBid({'shipmentId': 1, 'driverId': 2, 'bidAmount': 10.0}),
        throwsA(
          isA<DarbakException>().having(
            (e) => e.toString(),
            'message',
            contains('تعذر الاتصال بالخادم'),
          ),
        ),
      );
    });

    for (final status in [400, 401, 403, 404, 500, 503]) {
      /// ========================================
      /// 🧪 الهدف: التحقق من سيناريو: HTTP $status throws for placeBid
      /// 📥 المدخلات: استدعاء الدالة بمدخلات الاختبار المحددة مع تهيئة MockClient
      /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
      /// 🔍 التقنية: Error Handling — معالجة الأخطاء
      /// ========================================
      test('HTTP $status throws for placeBid', () async {
        stubPost('/bids', statusCode: status, body: '{"message":"b$status"}');
        await expectLater(
          ApiService.placeBid({'shipmentId': 1, 'driverId': 2, 'bidAmount': 10.0}),
          throwsA(isA<DarbakException>()),
        );
      });
    }
  });

  group('ApiService.getShipments exhaustive scenarios', () {
    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: timeout exception wrapped as DarbakException
    /// 📥 المدخلات: تهيئة Mock لرمي TimeoutException أثناء استدعاء الشبكة
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('timeout exception wrapped as DarbakException', () async {
      when(
        mockClient.get(
          Uri.parse('$base/shipments'),
          headers: anyNamed('headers'),
        ),
      ).thenThrow(TimeoutException('request timeout'));
      await expectLater(ApiService.getShipments(), throwsA(isA<DarbakException>()));
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: socket exception wrapped as connectivity DarbakException
    /// 📥 المدخلات: تهيئة Mock لرمي SocketException لمحاكاة انقطاع الاتصال
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('socket exception wrapped as connectivity DarbakException', () async {
      when(
        mockClient.get(
          Uri.parse('$base/shipments'),
          headers: anyNamed('headers'),
        ),
      ).thenThrow(const SocketException('Failed host lookup'));
      await expectLater(
        ApiService.getShipments(),
        throwsA(
          isA<DarbakException>().having(
            (e) => e.toString(),
            'message',
            contains('تعذر الاتصال بالخادم'),
          ),
        ),
      );
    });

    for (final status in [400, 401, 403, 404, 500, 503]) {
      /// ========================================
      /// 🧪 الهدف: التحقق من سيناريو: HTTP $status throws for getShipments
      /// 📥 المدخلات: استدعاء الدالة بمدخلات الاختبار المحددة مع تهيئة MockClient
      /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
      /// 🔍 التقنية: Error Handling — معالجة الأخطاء
      /// ========================================
      test('HTTP $status throws for getShipments', () async {
        stubGet('/shipments', statusCode: status, body: '{"message":"m$status"}');
        await expectLater(ApiService.getShipments(), throwsA(isA<DarbakException>()));
      });
    }
  });

  group('ApiService.register exhaustive scenarios', () {
    Map<String, dynamic> makeData(String path) => {
      'fullName': 'Test User',
      'email': 't@t.com',
      'phone': '0511111111',
      'password': 'secret12',
      'role': 'shipper',
      'documentPath': path,
    };

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: empty parameters map still sends multipart and can fail with 400
    /// 📥 المدخلات: تهيئة Mock لإرجاع كود حالة خطأ مع استدعاء الدالة ببيانات مناسبة للحالة
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Negative Testing — اختبار الحالات الخاطئة
    /// ========================================
    test('empty parameters map still sends multipart and can fail with 400', () async {
      when(mockClient.send(any)).thenAnswer(
        (_) async => http.StreamedResponse(
          Stream.value(utf8.encode('{"message":"missing fields"}')),
          400,
        ),
      );
      await expectLater(ApiService.register({}), throwsA(isA<DarbakException>()));
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: null parameters through dynamic call throws TypeError
    /// 📥 المدخلات: استدعاء الدالة بقيم null (عبر dynamic عند الحاجة)
    /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('null parameters through dynamic call throws TypeError', () {
      final dynamic fn = ApiService.register;
      expect(() => Function.apply(fn, [null]), throwsA(isA<TypeError>()));
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: socket exception from multipart send maps to connectivity DarbakException
    /// 📥 المدخلات: تهيئة Mock لرمي SocketException لمحاكاة انقطاع الاتصال
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('socket exception from multipart send maps to connectivity DarbakException', () async {
      final dir = Directory.systemTemp.createTempSync();
      final f = File('${dir.path}/doc.pdf')..writeAsStringSync('x');
      when(mockClient.send(any)).thenThrow(const SocketException('Connection refused'));
      await expectLater(
        ApiService.register(makeData(f.path)),
        throwsA(
          isA<DarbakException>().having(
            (e) => e.toString(),
            'message',
            contains('تعذر الاتصال بالخادم'),
          ),
        ),
      );
    });

    /// ========================================
    /// 🧪 الهدف: التحقق من سيناريو: timeout exception from multipart send wrapped as DarbakException
    /// 📥 المدخلات: تهيئة Mock لرمي TimeoutException أثناء استدعاء الشبكة
    /// ✅ النتيجة المتوقعة: يجب إرجاع نتيجة صحيحة من نوع/قيمة متوقعة وفق السيناريو
    /// 🔍 التقنية: Error Handling — معالجة الأخطاء
    /// ========================================
    test('timeout exception from multipart send wrapped as DarbakException', () async {
      final dir = Directory.systemTemp.createTempSync();
      final f = File('${dir.path}/doc.pdf')..writeAsStringSync('x');
      when(mockClient.send(any)).thenThrow(TimeoutException('timeout'));
      await expectLater(
        ApiService.register(makeData(f.path)),
        throwsA(isA<DarbakException>()),
      );
    });

    for (final status in [401, 403, 404, 500, 503]) {
      /// ========================================
      /// 🧪 الهدف: التحقق من سيناريو: multipart HTTP $status throws for register
      /// 📥 المدخلات: تجهيز ملف مؤقت ومسار multipart مع تهيئة send في MockClient
      /// ✅ النتيجة المتوقعة: يجب رمي DarbakException (أو الخطأ المتوقع) والتحقق من السلوك الصحيح عند الفشل
      /// 🔍 التقنية: Error Handling — معالجة الأخطاء
      /// ========================================
      test('multipart HTTP $status throws for register', () async {
        final dir = Directory.systemTemp.createTempSync();
        final f = File('${dir.path}/doc.pdf')..writeAsStringSync('x');
        when(mockClient.send(any)).thenAnswer(
          (_) async => http.StreamedResponse(
            Stream.value(utf8.encode('{"message":"register $status"}')),
            status,
          ),
        );
        await expectLater(
          ApiService.register(makeData(f.path)),
          throwsA(isA<DarbakException>()),
        );
      });
    }
  });
}

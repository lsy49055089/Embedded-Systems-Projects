import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/carrier_position.dart';
import 'alert_service.dart';

class CloudService extends ChangeNotifier {
  CloudService({this.localAlerts});
  final AlertService? localAlerts;
  // 시뮬레이션 알림은 Firebase 컬렉션에 쓰지 않고 앱 메모리에만 남긴다.
  void publishDemoPosition(CarrierPosition position) {
    if (!AppConfig.demoMode) return;
    travelerUid = 'DEMO-TRAVELER';
    travelerPosition = position;
    notifyListeners();
  }

  void publishDemoAlert({
    required String type,
    required String message,
    CarrierPosition? position,
  }) {
    if (!AppConfig.demoMode) return;
    alerts.insert(0, {
      'id': 'demo-${DateTime.now().microsecondsSinceEpoch}',
      'type': '[시뮬레이션] $type',
      'message': message,
      'createdAt': DateTime.now(),
      'latitude': position?.latitude,
      'longitude': position?.longitude,
    });
    notifyListeners();
  }

  bool ready = false;
  String? error;
  String? uid;
  String? travelerUid;
  CarrierPosition? travelerPosition;
  DateTime? _lastLocationUpload;
  List<String> requests = [];
  List<Map<String, dynamic>> alerts = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _requestSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _alertSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _locationSub;
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _pushSub;
  FirebaseFirestore get db => FirebaseFirestore.instance;

  Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      final credential = await FirebaseAuth.instance.signInAnonymously();
      uid = credential.user!.uid;
      await db.collection('users').doc(uid).set({
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      ready = true;
      _listenRequests();
      await _registerPushToken();
      _pushSub = FirebaseMessaging.onMessage.listen((message) {
        final notification = message.notification;
        if (notification == null || localAlerts == null) return;
        unawaited(localAlerts!.show(
          notification.title ?? '스마트 캐리어 알림',
          notification.body ?? '',
        ).catchError((Object e) {
          error = '푸시 알림 표시 실패: $e';
          notifyListeners();
        }));
      });
    } catch (e) {
      error = 'Firebase 준비 필요: $e';
      ready = false;
    }
    notifyListeners();
  }

  Future<void> _registerPushToken() async {
    if (!ready || uid == null) return;
    try {
      await FirebaseMessaging.instance.requestPermission();
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _saveToken(token);
      _tokenSub = FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);
    } catch (e) {
      error = '푸시 알림 등록 실패: $e';
      notifyListeners();
    }
  }

  Future<void> _saveToken(String token) async {
    // 토큰 문자열을 문서 ID로 사용하지 않고 문서 필드로 저장한다.
    if (uid == null) return;
    await db.collection('users').doc(uid).collection('devices')
        .doc('primary').set({'token': token});
  }

  void _listenRequests() {
    _requestSub?.cancel();
    _requestSub = db.collection('users').doc(uid)
        .collection('requests').snapshots().listen((snapshot) {
      requests = snapshot.docs.map((d) => d.id).toList();
      notifyListeners();
    }, onError: (Object e) {
      error = '연결 요청 조회 실패: $e';
      notifyListeners();
    });
  }

  Future<void> requestGuardianAccess(String targetUid) async {
    if (!ready || uid == null) throw StateError('Firebase 연결이 필요합니다.');
    if (targetUid.isEmpty || targetUid == uid) throw StateError('여행자 UID를 확인하세요.');
    await db.collection('users').doc(targetUid)
        .collection('requests').doc(uid).set({
      'requestedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> approveGuardian(String guardianUid) async {
    if (!ready || uid == null) throw StateError('Firebase 연결이 필요합니다.');
    final root = db.collection('users').doc(uid);
    await root.collection('guardians').doc(guardianUid).set({
      'approvedAt': FieldValue.serverTimestamp(),
    });
    await root.collection('requests').doc(guardianUid).delete();
  }

  Future<void> publishPosition(CarrierPosition position) async {
    if (!ready || uid == null) return;
    final now = DateTime.now();
    if (_lastLocationUpload != null &&
        now.difference(_lastLocationUpload!) < const Duration(seconds: 15)) {
      return;
    }
    _lastLocationUpload = now;
    try {
      await db.collection('users').doc(uid)
          .collection('locations').doc('current').set({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'receivedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      error = '위치 공유 실패: $e';
      notifyListeners();
    }
  }

  Future<void> watchTraveler(String targetUid) async {
    if (targetUid.isEmpty || targetUid == uid) {
      throw StateError('조회할 여행자 UID를 확인하세요.');
    }
    if (!ready || uid == null) throw StateError('Firebase 연결이 필요합니다.');
    // 스트림을 열기 전에 보호자 승인 여부를 확인한다.
    // 승인되지 않은 요청을 성공으로 표시하지 않는다.
    final access = await db.collection('users').doc(targetUid)
        .collection('guardians').doc(uid).get();
    if (!access.exists) {
      throw StateError('여행자 계정에서 보호자 연결 승인이 필요합니다.');
    }
    await _alertSub?.cancel();
    await _locationSub?.cancel();
    travelerUid = targetUid;
    alerts = [];
    travelerPosition = null;
    _locationSub = db.collection('users').doc(targetUid)
        .collection('locations').doc('current').snapshots().listen((document) {
      final data = document.data();
      final lat = (data?['latitude'] as num?)?.toDouble();
      final lon = (data?['longitude'] as num?)?.toDouble();
      final stamp = data?['receivedAt'];
      travelerPosition = CarrierPosition.fromStored(
        latitude: lat, longitude: lon,
        receivedAtEpochMs: stamp is Timestamp
            ? stamp.toDate().millisecondsSinceEpoch : null,
      );
      notifyListeners();
    }, onError: (Object e) {
      error = '여행자 위치 접근 실패(승인 필요): $e';
      notifyListeners();
    });
    _alertSub = db.collection('users').doc(targetUid)
        .collection('alerts')
        .orderBy('createdAt', descending: true).limit(30)
        .snapshots().listen((snapshot) {
      alerts = snapshot.docs.map((d) => {...d.data(), 'id': d.id}).toList();
      error = null;
      notifyListeners();
    }, onError: (Object e) {
      error = '알림 접근 실패(여행자의 승인 필요): $e';
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> sendAlert({
    required String type,
    required String message,
    double? latitude,
    double? longitude,
  }) async {
    if (!ready || uid == null) throw StateError('Firebase 연결이 필요합니다.');
    await db.collection('users').doc(uid).collection('alerts').add({
      'type': type,
      'message': message,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  void dispose() {
    _requestSub?.cancel();
    _alertSub?.cancel();
    _locationSub?.cancel();
    _tokenSub?.cancel();
    _pushSub?.cancel();
    super.dispose();
  }
}

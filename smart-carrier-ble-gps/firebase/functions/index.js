'use strict';

const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');
admin.initializeApp();

// 새로운 SOS/분실 경고가 등록되면 승인된 보호자 기기에 FCM을 발송한다.
exports.notifyGuardians = functions.firestore
  .document('users/{ownerUid}/alerts/{alertId}')
  .onCreate(async (snapshot, context) => {
    const alert = snapshot.data();
    const ownerUid = context.params.ownerUid;
    const guardiansSnapshot = await admin.firestore().collection('users')
      .doc(ownerUid).collection('guardians').get();
    const tokens = [];
    for (const guardian of guardiansSnapshot.docs) {
      const devices = await admin.firestore().collection('users')
        .doc(guardian.id).collection('devices').get();
      for (const device of devices.docs) {
        const token = device.get('token');
        if (typeof token === 'string' && token.length) tokens.push(token);
      }
    }
    const recipients = [...new Set(tokens)];
    if (recipients.length === 0) return null;
    const title = alert.type === 'sos' ? '긴급 SOS 요청'
      : alert.type === 'safezone' ? '캐리어 안전구역 이탈' : '캐리어 분실 경고';
    // FCM은 하나의 multicast 요청에 최대 500개 토큰을 지원한다.
    for (let i = 0; i < recipients.length; i += 500) {
      const batch = recipients.slice(i, i + 500);
      await admin.messaging().sendEachForMulticast({
        tokens: batch,
        notification: { title, body: String(alert.message || '') },
        data: { type: String(alert.type || 'alert'), ownerUid },
      });
    }
    return null;
  });

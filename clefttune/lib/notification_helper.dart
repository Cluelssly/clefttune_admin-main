// ═══════════════════════════════════════════════════════════════════
// CLEFTTUNE ADMIN — notification_helper.dart
//
// A static helper that any part of the app (or even your user app /
// Cloud Functions) can call to fire a specific admin notification.
//
// HOW IT WORKS:
//   1. Call NotificationHelper.someEvent(...) from anywhere.
//   2. The helper writes a doc to Firestore: adminNotifications/{id}
//   3. NotificationProvider (notifications.dart) already listens to
//      that collection in real-time → the bell updates instantly.
//
// USAGE EXAMPLES:
//   // When a new user signs up (call from user app or Cloud Function):
//   await NotificationHelper.newUser(
//     userId: uid, name: 'Maria Santos', email: 'maria@email.com');
//
//   // When admin manually upgrades a user:
//   await NotificationHelper.newPremiumUser(
//     userId: uid, name: 'Maria Santos', email: 'maria@email.com');
//
//   // When a payment is submitted (call from user app):
//   await NotificationHelper.paymentPending(
//     userId: uid, name: 'Maria', method: 'GCash',
//     referenceNumber: 'GC-12345', amount: 99);
// ═══════════════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';

// Matches the NotifType enum in notifications.dart
enum _NType {
  newUser,
  newPremiumUser,
  accountDeleted,
  profileUpdated,
  paymentPending,
  paymentVerified,
  paymentRejected,
  paymentExpired,
  premiumCancelled,
  premiumExpired,
}

class NotificationHelper {
  NotificationHelper._(); // purely static — no instances

  static final _col =
      FirebaseFirestore.instance.collection('adminNotifications');

  // ─────────────────────────────────────────────────────────────────
  // INTERNAL WRITE
  // id is used as the Firestore document ID so duplicate events are
  // idempotent (set() with merge:false overwrites, but the
  // NotificationProvider's duplicate guard on `id` means it never
  // shows twice in a session even without merge).
  // ─────────────────────────────────────────────────────────────────
  static Future<void> _write({
    required String    id,
    required _NType    type,
    required String    title,
    required String    body,
    DateTime?          time,
  }) async {
    try {
      await _col.doc(id).set({
        'type':    type.name,
        'title':   title,
        'body':    body,
        'time':    Timestamp.fromDate(time ?? DateTime.now()),
        'isRead':  false,
        'savedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Never throw — a failed notification must never break the caller.
      debugPrint('[NotificationHelper] Failed to write "$id": $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // USER EVENTS
  // ─────────────────────────────────────────────────────────────────

  /// Call when a new user registers (from user app or Cloud Function).
  static Future<void> newUser({
    required String userId,
    required String name,
    required String email,
  }) =>
      _write(
        id:    'user_$userId',
        type:  _NType.newUser,
        title: 'New user registered',
        body:  '$name ($email) just created an account.',
      );

  /// Call when a user is upgraded to Premium (manually or via payment verify).
  /// The admin panel calls this automatically on verify — use this if you
  /// need to trigger it from outside the admin panel.
  static Future<void> newPremiumUser({
    required String userId,
    required String name,
    required String email,
  }) =>
      _write(
        id:    'newprem_$userId',
        type:  _NType.newPremiumUser,
        title: 'User upgraded to Premium ⭐',
        body:  '$name ($email) is now a Premium member. Revenue updated.',
      );

  /// Call when a user deletes their own account (from user app / Cloud Function).
  static Future<void> accountDeleted({
    required String userId,
    required String name,
    required String email,
  }) =>
      _write(
        id:    'deleted_${userId}_${DateTime.now().millisecondsSinceEpoch}',
        type:  _NType.accountDeleted,
        title: 'Account deleted',
        body:  '$name ($email) permanently deleted their account.',
      );

  /// Call when a user updates their profile (name / email).
  static Future<void> profileUpdated({
    required String userId,
    required String name,
    List<String>    changedFields = const ['profile'],
  }) =>
      _write(
        id:    'profile_${userId}_${DateTime.now().millisecondsSinceEpoch}',
        type:  _NType.profileUpdated,
        title: 'Profile updated',
        body:  '$name updated their ${changedFields.join(" & ")}.',
      );

  // ─────────────────────────────────────────────────────────────────
  // PAYMENT EVENTS
  // ─────────────────────────────────────────────────────────────────

  /// Call from the user app when a payment is submitted and pending review.
  static Future<void> paymentPending({
    required String paymentId,
    required String userId,
    required String name,
    required String method,
    required String referenceNumber,
    int             amount = 99,
  }) =>
      _write(
        id:    'pay_pending_$paymentId',
        type:  _NType.paymentPending,
        title: 'New payment submitted',
        body:  '$name submitted a ₱$amount ${method.toUpperCase()} payment.'
               ' Ref: $referenceNumber — awaiting your review.',
      );

  /// Call (or let the admin panel trigger it) after verifying a payment.
  static Future<void> paymentVerified({
    required String paymentId,
    required String name,
    required String method,
    required String referenceNumber,
    int             amount = 99,
  }) =>
      _write(
        id:    'pay_verified_$paymentId',
        type:  _NType.paymentVerified,
        title: 'Payment verified',
        body:  '₱$amount ${method.toUpperCase()} payment from $name'
               ' (Ref: $referenceNumber) was verified. User upgraded to Premium.',
      );

  /// Call after rejecting a payment.
  static Future<void> paymentRejected({
    required String paymentId,
    required String name,
    required String method,
    required String referenceNumber,
    int             amount  = 99,
    String          reason  = '',
  }) =>
      _write(
        id:    'pay_rejected_$paymentId',
        type:  _NType.paymentRejected,
        title: 'Payment rejected',
        body:  '₱$amount ${method.toUpperCase()} payment from $name'
               ' (Ref: $referenceNumber) was rejected.'
               '${reason.isNotEmpty ? ' Reason: $reason' : ''}',
      );

  /// Call when a pending payment expires without admin action.
  static Future<void> paymentExpired({
    required String paymentId,
    required String name,
    required String method,
    required String referenceNumber,
    int             amount = 99,
  }) =>
      _write(
        id:    'pay_expired_$paymentId',
        type:  _NType.paymentExpired,
        title: 'Payment expired',
        body:  '₱$amount ${method.toUpperCase()} payment from $name'
               ' (Ref: $referenceNumber) expired without being actioned.',
      );

  // ─────────────────────────────────────────────────────────────────
  // PREMIUM EVENTS
  // ─────────────────────────────────────────────────────────────────

  /// Call when a user cancels their premium subscription.
  static Future<void> premiumCancelled({
    required String userId,
    required String name,
    required String email,
  }) =>
      _write(
        id:    'cancel_$userId',
        type:  _NType.premiumCancelled,
        title: 'Premium cancelled',
        body:  '$name ($email) cancelled their premium subscription.',
      );

  /// Call when a premium subscription expires (e.g. from a scheduled
  /// Cloud Function that checks premiumUntil dates).
  static Future<void> premiumExpired({
    required String userId,
    required String name,
    required String email,
  }) =>
      _write(
        id:    'expired_$userId',
        type:  _NType.premiumExpired,
        title: 'Premium expired',
        body:  '$name\'s ($email) premium subscription has expired.',
      );

  // ─────────────────────────────────────────────────────────────────
  // GENERIC / CUSTOM
  // ─────────────────────────────────────────────────────────────────

  /// Fire a fully custom notification — useful for one-off admin alerts.
  ///
  /// [id] should be unique per event. If you reuse an id, the existing
  /// Firestore doc is overwritten and the NotificationProvider will
  /// ignore it (duplicate guard by id) unless it's a new session.
  ///
  /// [type] must be one of the NotifType.name strings defined in
  /// notifications.dart — e.g. 'paymentPending', 'newUser', etc.
  static Future<void> custom({
    required String id,
    required String type,
    required String title,
    required String body,
    DateTime?       time,
  }) async {
    try {
      await _col.doc(id).set({
        'type':    type,
        'title':   title,
        'body':    body,
        'time':    Timestamp.fromDate(time ?? DateTime.now()),
        'isRead':  false,
        'savedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[NotificationHelper] Failed to write custom "$id": $e');
    }
  }
}

// Minimal debugPrint shim so this file compiles without importing flutter/foundation
// Remove this if you import flutter/foundation elsewhere in your project.
void debugPrint(String msg) {
  // ignore: avoid_print
  print(msg);
}
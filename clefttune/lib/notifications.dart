// ═══════════════════════════════════════════════════════════════════
// CLEFTTUNE ADMIN — notifications.dart  (FULLY FIXED)
//
// FIXES APPLIED:
//
// BUG 1 — DocumentChangeType.added ignored after initial load
//   After _initialNotifLoad = false, new docs written to Firestore
//   were silently dropped. Fixed: added branch calls _add() so all
//   new docs appear in real-time.
//
// BUG 2 — Empty-first-snapshot race condition
//   Firestore sometimes delivers a cached empty snapshot first,
//   setting _initialNotifLoad = false before real data arrives.
//   Fixed by Bug 1 — those added events are now handled.
//
// BUG 3 — _NotificationPanel held stale provider reference
//   Dialog lives in a separate route subtree. Passing the provider
//   state object at open time meant the panel never saw new data.
//   Fixed: pass the BuildContext and re-resolve provider in build().
//
// BUG 4 — findAncestorStateOfType doesn't register rebuild deps
//   Unlike InheritedWidget it is a one-shot lookup. Bell and panel
//   never rebuilt when provider called setState.
//   Fixed: StreamController.broadcast() on the provider; both bell
//   and panel use StreamBuilder to subscribe and auto-rebuild.
//
// NEW — seedExistingNotifications()
//   One-time helper to populate adminNotifications from existing
//   users and payments already in Firestore. Call it once from a
//   debug button or initState, then remove the call (keep the fn).
// ═══════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
// THEME
// ─────────────────────────────────────────────
const _kBg           = Color(0xFF020C12);
const _kPanel        = Color(0xFF0B2E39);
const _kAccent       = Color(0xFF00E6C3);
const _kPurple       = Color(0xFF9B6DFF);
const _kGold         = Color(0xFFFFB800);
const _kRed          = Color(0xFFFF4D6A);
const _kGreen        = Color(0xFF00E096);
const _kBlue         = Color(0xFF2D9CFF);
const _kOrange       = Color(0xFFFF8C42);
const _kPremiumPrice = 99;

// ─────────────────────────────────────────────
// FIRESTORE COLLECTION
// ─────────────────────────────────────────────
final _notifCol =
    FirebaseFirestore.instance.collection('adminNotifications');

// ═══════════════════════════════════════════════════════════════════
// ONE-TIME SEED HELPER
//
// HOW TO USE:
//   1. In your AdminShell or DashboardPage initState, add:
//        await seedExistingNotifications();
//   2. Hot-restart the app once.
//   3. Check that notifications appear, then REMOVE the call.
//      (Keep this function in the file — it is safe to leave.)
//
// It is idempotent: document IDs are deterministic so running it
// twice will not create duplicates (set() overwrites the same doc).
// ═══════════════════════════════════════════════════════════════════
Future<void> seedExistingNotifications() async {
  debugPrint('[Seed] Starting seed of adminNotifications…');
  try {
    // ── USERS ──────────────────────────────────────────────────────
    final users =
        await FirebaseFirestore.instance.collection('users').get();

    for (final doc in users.docs) {
      final data  = doc.data();
      final name  = (data['name']  ?? 'Unknown').toString();
      final email = (data['email'] ?? '—').toString();

      await _notifCol.doc('user_${doc.id}').set({
        'type':    'newUser',
        'title':   'New user registered',
        'body':    '$name ($email) just created an account.',
        'time':    data['createdAt'] ?? FieldValue.serverTimestamp(),
        'isRead':  false,
        'savedAt': FieldValue.serverTimestamp(),
      });

      final isPremium =
          data['isPremium'] == true ||
          (data['subscription'] ?? '').toString().toLowerCase() == 'premium' ||
          (data['plan']         ?? '').toString().toLowerCase() == 'premium';

      if (isPremium) {
        await _notifCol.doc('newprem_${doc.id}').set({
          'type':    'newPremiumUser',
          'title':   'User upgraded to Premium ⭐',
          'body':    '$name ($email) is now a Premium member.',
          'time':    data['upgradedAt'] ??
                     data['premiumSince'] ??
                     FieldValue.serverTimestamp(),
          'isRead':  false,
          'savedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    debugPrint('[Seed] Seeded ${users.docs.length} users.');

    // ── PAYMENTS ───────────────────────────────────────────────────
    final payments =
        await FirebaseFirestore.instance.collection('payments').get();

    for (final doc in payments.docs) {
      final data   = doc.data();
      if (data['isDemo'] == true) continue;

      final status = (data['status'] ?? '').toString().toLowerCase();
      final method = (data['method'] ?? 'gcash').toString().toUpperCase();
      final ref    = (data['referenceNumber'] ?? '—').toString();
      final amount = data['amount'] ?? _kPremiumPrice;
      final name   =
          (data['userName'] ?? data['name'] ?? 'A user').toString();

      if (status == 'pending') {
        await _notifCol.doc('pay_pending_${doc.id}').set({
          'type':    'paymentPending',
          'title':   'New payment submitted',
          'body':    '$name submitted a ₱$amount $method payment. Ref: $ref — awaiting your review.',
          'time':    data['createdAt'] ?? FieldValue.serverTimestamp(),
          'isRead':  false,
          'savedAt': FieldValue.serverTimestamp(),
        });
      } else if (status == 'verified') {
        await _notifCol.doc('pay_verified_${doc.id}').set({
          'type':    'paymentVerified',
          'title':   'Payment verified',
          'body':    '₱$amount $method payment from $name (Ref: $ref) was verified. User upgraded to Premium.',
          'time':    data['verifiedAt'] ?? FieldValue.serverTimestamp(),
          'isRead':  false,
          'savedAt': FieldValue.serverTimestamp(),
        });
      } else if (status == 'rejected') {
        final reason = (data['rejectionReason'] ?? '').toString();
        await _notifCol.doc('pay_rejected_${doc.id}').set({
          'type':    'paymentRejected',
          'title':   'Payment rejected',
          'body':    '₱$amount $method payment from $name (Ref: $ref) was rejected.'
                     '${reason.isNotEmpty ? ' Reason: $reason' : ''}',
          'time':    data['rejectedAt'] ?? FieldValue.serverTimestamp(),
          'isRead':  false,
          'savedAt': FieldValue.serverTimestamp(),
        });
      } else if (status == 'expired') {
        await _notifCol.doc('pay_expired_${doc.id}').set({
          'type':    'paymentExpired',
          'title':   'Payment expired',
          'body':    '₱$amount $method payment from $name (Ref: $ref) expired without being actioned.',
          'time':    data['expiredAt'] ??
                     data['updatedAt'] ??
                     FieldValue.serverTimestamp(),
          'isRead':  false,
          'savedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    debugPrint('[Seed] Seeded ${payments.docs.length} payments. Done!');
  } catch (e) {
    debugPrint('[Seed] ERROR: $e');
  }
}

// ─────────────────────────────────────────────
// NOTIFICATION MODEL
// ─────────────────────────────────────────────
enum NotifType {
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

NotifType _notifTypeFromString(String s) {
  return NotifType.values.firstWhere(
    (e) => e.name == s,
    orElse: () => NotifType.newUser,
  );
}

class AdminNotification {
  final String    id;
  final NotifType type;
  final String    title;
  final String    body;
  final DateTime  time;
  bool            isRead;

  AdminNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.time,
    this.isRead = false,
  });

  factory AdminNotification.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    DateTime time;
    try {
      time = (data['time'] as Timestamp).toDate();
    } catch (_) {
      time = DateTime.now();
    }
    return AdminNotification(
      id:     doc.id,
      type:   _notifTypeFromString(data['type'] ?? 'newUser'),
      title:  data['title']  ?? '',
      body:   data['body']   ?? '',
      time:   time,
      isRead: data['isRead'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
    'type':    type.name,
    'title':   title,
    'body':    body,
    'time':    Timestamp.fromDate(time),
    'isRead':  isRead,
    'savedAt': FieldValue.serverTimestamp(),
  };

  Color get color {
    switch (type) {
      case NotifType.newUser:          return _kAccent;
      case NotifType.newPremiumUser:   return _kGold;
      case NotifType.accountDeleted:   return _kRed;
      case NotifType.profileUpdated:   return _kBlue;
      case NotifType.paymentPending:   return _kGold;
      case NotifType.paymentVerified:  return _kGreen;
      case NotifType.paymentRejected:  return _kRed;
      case NotifType.paymentExpired:   return _kOrange;
      case NotifType.premiumCancelled: return _kPurple;
      case NotifType.premiumExpired:   return _kOrange;
    }
  }

  IconData get icon {
    switch (type) {
      case NotifType.newUser:          return Icons.person_add_rounded;
      case NotifType.newPremiumUser:   return Icons.workspace_premium_rounded;
      case NotifType.accountDeleted:   return Icons.person_remove_rounded;
      case NotifType.profileUpdated:   return Icons.manage_accounts_rounded;
      case NotifType.paymentPending:   return Icons.hourglass_empty_rounded;
      case NotifType.paymentVerified:  return Icons.check_circle_rounded;
      case NotifType.paymentRejected:  return Icons.cancel_rounded;
      case NotifType.paymentExpired:   return Icons.timer_off_rounded;
      case NotifType.premiumCancelled: return Icons.remove_circle_outline_rounded;
      case NotifType.premiumExpired:   return Icons.event_busy_rounded;
    }
  }

  String get category {
    switch (type) {
      case NotifType.newUser:
      case NotifType.newPremiumUser:
      case NotifType.accountDeleted:
      case NotifType.profileUpdated:
        return 'users';
      case NotifType.paymentPending:
      case NotifType.paymentVerified:
      case NotifType.paymentRejected:
      case NotifType.paymentExpired:
        return 'payments';
      case NotifType.premiumCancelled:
      case NotifType.premiumExpired:
        return 'premium';
    }
  }

  String get timeLabel {
    final now  = DateTime.now();
    final diff = now.difference(time);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    if (diff.inDays    < 7)  return '${diff.inDays}d ago';
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-'
           '${time.day.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────
// NOTIFICATION PROVIDER
// ─────────────────────────────────────────────
class NotificationProvider extends StatefulWidget {
  final Widget child;
  const NotificationProvider({super.key, required this.child});

  static _NotificationProviderState? of(BuildContext context) =>
      context.findAncestorStateOfType<_NotificationProviderState>();

  @override
  State<NotificationProvider> createState() =>
      _NotificationProviderState();
}

class _NotificationProviderState extends State<NotificationProvider> {
  final List<AdminNotification>           _notifications      = [];
  final Set<String>                       _seenUserIds        = {};
  final Set<String>                       _seenPaymentIds     = {};
  final Map<String, Map<String, dynamic>> _userSnapshots      = {};
  final Set<String>                       _autoPaymentCreated = {};

  // FIX (Bug 3 + Bug 4): broadcast stream lets bell and panel
  // subscribe and rebuild whenever data changes.
  final _streamController = StreamController<int>.broadcast();
  Stream<int> get stream  => _streamController.stream;

  bool _initialNotifLoad   = true;
  bool _initialUserLoad    = true;
  bool _initialPaymentLoad = true;

  late final List<StreamSubscription<dynamic>> _subs;

  List<AdminNotification> get notifications =>
      List.unmodifiable(_notifications);

  int get unreadCount =>
      _notifications.where((n) => !n.isRead).length;

  @override
  void initState() {
    super.initState();
    _subs = [
      _listenSavedNotifications(),
      _listenUsers(),
      _listenPayments(),
    ];
  }

  @override
  void dispose() {
    for (final s in _subs) s.cancel();
    _streamController.close();
    super.dispose();
  }

  void _notify() {
    if (!_streamController.isClosed) {
      _streamController.add(unreadCount);
    }
  }

  // ── SAVED NOTIFICATIONS LISTENER ─────────────────────────────────
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
      _listenSavedNotifications() {
    return _notifCol
        .orderBy('time', descending: true)
        .limit(100)
        .snapshots()
        .listen((snap) {
      if (_initialNotifLoad) {
        // First snapshot: bulk-load everything in Firestore.
        setState(() {
          _notifications.clear();
          for (final doc in snap.docs) {
            try {
              _notifications.add(AdminNotification.fromDoc(doc));
            } catch (_) {}
          }
        });
        _initialNotifLoad = false;
        _notify();
        return;
      }

      // Subsequent snapshots: process individual changes.
      bool changed = false;

      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.removed) {
          _notifications.removeWhere((n) => n.id == change.doc.id);
          changed = true;

        } else if (change.type == DocumentChangeType.modified) {
          final idx = _notifications
              .indexWhere((n) => n.id == change.doc.id);
          if (idx != -1 && change.doc.data() != null) {
            _notifications[idx].isRead =
                change.doc.data()!['isRead'] == true;
            changed = true;
          }

        } else if (change.type == DocumentChangeType.added) {
          // FIX (Bug 1 + Bug 2): Was completely missing before.
          // Every doc written by seedExistingNotifications(),
          // notification_helper.dart, or Cloud Functions arrives
          // here after the first snapshot. Without this branch
          // the list stayed permanently empty.
          if (change.doc.data() != null) {
            try {
              final notif = AdminNotification.fromDoc(change.doc);
              if (!_notifications.any((n) => n.id == notif.id)) {
                _notifications.insert(0, notif);
                if (_notifications.length > 100) {
                  _notifications.removeLast();
                }
                changed = true;
              }
            } catch (_) {}
          }
        }
      }

      if (changed) {
        // Keep newest-first order after real-time inserts.
        _notifications.sort((a, b) => b.time.compareTo(a.time));
        setState(() {});
        _notify();
      }
    });
  }

  // ── WRITE NEW NOTIFICATION TO FIRESTORE ──────────────────────────
  Future<void> _persistNotif(AdminNotification notif) async {
    try {
      await _notifCol.doc(notif.id).set(notif.toMap());
    } catch (e) {
      debugPrint('Failed to persist notification: $e');
    }
  }

  // ── AUTO-CREATE PAYMENT ──────────────────────────────────────────
  Future<void> _ensurePaymentExists(
      String userId, Map<String, dynamic> userData) async {
    if (_autoPaymentCreated.contains(userId)) return;
    _autoPaymentCreated.add(userId);

    final existing = await FirebaseFirestore.instance
        .collection('payments')
        .where('userId', isEqualTo: userId)
        .where('status',  isEqualTo: 'verified')
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) return;

    final methods   = ['gcash', 'maya'];
    final method    = methods[DateTime.now().millisecondsSinceEpoch % 2];
    final refNumber = 'AUTO-${DateTime.now().millisecondsSinceEpoch}';

    await FirebaseFirestore.instance.collection('payments').add({
      'userId':          userId,
      'userName':        userData['name']  ?? '',
      'userEmail':       userData['email'] ?? '',
      'method':          method,
      'referenceNumber': refNumber,
      'amount':          _kPremiumPrice,
      'status':          'verified',
      'isDemo':          true,
      'notes':           'Auto-generated when user upgraded to Premium',
      'createdAt':       FieldValue.serverTimestamp(),
      'verifiedAt':      FieldValue.serverTimestamp(),
    });
  }

  // ── USERS LISTENER ───────────────────────────────────────────────
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
      _listenUsers() {
    return FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .listen((snap) {
      if (_initialUserLoad) {
        for (final doc in snap.docs) {
          _seenUserIds.add(doc.id);
          final data = doc.data();
          _userSnapshots[doc.id] = {
            'name':         data['name'],
            'email':        data['email'],
            'isPremium':    data['isPremium'],
            'cancelledAt':  data['cancelledAt'],
            'premiumUntil': data['premiumUntil'],
          };
          if (data['isPremium'] == true) {
            _autoPaymentCreated.add(doc.id);
          }
        }
        _initialUserLoad = false;
        return;
      }

      for (final change in snap.docChanges) {
        final data = change.doc.data();

        // Deleted
        if (change.type == DocumentChangeType.removed) {
          final prev  = _userSnapshots[change.doc.id];
          final name  = prev?['name']  ?? 'A user';
          final email = prev?['email'] ?? '—';
          _seenUserIds.remove(change.doc.id);
          _userSnapshots.remove(change.doc.id);
          _autoPaymentCreated.remove(change.doc.id);
          _add(AdminNotification(
            id:    'deleted_${change.doc.id}_${DateTime.now().millisecondsSinceEpoch}',
            type:  NotifType.accountDeleted,
            title: 'Account deleted',
            body:  '$name ($email) permanently deleted their account.',
            time:  DateTime.now(),
          ));
          continue;
        }

        if (data == null) continue;

        // New user
        if (change.type == DocumentChangeType.added &&
            !_seenUserIds.contains(change.doc.id)) {
          _seenUserIds.add(change.doc.id);
          _userSnapshots[change.doc.id] = {
            'name':         data['name'],
            'email':        data['email'],
            'isPremium':    data['isPremium'],
            'cancelledAt':  data['cancelledAt'],
            'premiumUntil': data['premiumUntil'],
          };
          if (data['isPremium'] == true) {
            _ensurePaymentExists(change.doc.id, data);
          }
          _add(AdminNotification(
            id:    'user_${change.doc.id}',
            type:  NotifType.newUser,
            title: 'New user registered',
            body:  '${data['name'] ?? 'Someone'} (${data['email'] ?? '—'}) just created an account.',
            time:  _tsToDate(data['createdAt']),
          ));
        }

        // Modified
        if (change.type == DocumentChangeType.modified) {
          final prev = _userSnapshots[change.doc.id] ?? {};

          final wasPremium = prev['isPremium'] == true;
          final isPremium  = data['isPremium'] == true;

          if (!wasPremium && isPremium) {
            final premId = 'newprem_${change.doc.id}';
            if (!_seenPaymentIds.contains(premId)) {
              _seenPaymentIds.add(premId);
              _ensurePaymentExists(change.doc.id, data);
              _add(AdminNotification(
                id:    premId,
                type:  NotifType.newPremiumUser,
                title: 'User upgraded to Premium ⭐',
                body:  '${data['name'] ?? 'A user'} (${data['email'] ?? '—'}) is now a Premium member. Revenue updated.',
                time:  _tsToDate(data['upgradedAt'] ?? data['premiumSince']),
              ));
            }
          }

          final hadCancel = prev['cancelledAt'] != null;
          final hasCancel = data['cancelledAt'] != null;
          if (!hadCancel && hasCancel) {
            final cancelId = 'cancel_${change.doc.id}';
            if (!_seenPaymentIds.contains(cancelId)) {
              _seenPaymentIds.add(cancelId);
              _add(AdminNotification(
                id:    cancelId,
                type:  NotifType.premiumCancelled,
                title: 'Premium cancelled',
                body:  '${data['name'] ?? 'A user'} (${data['email'] ?? '—'}) cancelled their premium subscription.',
                time:  _tsToDate(data['cancelledAt']),
              ));
            }
          }

          final hadPremiumUntil = prev['premiumUntil'] != null;
          final premiumUntilNow = data['premiumUntil'];
          final expiredId       = 'expired_${change.doc.id}';
          if (wasPremium &&
              !isPremium &&
              !hasCancel &&
              !_seenPaymentIds.contains(expiredId)) {
            _seenPaymentIds.add(expiredId);
            _add(AdminNotification(
              id:    expiredId,
              type:  NotifType.premiumExpired,
              title: 'Premium expired',
              body:  '${data['name'] ?? 'A user'}\'s (${data['email'] ?? '—'}) premium subscription has expired.',
              time:  hadPremiumUntil
                  ? _tsToDate(prev['premiumUntil'])
                  : DateTime.now(),
            ));
          }

          final nameChanged  = prev['name']  != data['name'];
          final emailChanged = prev['email'] != data['email'];
          if (nameChanged || emailChanged) {
            final changed = <String>[];
            if (nameChanged)  changed.add('name');
            if (emailChanged) changed.add('email');
            _add(AdminNotification(
              id:    'profile_${change.doc.id}_${DateTime.now().millisecondsSinceEpoch}',
              type:  NotifType.profileUpdated,
              title: 'Profile updated',
              body:  '${data['name'] ?? 'A user'} updated their ${changed.join(' & ')}.',
              time:  _tsToDate(data['updatedAt']),
            ));
          }

          _userSnapshots[change.doc.id] = {
            'name':         data['name'],
            'email':        data['email'],
            'isPremium':    data['isPremium'],
            'cancelledAt':  data['cancelledAt'],
            'premiumUntil': premiumUntilNow,
          };
        }
      }
    });
  }

  // ── PAYMENTS LISTENER ────────────────────────────────────────────
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>
      _listenPayments() {
    return FirebaseFirestore.instance
        .collection('payments')
        .snapshots()
        .listen((snap) {
      if (_initialPaymentLoad) {
        for (final doc in snap.docs) {
          _seenPaymentIds
              .add('${doc.id}_${doc.data()['status']}');
        }
        _initialPaymentLoad = false;
        return;
      }

      for (final change in snap.docChanges) {
        final data = change.doc.data();
        if (data == null) continue;

        final status = (data['status'] ?? '').toString().toLowerCase();
        final key    = '${change.doc.id}_$status';
        if (_seenPaymentIds.contains(key)) continue;
        _seenPaymentIds.add(key);

        final method = (data['method'] ?? '').toString().toUpperCase();
        final ref    = data['referenceNumber'] ?? '—';
        final amount = data['amount'] ?? _kPremiumPrice;
        final name   = data['userName'] ?? data['name'] ?? 'A user';
        if (data['isDemo'] == true) continue;

        if (change.type == DocumentChangeType.added &&
            status == 'pending') {
          _add(AdminNotification(
            id:    'pay_pending_${change.doc.id}',
            type:  NotifType.paymentPending,
            title: 'New payment submitted',
            body:  '$name submitted a ₱$amount $method payment. Ref: $ref — awaiting your review.',
            time:  _tsToDate(data['createdAt']),
          ));
        }

        if (change.type == DocumentChangeType.modified &&
            status == 'verified') {
          _add(AdminNotification(
            id:    'pay_verified_${change.doc.id}',
            type:  NotifType.paymentVerified,
            title: 'Payment verified',
            body:  '₱$amount $method payment from $name (Ref: $ref) was verified. User upgraded to Premium.',
            time:  _tsToDate(data['verifiedAt']),
          ));
        }

        if (change.type == DocumentChangeType.modified &&
            status == 'rejected') {
          final reason = data['rejectionReason'] ?? '';
          _add(AdminNotification(
            id:    'pay_rejected_${change.doc.id}',
            type:  NotifType.paymentRejected,
            title: 'Payment rejected',
            body:  '₱$amount $method payment from $name (Ref: $ref) was rejected.'
                   '${reason.isNotEmpty ? ' Reason: $reason' : ''}',
            time:  _tsToDate(data['rejectedAt']),
          ));
        }

        if ((change.type == DocumentChangeType.added ||
             change.type == DocumentChangeType.modified) &&
            status == 'expired') {
          _add(AdminNotification(
            id:    'pay_expired_${change.doc.id}',
            type:  NotifType.paymentExpired,
            title: 'Payment expired',
            body:  '₱$amount $method payment from $name (Ref: $ref) expired without being actioned.',
            time:  _tsToDate(data['expiredAt'] ?? data['updatedAt']),
          ));
        }
      }
    });
  }

  // ── HELPERS ──────────────────────────────────────────────────────

  void _add(AdminNotification notif) {
    if (_notifications.any((n) => n.id == notif.id)) return;
    setState(() {
      _notifications.insert(0, notif);
      if (_notifications.length > 100) _notifications.removeLast();
    });
    _notify();
    _persistNotif(notif);
  }

  void markRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    if (_notifications[idx].isRead) return;
    setState(() => _notifications[idx].isRead = true);
    _notify();
    _notifCol.doc(id).update({'isRead': true}).catchError((_) {});
  }

  void markAllRead() {
    final unread = _notifications.where((n) => !n.isRead).toList();
    if (unread.isEmpty) return;
    setState(() {
      for (final n in _notifications) n.isRead = true;
    });
    _notify();
    final batch = FirebaseFirestore.instance.batch();
    for (final n in unread) {
      batch.update(_notifCol.doc(n.id), {'isRead': true});
    }
    batch.commit().catchError((_) {});
  }

  void clearAll() {
    final ids = _notifications.map((n) => n.id).toList();
    setState(() => _notifications.clear());
    _notify();
    final batch = FirebaseFirestore.instance.batch();
    for (final id in ids) {
      batch.delete(_notifCol.doc(id));
    }
    batch.commit().catchError((_) {});
  }

  DateTime _tsToDate(dynamic ts) {
    if (ts == null) return DateTime.now();
    try { return (ts as Timestamp).toDate(); }
    catch (_) { return DateTime.now(); }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ─────────────────────────────────────────────
// NOTIFICATION BELL
// FIX (Bug 4): StreamBuilder auto-rebuilds badge on every change.
// ─────────────────────────────────────────────
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = NotificationProvider.of(context);

    return StreamBuilder<int>(
      stream:      provider?.stream,
      initialData: provider?.unreadCount ?? 0,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;

        return GestureDetector(
          onTap: () => _openPanel(context, provider),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color:        _kPanel,
                  borderRadius: BorderRadius.circular(12),
                  border:       Border.all(
                      color: _kAccent.withOpacity(0.25)),
                ),
                child: Icon(
                  count > 0
                      ? Icons.notifications_rounded
                      : Icons.notifications_none_rounded,
                  color: count > 0 ? _kAccent : Colors.white38,
                  size:  20,
                ),
              ),
              if (count > 0)
                Positioned(
                  top: -4, right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color:        _kRed,
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: _kBg, width: 1.5),
                    ),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      style: const TextStyle(
                          color:      Colors.white,
                          fontSize:   9,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _openPanel(
      BuildContext context, _NotificationProviderState? provider) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel:       'notifications',
      barrierColor:       Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(
            parent: anim, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0), end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
      // FIX (Bug 3): pass tree context so panel re-resolves provider
      // fresh on every build() instead of holding a stale reference.
      pageBuilder: (ctx, _, __) =>
          _NotificationPanel(providerContext: context),
    );
  }
}

// ─────────────────────────────────────────────
// NOTIFICATION PANEL
// FIX (Bug 3 + Bug 4): resolves provider in build() and uses
// StreamBuilder to stay in sync with live data.
// ─────────────────────────────────────────────
class _NotificationPanel extends StatefulWidget {
  final BuildContext providerContext;
  const _NotificationPanel({required this.providerContext});

  @override
  State<_NotificationPanel> createState() =>
      _NotificationPanelState();
}

class _NotificationPanelState extends State<_NotificationPanel> {
  // Only All | Unread filters remain (category chips removed)
  String _filter = 'all';

  _NotificationProviderState? get _provider =>
      NotificationProvider.of(widget.providerContext);

  List<AdminNotification> _applyFilter(
      List<AdminNotification> all) {
    switch (_filter) {
      case 'unread':
        return all.where((n) => !n.isRead).toList();
      default:
        return all;
    }
  }

  // ── WARNING DIALOG FOR DELETED ACCOUNTS ─────────────────────────
  void _showDeletedWarning(
      BuildContext context, AdminNotification notif) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color:        const Color(0xFF0D1F2D),
            borderRadius: BorderRadius.circular(20),
            border:       Border.all(
                color: _kRed.withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color:        _kRed.withOpacity(0.15),
                blurRadius:   30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color:  _kRed.withOpacity(0.12),
                  shape:  BoxShape.circle,
                  border: Border.all(
                      color: _kRed.withOpacity(0.4), width: 1.5),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: _kRed,
                  size:  32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Account Deleted',
                style: TextStyle(
                  color:      Colors.white,
                  fontSize:   20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                notif.body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color:    Colors.white60,
                  fontSize: 13,
                  height:   1.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:        _kRed.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border:       Border.all(
                      color: _kRed.withOpacity(0.2)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: _kRed, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This action is permanent and cannot be undone. '
                        'All data associated with this account has been '
                        'removed from Firestore.',
                        style: TextStyle(
                          color:    Colors.white54,
                          fontSize: 12,
                          height:   1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Occurred: ${notif.timeLabel}',
                style: TextStyle(
                    color:    _kRed.withOpacity(0.6),
                    fontSize: 11),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    backgroundColor: _kRed.withOpacity(0.12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: _kRed.withOpacity(0.3)),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Understood',
                    style: TextStyle(
                      color:      _kRed,
                      fontWeight: FontWeight.bold,
                      fontSize:   14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider;

    return StreamBuilder<int>(
      stream:      provider?.stream,
      initialData: provider?.unreadCount ?? 0,
      builder: (context, _) {
        final all    = provider?.notifications ?? [];
        final items  = _applyFilter(all.toList());
        final unread = provider?.unreadCount ?? 0;
        final w      = MediaQuery.of(context).size.width;
        final panelW = w < 500 ? w : 400.0;

        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width:  panelW,
              height: double.infinity,
              decoration: BoxDecoration(
                color:  _kBg,
                border: Border(left: BorderSide(
                    color: _kAccent.withOpacity(0.2))),
              ),
              child: SafeArea(
                child: Column(children: [

                  // ── HEADER ──────────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(
                        20, 20, 12, 16),
                    decoration: BoxDecoration(
                      color:  _kPanel.withOpacity(0.6),
                      border: Border(bottom: BorderSide(
                          color: _kAccent.withOpacity(0.15))),
                    ),
                    child: Row(children: [
                      const Icon(Icons.notifications_rounded,
                          color: _kAccent, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text('Notifications',
                                style: TextStyle(
                                    color:      Colors.white,
                                    fontSize:   18,
                                    fontWeight: FontWeight.bold)),
                            Text(
                              unread > 0
                                  ? '$unread unread'
                                  : 'All caught up',
                              style: TextStyle(
                                  color: unread > 0
                                      ? _kAccent
                                      : Colors.white38,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (unread > 0)
                        TextButton(
                          onPressed: () =>
                              provider?.markAllRead(),
                          child: const Text('Mark all read',
                              style: TextStyle(
                                  color:    _kAccent,
                                  fontSize: 12)),
                        ),
                      if (all.isNotEmpty)
                        IconButton(
                          icon: const Icon(
                              Icons.delete_sweep_rounded,
                              color: Colors.white38,
                              size:  20),
                          tooltip:   'Clear all',
                          onPressed: () => provider?.clearAll(),
                        ),
                      IconButton(
                        icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white38),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ]),
                  ),

                  // ── FILTER CHIPS (All | Unread only) ────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color:  _kPanel.withOpacity(0.3),
                      border: Border(bottom: BorderSide(
                          color:
                              Colors.white.withOpacity(0.06))),
                    ),
                    child: Row(children: [
                      _Chip(
                          label: 'All',
                          selected: _filter == 'all',
                          onTap: () => setState(
                              () => _filter = 'all')),
                      const SizedBox(width: 8),
                      _Chip(
                          label: 'Unread',
                          selected: _filter == 'unread',
                          color: _kRed,
                          onTap: () => setState(
                              () => _filter = 'unread')),
                    ]),
                  ),

                  // ── LIST ────────────────────────────────────
                  Expanded(
                    child: items.isEmpty
                        ? _EmptyState(filter: _filter)
                        : ListView.separated(
                            padding:
                                const EdgeInsets.symmetric(
                                    vertical: 8),
                            itemCount: items.length,
                            separatorBuilder: (_, __) =>
                                Divider(
                                    color: Colors.white
                                        .withOpacity(0.05),
                                    height: 1),
                            itemBuilder: (_, i) => _NotifTile(
                              notif: items[i],
                              onTap: () {
                                provider?.markRead(items[i].id);
                                if (items[i].type ==
                                    NotifType.accountDeleted) {
                                  _showDeletedWarning(
                                      context, items[i]);
                                }
                              },
                            ),
                          ),
                  ),

                  // ── FOOTER ──────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(
                          color: _kAccent.withOpacity(0.1))),
                    ),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_done_rounded,
                            color: Colors.white24, size: 13),
                        const SizedBox(width: 6),
                        Text(
                          'Saved to Firestore · ${all.length} total',
                          style: const TextStyle(
                              color:    Colors.white24,
                              fontSize: 11),
                        ),
                      ],
                    ),
                  ),

                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// NOTIFICATION TILE
// ─────────────────────────────────────────────
class _NotifTile extends StatelessWidget {
  final AdminNotification notif;
  final VoidCallback      onTap;
  const _NotifTile({required this.notif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color:   notif.isRead
            ? Colors.transparent
            : notif.color.withOpacity(0.06),
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color:        notif.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: notif.color.withOpacity(0.3)),
              ),
              child: Icon(notif.icon,
                  color: notif.color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(notif.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: notif.isRead
                                ? FontWeight.normal
                                : FontWeight.bold,
                            fontSize: 13,
                          )),
                    ),
                    if (notif.type == NotifType.accountDeleted)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color:        _kRed.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border:       Border.all(
                              color: _kRed.withOpacity(0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: _kRed, size: 11),
                            SizedBox(width: 3),
                            Text('WARNING',
                                style: TextStyle(
                                    color:         _kRed,
                                    fontSize:      9,
                                    fontWeight:    FontWeight.bold,
                                    letterSpacing: 0.5)),
                          ],
                        ),
                      )
                    else if (!notif.isRead)
                      Container(
                        width: 7, height: 7,
                        decoration: BoxDecoration(
                            color: notif.color,
                            shape: BoxShape.circle),
                      ),
                  ]),
                  const SizedBox(height: 4),
                  Text(notif.body,
                      style: const TextStyle(
                          color:    Colors.white60,
                          fontSize: 12,
                          height:   1.4)),
                  const SizedBox(height: 6),
                  Text(notif.timeLabel,
                      style: TextStyle(
                          color: notif.color.withOpacity(0.7),
                          fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.notifications_off_rounded,
            color: Colors.white12, size: 56),
        const SizedBox(height: 16),
        Text(
          filter == 'all'
              ? 'No notifications yet'
              : 'No $filter notifications',
          style: const TextStyle(
              color: Colors.white38, fontSize: 15),
        ),
        const SizedBox(height: 8),
        const Text(
          'Events from Firestore will appear here\n'
          'in real-time as they happen.',
          style:     TextStyle(color: Colors.white24, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// CHIP WIDGET
// ─────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String       label;
  final bool         selected;
  final VoidCallback onTap;
  final Color        color;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = _kAccent,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:  const EdgeInsets.symmetric(
            horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: selected ? color : Colors.white24),
        ),
        child: Text(label,
            style: TextStyle(
              color: selected ? color : Colors.white54,
              fontWeight:
                  selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            )),
      ),
    );
  }
}
// ═══════════════════════════════════════════════════════════════════
// CLEFTTUNE ADMIN — notifications.dart
//
// Real-time notification system. Listens to Firestore for:
//   • New user registrations        (users collection, new docs)
//   • New premium user              (users collection, isPremium set to true)
//   • Account deleted               (users collection, doc removed)
//   • Profile updated               (users collection, name/email changed)
//   • Payment submitted (pending)   (payments collection, status=pending)
//   • Payment verified              (payments collection, status=verified)
//   • Payment rejected              (payments collection, status=rejected)
//   • Payment expired               (payments collection, status=expired)
//   • Premium cancelled             (users collection, cancelledAt field set)
//   • Premium expired               (users collection, premiumUntil lapses)
//
// HOW TO INTEGRATE into main.dart:
//   1. Import this file:
//        import 'notifications.dart';
//
//   2. Wrap your AdminShell (or top-level widget) with NotificationProvider:
//        home: NotificationProvider(child: const AdminShell()),
//
//   3. Replace the empty notification IconButton in _DashboardHeader with:
//        NotificationBell()
//
// That's it — everything else is automatic.
// ═══════════════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
// THEME (mirrors main.dart constants)
// ─────────────────────────────────────────────
const _kBg     = Color(0xFF020C12);
const _kPanel  = Color(0xFF0B2E39);
const _kAccent = Color(0xFF00E6C3);
const _kPurple = Color(0xFF9B6DFF);
const _kGold   = Color(0xFFFFB800);
const _kRed    = Color(0xFFFF4D6A);
const _kGreen  = Color(0xFF00E096);
const _kBlue   = Color(0xFF2D9CFF);
const _kOrange = Color(0xFFFF8C42);

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

  /// Category label used for filter chips
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
    if (diff.inSeconds < 60)  return 'Just now';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24)  return '${diff.inHours}h ago';
    if (diff.inDays    < 7)   return '${diff.inDays}d ago';
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────
// NOTIFICATION PROVIDER (InheritedWidget)
// ─────────────────────────────────────────────
class NotificationProvider extends StatefulWidget {
  final Widget child;
  const NotificationProvider({super.key, required this.child});

  static _NotificationProviderState? of(BuildContext context) {
    return context.findAncestorStateOfType<_NotificationProviderState>();
  }

  @override
  State<NotificationProvider> createState() => _NotificationProviderState();
}

class _NotificationProviderState extends State<NotificationProvider> {
  final List<AdminNotification> _notifications = [];

  // Track doc IDs / state keys we've already seen so we don't re-fire on start
  final Set<String> _seenUserIds    = {};
  final Set<String> _seenPaymentIds = {};

  // Snapshot of user field values on first load (for change-detection)
  final Map<String, Map<String, dynamic>> _userSnapshots = {};

  bool _initialUserLoad    = true;
  bool _initialPaymentLoad = true;

  late final List<dynamic> _subs; // StreamSubscription list

  List<AdminNotification> get notifications =>
      List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  @override
  void initState() {
    super.initState();
    _subs = [
      _listenUsers(),
      _listenPayments(),
    ];
  }

  @override
  void dispose() {
    for (final s in _subs) s.cancel();
    super.dispose();
  }

  // ── USERS listener ──────────────────────────────────────────────
  dynamic _listenUsers() {
    return FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .listen((snap) {
      // ── First load: seed seen sets, don't fire for existing docs ──
      if (_initialUserLoad) {
        for (final doc in snap.docs) {
          _seenUserIds.add(doc.id);
          final data = doc.data();
          // Store a snapshot for change-detection later
          _userSnapshots[doc.id] = {
            'name':         data['name'],
            'email':        data['email'],
            'isPremium':    data['isPremium'],
            'cancelledAt':  data['cancelledAt'],
            'premiumUntil': data['premiumUntil'],
          };
        }
        _initialUserLoad = false;
        return;
      }

      for (final change in snap.docChanges) {
        final data = change.doc.data();

        // ── ACCOUNT DELETED ─────────────────────────────────────────
        if (change.type == DocumentChangeType.removed) {
          final prev = _userSnapshots[change.doc.id];
          final name  = prev?['name']  ?? 'A user';
          final email = prev?['email'] ?? '—';
          _seenUserIds.remove(change.doc.id);
          _userSnapshots.remove(change.doc.id);
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

        // ── NEW USER REGISTERED ─────────────────────────────────────
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
          _add(AdminNotification(
            id:    'user_${change.doc.id}',
            type:  NotifType.newUser,
            title: 'New user registered',
            body:  '${data['name'] ?? 'Someone'} (${data['email'] ?? '—'}) just created an account.',
            time:  _tsToDate(data['createdAt']),
          ));
        }

        // ── MODIFICATIONS ───────────────────────────────────────────
        if (change.type == DocumentChangeType.modified) {
          final prev = _userSnapshots[change.doc.id] ?? {};

          // 1. NEW PREMIUM USER — isPremium flipped to true
          final wasPremium = prev['isPremium'] == true;
          final isPremium  = data['isPremium'] == true;
          if (!wasPremium && isPremium) {
            final premId = 'newprem_${change.doc.id}';
            if (!_seenPaymentIds.contains(premId)) {
              _seenPaymentIds.add(premId);
              _add(AdminNotification(
                id:    premId,
                type:  NotifType.newPremiumUser,
                title: 'User upgraded to Premium',
                body:  '${data['name'] ?? 'A user'} (${data['email'] ?? '—'}) is now a Premium member.',
                time:  _tsToDate(data['premiumSince'] ?? data['updatedAt']),
              ));
            }
          }

          // 2. PREMIUM CANCELLED — cancelledAt field newly set
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

          // 3. PREMIUM EXPIRED — premiumUntil was set but now null/cleared,
          //    OR premiumUntil date has passed and isPremium flipped false
          final hadPremiumUntil = prev['premiumUntil'] != null;
          final premiumUntilNow = data['premiumUntil'];
          final expiredId       = 'expired_${change.doc.id}';
          if (wasPremium && !isPremium && !hasCancel &&
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

          // 4. PROFILE UPDATED — name or email changed
          final nameChanged  = prev['name']  != data['name'];
          final emailChanged = prev['email'] != data['email'];
          if (nameChanged || emailChanged) {
            final updateId = 'profile_${change.doc.id}_${DateTime.now().millisecondsSinceEpoch}';
            final changed  = <String>[];
            if (nameChanged)  changed.add('name');
            if (emailChanged) changed.add('email');
            _add(AdminNotification(
              id:    updateId,
              type:  NotifType.profileUpdated,
              title: 'Profile updated',
              body:  '${data['name'] ?? 'A user'} updated their ${changed.join(' & ')}.',
              time:  _tsToDate(data['updatedAt']),
            ));
          }

          // Always refresh local snapshot
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

  // ── PAYMENTS listener ────────────────────────────────────────────
  dynamic _listenPayments() {
    return FirebaseFirestore.instance
        .collection('payments')
        .snapshots()
        .listen((snap) {
      if (_initialPaymentLoad) {
        for (final doc in snap.docs) {
          _seenPaymentIds.add('${doc.id}_${doc.data()['status']}');
        }
        _initialPaymentLoad = false;
        return;
      }

      for (final change in snap.docChanges) {
        final data   = change.doc.data();
        if (data == null) continue;
        final status = (data['status'] ?? '').toString().toLowerCase();
        final key    = '${change.doc.id}_$status';

        if (_seenPaymentIds.contains(key)) continue;
        _seenPaymentIds.add(key);

        final method = (data['method'] ?? '').toString().toUpperCase();
        final ref    = data['referenceNumber'] ?? '—';
        final amount = data['amount'] ?? 99;
        final name   = data['userName'] ?? data['name'] ?? 'A user';

        // PENDING — new payment submitted
        if (change.type == DocumentChangeType.added && status == 'pending') {
          _add(AdminNotification(
            id:    'pay_pending_${change.doc.id}',
            type:  NotifType.paymentPending,
            title: 'New payment submitted',
            body:  '$name submitted a ₱$amount $method payment. Ref: $ref — awaiting your review.',
            time:  _tsToDate(data['createdAt']),
          ));
        }

        // VERIFIED — payment approved
        if (change.type == DocumentChangeType.modified && status == 'verified') {
          _add(AdminNotification(
            id:    'pay_verified_${change.doc.id}',
            type:  NotifType.paymentVerified,
            title: 'Payment verified',
            body:  '₱$amount $method payment from $name (Ref: $ref) was verified. User upgraded to Premium.',
            time:  _tsToDate(data['verifiedAt']),
          ));
        }

        // REJECTED — payment denied
        if (change.type == DocumentChangeType.modified && status == 'rejected') {
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

        // EXPIRED — payment link/session expired without action
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
    setState(() {
      if (!_notifications.any((n) => n.id == notif.id)) {
        _notifications.insert(0, notif);
        if (_notifications.length > 100) _notifications.removeLast();
      }
    });
  }

  void markAllRead() => setState(() {
    for (final n in _notifications) n.isRead = true;
  });

  void markRead(String id) => setState(() {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) _notifications[idx].isRead = true;
  });

  void clearAll() => setState(() => _notifications.clear());

  DateTime _tsToDate(dynamic ts) {
    if (ts == null) return DateTime.now();
    try { return (ts as Timestamp).toDate(); } catch (_) { return DateTime.now(); }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ─────────────────────────────────────────────
// NOTIFICATION BELL (drop-in replacement)
// ─────────────────────────────────────────────
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = NotificationProvider.of(context);
    final count    = provider?.unreadCount ?? 0;

    return GestureDetector(
      onTap: () => _openPanel(context, provider),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _kPanel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kAccent.withOpacity(0.25)),
            ),
            child: Icon(
              count > 0
                  ? Icons.notifications_rounded
                  : Icons.notifications_none_rounded,
              color: count > 0 ? _kAccent : Colors.white38,
              size: 20,
            ),
          ),
          if (count > 0)
            Positioned(
              top: -4, right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: _kRed,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kBg, width: 1.5),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openPanel(BuildContext context, _NotificationProviderState? provider) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'notifications',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
      pageBuilder: (ctx, _, __) => _NotificationPanel(provider: provider),
    );
  }
}

// ─────────────────────────────────────────────
// NOTIFICATION PANEL (slide-in drawer)
// ─────────────────────────────────────────────
class _NotificationPanel extends StatefulWidget {
  final _NotificationProviderState? provider;
  const _NotificationPanel({required this.provider});

  @override
  State<_NotificationPanel> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends State<_NotificationPanel> {
  String _filter = 'all';

  List<AdminNotification> get _filtered {
    final all = widget.provider?.notifications ?? [];
    switch (_filter) {
      case 'unread':   return all.where((n) => !n.isRead).toList();
      case 'payments': return all.where((n) => n.category == 'payments').toList();
      case 'users':    return all.where((n) => n.category == 'users').toList();
      case 'premium':  return all.where((n) => n.category == 'premium').toList();
      default:         return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    final w      = MediaQuery.of(context).size.width;
    final panelW = w < 500 ? w : 400.0;
    final unread = widget.provider?.unreadCount ?? 0;
    final items  = _filtered;

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: panelW,
          height: double.infinity,
          decoration: BoxDecoration(
            color: _kBg,
            border: Border(left: BorderSide(color: _kAccent.withOpacity(0.2))),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // ── HEADER ────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
                  decoration: BoxDecoration(
                    color: _kPanel.withOpacity(0.6),
                    border: Border(
                        bottom: BorderSide(color: _kAccent.withOpacity(0.15))),
                  ),
                  child: Row(children: [
                    const Icon(Icons.notifications_rounded,
                        color: _kAccent, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Notifications',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            if (unread > 0)
                              Text('$unread unread',
                                  style: const TextStyle(
                                      color: _kAccent, fontSize: 12)),
                          ]),
                    ),
                    if (unread > 0)
                      TextButton(
                        onPressed: () {
                          widget.provider?.markAllRead();
                          setState(() {});
                        },
                        child: const Text('Mark all read',
                            style:
                                TextStyle(color: _kAccent, fontSize: 12)),
                      ),
                    if ((widget.provider?.notifications.length ?? 0) > 0)
                      IconButton(
                        icon: const Icon(Icons.delete_sweep_rounded,
                            color: Colors.white38, size: 20),
                        tooltip: 'Clear all',
                        onPressed: () {
                          widget.provider?.clearAll();
                          setState(() {});
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white38),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ]),
                ),

                // ── FILTER CHIPS ──────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _kPanel.withOpacity(0.3),
                    border: Border(
                        bottom: BorderSide(
                            color: Colors.white.withOpacity(0.06))),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      _Chip(
                          label: 'All',
                          selected: _filter == 'all',
                          onTap: () =>
                              setState(() => _filter = 'all')),
                      const SizedBox(width: 8),
                      _Chip(
                          label: 'Unread',
                          selected: _filter == 'unread',
                          color: _kRed,
                          onTap: () =>
                              setState(() => _filter = 'unread')),
                      const SizedBox(width: 8),
                      _Chip(
                          label: 'Payments',
                          selected: _filter == 'payments',
                          color: _kGold,
                          onTap: () =>
                              setState(() => _filter = 'payments')),
                      const SizedBox(width: 8),
                      _Chip(
                          label: 'Users',
                          selected: _filter == 'users',
                          color: _kBlue,
                          onTap: () =>
                              setState(() => _filter = 'users')),
                      const SizedBox(width: 8),
                      _Chip(
                          label: 'Premium',
                          selected: _filter == 'premium',
                          color: _kPurple,
                          onTap: () =>
                              setState(() => _filter = 'premium')),
                    ]),
                  ),
                ),

                // ── NOTIFICATION LIST ─────────────────────────────
                Expanded(
                  child: items.isEmpty
                      ? _EmptyState(filter: _filter)
                      : ListView.separated(
                          padding:
                              const EdgeInsets.symmetric(vertical: 8),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => Divider(
                              color: Colors.white.withOpacity(0.05),
                              height: 1),
                          itemBuilder: (_, i) => _NotifTile(
                            notif: items[i],
                            onTap: () {
                              widget.provider?.markRead(items[i].id);
                              setState(() {});
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// NOTIFICATION TILE
// ─────────────────────────────────────────────
class _NotifTile extends StatelessWidget {
  final AdminNotification notif;
  final VoidCallback onTap;
  const _NotifTile({required this.notif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: notif.isRead
            ? Colors.transparent
            : notif.color.withOpacity(0.06),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child:
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Icon bubble
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: notif.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: notif.color.withOpacity(0.3)),
            ),
            child: Icon(notif.icon, color: notif.color, size: 18),
          ),
          const SizedBox(width: 12),

          // Content
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
                    if (!notif.isRead)
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
                          color: Colors.white60,
                          fontSize: 12,
                          height: 1.4)),
                  const SizedBox(height: 6),
                  Text(notif.timeLabel,
                      style: TextStyle(
                          color: notif.color.withOpacity(0.7),
                          fontSize: 11)),
                ]),
          ),
        ]),
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
          style: const TextStyle(color: Colors.white38, fontSize: 15),
        ),
        const SizedBox(height: 8),
        const Text(
          'Events from Firestore will appear here\nin real-time as they happen.',
          style: TextStyle(color: Colors.white24, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// SMALL CHIP WIDGET
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
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: selected ? color : Colors.white24),
        ),
        child: Text(label,
            style: TextStyle(
              color:      selected ? color : Colors.white54,
              fontWeight:
                  selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            )),
      ),
    );
  }
}
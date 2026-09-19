// ═══════════════════════════════════════════════════════════════════
// CLEFTTUNE ADMIN — notifications.dart  (White Theme v1)
//
// Matches the clean white theme from main.dart.
// Removed all premium/payment notification types.
// Added gamification-aware notification types:
//   • newUser, accountDeleted, profileUpdated
//   • levelUp, streakAchieved, streakBroken
//   • feedbackReceived
// ═══════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
// THEME — mirrors main.dart constants
// ─────────────────────────────────────────────
const _kBg      = Color(0xFFF5F4F0);
const _kSurface = Color(0xFFFFFFFF);
const _kSidebar = Color(0xFF1A1A2E);
const _kAccent  = Color(0xFF2563EB);
const _kIndigo  = Color(0xFF4F46E5);
const _kEmerald = Color(0xFF059669);
const _kAmber   = Color(0xFFD97706);
const _kRose    = Color(0xFFE11D48);
const _kSlate   = Color(0xFF64748B);
const _kBorder  = Color(0xFFE2E8F0);
const _kText    = Color(0xFF0F172A);

// ─────────────────────────────────────────────
// FIRESTORE COLLECTION
// ─────────────────────────────────────────────
final _notifCol =
    FirebaseFirestore.instance.collection('adminNotifications');

// ─────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────
int _getLevel(Map<String, dynamic> data) =>
    (data['level'] ?? data['userLevel'] ?? 0) as int;

int _getStreak(Map<String, dynamic> data) =>
    (data['streak'] ?? data['currentStreak'] ?? 0) as int;

// ═══════════════════════════════════════════════════════════════════
// ONE-TIME SEED HELPER
// ═══════════════════════════════════════════════════════════════════
Future<void> seedExistingNotifications() async {
  debugPrint('[Seed] Starting seed of adminNotifications…');
  try {
    final users =
        await FirebaseFirestore.instance.collection('users').get();

    for (final doc in users.docs) {
      final data  = doc.data();
      final name  = (data['name']  ?? 'Unknown').toString();
      final email = (data['email'] ?? '—').toString();
      final level  = _getLevel(data);
      final streak = _getStreak(data);

      await _notifCol.doc('user_${doc.id}').set({
        'type':    'newUser',
        'title':   'New user registered',
        'body':    '$name ($email) just created an account.',
        'time':    data['createdAt'] ?? FieldValue.serverTimestamp(),
        'isRead':  false,
        'savedAt': FieldValue.serverTimestamp(),
      });

      if (level >= 10) {
        await _notifCol.doc('level_${doc.id}').set({
          'type':    'levelUp',
          'title':   'Level milestone reached 🏆',
          'body':    '$name reached Level $level.',
          'time':    data['updatedAt'] ?? FieldValue.serverTimestamp(),
          'isRead':  false,
          'savedAt': FieldValue.serverTimestamp(),
        });
      }

      if (streak >= 7) {
        await _notifCol.doc('streak_${doc.id}').set({
          'type':    'streakAchieved',
          'title':   'Streak milestone 🔥',
          'body':    '$name is on a $streak-day streak!',
          'time':    data['updatedAt'] ?? FieldValue.serverTimestamp(),
          'isRead':  false,
          'savedAt': FieldValue.serverTimestamp(),
        });
      }
    }
    debugPrint('[Seed] Seeded ${users.docs.length} users.');

    final feedback =
        await FirebaseFirestore.instance.collection('feedback').get();

    for (final doc in feedback.docs) {
      final data   = doc.data();
      final rating = ((data['rating'] ?? 0) as num).toInt();
      final comment = (data['comment'] ?? data['feedback'] ?? '').toString();
      await _notifCol.doc('fb_${doc.id}').set({
        'type':    'feedbackReceived',
        'title':   'New feedback received ⭐',
        'body':    'A user left a $rating-star review.${comment.isNotEmpty ? ' "$comment"' : ''}',
        'time':    data['createdAt'] ?? FieldValue.serverTimestamp(),
        'isRead':  false,
        'savedAt': FieldValue.serverTimestamp(),
      });
    }
    debugPrint('[Seed] Seeded ${feedback.docs.length} feedback entries. Done!');
  } catch (e) {
    debugPrint('[Seed] ERROR: $e');
  }
}

// ─────────────────────────────────────────────
// NOTIFICATION MODEL
// ─────────────────────────────────────────────
enum NotifType {
  newUser,
  accountDeleted,
  profileUpdated,
  levelUp,
  streakAchieved,
  streakBroken,
  feedbackReceived,
}

NotifType _typeFromString(String s) => NotifType.values.firstWhere(
      (e) => e.name == s,
      orElse: () => NotifType.newUser,
    );

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
    try { time = (data['time'] as Timestamp).toDate(); }
    catch (_) { time = DateTime.now(); }
    return AdminNotification(
      id:     doc.id,
      type:   _typeFromString(data['type'] ?? 'newUser'),
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
      case NotifType.accountDeleted:   return _kRose;
      case NotifType.profileUpdated:   return _kIndigo;
      case NotifType.levelUp:          return _kAmber;
      case NotifType.streakAchieved:   return _kEmerald;
      case NotifType.streakBroken:     return _kRose;
      case NotifType.feedbackReceived: return _kIndigo;
    }
  }

  IconData get icon {
    switch (type) {
      case NotifType.newUser:          return Icons.person_add_rounded;
      case NotifType.accountDeleted:   return Icons.person_remove_rounded;
      case NotifType.profileUpdated:   return Icons.manage_accounts_rounded;
      case NotifType.levelUp:          return Icons.emoji_events_rounded;
      case NotifType.streakAchieved:   return Icons.local_fire_department_rounded;
      case NotifType.streakBroken:     return Icons.whatshot_rounded;
      case NotifType.feedbackReceived: return Icons.star_rounded;
    }
  }

  String get timeLabel {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    if (diff.inDays    <  7) return '${diff.inDays}d ago';
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-'
           '${time.day.toString().padLeft(2, '0')}';
  }
}

// ═══════════════════════════════════════════════════════════════════
// NOTIFICATION PROVIDER
// ═══════════════════════════════════════════════════════════════════
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
  final List<AdminNotification>           _notifications  = [];
  final Set<String>                       _seenIds        = {};
  final Map<String, Map<String, dynamic>> _userSnapshots  = {};
  final Set<String>                       _seenFeedbackIds = {};

  final _stream = StreamController<int>.broadcast();
  Stream<int> get stream => _stream.stream;

  bool _initialUserLoad     = true;
  bool _initialFeedbackLoad = true;
  bool _initialNotifLoad    = true;

  StreamSubscription? _notifSub;
  StreamSubscription? _userSub;
  StreamSubscription? _feedbackSub;

  List<AdminNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  @override
  void initState() {
    super.initState();
    _notifSub    = _listenNotifs();
    _userSub     = _listenUsers();
    _feedbackSub = _listenFeedback();
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    _userSub?.cancel();
    _feedbackSub?.cancel();
    _stream.close();
    super.dispose();
  }

  void _notify() {
    if (!_stream.isClosed) _stream.add(unreadCount);
  }

  // ── RESUBSCRIBE HELPERS ───────────────────────────────────────────
  void _resubNotifs() {
    debugPrint('[Notif] adminNotifications error — resubscribing in 5s');
    _notifSub?.cancel();
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      _notifSub = _listenNotifs();
    });
  }

  void _resubUsers() {
    debugPrint('[Notif] users error — resubscribing in 5s');
    _userSub?.cancel();
    _initialUserLoad = true;
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      _userSub = _listenUsers();
    });
  }

  void _resubFeedback() {
    debugPrint('[Notif] feedback error — resubscribing in 5s');
    _feedbackSub?.cancel();
    _initialFeedbackLoad = true;
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      _feedbackSub = _listenFeedback();
    });
  }

  // ── 1. SAVED NOTIFICATIONS LISTENER ──────────────────────────────
  StreamSubscription _listenNotifs() {
    return _notifCol
        .orderBy('time', descending: true)
        .limit(100)
        .snapshots()
        .listen(
      (snap) {
        bool changed = false;
        for (final change in snap.docChanges) {
          if (change.type == DocumentChangeType.removed) {
            _notifications.removeWhere((n) => n.id == change.doc.id);
            _seenIds.remove(change.doc.id);
            changed = true;
          } else if (change.type == DocumentChangeType.modified) {
            final idx = _notifications.indexWhere((n) => n.id == change.doc.id);
            if (idx != -1 && change.doc.data() != null) {
              _notifications[idx].isRead =
                  change.doc.data()!['isRead'] == true;
              changed = true;
            }
          } else if (change.type == DocumentChangeType.added) {
            if (change.doc.data() != null &&
                !_seenIds.contains(change.doc.id)) {
              try {
                final n = AdminNotification.fromDoc(change.doc);
                _notifications.add(n);
                _seenIds.add(n.id);
                changed = true;
              } catch (_) {}
            }
          }
        }
        if (_initialNotifLoad) _initialNotifLoad = false;
        if (changed) {
          _notifications.sort((a, b) => b.time.compareTo(a.time));
          if (_notifications.length > 100) {
            _notifications.removeRange(100, _notifications.length);
          }
          setState(() {});
          _notify();
        }
      },
      onError: (e, s) {
        debugPrint('[Notif] adminNotifications error: $e');
        _resubNotifs();
      },
      cancelOnError: true,
    );
  }

  // ── 2. USERS LISTENER ─────────────────────────────────────────────
  // Watches for:
  //   • New registration        → newUser
  //   • Account deleted         → accountDeleted
  //   • Name/email changed      → profileUpdated
  //   • Level milestone (10+)   → levelUp
  //   • Streak milestone (7+)   → streakAchieved
  //   • Streak reset to 0       → streakBroken
  StreamSubscription _listenUsers() {
    return FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .listen(
      (snap) {
        for (final change in snap.docChanges) {
          final data = change.doc.data();
          final uid  = change.doc.id;

          // ── DELETED ──────────────────────────────────────────────
          if (change.type == DocumentChangeType.removed) {
            final prev  = _userSnapshots[uid];
            final name  = prev?['name']  ?? 'A user';
            final email = prev?['email'] ?? '—';
            _userSnapshots.remove(uid);
            if (prev != null && !_initialUserLoad) {
              _add(AdminNotification(
                id:    'deleted_${uid}_${DateTime.now().millisecondsSinceEpoch}',
                type:  NotifType.accountDeleted,
                title: 'Account deleted',
                body:  '$name ($email) permanently deleted their account.',
                time:  DateTime.now(),
              ));
            }
            continue;
          }

          if (data == null) continue;

          // ── ADDED ─────────────────────────────────────────────────
          if (change.type == DocumentChangeType.added) {
            _userSnapshots[uid] = _snapshot(data);
            if (!_initialUserLoad) {
              _add(AdminNotification(
                id:    'user_$uid',
                type:  NotifType.newUser,
                title: 'New user registered 👋',
                body:  '${data['name'] ?? 'Someone'} (${data['email'] ?? '—'}) just created an account.',
                time:  _ts(data['createdAt']),
              ));
            }
          }

          // ── MODIFIED ──────────────────────────────────────────────
          if (change.type == DocumentChangeType.modified) {
            final prev = _userSnapshots[uid] ?? {};

            final prevLevel  = prev['level']  as int? ?? 0;
            final nowLevel   = _getLevel(data);
            final prevStreak = prev['streak'] as int? ?? 0;
            final nowStreak  = _getStreak(data);

            // Level milestone crossed
            final milestones = [5, 10, 20, 30, 50];
            for (final m in milestones) {
              if (prevLevel < m && nowLevel >= m) {
                final id = 'level_${uid}_$m';
                if (!_seenIds.contains(id)) {
                  _add(AdminNotification(
                    id:    id,
                    type:  NotifType.levelUp,
                    title: 'Level milestone reached 🏆',
                    body:  '${data['name'] ?? 'A user'} (${data['email'] ?? '—'}) reached Level $nowLevel!',
                    time:  _ts(data['updatedAt']),
                  ));
                }
              }
            }

            // Streak milestone (every 7 days)
            final streakMilestones = [7, 14, 21, 30, 60, 100];
            for (final m in streakMilestones) {
              if (prevStreak < m && nowStreak >= m) {
                final id = 'streak_${uid}_$m';
                if (!_seenIds.contains(id)) {
                  _add(AdminNotification(
                    id:    id,
                    type:  NotifType.streakAchieved,
                    title: 'Streak milestone 🔥',
                    body:  '${data['name'] ?? 'A user'} (${data['email'] ?? '—'}) hit a $nowStreak-day streak!',
                    time:  _ts(data['updatedAt']),
                  ));
                }
              }
            }

            // Streak broken (went from >0 back to 0)
            if (prevStreak > 2 && nowStreak == 0) {
              final id = 'streakbroken_${uid}_${DateTime.now().millisecondsSinceEpoch}';
              _add(AdminNotification(
                id:    id,
                type:  NotifType.streakBroken,
                title: 'Streak ended',
                body:  '${data['name'] ?? 'A user'}\'s $prevStreak-day streak was broken.',
                time:  DateTime.now(),
              ));
            }

            // Name or email changed
            final nameChanged  = prev['name']  != data['name'];
            final emailChanged = prev['email'] != data['email'];
            if ((nameChanged || emailChanged) && !_initialUserLoad) {
              final changed = <String>[
                if (nameChanged)  'name',
                if (emailChanged) 'email',
              ];
              _add(AdminNotification(
                id:    'profile_${uid}_${DateTime.now().millisecondsSinceEpoch}',
                type:  NotifType.profileUpdated,
                title: 'Profile updated',
                body:  '${data['name'] ?? 'A user'} updated their ${changed.join(' & ')}.',
                time:  _ts(data['updatedAt']),
              ));
            }

            _userSnapshots[uid] = _snapshot(data);
          }
        }
        if (_initialUserLoad) _initialUserLoad = false;
      },
      onError: (e, s) {
        debugPrint('[Notif] users error: $e');
        _resubUsers();
      },
      cancelOnError: true,
    );
  }

  // ── 3. FEEDBACK LISTENER ──────────────────────────────────────────
  StreamSubscription _listenFeedback() {
    return FirebaseFirestore.instance
        .collection('feedback')
        .snapshots()
        .listen(
      (snap) {
        for (final change in snap.docChanges) {
          final data = change.doc.data();
          if (data == null) continue;

          final key   = change.doc.id;
          final isNew = !_initialFeedbackLoad && !_seenFeedbackIds.contains(key);
          _seenFeedbackIds.add(key);

          if (!isNew) continue;
          if (change.type != DocumentChangeType.added) continue;

          final rating  = ((data['rating'] ?? 0) as num).toInt();
          final comment = (data['comment'] ?? data['feedback'] ?? '').toString();
          final stars   = '⭐' * rating.clamp(0, 5);

          _add(AdminNotification(
            id:    'fb_$key',
            type:  NotifType.feedbackReceived,
            title: 'New feedback received $stars',
            body:  'A user left a $rating-star review.${comment.isNotEmpty ? ' "$comment"' : ''}',
            time:  _ts(data['createdAt']),
          ));
        }
        if (_initialFeedbackLoad) _initialFeedbackLoad = false;
      },
      onError: (e, s) {
        debugPrint('[Notif] feedback error: $e');
        _resubFeedback();
      },
      cancelOnError: true,
    );
  }

  // ── WRITE TO BOTH IN-MEMORY LIST AND FIRESTORE ────────────────────
  void _add(AdminNotification notif) {
    if (_seenIds.contains(notif.id)) return;
    _seenIds.add(notif.id);
    setState(() {
      _notifications.insert(0, notif);
      if (_notifications.length > 100) _notifications.removeLast();
    });
    _notify();
    _notifCol.doc(notif.id).set(notif.toMap()).catchError((e) {
      debugPrint('[Notif] persist error: $e');
    });
  }

  // ── PUBLIC ACTIONS ────────────────────────────────────────────────
  void markRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx == -1 || _notifications[idx].isRead) return;
    setState(() => _notifications[idx].isRead = true);
    _notify();
    _notifCol.doc(id).update({'isRead': true}).catchError((_) {});
  }

  void markAllRead() {
    final unread = _notifications.where((n) => !n.isRead).toList();
    if (unread.isEmpty) return;
    setState(() { for (final n in _notifications) n.isRead = true; });
    _notify();
    final batch = FirebaseFirestore.instance.batch();
    for (final n in unread) {
      batch.update(_notifCol.doc(n.id), {'isRead': true});
    }
    batch.commit().catchError((_) {});
  }

  void clearAll() {
    final ids = _notifications.map((n) => n.id).toList();
    setState(() { _notifications.clear(); _seenIds.clear(); });
    _notify();
    final batch = FirebaseFirestore.instance.batch();
    for (final id in ids) batch.delete(_notifCol.doc(id));
    batch.commit().catchError((_) {});
  }

  // ── HELPERS ───────────────────────────────────────────────────────
  Map<String, dynamic> _snapshot(Map<String, dynamic> d) => {
    'name':   d['name'],
    'email':  d['email'],
    'level':  _getLevel(d),
    'streak': _getStreak(d),
  };

  DateTime _ts(dynamic ts) {
    if (ts == null) return DateTime.now();
    try { return (ts as Timestamp).toDate(); }
    catch (_) { return DateTime.now(); }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ═══════════════════════════════════════════════════════════════════
// NOTIFICATION BELL
// ═══════════════════════════════════════════════════════════════════
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = NotificationProvider.of(context);

    return StreamBuilder<int>(
      stream:      provider?.stream,
      initialData: provider?.unreadCount ?? 0,
      builder: (context, snap) {
        final count = snap.data ?? 0;
        return GestureDetector(
          onTap: () => _openPanel(context, provider),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color:        _kSurface,
                  borderRadius: BorderRadius.circular(12),
                  border:       Border.all(color: _kBorder),
                  boxShadow: [
                    BoxShadow(
                      color:      Colors.black.withOpacity(0.06),
                      blurRadius: 6,
                      offset:     const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  count > 0
                      ? Icons.notifications_rounded
                      : Icons.notifications_none_rounded,
                  color: count > 0 ? _kAccent : _kSlate,
                  size:  20,
                ),
              ),
              if (count > 0)
                Positioned(
                  top: -4, right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color:        _kRose,
                      borderRadius: BorderRadius.circular(10),
                      border:       Border.all(color: _kBg, width: 1.5),
                    ),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _openPanel(BuildContext context, _NotificationProviderState? provider) {
    showGeneralDialog(
      context:            context,
      barrierDismissible: true,
      barrierLabel:       'notifications',
      barrierColor:       Colors.black.withOpacity(0.3),
      transitionDuration: const Duration(milliseconds: 240),
      transitionBuilder: (ctx, anim, _, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0), end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
      pageBuilder: (ctx, _, __) =>
          _NotificationPanel(providerContext: context),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// NOTIFICATION PANEL
// ═══════════════════════════════════════════════════════════════════
class _NotificationPanel extends StatefulWidget {
  final BuildContext providerContext;
  const _NotificationPanel({required this.providerContext});

  @override
  State<_NotificationPanel> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends State<_NotificationPanel> {
  String _filter = 'all';

  _NotificationProviderState? get _provider {
    try {
      if (!widget.providerContext.mounted) return null;
      return NotificationProvider.of(widget.providerContext);
    } catch (_) { return null; }
  }

  List<AdminNotification> _apply(List<AdminNotification> all) {
    if (_filter == 'unread') return all.where((n) => !n.isRead).toList();
    return all;
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider;

    return StreamBuilder<int>(
      stream:      provider?.stream,
      initialData: provider?.unreadCount ?? 0,
      builder: (context, _) {
        final all    = provider?.notifications ?? [];
        final items  = _apply(all.toList());
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
              decoration: const BoxDecoration(
                color: _kSurface,
                border: Border(left: BorderSide(color: _kBorder)),
                boxShadow: [
                  BoxShadow(
                    color:      Color(0x14000000),
                    blurRadius: 24,
                    offset:     Offset(-4, 0),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(children: [

                  // ── HEADER ────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
                    decoration: const BoxDecoration(
                      color: _kSurface,
                      border: Border(bottom: BorderSide(color: _kBorder)),
                    ),
                    child: Row(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color:        _kAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.notifications_rounded, color: _kAccent, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Notifications',
                                style: TextStyle(
                                    color: _kText, fontSize: 16, fontWeight: FontWeight.bold)),
                            Text(
                              unread > 0 ? '$unread unread' : 'All caught up ✓',
                              style: TextStyle(
                                  color:    unread > 0 ? _kAccent : _kSlate,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (unread > 0)
                        TextButton(
                          onPressed: () => provider?.markAllRead(),
                          style: TextButton.styleFrom(
                            foregroundColor: _kAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text('Mark all read', style: TextStyle(fontSize: 12)),
                        ),
                      if (all.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.delete_sweep_rounded, color: _kSlate, size: 20),
                          tooltip:   'Clear all',
                          onPressed: () => provider?.clearAll(),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: _kSlate),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ]),
                  ),

                  // ── FILTER CHIPS ──────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: const BoxDecoration(
                      color:  _kBg,
                      border: Border(bottom: BorderSide(color: _kBorder)),
                    ),
                    child: Row(children: [
                      _PanelChip(
                        label:    'All',
                        selected: _filter == 'all',
                        onTap:    () => setState(() => _filter = 'all'),
                      ),
                      const SizedBox(width: 8),
                      _PanelChip(
                        label:    'Unread',
                        selected: _filter == 'unread',
                        color:    _kRose,
                        onTap:    () => setState(() => _filter = 'unread'),
                      ),
                    ]),
                  ),

                  // ── LIST ──────────────────────────────────────────
                  Expanded(
                    child: items.isEmpty
                        ? _EmptyState(filter: _filter)
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: items.length,
                            separatorBuilder: (_, __) =>
                                const Divider(color: _kBorder, height: 1),
                            itemBuilder: (_, i) => _NotifTile(
                              notif: items[i],
                              onTap: () {
                                provider?.markRead(items[i].id);
                                if (items[i].type == NotifType.accountDeleted) {
                                  _showDeletedWarning(context, items[i]);
                                }
                              },
                            ),
                          ),
                  ),

                  // ── FOOTER ────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: _kBorder)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_done_rounded, color: _kSlate, size: 13),
                        const SizedBox(width: 6),
                        Text(
                          'Live from Firestore · ${all.length} total',
                          style: const TextStyle(color: _kSlate, fontSize: 11),
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

  void _showDeletedWarning(BuildContext context, AdminNotification notif) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kSurface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: _kRose.withOpacity(0.4))),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: _kRose, size: 22),
          SizedBox(width: 8),
          Text('Account Deleted',
              style: TextStyle(color: _kText, fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        content: Text(notif.body,
            style: const TextStyle(color: _kSlate, fontSize: 13, height: 1.5)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kRose, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// NOTIFICATION TILE
// ═══════════════════════════════════════════════════════════════════
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
        color:   notif.isRead ? Colors.transparent : notif.color.withOpacity(0.05),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon badge
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color:        notif.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border:       Border.all(color: notif.color.withOpacity(0.25)),
              ),
              child: Icon(notif.icon, color: notif.color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        notif.title,
                        style: TextStyle(
                          color:      _kText,
                          fontWeight: notif.isRead ? FontWeight.normal : FontWeight.bold,
                          fontSize:   13,
                        ),
                      ),
                    ),
                    if (!notif.isRead)
                      Container(
                        width: 7, height: 7,
                        decoration: BoxDecoration(
                            color: notif.color, shape: BoxShape.circle),
                      ),
                  ]),
                  const SizedBox(height: 3),
                  Text(
                    notif.body,
                    style: const TextStyle(
                        color: _kSlate, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    notif.timeLabel,
                    style: TextStyle(
                        color: notif.color.withOpacity(0.8), fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SMALL WIDGETS
// ═══════════════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  final String filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color:        _kBg,
            shape:        BoxShape.circle,
            border:       Border.all(color: _kBorder),
          ),
          child: const Icon(Icons.notifications_off_rounded, color: _kSlate, size: 28),
        ),
        const SizedBox(height: 16),
        Text(
          filter == 'all' ? 'No notifications yet' : 'No unread notifications',
          style: const TextStyle(
              color: _kText, fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        const Text(
          'Events from Firestore will appear here\nin real-time as they happen.',
          style: TextStyle(color: _kSlate, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }
}

class _PanelChip extends StatelessWidget {
  final String       label;
  final bool         selected;
  final VoidCallback onTap;
  final Color        color;

  const _PanelChip({
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
        padding:  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color:        selected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(color: selected ? color : _kBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:      selected ? color : _kSlate,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize:   12,
          ),
        ),
      ),
    );
  }
}
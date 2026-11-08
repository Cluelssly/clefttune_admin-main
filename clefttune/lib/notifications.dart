// ═══════════════════════════════════════════════════════════════════
// CLEFTTUNE ADMIN — notifications.dart  (White Theme v2)
//
// Matches the clean white theme from main.dart.
// The admin notification feed now listens to:
//   • saved notifications (Firestore 'notifications')
//   • users    (new user, deleted, profile updated, streaks)
//   • feedback (new feedback received)
// ═══════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
// THEME — mirrors main.dart constants
// ─────────────────────────────────────────────
const _kBg      = Color(0xFFF5F4F0);
const _kSurface = Color(0xFFFFFFFF);
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
    FirebaseFirestore.instance.collection('notifications');

int _getLevel(Map<String, dynamic> data) =>
    (data['level'] ?? data['userLevel'] ?? 0) as int;

int _getStreak(Map<String, dynamic> data) =>
    (data['streak'] ?? data['currentStreak'] ?? 0) as int;

// ─────────────────────────────────────────────
// NOTIFICATION MODEL
// ─────────────────────────────────────────────
enum NotifType {
  newUser,
  badgeEarned,
  accountDeleted,
  profileUpdated,
  levelUp,
  streakAchieved,
  streakBroken,
  feedbackReceived,
}

NotifType _typeFromString(String s) {
  switch (s) {
    case 'new_user':
      return NotifType.newUser;
    case 'badge_earned':
      return NotifType.badgeEarned;
    default:
      return NotifType.values.firstWhere(
        (type) => type.name == s,
        orElse: () => NotifType.newUser,
      );
  }
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
      time = ((data['createdAt'] ?? data['time']) as Timestamp).toDate();
    } catch (_) {
      time = DateTime.now();
    }
    return AdminNotification(
      id:     doc.id,
      type:   _typeFromString(data['type'] ?? 'newUser'),
      title:  data['title'] ?? '',
      body:   data['body']  ?? '',
      time:   time,
      isRead: data['read'] == true || data['isRead'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
        'type':      type.name,
        'title':     title,
        'body':      body,
        'time':      Timestamp.fromDate(time),
        'createdAt': Timestamp.fromDate(time),
        'userId':    '',
        'userName':  '',
        'userEmail': '',
        'details':   <String, dynamic>{},
        'isRead':    isRead,
        'read':      isRead,
        'savedAt':   FieldValue.serverTimestamp(),
      };

  Color get color {
    switch (type) {
      case NotifType.newUser:          return _kAccent;
      case NotifType.badgeEarned:      return _kAmber;
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
      case NotifType.badgeEarned:      return Icons.workspace_premium_rounded;
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
  final List<AdminNotification>           _notifications   = [];
  final Set<String>                       _seenIds         = {};
  final Map<String, Map<String, dynamic>> _userSnapshots   = {};
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

  // ── PERSISTENCE / CATCH-UP ────────────────────────────────────────
  // Every notification is saved in Firestore ('notifications'), so the
  // history is still there after logout / app restart.
  // 'admin_meta/notifications.lastSyncedAt' remembers when the admin panel
  // last ran. On the next login, any user or feedback created AFTER that
  // moment (i.e. while you were logged out) gets its notification created.
  DocumentReference<Map<String, dynamic>> get _metaDoc =>
      FirebaseFirestore.instance.collection('admin_meta').doc('notifications');

  DateTime? _lastSync;
  bool _syncSaved = false;
  int  _initialLoadsDone = 0;
  final Completer<void> _notifsReady = Completer<void>();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // 1) when did the admin panel last run?
    try {
      final snap = await _metaDoc.get();
      final ts = snap.data()?['lastSyncedAt'];
      if (ts is Timestamp) _lastSync = ts.toDate();
    } catch (e) {
      debugPrint('[Notif] could not read sync marker: $e');
    }
    if (!mounted) return;

    // 2) load the saved notifications first, so we know what already exists
    _notifSub = _listenNotifs();
    await _notifsReady.future
        .timeout(const Duration(seconds: 8), onTimeout: () {});
    if (!mounted) return;

    // 3) then watch users + feedback (these also catch up on missed events)
    _userSub     = _listenUsers();
    _feedbackSub = _listenFeedback();
  }

  /// True if something was created after the last time the admin panel ran.
  bool _isMissed(DateTime? created) =>
      _lastSync != null && created != null && created.isAfter(_lastSync!);

  /// Called when users + feedback have both finished their first load.
  void _initialLoadFinished() {
    _initialLoadsDone++;
    if (_initialLoadsDone >= 2) _saveSyncMarker();
  }

  void _saveSyncMarker() {
    _syncSaved = true;
    _metaDoc
        .set({'lastSyncedAt': Timestamp.now()}, SetOptions(merge: true))
        .catchError((e) => debugPrint('[Notif] sync marker error: $e'));
  }

  DateTime? _docTime(Map<String, dynamic> data, List<String> keys) {
    for (final k in keys) {
      final v = data[k];
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is String) {
        final p = DateTime.tryParse(v);
        if (p != null) return p;
      }
    }
    return null;
  }

  @override
  void dispose() {
    if (_syncSaved) _saveSyncMarker(); // remember when we last ran
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
    debugPrint('[Notif] notifications error — resubscribing in 5s');
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
  // FIX #2: removed the whereIn filter. whereIn + orderBy needs a
  // composite index (the stream silently errored without it) and it
  // also hid feedback / streak / profile notifications.
  StreamSubscription _listenNotifs() {
    return _notifCol
        .orderBy('createdAt', descending: true)
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
                  change.doc.data()!['read'] == true ||
                      change.doc.data()!['isRead'] == true;
              changed = true;
            }
          } else if (change.type == DocumentChangeType.added) {
            final data = change.doc.data();
            if (data != null && !_seenIds.contains(change.doc.id)) {
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
        if (!_notifsReady.isCompleted) _notifsReady.complete();
        if (changed) {
          _notifications.sort((a, b) => b.time.compareTo(a.time));
          if (_notifications.length > 100) {
            _notifications.removeRange(100, _notifications.length);
          }
          if (mounted) setState(() {});
          _notify();
        }
      },
      onError: (e, s) {
        debugPrint('[Notif] notifications error: $e');
        _saveError = 'Cannot read saved notifications: $e';
        _notify();
        if (!_notifsReady.isCompleted) _notifsReady.complete();
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
          // Live sign-ups, plus sign-ups that happened while the admin was
          // logged out (created after the last sync). Older users on the
          // first load are skipped so the feed isn't flooded.
          if (change.type == DocumentChangeType.added) {
            _userSnapshots[uid] = _snapshot(data);

            final created  = _docTime(data, ['createdAt', 'joinedDate']);
            final isLive   = !_initialUserLoad;
            final isMissed = _initialUserLoad && _isMissed(created);

            if (isLive || isMissed) {
              final name  = data['name'] ?? 'A user';
              final email = (data['email'] ?? '').toString();
              _add(AdminNotification(
                id:    'user_$uid', // same id as NotificationHelper → no duplicates
                type:  NotifType.newUser,
                title: 'New user registered',
                body:  '$name (${email.isEmpty ? '—' : email}) just created an account.',
                time:  created ?? DateTime.now(),
              ));
            }
          }

          // ── MODIFIED ──────────────────────────────────────────────
          if (change.type == DocumentChangeType.modified) {
            final prev = _userSnapshots[uid] ?? {};

            final prevStreak = prev['streak'] as int? ?? 0;
            final nowStreak  = _getStreak(data);

            // Streak milestones
            const streakMilestones = [7, 14, 21, 30, 60, 100];
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

            // Streak broken (went from >2 back to 0)
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
        if (_initialUserLoad) {
          _initialUserLoad = false;
          _initialLoadFinished();
        }
      },
      onError: (e, s) {
        debugPrint('[Notif] users error: $e');
        _resubUsers();
      },
      cancelOnError: true,
    );
  }

  // ── 3. FEEDBACK LISTENER ──────────────────────────────────────────
  // NOTE: change 'feedback' if your user app saves under another name.
  StreamSubscription _listenFeedback() {
    return FirebaseFirestore.instance
        .collection('feedback')
        .snapshots()
        .listen(
      (snap) {
        for (final change in snap.docChanges) {
          final data = change.doc.data();
          if (data == null) continue;

          final key     = change.doc.id;
          final already = _seenFeedbackIds.contains(key);
          _seenFeedbackIds.add(key);

          if (already) continue;
          if (change.type != DocumentChangeType.added) continue;

          // Live feedback, plus feedback sent while the admin was logged out.
          final created  = _docTime(data, ['createdAt', 'date', 'timestamp']);
          final isLive   = !_initialFeedbackLoad;
          final isMissed = _initialFeedbackLoad && _isMissed(created);
          if (!isLive && !isMissed) continue;

          final rating  = ((data['rating'] ?? 0) as num).toInt();
          final comment = (data['comment'] ?? data['feedback'] ?? '').toString();
          final stars   = '⭐' * rating.clamp(0, 5);

          _add(AdminNotification(
            id:    'fb_$key',
            type:  NotifType.feedbackReceived,
            title: 'New feedback received $stars',
            body:  'A user left a $rating-star review.${comment.isNotEmpty ? ' "$comment"' : ''}',
            time:  created ?? DateTime.now(),
          ));
        }
        if (_initialFeedbackLoad) {
          _initialFeedbackLoad = false;
          _initialLoadFinished();
        }
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
    if (mounted) {
      setState(() {
        _notifications.insert(0, notif);
        if (_notifications.length > 100) _notifications.removeLast();
      });
    }
    _notify();
    _persist(notif);
  }

  /// Saves the notification to Firestore. If a document with this id already
  /// exists (e.g. written by the user app), it is left untouched so its
  /// read / unread state is never overwritten.
  Future<void> _persist(AdminNotification notif) async {
    try {
      final ref  = _notifCol.doc(notif.id);
      final snap = await ref.get();
      if (!snap.exists) await ref.set(notif.toMap());
      if (_saveError != null) {
        _saveError = null;
        _notify();
      }
    } catch (e) {
      debugPrint('[Notif] persist error: $e');
      _saveError = e.toString();
      _notify(); // refreshes the panel so the warning is visible
    }
  }

  /// Non-null when notifications could NOT be saved to / read from Firestore
  /// (usually Firestore security rules). Shown in the panel footer.
  String? _saveError;
  String? get saveError => _saveError;

  // ── PUBLIC ACTIONS ────────────────────────────────────────────────
  void markRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx == -1 || _notifications[idx].isRead) return;
    setState(() => _notifications[idx].isRead = true);
    _notify();
    _notifCol.doc(id).update({'read': true, 'isRead': true}).catchError((_) {});
  }

  void markAllRead() {
    final unread = _notifications.where((n) => !n.isRead).toList();
    if (unread.isEmpty) return;
    setState(() {
      for (final n in _notifications) {
        n.isRead = true;
      }
    });
    _notify();
    final batch = FirebaseFirestore.instance.batch();
    for (final n in unread) {
      batch.update(_notifCol.doc(n.id), {'read': true, 'isRead': true});
    }
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
    try {
      return (ts as Timestamp).toDate();
    } catch (_) {
      return DateTime.now();
    }
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
    } catch (_) {
      return null;
    }
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
                        child: const Icon(Icons.notifications_rounded,
                            color: _kAccent, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Notifications',
                                style: TextStyle(
                                    color: _kText,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
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
                          child: const Text('Mark all read',
                              style: TextStyle(fontSize: 12)),
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
                              onTap: () => provider?.markRead(items[i].id),
                            ),
                          ),
                  ),

                  // ── FOOTER ────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: _kBorder)),
                    ),
                    child: provider?.saveError != null
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    color: _kRose, size: 14),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Not saved to Firestore — check your '
                                    'Firestore rules for "notifications" '
                                    'and "admin_meta".\n${provider!.saveError}',
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: _kRose, fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.cloud_done_rounded,
                                  color: _kSlate, size: 13),
                              const SizedBox(width: 6),
                              Text(
                                'Saved in Firestore · ${all.length} total',
                                style: const TextStyle(
                                    color: _kSlate, fontSize: 11),
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
                          fontWeight: notif.isRead
                              ? FontWeight.normal
                              : FontWeight.bold,
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
            color:  _kBg,
            shape:  BoxShape.circle,
            border: Border.all(color: _kBorder),
          ),
          child: const Icon(Icons.notifications_off_rounded,
              color: _kSlate, size: 28),
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
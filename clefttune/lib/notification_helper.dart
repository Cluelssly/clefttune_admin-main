import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationHelper {
  NotificationHelper._();

  static final _notifications =
      FirebaseFirestore.instance.collection('notifications');

  static Future<void> newUser({
    required String userId,
    required String name,
    required String email,
  }) {
    return _write(
      id: 'user_$userId',
      type: 'new_user',
      userId: userId,
      userName: name,
      userEmail: email,
      title: 'New user registered',
      body: '$name (${email.isEmpty ? '—' : email}) just created an account.',
    );
  }

  static Future<void> badgeEarned({
    required String eventId,
    required String userId,
    required String name,
    required String email,
    required String badgeLabel,
    required String badgeEmoji,
    required int level,
  }) {
    return _write(
      id: 'badge_$eventId',
      type: 'badge_earned',
      userId: userId,
      userName: name,
      userEmail: email,
      title: 'Badge tier earned',
      body: '$name just earned the $badgeEmoji $badgeLabel badge at Level $level.',
      details: {
        'level': level,
        'badgeLabel': badgeLabel,
        'badgeEmoji': badgeEmoji,
      },
    );
  }

  static Future<void> _write({
    required String id,
    required String type,
    required String userId,
    required String userName,
    required String userEmail,
    required String title,
    required String body,
    Map<String, dynamic> details = const {},
  }) {
    final timestamp = FieldValue.serverTimestamp();
    return _notifications.doc(id).set({
      'type': type,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'details': details,
      'title': title,
      'body': body,
      'createdAt': timestamp,
      'time': timestamp,
      'read': false,
      'isRead': false,
    });
  }
}

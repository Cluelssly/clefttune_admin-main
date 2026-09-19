import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'landingpage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VoiceMate Admin',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: kBg,
        fontFamily: 'Georgia',
        colorScheme: ColorScheme.fromSeed(
          seedColor: kAccent,
          brightness: Brightness.light,
        ),
      ),
      home: const AdminLandingPage(),
    );
  }
}

// ─────────────────────────────────────────────
// THEME CONSTANTS
// ─────────────────────────────────────────────
const kBg      = Color(0xFFF5F4F0);
const kSurface = Color(0xFFFFFFFF);
const kSidebar = Color(0xFF1A1A2E);
const kAccent  = Color(0xFF2563EB);
const kIndigo  = Color(0xFF4F46E5);
const kEmerald = Color(0xFF059669);
const kAmber   = Color(0xFFD97706);
const kRose    = Color(0xFFE11D48);
const kSlate   = Color(0xFF64748B);
const kBorder  = Color(0xFFE2E8F0);
const kText    = Color(0xFF0F172A);

// ─────────────────────────────────────────────
// DATA MODEL
// ─────────────────────────────────────────────
class SampleUser {
  String id;
  String name;
  String email;
  int    level;
  int    streak;
  double rating;
  String joinedDate;
  String lastActive;

  SampleUser({
    required this.id,
    required this.name,
    required this.email,
    required this.level,
    required this.streak,
    required this.rating,
    required this.joinedDate,
    required this.lastActive,
  });

  SampleUser copyWith({
    String? name,
    String? email,
    int?    level,
    int?    streak,
    double? rating,
    String? joinedDate,
    String? lastActive,
  }) => SampleUser(
    id:         id,
    name:       name        ?? this.name,
    email:      email       ?? this.email,
    level:      level       ?? this.level,
    streak:     streak      ?? this.streak,
    rating:     rating      ?? this.rating,
    joinedDate: joinedDate  ?? this.joinedDate,
    lastActive: lastActive  ?? this.lastActive,
  );
}

class SampleFeedback {
  final String userId;
  final String userName;
  final String userEmail;
  final int    rating;
  final String comment;
  final String date;

  const SampleFeedback({
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.rating,
    required this.comment,
    required this.date,
  });
}

// ─────────────────────────────────────────────
// BADGE TIER MODEL  (admin-managed)
// ─────────────────────────────────────────────
class BadgeTier {
  String id;
  String emoji;
  String label;
  int    minLevel;
  Color  color;
  List<String> tasks;

  BadgeTier({
    required this.id,
    required this.emoji,
    required this.label,
    required this.minLevel,
    required this.color,
    List<String>? tasks,
  }) : tasks = tasks ?? List.filled(5, '', growable: true);

  BadgeTier copyWith({
    String? emoji,
    String? label,
    int?    minLevel,
    Color?  color,
    List<String>? tasks,
  }) => BadgeTier(
    id:       id,
    emoji:    emoji    ?? this.emoji,
    label:    label    ?? this.label,
    minLevel: minLevel ?? this.minLevel,
    color:    color    ?? this.color,
    tasks:    tasks    ?? List<String>.from(this.tasks),
  );
}

// ─────────────────────────────────────────────
// MUTABLE SAMPLE DATA
// ─────────────────────────────────────────────
final List<SampleUser> sampleUsers = [
  SampleUser(id: '1',  name: 'Alex Rivera',      email: 'alex.rivera@example.com',     level: 32, streak: 14, rating: 4.8, joinedDate: '2024-01-15', lastActive: '2025-05-30'),
  SampleUser(id: '2',  name: 'Maria Santos',     email: 'maria.santos@example.com',    level: 25, streak: 7,  rating: 4.5, joinedDate: '2024-02-20', lastActive: '2025-05-29'),
  SampleUser(id: '3',  name: 'James Kim',        email: 'james.kim@example.com',       level: 18, streak: 21, rating: 4.2, joinedDate: '2024-03-10', lastActive: '2025-05-28'),
  SampleUser(id: '4',  name: 'Sofia Reyes',      email: 'sofia.reyes@example.com',     level: 12, streak: 5,  rating: 5.0, joinedDate: '2024-04-05', lastActive: '2025-05-27'),
  SampleUser(id: '5',  name: 'Carlos Mendoza',   email: 'carlos.m@example.com',        level: 8,  streak: 3,  rating: 3.8, joinedDate: '2024-05-12', lastActive: '2025-05-26'),
  SampleUser(id: '6',  name: 'Aisha Johnson',    email: 'aisha.j@example.com',         level: 45, streak: 30, rating: 4.9, joinedDate: '2023-11-01', lastActive: '2025-05-31'),
  SampleUser(id: '7',  name: 'David Tan',        email: 'david.tan@example.com',       level: 3,  streak: 0,  rating: 4.0, joinedDate: '2025-01-10', lastActive: '2025-05-20'),
  SampleUser(id: '8',  name: 'Priya Sharma',     email: 'priya.sharma@example.com',    level: 20, streak: 12, rating: 4.6, joinedDate: '2024-06-22', lastActive: '2025-05-30'),
  SampleUser(id: '9',  name: 'Liam O\'Brien',    email: 'liam.ob@example.com',         level: 55, streak: 45, rating: 4.7, joinedDate: '2023-08-14', lastActive: '2025-05-31'),
  SampleUser(id: '10', name: 'Elena Vasquez',    email: 'elena.v@example.com',         level: 15, streak: 8,  rating: 3.5, joinedDate: '2024-07-03', lastActive: '2025-05-25'),
  SampleUser(id: '11', name: 'Noah Williams',    email: 'noah.w@example.com',          level: 7,  streak: 2,  rating: 4.1, joinedDate: '2024-09-18', lastActive: '2025-05-22'),
  SampleUser(id: '12', name: 'Fatima Al-Hassan', email: 'fatima.ah@example.com',       level: 28, streak: 18, rating: 4.8, joinedDate: '2024-03-30', lastActive: '2025-05-29'),
  SampleUser(id: '13', name: 'Jin Park',         email: 'jin.park@example.com',        level: 10, streak: 6,  rating: 4.3, joinedDate: '2024-08-07', lastActive: '2025-05-28'),
  SampleUser(id: '14', name: 'Isabella Costa',   email: 'isabella.c@example.com',      level: 35, streak: 22, rating: 4.6, joinedDate: '2023-12-05', lastActive: '2025-05-31'),
  SampleUser(id: '15', name: 'Omar Farooq',      email: 'omar.f@example.com',          level: 2,  streak: 1,  rating: 3.0, joinedDate: '2025-03-14', lastActive: '2025-05-10'),
];

final List<SampleFeedback> sampleFeedback = [
  SampleFeedback(userId: '1',  userName: 'Alex Rivera',      userEmail: 'alex.rivera@example.com',  rating: 5, comment: "CleftTune has been life-changing. The voice recognition adapts incredibly well to my speech. I've seen huge improvements in just 3 months!", date: '2025-05-30'),
  SampleFeedback(userId: '6',  userName: 'Aisha Johnson',    userEmail: 'aisha.j@example.com',      rating: 5, comment: "The AI corrections are spot-on. It understood my patterns after just a few sessions. Highly recommend to anyone with cleft palate speech differences.", date: '2025-05-29'),
  SampleFeedback(userId: '14', userName: 'Isabella Costa',   userEmail: 'isabella.c@example.com',   rating: 5, comment: "Outstanding app. The training model is incredibly accurate and the interface is clean and easy to use.", date: '2025-05-28'),
  SampleFeedback(userId: '9',  userName: "Liam O'Brien",     userEmail: 'liam.ob@example.com',      rating: 4, comment: "Really solid app. The streak system keeps me motivated. Would love a dark mode option though.", date: '2025-05-27'),
  SampleFeedback(userId: '8',  userName: 'Priya Sharma',     userEmail: 'priya.sharma@example.com', rating: 5, comment: "I was skeptical at first but the personalized voice model genuinely works. My family says I'm much easier to understand now.", date: '2025-05-26'),
  SampleFeedback(userId: '4',  userName: 'Sofia Reyes',      userEmail: 'sofia.reyes@example.com',  rating: 5, comment: "The correction system is brilliant. It learned my specific phoneme substitutions within days. 10/10!", date: '2025-05-25'),
  SampleFeedback(userId: '2',  userName: 'Maria Santos',     userEmail: 'maria.santos@example.com', rating: 4, comment: "Great app! The training screen is intuitive. Minor feedback: the history page could show more details.", date: '2025-05-24'),
  SampleFeedback(userId: '12', userName: 'Fatima Al-Hassan', userEmail: 'fatima.ah@example.com',    rating: 5, comment: "I've tried many similar apps and nothing compares to CleftTune. The AI is remarkably good at understanding cleft palate speech.", date: '2025-05-23'),
  SampleFeedback(userId: '3',  userName: 'James Kim',        userEmail: 'james.kim@example.com',    rating: 4, comment: "Good progress tracking. The leaderboard feature motivates me to keep training every day.", date: '2025-05-22'),
  SampleFeedback(userId: '5',  userName: 'Carlos Mendoza',   userEmail: 'carlos.m@example.com',     rating: 4, comment: "The app works well. Support team responded quickly when I had a question. Overall very happy.", date: '2025-05-21'),
  SampleFeedback(userId: '10', userName: 'Elena Vasquez',    userEmail: 'elena.v@example.com',      rating: 3, comment: "Decent app but the processing can be slow on older devices. Hope performance improves in future updates.", date: '2025-05-20'),
  SampleFeedback(userId: '13', userName: 'Jin Park',         userEmail: 'jin.park@example.com',     rating: 4, comment: "Steady improvement after 2 months of use. The badge system is a fun touch!", date: '2025-05-19'),
];

// ─────────────────────────────────────────────
// MUTABLE BADGE TIERS  (admin CRUD)
// ─────────────────────────────────────────────
final List<BadgeTier> badgeTiers = [
  BadgeTier(
    id: 'b1', emoji: '🌱', label: 'Seedling', minLevel: 0,  color: kEmerald,
    tasks: [
      'Complete your profile setup',
      'Finish your first training session',
      'Practice for 3 days in a row',
      'Log your first recording',
      'Review your first feedback report',
    ],
  ),
  BadgeTier(
    id: 'b2', emoji: '🥉', label: 'Bronze',   minLevel: 5,  color: const Color(0xFFCD7F32),
    tasks: [
      'Reach a 5-day streak',
      'Complete 10 training sessions',
      'Score 80%+ on a phoneme drill',
      'Finish the beginner exercise set',
      'Submit your first app feedback',
    ],
  ),
  BadgeTier(
    id: 'b3', emoji: '🥈', label: 'Silver',   minLevel: 10, color: kSlate,
    tasks: [
      'Reach a 10-day streak',
      'Complete 25 training sessions',
      'Score 85%+ on 3 phoneme drills',
      'Finish the intermediate exercise set',
      'Help another user by sharing a tip',
    ],
  ),
  BadgeTier(
    id: 'b4', emoji: '🥇', label: 'Gold',     minLevel: 20, color: kAmber,
    tasks: [
      'Reach a 20-day streak',
      'Complete 50 training sessions',
      'Score 90%+ on 5 phoneme drills',
      'Finish the advanced exercise set',
      'Maintain a 4.5+ self-rated average',
    ],
  ),
  BadgeTier(
    id: 'b5', emoji: '💎', label: 'Diamond',  minLevel: 30, color: const Color(0xFF0EA5E9),
    tasks: [
      'Reach a 30-day streak',
      'Complete 100 training sessions',
      'Score 95%+ on 10 phoneme drills',
      'Finish all exercise sets',
      'Mentor a new user through onboarding',
    ],
  ),
  BadgeTier(
    id: 'b6', emoji: '🏆', label: 'Legend',   minLevel: 50, color: const Color(0xFFB45309),
    tasks: [
      'Reach a 50-day streak',
      'Complete 200 training sessions',
      'Achieve a perfect score on all drills',
      'Finish every exercise set twice',
      'Top the leaderboard for a full month',
    ],
  ),
];

// ─────────────────────────────────────────────
// HELPERS  (resolve badge from live badgeTiers list)
// ─────────────────────────────────────────────
BadgeTier _getBadgeTierFor(int level) {
  final sorted = [...badgeTiers]..sort((a, b) => b.minLevel.compareTo(a.minLevel));
  return sorted.firstWhere((t) => level >= t.minLevel, orElse: () => badgeTiers.first);
}

String _getBadgeEmoji(int level)  => _getBadgeTierFor(level).emoji;
String _getBadgeLabel(int level)  => _getBadgeTierFor(level).label;
Color  _getBadgeColor(int level)  => _getBadgeTierFor(level).color;

int _nextUserId() {
  if (sampleUsers.isEmpty) return 1;
  return sampleUsers
      .map((u) => int.tryParse(u.id) ?? 0)
      .reduce((a, b) => a > b ? a : b) + 1;
}

int _nextBadgeId() {
  if (badgeTiers.isEmpty) return 1;
  return badgeTiers
      .map((b) => int.tryParse(b.id.replaceAll('b', '')) ?? 0)
      .reduce((a, b) => a > b ? a : b) + 1;
}

class _AppStats {
  final int    total;
  final int    activeStreaks;
  final int    highLevel;
  final double avgRating;
  final int    totalFeedback;

  _AppStats({
    required this.total,
    required this.activeStreaks,
    required this.highLevel,
    required this.avgRating,
    required this.totalFeedback,
  });

  factory _AppStats.fromSample() {
    final total        = sampleUsers.length;
    final activeStreaks = sampleUsers.where((u) => u.streak > 0).length;
    final highLevel    = sampleUsers.where((u) => u.level >= 10).length;
    final ratings      = sampleUsers.where((u) => u.rating > 0).map((u) => u.rating).toList();
    final avgRating    = ratings.isEmpty ? 0.0 : ratings.reduce((a, b) => a + b) / ratings.length;

    return _AppStats(
      total:        total,
      activeStreaks: activeStreaks,
      highLevel:    highLevel,
      avgRating:    avgRating,
      totalFeedback: sampleFeedback.length,
    );
  }
}

// ─────────────────────────────────────────────
// RADIO WAVE ICON
// ─────────────────────────────────────────────
class RadioWaveIcon extends StatelessWidget {
  final Color color;
  final double size;
  const RadioWaveIcon({super.key, this.color = Colors.white, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size, height: size,
      child: CustomPaint(painter: _RadioWavePainter(color: color)),
    );
  }
}

class _RadioWavePainter extends CustomPainter {
  final Color color;
  const _RadioWavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;

    canvas.drawCircle(Offset(cx, cy), 2.5, Paint()..color = color);

    for (final r in [6.0, 10.0, 14.0]) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -0.7, 1.4, false, paint,
      );
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        3.14 - 0.7, 1.4, false, paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────
// SHELL
// ─────────────────────────────────────────────
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _loadFirestoreData();
  }

  Future<void> _loadFirestoreData() async {
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('users').get(),
        FirebaseFirestore.instance.collection('feedback').get(),
      ]);
      final users = results[0].docs.map(_userFromDocument).toList();
      final feedback = results[1].docs.map(_feedbackFromDocument).toList();

      if (!mounted) return;
      setState(() {
        sampleUsers
          ..clear()
          ..addAll(users);
        sampleFeedback
          ..clear()
          ..addAll(feedback);
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load Firebase data: $error')),
        );
      }
    }
  }

  // Admin-managed content pages.
  static const _navItems = [
    _NavItem(Icons.dashboard_rounded,       'Dashboard'),
    _NavItem(Icons.manage_accounts_rounded, 'Manage Users'),
    _NavItem(Icons.emoji_events_rounded,    'Leaderboard'),
    _NavItem(Icons.star_rounded,            'Feedback'),
    _NavItem(Icons.military_tech_rounded,   'Badges'),
    _NavItem(Icons.analytics_rounded,       'Analytics'),
  ];

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final w        = MediaQuery.of(context).size.width;
    final isMobile = w < 800;
    final stats    = _AppStats.fromSample();

    final pages = [
      DashboardPage(stats: stats),
      UsersPage(),                   // read-only now
      LeaderboardPage(),
      FeedbackPage(),
      BadgesPage(onChanged: _refresh),
      AnalyticsPage(stats: stats),
    ];

    final sidebar = _SidebarContent(
      selectedIndex: _selectedIndex,
      navItems:      _navItems,
      onSelect: (i) {
        setState(() => _selectedIndex = i);
        if (isMobile) Navigator.pop(context);
      },
    );

    return Scaffold(
      key:             _scaffoldKey,
      backgroundColor: kBg,
      drawer: isMobile
          ? Drawer(backgroundColor: kSidebar, child: SafeArea(child: sidebar))
          : null,
      body: SafeArea(
        child: Stack(children: [
          Row(children: [
            if (!isMobile) sidebar,
            Expanded(child: pages[_selectedIndex]),
          ]),
          if (isMobile)
            Positioned(
              top: 12, left: 12,
              child: _HamburgerButton(
                  onTap: () => _scaffoldKey.currentState?.openDrawer()),
            ),
        ]),
      ),
    );
  }
}

SampleUser _userFromDocument(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data();
  return SampleUser(
    id: doc.id,
    name: (data['name'] ?? data['displayName'] ?? 'Unknown user').toString(),
    email: (data['email'] ?? '—').toString(),
    level: _asInt(data['level'] ?? data['userLevel']),
    streak: _asInt(data['streak'] ?? data['currentStreak']),
    rating: _asDouble(data['rating'] ?? data['averageRating']),
    joinedDate: _asDate(data['joinedDate'] ?? data['createdAt']),
    lastActive: _asDate(data['lastActive'] ?? data['lastActiveAt'] ?? data['updatedAt']),
  );
}

SampleFeedback _feedbackFromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data();
  return SampleFeedback(
    userId: (data['userId'] ?? doc.id).toString(),
    userName: (data['userName'] ?? data['name'] ?? 'Unknown user').toString(),
    userEmail: (data['userEmail'] ?? data['email'] ?? '—').toString(),
    rating: _asInt(data['rating']),
    comment: (data['comment'] ?? data['feedback'] ?? '').toString(),
    date: _asDate(data['date'] ?? data['createdAt']),
  );
}

int _asInt(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;

double _asDouble(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0.0;

String _asDate(dynamic value) {
  if (value is Timestamp) return value.toDate().toIso8601String().split('T').first;
  if (value is DateTime) return value.toIso8601String().split('T').first;
  return value?.toString() ?? '—';
}

// ─────────────────────────────────────────────
// HAMBURGER
// ─────────────────────────────────────────────
class _HamburgerButton extends StatelessWidget {
  final VoidCallback onTap;
  const _HamburgerButton({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: kSurface, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        _HLine(18), const SizedBox(height: 4),
        _HLine(14), const SizedBox(height: 4),
        _HLine(18),
      ]),
    ),
  );
}

class _HLine extends StatelessWidget {
  final double w;
  const _HLine(this.w);
  @override
  Widget build(BuildContext context) => Container(
    width: w, height: 2,
    decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(2)),
  );
}

// ─────────────────────────────────────────────
// SIDEBAR
// ─────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final String   label;
  const _NavItem(this.icon, this.label);
}

class _SidebarContent extends StatelessWidget {
  final int               selectedIndex;
  final List<_NavItem>    navItems;
  final ValueChanged<int> onSelect;
  const _SidebarContent({required this.selectedIndex, required this.navItems, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240, color: kSidebar,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: kAccent, borderRadius: BorderRadius.circular(8)),
              child: const RadioWaveIcon(size: 32),
            ),
            const SizedBox(width: 10),
            const Text('CleftTune',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          ]),
        ),
        const SizedBox(height: 4),
        const Padding(
          padding: EdgeInsets.only(left: 8),
          child: Text('Admin Panel',
              style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1.2)),
        ),
        const SizedBox(height: 32),
        for (int i = 0; i < navItems.length; i++) ...[
          _SidebarTile(
            icon:     navItems[i].icon,
            label:    navItems[i].label,
            selected: selectedIndex == i,
            onTap:    () => onSelect(i),
          ),
          const SizedBox(height: 2),
        ],
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(color: kEmerald, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            const Text('Sample Data Mode',
                style: TextStyle(color: Colors.white38, fontSize: 11)),
          ]),
        ),
      ]),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  final IconData icon; final String label; final bool selected; final VoidCallback onTap;
  const _SidebarTile({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? kAccent.withOpacity(0.15) : Colors.transparent,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(children: [
          Icon(icon, color: selected ? kAccent : Colors.white38, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(
            color:      selected ? Colors.white : Colors.white54,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            fontSize:   13,
          ))),
          if (selected)
            Container(width: 6, height: 6,
                decoration: const BoxDecoration(color: kAccent, shape: BoxShape.circle)),
        ]),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════
// PAGE: DASHBOARD
// ═══════════════════════════════════════════════════════════════════
class DashboardPage extends StatelessWidget {
  final _AppStats stats;
  const DashboardPage({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final isMobile   = MediaQuery.of(context).size.width < 800;
    final recentUsers = sampleUsers.take(5).toList();
    final topStreaks  = [...sampleUsers]..sort((a, b) => b.streak.compareTo(a.streak));

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          isMobile ? 16 : 28, isMobile ? 68 : 28, isMobile ? 16 : 28, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Good morning 👋', style: TextStyle(color: kSlate, fontSize: 13)),
            const SizedBox(height: 4),
            const Text('Dashboard Overview',
                style: TextStyle(color: kText, fontSize: 26, fontWeight: FontWeight.bold)),
          ]),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: kAmber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kAmber.withOpacity(0.4)),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.data_array_rounded, color: kAmber, size: 14),
              SizedBox(width: 6),
              Text('Sample Data', style: TextStyle(color: kAmber, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
        const SizedBox(height: 28),

        LayoutBuilder(builder: (ctx, constraints) {
          final cols = constraints.maxWidth > 900 ? 4 : constraints.maxWidth > 600 ? 2 : 2;
          return GridView.count(
            crossAxisCount: cols, shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12, mainAxisSpacing: 12,
            childAspectRatio: constraints.maxWidth > 600 ? 1.5 : 1.7,
            children: [
              _DashCard(title: 'Total Users',      value: '${stats.total}',
                  icon: Icons.people_alt_rounded,             color: kAccent),
              _DashCard(title: 'Active Streaks',   value: '${stats.activeStreaks}',
                  icon: Icons.local_fire_department_rounded,  color: kRose),
              _DashCard(title: 'High Level (10+)', value: '${stats.highLevel}',
                  icon: Icons.emoji_events_rounded,           color: kAmber),
              _DashCard(title: 'Avg Rating',       value: stats.avgRating.toStringAsFixed(1),
                  icon: Icons.star_rounded,                   color: kEmerald),
            ],
          );
        }),

        const SizedBox(height: 20),

        _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SectionTitle(icon: Icons.group_rounded, title: 'Recent Users'),
          const SizedBox(height: 16),
          for (final u in recentUsers) _UserSummaryTile(user: u),
        ])),

        const SizedBox(height: 20),

        _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SectionTitle(icon: Icons.local_fire_department_rounded, title: 'Top Streaks'),
          const SizedBox(height: 14),
          for (final u in topStreaks.take(5)) _StreakTile(user: u),
        ])),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PAGE: MANAGE USERS  (READ-ONLY — no edit / delete)
// ═══════════════════════════════════════════════════════════════════
class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  String _search = '';

  // ── VIEW detail dialog ────────────────────────────────────────
  void _showUserDetail(SampleUser user) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          CircleAvatar(
            backgroundColor: kAccent.withOpacity(0.1),
            child: Text(user.name[0].toUpperCase(),
                style: const TextStyle(color: kAccent, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user.name,  style: const TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.bold)),
            Text(user.email, style: const TextStyle(color: kSlate, fontSize: 12)),
          ])),
        ]),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Divider(color: kBorder),
            const SizedBox(height: 8),
            _DetailRow('Level',       '${user.level}'),
            _DetailRow('Badge',       '${_getBadgeEmoji(user.level)} ${_getBadgeLabel(user.level)}'),
            _DetailRow('Streak',      '🔥 ${user.streak} days'),
            _DetailRow('Rating',      '⭐ ${user.rating.toStringAsFixed(1)} / 5.0'),
            _DetailRow('Joined',      user.joinedDate),
            _DetailRow('Last Active', user.lastActive),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kAmber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kAmber.withOpacity(0.25)),
              ),
              child: const Row(children: [
                Icon(Icons.lock_outline_rounded, color: kAmber, size: 14),
                SizedBox(width: 8),
                Expanded(child: Text(
                  'User profiles are read-only. Changes are managed by users.',
                  style: TextStyle(color: kAmber, fontSize: 11),
                )),
              ]),
            ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: kSlate)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final filtered  = sampleUsers.where((u) {
      final q = _search.toLowerCase();
      return q.isEmpty ||
          u.name.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q);
    }).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          isMobile ? 16 : 28, isMobile ? 68 : 28, isMobile ? 16 : 28, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header — no Add button (read-only)
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: _PageHeader(
            title: 'Manage Users',
            subtitle: '${sampleUsers.length} registered · read-only',
          )),
          // Read-only badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: kSlate.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kSlate.withOpacity(0.25)),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.lock_outline_rounded, color: kSlate, size: 14),
              SizedBox(width: 6),
              Text('Read-Only', style: TextStyle(color: kSlate, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
        const SizedBox(height: 20),

        // Search
        Container(
          decoration: BoxDecoration(
              color: kSurface, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kBorder)),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            style: const TextStyle(color: kText),
            decoration: const InputDecoration(
              hintText:    'Search by name or email…',
              hintStyle:   TextStyle(color: kSlate),
              prefixIcon:  Icon(Icons.search, color: kSlate),
              border:      InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Users table
        _Card(
          padding: EdgeInsets.zero,
          child: filtered.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('No users found.',
                      style: TextStyle(color: kSlate, fontSize: 14))),
                )
              : Column(children: [
                  // Header row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: kBorder))),
                    child: const Row(children: [
                      Expanded(flex: 3, child: _ColHeader('USER')),
                      Expanded(child: _ColHeader('LEVEL')),
                      Expanded(child: _ColHeader('STREAK')),
                      Expanded(child: _ColHeader('RATING')),
                      SizedBox(width: 40), // space for single view button
                    ]),
                  ),
                  for (int i = 0; i < filtered.length; i++) ...[
                    if (i != 0) const Divider(color: kBorder, height: 1),
                    _UserRowReadOnly(
                      user:   filtered[i],
                      onView: () => _showUserDetail(filtered[i]),
                    ),
                  ],
                ]),
        ),
      ]),
    );
  }
}

// ── Read-only user row (View only) ─────────────────────────────────
class _UserRowReadOnly extends StatelessWidget {
  final SampleUser   user;
  final VoidCallback onView;

  const _UserRowReadOnly({required this.user, required this.onView});

  @override
  Widget build(BuildContext context) {
    final badgeColor = _getBadgeColor(user.level);

    return InkWell(
      onTap: onView,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Expanded(flex: 3, child: Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: kAccent.withOpacity(0.1),
              child: Text(user.name[0].toUpperCase(),
                  style: const TextStyle(color: kAccent, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user.name,  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kText, fontWeight: FontWeight.w600, fontSize: 13)),
              Text(user.email, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kSlate, fontSize: 11)),
            ])),
          ])),
          Expanded(child: Row(children: [
            Text(_getBadgeEmoji(user.level), style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text('Lv.${user.level}',
                style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 12)),
          ])),
          Expanded(child: Row(children: [
            const Icon(Icons.local_fire_department_rounded, color: kRose, size: 14),
            const SizedBox(width: 3),
            Text('${user.streak}',
                style: const TextStyle(color: kText, fontSize: 12, fontWeight: FontWeight.w600)),
          ])),
          Expanded(child: Row(children: [
            const Icon(Icons.star_rounded, color: kAmber, size: 14),
            const SizedBox(width: 3),
            Text(user.rating.toStringAsFixed(1),
                style: const TextStyle(color: kText, fontSize: 12, fontWeight: FontWeight.w600)),
          ])),
          // View only
          _IconBtn(icon: Icons.visibility_rounded, color: kAccent, tooltip: 'View', onTap: onView),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PAGE: BADGES  (full CRUD)
// ═══════════════════════════════════════════════════════════════════
class BadgesPage extends StatefulWidget {
  final VoidCallback? onChanged;
  const BadgesPage({super.key, this.onChanged});

  @override
  State<BadgesPage> createState() => _BadgesPageState();
}

class _BadgesPageState extends State<BadgesPage> {

  @override
  void initState() {
    super.initState();
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('badges').get();
      if (!mounted) return;

      final loaded = snapshot.docs.map((doc) {
        final data = doc.data();
        final rawTasks = data['tasks'];
        final tasks = rawTasks is List
            ? rawTasks.map((task) => task.toString()).toList()
            : (data['badge_description'] ?? '')
                .toString()
                .split(' | ')
                .where((task) => task.trim().isNotEmpty)
                .toList();
        while (tasks.length < 5) {
          tasks.add('');
        }

        final rawColor = data['color'];
        final colorValue = rawColor is num ? rawColor.toInt() : kAccent.value;
        return BadgeTier(
          id: doc.id,
          emoji: (data['emoji'] ?? '🏅').toString(),
          label: (data['badge_name'] ?? 'Unnamed Badge').toString(),
          minLevel: (data['min_level'] as num?)?.toInt() ?? 0,
          color: Color(colorValue),
          tasks: tasks.take(5).toList(),
        );
      }).toList();

      setState(() {
        badgeTiers
          ..clear()
          ..addAll(loaded);
      });
      widget.onChanged?.call();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load badges: $error')),
        );
      }
    }
  }

  // Preset color swatches for the color picker
  static const _colorSwatches = [
    kEmerald,
    kAmber,
    kRose,
    kAccent,
    kIndigo,
    kSlate,
    Color(0xFFCD7F32),
    Color(0xFF0EA5E9),
    Color(0xFFB45309),
    Color(0xFF7C3AED),
    Color(0xFFDB2777),
    Color(0xFF0F766E),
  ];

  // ── CREATE / EDIT dialog ──────────────────────────────────────
  void _openBadgeForm({BadgeTier? existing}) {
    final isEdit = existing != null;

    final emojiCtrl = TextEditingController(text: existing?.emoji ?? '🏅');
    final labelCtrl = TextEditingController(text: existing?.label ?? '');
    final levelCtrl = TextEditingController(text: existing?.minLevel.toString() ?? '0');
    Color selectedColor = existing?.color ?? kAccent;

    // Exactly 5 task fields
    final existingTasks = existing?.tasks ?? <String>[];
    final taskCtrls = List<TextEditingController>.generate(
      5,
      (i) => TextEditingController(text: i < existingTasks.length ? existingTasks[i] : ''),
    );

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          backgroundColor: kSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: kAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isEdit ? Icons.edit_rounded : Icons.add_rounded,
                color: kAccent, size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Text(isEdit ? 'Edit Badge Tier' : 'New Badge Tier',
                style: const TextStyle(color: kText, fontSize: 17, fontWeight: FontWeight.bold)),
          ]),
          content: SizedBox(
            width: 380,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Divider(color: kBorder),
                  const SizedBox(height: 12),

                  // Live preview
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: selectedColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: selectedColor.withOpacity(0.4)),
                      ),
                      child: Text(
                        '${emojiCtrl.text}  ${labelCtrl.text.isEmpty ? 'Preview' : labelCtrl.text}',
                        style: TextStyle(color: selectedColor, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Emoji + Label row
                  Row(children: [
                    SizedBox(
                      width: 80,
                      child: _BadgeFormField(
                        ctrl: emojiCtrl,
                        label: 'Emoji',
                        hint: '🏅',
                        onChanged: (_) => setInner(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _BadgeFormField(
                      ctrl: labelCtrl,
                      label: 'Badge Name',
                      hint: 'e.g. Gold',
                      onChanged: (_) => setInner(() {}),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Name is required' : null,
                    )),
                  ]),

                  // Min level
                  _BadgeFormField(
                    ctrl: levelCtrl,
                    label: 'Minimum Level',
                    hint: 'e.g. 10',
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 0) return 'Enter a valid level (≥ 0)';
                      return null;
                    },
                  ),

                  // Color picker
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Badge Color',
                        style: const TextStyle(
                            color: kSlate, fontSize: 11,
                            fontWeight: FontWeight.w600, letterSpacing: 0.6)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _colorSwatches.map((c) {
                      final isSelected = selectedColor.value == c.value;
                      return GestureDetector(
                        onTap: () => setInner(() => selectedColor = c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: kText, width: 2.5)
                                : Border.all(color: Colors.transparent, width: 2),
                            boxShadow: isSelected
                                ? [BoxShadow(color: c.withOpacity(0.5), blurRadius: 6)]
                                : [],
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white, size: 16)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Tasks to reach this badge (exactly 5)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Tasks to Reach This Badge (5)',
                        style: const TextStyle(
                            color: kSlate, fontSize: 11,
                            fontWeight: FontWeight.w600, letterSpacing: 0.6)),
                  ),
                  const SizedBox(height: 8),
                  for (int i = 0; i < 5; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                        Container(
                          width: 22, height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selectedColor.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Text('${i + 1}',
                              style: TextStyle(color: selectedColor, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: taskCtrls[i],
                            style: const TextStyle(color: kText, fontSize: 13),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Task ${i + 1} is required'
                                : null,
                            decoration: InputDecoration(
                              hintText: 'Task ${i + 1}',
                              hintStyle: const TextStyle(color: kBorder),
                              isDense: true,
                              filled: true,
                              fillColor: kBg,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: kBorder)),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: kBorder)),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: kAccent, width: 1.5)),
                              errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: kRose)),
                              focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: kRose, width: 1.5)),
                            ),
                          ),
                        ),
                      ]),
                    ),
                ]),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: kSlate)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: Icon(isEdit ? Icons.save_rounded : Icons.add_rounded, size: 16),
              label: Text(isEdit ? 'Save Changes' : 'Create Badge'),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final tasks = taskCtrls.map((c) => c.text.trim()).toList();
                final badgeId = isEdit ? existing.id : 'b${_nextBadgeId()}';
                final badge = BadgeTier(
                  id:       badgeId,
                  emoji:    emojiCtrl.text.trim(),
                  label:    labelCtrl.text.trim(),
                  minLevel: int.tryParse(levelCtrl.text) ?? 0,
                  color:    selectedColor,
                  tasks:    tasks,
                );

                try {
                  final data = <String, dynamic>{
                    'badge_id':             badge.id,
                    'badge_name':           badge.label,
                    'badge_description':    badge.tasks.join(' | '),
                    'required_taskcount':   badge.tasks.length,
                    'emoji':                badge.emoji,
                    'min_level':            badge.minLevel,
                    'color':                badge.color.value,
                    'tasks':                badge.tasks,
                  };
                  if (!isEdit) {
                    data['created_at'] = FieldValue.serverTimestamp();
                  }
                  await FirebaseFirestore.instance
                      .collection('badges')
                      .doc(badge.id)
                      .set(data, SetOptions(merge: true));
                } catch (error) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not save badge: $error')),
                    );
                  }
                  return;
                }

                setState(() {
                  if (isEdit) {
                    final idx = badgeTiers.indexWhere((b) => b.id == existing.id);
                    if (idx != -1) {
                      badgeTiers[idx] = badge;
                    }
                  } else {
                    badgeTiers.add(badge);
                  }
                });
                widget.onChanged?.call();
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── VIEW tasks dialog ─────────────────────────────────────────
  void _showTasks(BadgeTier badge) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: badge.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(badge.emoji, style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('${badge.label} · Tasks',
              style: const TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.bold))),
        ]),
        content: SizedBox(
          width: 360,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Divider(color: kBorder),
            const SizedBox(height: 8),
            Text('Complete these 5 tasks to earn the ${badge.label} badge (min. level ${badge.minLevel}):',
                style: const TextStyle(color: kSlate, fontSize: 12)),
            const SizedBox(height: 12),
            for (int i = 0; i < badge.tasks.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 20, height: 20,
                    margin: const EdgeInsets.only(top: 1),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: badge.color.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Text('${i + 1}',
                        style: TextStyle(color: badge.color, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    badge.tasks[i].isEmpty ? '—' : badge.tasks[i],
                    style: const TextStyle(color: kText, fontSize: 13, height: 1.4),
                  )),
                ]),
              ),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: kSlate)),
          ),
        ],
      ),
    );
  }

  // ── DELETE confirm ────────────────────────────────────────────
  void _confirmDelete(BadgeTier badge) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: kRose, size: 22),
          SizedBox(width: 10),
          Text('Delete Badge', style: TextStyle(color: kText, fontSize: 17, fontWeight: FontWeight.bold)),
        ]),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(color: kSlate, fontSize: 14, height: 1.5),
            children: [
              const TextSpan(text: 'Delete the '),
              TextSpan(text: '${badge.emoji} ${badge.label}',
                  style: const TextStyle(color: kText, fontWeight: FontWeight.bold)),
              const TextSpan(text: ' badge tier? Users at this level will fall back to the next lower tier.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: kSlate)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: kRose,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.delete_rounded, size: 16),
            label: const Text('Delete'),
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('badges')
                    .doc(badge.id)
                    .delete();
              } catch (error) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not delete badge: $error')),
                  );
                }
                return;
              }
              setState(() => badgeTiers.removeWhere((b) => b.id == badge.id));
              widget.onChanged?.call();
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final sorted   = [...badgeTiers]..sort((a, b) => a.minLevel.compareTo(b.minLevel));

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          isMobile ? 16 : 28, isMobile ? 68 : 28, isMobile ? 16 : 28, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: _PageHeader(
            title: 'Badge Tiers',
            subtitle: '${badgeTiers.length} tiers configured',
          )),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('New Badge', style: TextStyle(fontWeight: FontWeight.w600)),
            onPressed: () => _openBadgeForm(),
          ),
        ]),
        const SizedBox(height: 8),

        // Info banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: kAccent.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kAccent.withOpacity(0.2)),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline_rounded, color: kAccent, size: 16),
            SizedBox(width: 10),
            Expanded(child: Text(
              'Badge tiers are awarded based on minimum level thresholds. Each tier lists 5 tasks '
              'a user must complete to earn it. The highest tier a user qualifies for is shown on their profile.',
              style: TextStyle(color: kAccent, fontSize: 12),
            )),
          ]),
        ),

        // Badge cards grid
        LayoutBuilder(builder: (ctx, constraints) {
          final cols = constraints.maxWidth > 700 ? 2 : 1;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount:    cols,
              crossAxisSpacing:  14,
              mainAxisSpacing:   14,
              childAspectRatio:  2.1,
            ),
            itemCount: sorted.length,
            itemBuilder: (ctx, i) => _BadgeCard(
              tier:      sorted[i],
              rank:      i + 1,
              onEdit:    () => _openBadgeForm(existing: sorted[i]),
              onDelete:  () => _confirmDelete(sorted[i]),
              onTasks:   () => _showTasks(sorted[i]),
            ),
          );
        }),

        const SizedBox(height: 20),

        // Preview: which badge each sample user holds
        _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SectionTitle(icon: Icons.people_alt_rounded, title: 'User Badge Preview'),
          const SizedBox(height: 4),
          const Text('Shows current badge assignment based on active tiers.',
              style: TextStyle(color: kSlate, fontSize: 12)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: sampleUsers.map((u) {
              final tier  = _getBadgeTierFor(u.level);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: tier.color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: tier.color.withOpacity(0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(tier.emoji, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 5),
                  Text(u.name.split(' ').first,
                      style: TextStyle(color: tier.color, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 4),
                  Text('Lv.${u.level}',
                      style: TextStyle(color: tier.color.withOpacity(0.7), fontSize: 11)),
                ]),
              );
            }).toList(),
          ),
        ])),
      ]),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final BadgeTier    tier;
  final int          rank;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTasks;
  const _BadgeCard({
    required this.tier,
    required this.rank,
    required this.onEdit,
    required this.onDelete,
    required this.onTasks,
  });

  @override
  Widget build(BuildContext context) {
    // Count how many sample users currently hold this tier
    final holders = sampleUsers.where((u) => _getBadgeTierFor(u.level).id == tier.id).length;
    final filledTasks = tier.tasks.where((t) => t.trim().isNotEmpty).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tier.color.withOpacity(0.3), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // Color dot + emoji
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: tier.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(tier.emoji, style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(tier.label,
                style: TextStyle(color: tier.color, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 2),
            Text('Min Level ${tier.minLevel}  ·  $holders user${holders == 1 ? '' : 's'}',
                style: const TextStyle(color: kSlate, fontSize: 11)),
          ])),
          // Tier rank chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: tier.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Tier $rank',
                style: TextStyle(color: tier.color, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          _IconBtn(icon: Icons.edit_rounded,   color: kEmerald, tooltip: 'Edit',   onTap: onEdit),
          const SizedBox(width: 6),
          _IconBtn(icon: Icons.delete_rounded, color: kRose,    tooltip: 'Delete', onTap: onDelete),
        ]),
        const SizedBox(height: 10),
        // Tasks summary row (tap to view full list)
        InkWell(
          onTap: onTasks,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: tier.color.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: tier.color.withOpacity(0.2)),
            ),
            child: Row(children: [
              Icon(Icons.checklist_rounded, color: tier.color, size: 15),
              const SizedBox(width: 8),
              Expanded(child: Text(
                '$filledTasks/5 tasks set to earn this badge',
                style: TextStyle(color: tier.color, fontSize: 11, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              )),
              Icon(Icons.chevron_right_rounded, color: tier.color.withOpacity(0.6), size: 16),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── Badge form field (inline) ──────────────────────────────────────
class _BadgeFormField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  const _BadgeFormField({
    required this.ctrl,
    required this.label,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: kSlate, fontSize: 11,
          fontWeight: FontWeight.w600, letterSpacing: 0.6)),
      const SizedBox(height: 4),
      TextFormField(
        controller:   ctrl,
        keyboardType: keyboardType,
        validator:    validator,
        onChanged:    onChanged,
        style: const TextStyle(color: kText, fontSize: 14),
        decoration: InputDecoration(
          hintText:        hint,
          hintStyle:       const TextStyle(color: kBorder),
          filled:          true,
          fillColor:       kBg,
          contentPadding:  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kBorder)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kBorder)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kAccent, width: 1.5)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kRose)),
          focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kRose, width: 1.5)),
        ),
      ),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════
// PAGE: LEADERBOARD
// ═══════════════════════════════════════════════════════════════════
class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final byLevel  = [...sampleUsers]..sort((a, b) => b.level.compareTo(a.level));
    final byStreak = [...sampleUsers]..sort((a, b) => b.streak.compareTo(a.streak));

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          isMobile ? 16 : 28, isMobile ? 68 : 28, isMobile ? 16 : 28, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _PageHeader(title: 'Leaderboard', subtitle: 'Top users by level & streak'),
        const SizedBox(height: 20),

        Container(
          decoration: BoxDecoration(
              color: kSurface, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kBorder)),
          child: TabBar(
            controller: _tabController,
            labelColor: kAccent,
            unselectedLabelColor: kSlate,
            indicatorColor: kAccent,
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: const [Tab(text: '🏆  By Level'), Tab(text: '🔥  By Streak')],
          ),
        ),
        const SizedBox(height: 16),

        SizedBox(
          height: 600,
          child: TabBarView(
            controller: _tabController,
            children: [
              _LeaderboardList(users: byLevel,  metric: 'level'),
              _LeaderboardList(users: byStreak, metric: 'streak'),
            ],
          ),
        ),
      ]),
    );
  }
}

class _LeaderboardList extends StatelessWidget {
  final List<SampleUser> users;
  final String           metric;
  const _LeaderboardList({required this.users, required this.metric});

  @override
  Widget build(BuildContext context) => _Card(
    padding: EdgeInsets.zero,
    child: ListView.separated(
      itemCount: users.length,
      separatorBuilder: (_, __) => const Divider(color: kBorder, height: 1),
      itemBuilder: (ctx, i) {
        final u          = users[i];
        final value      = metric == 'level' ? u.level : u.streak;
        final badgeColor = _getBadgeColor(u.level);

        Color rankColor = kSlate;
        if (i == 0) rankColor = kAmber;
        if (i == 1) rankColor = kSlate;
        if (i == 2) rankColor = const Color(0xFFCD7F32);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            SizedBox(
              width: 32,
              child: Text(
                i < 3 ? ['🥇', '🥈', '🥉'][i] : '#${i + 1}',
                style: TextStyle(
                    fontSize: i < 3 ? 18 : 13,
                    color: rankColor,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 10),
            CircleAvatar(
              radius: 18,
              backgroundColor: kAccent.withOpacity(0.1),
              child: Text(u.name[0].toUpperCase(),
                  style: const TextStyle(color: kAccent, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(u.name,  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kText, fontWeight: FontWeight.w600)),
              Text(u.email, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kSlate, fontSize: 11)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color:        badgeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border:       Border.all(color: badgeColor.withOpacity(0.4)),
              ),
              child: Text(
                '${_getBadgeEmoji(u.level)} ${_getBadgeLabel(u.level)}',
                style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 60,
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Icon(
                  metric == 'level' ? Icons.emoji_events_rounded : Icons.local_fire_department_rounded,
                  color: metric == 'level' ? kAmber : kRose, size: 15,
                ),
                const SizedBox(width: 4),
                Text('$value',
                    style: const TextStyle(color: kText, fontWeight: FontWeight.bold, fontSize: 14)),
              ]),
            ),
          ]),
        );
      },
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════
// PAGE: FEEDBACK
// ═══════════════════════════════════════════════════════════════════
class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  String _filter = 'all';

  List<SampleFeedback> get _filtered {
    return sampleFeedback.where((f) {
      if (_filter == '5') return f.rating == 5;
      if (_filter == '4') return f.rating == 4;
      if (_filter == '3') return f.rating <= 3;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    final totalRating = sampleFeedback.fold(0, (s, f) => s + f.rating);
    final avgRating   = sampleFeedback.isEmpty ? 0.0 : totalRating / sampleFeedback.length;
    final Map<int, int> dist = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final f in sampleFeedback) dist[f.rating] = (dist[f.rating] ?? 0) + 1;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          isMobile ? 16 : 28, isMobile ? 68 : 28, isMobile ? 16 : 28, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _PageHeader(title: 'Feedback & Ratings',
            subtitle: '${sampleFeedback.length} total reviews'),
        const SizedBox(height: 20),

        _Card(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [
              Text(avgRating.toStringAsFixed(1),
                  style: const TextStyle(
                      fontSize: 52, fontWeight: FontWeight.bold, color: kText)),
              Row(children: List.generate(5, (i) => Icon(
                i < avgRating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                color: kAmber, size: 18,
              ))),
              const SizedBox(height: 4),
              Text('${sampleFeedback.length} reviews',
                  style: const TextStyle(color: kSlate, fontSize: 12)),
            ]),
            const SizedBox(width: 28),
            const VerticalDivider(color: kBorder, width: 1),
            const SizedBox(width: 20),
            Expanded(child: Column(
              children: List.generate(5, (i) {
                final star  = 5 - i;
                final count = dist[star] ?? 0;
                final pct   = sampleFeedback.isEmpty
                    ? 0.0
                    : count / sampleFeedback.length;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    SizedBox(width: 24,
                        child: Text('$star',
                            style: const TextStyle(color: kSlate, fontSize: 11))),
                    const Icon(Icons.star_rounded, color: kAmber, size: 11),
                    const SizedBox(width: 6),
                    Expanded(child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct, minHeight: 8,
                        backgroundColor: kBorder, color: kAmber,
                      ),
                    )),
                    const SizedBox(width: 8),
                    SizedBox(width: 24,
                        child: Text('$count',
                            style: const TextStyle(color: kSlate, fontSize: 11))),
                  ]),
                );
              }),
            )),
          ]),
        ),

        const SizedBox(height: 16),

        Wrap(spacing: 8, runSpacing: 8, children: [
          _Chip(label: 'All',    selected: _filter == 'all', onTap: () => setState(() => _filter = 'all')),
          _Chip(label: '★★★★★', selected: _filter == '5',   onTap: () => setState(() => _filter = '5')),
          _Chip(label: '★★★★',  selected: _filter == '4',   onTap: () => setState(() => _filter = '4')),
          _Chip(label: '≤ ★★★', selected: _filter == '3',   onTap: () => setState(() => _filter = '3')),
        ]),

        const SizedBox(height: 16),

        _Card(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (int i = 0; i < _filtered.length; i++) ...[
              if (i != 0) const Divider(color: kBorder, height: 1),
              _FeedbackTile(feedback: _filtered[i]),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _FeedbackTile extends StatelessWidget {
  final SampleFeedback feedback;
  const _FeedbackTile({required this.feedback});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: kAccent.withOpacity(0.1),
          child: Text(feedback.userName[0].toUpperCase(),
              style: const TextStyle(color: kAccent, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(feedback.userName,
              style: const TextStyle(color: kText, fontWeight: FontWeight.w600, fontSize: 13)),
          Text(feedback.userEmail,
              style: const TextStyle(color: kSlate, fontSize: 11)),
        ])),
        Row(children: List.generate(5, (i) => Icon(
          i < feedback.rating ? Icons.star_rounded : Icons.star_outline_rounded,
          color: kAmber, size: 14,
        ))),
        const SizedBox(width: 8),
        Text(feedback.date, style: const TextStyle(color: kSlate, fontSize: 11)),
      ]),
      if (feedback.comment.isNotEmpty) ...[
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kBg, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kBorder),
          ),
          child: Text(feedback.comment,
              style: const TextStyle(color: kText, fontSize: 13, height: 1.5)),
        ),
      ],
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════
// PAGE: ANALYTICS
// ═══════════════════════════════════════════════════════════════════
class AnalyticsPage extends StatelessWidget {
  final _AppStats stats;
  const AnalyticsPage({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    final Map<String, int> badgeDist = {};
    for (final u in sampleUsers) {
      final label = _getBadgeLabel(u.level);
      badgeDist[label] = (badgeDist[label] ?? 0) + 1;
    }

    final avgLevel  = sampleUsers.isEmpty ? 0.0
        : sampleUsers.map((u) => u.level).reduce((a, b) => a + b) / sampleUsers.length;
    final avgStreak = sampleUsers.isEmpty ? 0.0
        : sampleUsers.map((u) => u.streak).reduce((a, b) => a + b) / sampleUsers.length;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          isMobile ? 16 : 28, isMobile ? 68 : 28, isMobile ? 16 : 28, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _PageHeader(title: 'Analytics',
            subtitle: 'Engagement & gamification insights'),
        const SizedBox(height: 20),

        LayoutBuilder(builder: (ctx, constraints) {
          final cols = constraints.maxWidth > 700 ? 2 : 1;
          return GridView.count(
            crossAxisCount: cols, shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 2.4,
            children: [
              _KpiCard(title: 'Avg Level',   value: avgLevel.toStringAsFixed(1),
                  icon: Icons.emoji_events_rounded,          color: kAmber),
              _KpiCard(title: 'Avg Streak',  value: avgStreak.toStringAsFixed(1),
                  icon: Icons.local_fire_department_rounded, color: kRose),
              _KpiCard(title: 'Engagement Rate',
                  value: stats.total == 0 ? '0%'
                      : '${((stats.activeStreaks / stats.total) * 100).toStringAsFixed(1)}%',
                  icon: Icons.trending_up_rounded, color: kAccent),
              _KpiCard(title: 'Avg Rating',
                  value: '${stats.avgRating.toStringAsFixed(1)} ★',
                  icon: Icons.star_rounded, color: kEmerald),
            ],
          );
        }),

        const SizedBox(height: 20),

        _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SectionTitle(icon: Icons.pie_chart_rounded, title: 'Badge Distribution'),
          const SizedBox(height: 16),
          for (final entry in badgeDist.entries) ...[
            _ProgressBar(
              label: '${_getBadgeEmoji(entry.value * 5)} ${entry.key}',
              count: entry.value,
              total: stats.total,
              color: kAccent,
            ),
            const SizedBox(height: 10),
          ],
        ])),

        const SizedBox(height: 20),

        _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SectionTitle(icon: Icons.table_chart_rounded, title: 'Summary'),
          const SizedBox(height: 16),
          _SummaryRow(label: 'Total Users',     value: '${stats.total}'),
          _SummaryRow(label: 'Active Streaks',  value: '${stats.activeStreaks}'),
          _SummaryRow(label: 'High Level (10+)', value: '${stats.highLevel}'),
          _SummaryRow(label: 'Total Feedback',  value: '${stats.totalFeedback}'),
          _SummaryRow(label: 'Average Rating',
              value: '${stats.avgRating.toStringAsFixed(2)} / 5.0', highlight: true),
        ])),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────
class _PageHeader extends StatelessWidget {
  final String title, subtitle;
  const _PageHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title,    style: const TextStyle(color: kText, fontSize: 26, fontWeight: FontWeight.bold)),
    const SizedBox(height: 2),
    Text(subtitle, style: const TextStyle(color: kSlate, fontSize: 13)),
  ]);
}

class _Card extends StatelessWidget {
  final Widget     child;
  final EdgeInsets padding;
  const _Card({required this.child, this.padding = const EdgeInsets.all(20)});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: padding,
    decoration: BoxDecoration(
      color: kSurface, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: kBorder),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: child,
  );
}

class _DashCard extends StatelessWidget {
  final String title, value; final IconData icon; final Color color;
  const _DashCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => _Card(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20),
        ),
        Icon(Icons.arrow_forward_ios_rounded, color: kBorder, size: 12),
      ]),
      const Spacer(),
      Text(value,
          style: const TextStyle(color: kText, fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text(title,
          style: const TextStyle(color: kSlate, fontSize: 11), overflow: TextOverflow.ellipsis),
    ]),
  );
}

class _KpiCard extends StatelessWidget {
  final String title, value; final IconData icon; final Color color;
  const _KpiCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => _Card(
    child: Row(children: [
      Container(
        width: 48, height: 48,
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
        child: Icon(icon, color: color, size: 24),
      ),
      const SizedBox(width: 16),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: kSlate, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
      ]),
    ]),
  );
}

class _SectionTitle extends StatelessWidget {
  final IconData icon; final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: kAccent, size: 18),
    const SizedBox(width: 8),
    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kText)),
  ]);
}

class _ColHeader extends StatelessWidget {
  final String text;
  const _ColHeader(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(color: kSlate, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8));
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  const _DetailRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(children: [
      SizedBox(width: 100, child: Text(label, style: const TextStyle(color: kSlate, fontSize: 13))),
      Expanded(child: Text(value,
          style: const TextStyle(color: kText, fontSize: 13, fontWeight: FontWeight.w600))),
    ]),
  );
}

class _SummaryRow extends StatelessWidget {
  final String label, value; final bool highlight;
  const _SummaryRow({required this.label, required this.value, this.highlight = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(
        color: highlight ? kText : kSlate,
        fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
      ))),
      Text(value, style: TextStyle(
        color:      highlight ? kAccent : kText,
        fontWeight: FontWeight.bold,
        fontSize:   highlight ? 16 : 14,
      )),
    ]),
  );
}

class _ProgressBar extends StatelessWidget {
  final String label; final int count, total; final Color color;
  const _ProgressBar({required this.label, required this.count, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : count / total;
    return Row(children: [
      SizedBox(width: 110, child: Text(label, style: const TextStyle(color: kText, fontSize: 12))),
      const SizedBox(width: 8),
      Expanded(child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(value: pct, minHeight: 10, backgroundColor: kBorder, color: color),
      )),
      const SizedBox(width: 10),
      Text('$count', style: const TextStyle(color: kSlate, fontSize: 12, fontWeight: FontWeight.bold)),
    ]);
  }
}

class _Chip extends StatelessWidget {
  final String label; final bool selected; final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? kAccent : kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? kAccent : kBorder),
      ),
      child: Text(label, style: TextStyle(
        color:      selected ? Colors.white : kSlate,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        fontSize:   13,
      )),
    ),
  );
}

class _IconBtn extends StatelessWidget {
  final IconData icon; final Color color; final String tooltip; final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.color, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 16),
      ),
    ),
  );
}

class _UserSummaryTile extends StatelessWidget {
  final SampleUser user;
  const _UserSummaryTile({required this.user});

  @override
  Widget build(BuildContext context) {
    final badgeColor = _getBadgeColor(user.level);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: kAccent.withOpacity(0.1),
          child: Text(user.name[0].toUpperCase(),
              style: const TextStyle(color: kAccent, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(user.name,  style: const TextStyle(color: kText, fontWeight: FontWeight.w600, fontSize: 13)),
          Text(user.email, style: const TextStyle(color: kSlate, fontSize: 11)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: badgeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20),
            border: Border.all(color: badgeColor.withOpacity(0.3)),
          ),
          child: Text('${_getBadgeEmoji(user.level)} Lv.${user.level}',
              style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 8),
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.local_fire_department_rounded, color: kRose, size: 13),
          const SizedBox(width: 2),
          Text('${user.streak}', style: const TextStyle(color: kSlate, fontSize: 12)),
        ]),
      ]),
    );
  }
}

class _StreakTile extends StatelessWidget {
  final SampleUser user;
  const _StreakTile({required this.user});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      CircleAvatar(
        radius: 16,
        backgroundColor: kRose.withOpacity(0.1),
        child: Text(user.name[0].toUpperCase(),
            style: const TextStyle(color: kRose, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
      const SizedBox(width: 12),
      Expanded(child: Text(user.name,
          style: const TextStyle(color: kText, fontWeight: FontWeight.w600))),
      Row(children: [
        const Icon(Icons.local_fire_department_rounded, color: kRose, size: 16),
        const SizedBox(width: 4),
        Text('${user.streak} days',
            style: const TextStyle(color: kRose, fontWeight: FontWeight.bold)),
      ]),
    ]),
  );
}
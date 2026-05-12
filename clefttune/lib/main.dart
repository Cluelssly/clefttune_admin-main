// ═══════════════════════════════════════════════════════════════════
// CLEFTTUNE ADMIN — main.dart
//
// FIRESTORE FIELD CONTRACT (synced with CleftTune user app):
//
//   users/{uid}
//     • subscription  String   "premium" | "free"   ← read by admin
//     • plan          String   "premium" | "free"   ← read by CleftTune SettingsScreen
//     • isPremium     bool     true | false         ← read by CleftTune PremiumGate
//     • email         String
//     • name          String
//     • createdAt     Timestamp
//     • paymentMethod String   "gcash" | "maya"
//     • upgradedAt    Timestamp
//     • cancelledAt   Timestamp
//
//   payments/{docId}
//     • userId          String    Firestore UID
//     • method          String    "gcash" | "maya"
//     • referenceNumber String
//     • amount          Number    99
//     • status          String    "pending" | "verified" | "rejected"
//     • createdAt       Timestamp
//     • verifiedAt      Timestamp
//     • rejectedAt      Timestamp
//     • rejectionReason String
//     • notes           String
//
// When admin VERIFIES a payment, ALL three user fields are written:
//   subscription = "premium", plan = "premium", isPremium = true
// When admin REJECTS or manually sets FREE:
//   subscription = "free",    plan = "free",    isPremium = false
// ═══════════════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => const CleftTuneAdminApp();
}

// ─────────────────────────────────────────────
// THEME CONSTANTS
// ─────────────────────────────────────────────
const kBg           = Color(0xFF020C12);
const kPanel        = Color(0xFF0B2E39);
const kSidebar      = Color(0xFF081920);
const kAccent       = Color(0xFF00E6C3);
const kPurple       = Color(0xFF9B6DFF);
const kBlue         = Color(0xFF2D9CFF);
const kGold         = Color(0xFFFFB800);
const kRed          = Color(0xFFFF4D6A);
const kGreen        = Color(0xFF00E096);
const kPremiumPrice = 99;

// ─────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────
bool _isPremium(Map<String, dynamic> data) {
  final sub  = (data['subscription'] ?? '').toString().toLowerCase().trim();
  final plan = (data['plan']         ?? '').toString().toLowerCase().trim();
  final flag =  data['isPremium'] == true;
  return sub == 'premium' || plan == 'premium' || flag;
}

Map<String, dynamic> _premiumFields() => {
  'subscription': 'premium',
  'plan':         'premium',
  'isPremium':    true,
};

Map<String, dynamic> _freeFields() => {
  'subscription': 'free',
  'plan':         'free',
  'isPremium':    false,
};

String _formatDate(dynamic ts) {
  if (ts == null) return '—';
  try {
    final dt = (ts as Timestamp).toDate();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
           '${dt.day.toString().padLeft(2, '0')} '
           '${dt.hour.toString().padLeft(2, '0')}:'
           '${dt.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return '—';
  }
}

// ─────────────────────────────────────────────
// PAYMENT STATUS
// ─────────────────────────────────────────────
enum PaymentStatus { pending, verified, rejected }

PaymentStatus _parseStatus(String? s) {
  switch ((s ?? '').toLowerCase().trim()) {
    case 'verified': return PaymentStatus.verified;
    case 'rejected': return PaymentStatus.rejected;
    default:         return PaymentStatus.pending;
  }
}

// ─────────────────────────────────────────────
// APP
// ─────────────────────────────────────────────
class CleftTuneAdminApp extends StatelessWidget {
  const CleftTuneAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CleftTune Admin',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBg,
        fontFamily: 'Arial',
        colorScheme: ColorScheme.fromSeed(
          seedColor: kAccent,
          brightness: Brightness.dark,
        ),
      ),
      home: const AdminShell(),
    );
  }
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _navItems = [
    _NavItem(Icons.dashboard_rounded,         'Dashboard'),
    _NavItem(Icons.people_alt_rounded,        'Users'),
    _NavItem(Icons.workspace_premium_rounded, 'Premium'),
    _NavItem(Icons.payment_rounded,           'Payments'),
    _NavItem(Icons.analytics_rounded,         'Analytics'),
  ];

  @override
  Widget build(BuildContext context) {
    final w        = MediaQuery.of(context).size.width;
    final isMobile = w < 800;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, usersSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('payments').snapshots(),
          builder: (context, paymentsSnap) {
            final userDocs    = usersSnap.data?.docs    ?? [];
            final paymentDocs = paymentsSnap.data?.docs ?? [];
            final stats       = _AppStats.from(userDocs, paymentDocs);

            final pages = [
              DashboardPage(stats: stats, docs: userDocs),
              UsersPage(docs: userDocs),
              PremiumPage(stats: stats, docs: userDocs),
              PaymentsPage(paymentDocs: paymentDocs, userDocs: userDocs),
              AnalyticsPage(stats: stats, docs: userDocs, paymentDocs: paymentDocs),
            ];

            final isLoading = usersSnap.connectionState    == ConnectionState.waiting
                           || paymentsSnap.connectionState == ConnectionState.waiting;
            final hasError  = usersSnap.hasError || paymentsSnap.hasError;

            final pendingCount = paymentDocs
                .where((d) => _parseStatus(d.data()['status']) == PaymentStatus.pending)
                .length;

            // ── Drawer content shared by both mobile drawer and desktop sidebar
            final sidebarContent = _SidebarContent(
              selectedIndex:   _selectedIndex,
              navItems:        _navItems,
              pendingPayments: pendingCount,
              onSelect: (i) {
                setState(() => _selectedIndex = i);
                if (isMobile) Navigator.pop(context);
              },
            );

            return Scaffold(
              key: _scaffoldKey,
              backgroundColor: kBg,
              // ── Mobile drawer ──────────────────────────────────────────────
              drawer: isMobile
                  ? Drawer(
                      backgroundColor: kSidebar,
                      child: SafeArea(child: sidebarContent),
                    )
                  : null,
              body: SafeArea(
                child: Stack(
                  children: [
                    Row(
                      children: [
                        // ── Desktop sidebar ──────────────────────────────────
                        if (!isMobile) sidebarContent,
                        Expanded(
                          child: hasError
                              ? _ErrorView(error: (usersSnap.error ?? paymentsSnap.error).toString())
                              : isLoading
                                  ? const _LoadingView()
                                  : pages[_selectedIndex],
                        ),
                      ],
                    ),

                    // ── Mobile hamburger FAB (always on top) ─────────────────
                    if (isMobile)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: _HamburgerButton(
                          pendingCount: pendingCount,
                          onTap: () => _scaffoldKey.currentState?.openDrawer(),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// HAMBURGER BUTTON WIDGET
// ─────────────────────────────────────────────
class _HamburgerButton extends StatelessWidget {
  final int pendingCount;
  final VoidCallback onTap;

  const _HamburgerButton({required this.pendingCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: kPanel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kAccent.withOpacity(0.35)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Hamburger icon — three lines
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _HamburgerLine(width: 18),
                const SizedBox(height: 4),
                _HamburgerLine(width: 14),
                const SizedBox(height: 4),
                _HamburgerLine(width: 18),
              ],
            ),
            // Badge for pending payments
            if (pendingCount > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: kGold,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      pendingCount > 9 ? '9+' : '$pendingCount',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HamburgerLine extends StatelessWidget {
  final double width;
  const _HamburgerLine({required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 2,
      decoration: BoxDecoration(
        color: kAccent,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// STATS MODEL
// ─────────────────────────────────────────────
class _AppStats {
  final int total, free, premium;
  final int verifiedRevenue, pendingRevenue, totalPayments;
  final int pendingCount, verifiedCount, rejectedCount;

  _AppStats({
    required this.total,
    required this.free,
    required this.premium,
    required this.verifiedRevenue,
    required this.pendingRevenue,
    required this.totalPayments,
    required this.pendingCount,
    required this.verifiedCount,
    required this.rejectedCount,
  });

  factory _AppStats.from(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> userDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> paymentDocs,
  ) {
    final total   = userDocs.length;
    final premium = userDocs.where((d) => _isPremium(d.data())).length;
    final free    = total - premium;

    int verifiedRevenue = 0, pendingRevenue = 0;
    int pendingCount = 0, verifiedCount = 0, rejectedCount = 0;

    for (final p in paymentDocs) {
      final data   = p.data();
      final amount = (data['amount'] ?? kPremiumPrice) as num;
      switch (_parseStatus(data['status'])) {
        case PaymentStatus.verified:
          verifiedRevenue += amount.toInt();
          verifiedCount++;
          break;
        case PaymentStatus.pending:
          pendingRevenue += amount.toInt();
          pendingCount++;
          break;
        case PaymentStatus.rejected:
          rejectedCount++;
          break;
      }
    }

    return _AppStats(
      total: total, free: free, premium: premium,
      verifiedRevenue: verifiedRevenue, pendingRevenue: pendingRevenue,
      totalPayments: paymentDocs.length,
      pendingCount: pendingCount, verifiedCount: verifiedCount, rejectedCount: rejectedCount,
    );
  }

  int    get income         => verifiedRevenue;
  double get freePercent    => total == 0 ? 0 : free    / total;
  double get premiumPercent => total == 0 ? 0 : premium / total;
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
  final int              selectedIndex;
  final List<_NavItem>   navItems;
  final ValueChanged<int> onSelect;
  final int              pendingPayments;

  const _SidebarContent({
    required this.selectedIndex,
    required this.navItems,
    required this.onSelect,
    this.pendingPayments = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: kSidebar,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Text('CleftTune',
                style: TextStyle(color: kAccent, fontSize: 26,
                    fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Text('Admin Panel',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
          ),
          const SizedBox(height: 36),
          for (int i = 0; i < navItems.length; i++) ...[
            _SidebarTile(
              icon:     navItems[i].icon,
              label:    navItems[i].label,
              selected: selectedIndex == i,
              badge:    (i == 3 && pendingPayments > 0) ? pendingPayments : null,
              onTap:    () => onSelect(i),
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final bool         selected;
  final VoidCallback onTap;
  final int?         badge;

  const _SidebarTile({
    required this.icon, required this.label,
    required this.selected, required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? kAccent.withOpacity(0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: selected ? kAccent : Colors.white38, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                      color:      selected ? kAccent : Colors.white60,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    )),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: kGold, borderRadius: BorderRadius.circular(20)),
                  child: Text('$badge',
                      style: const TextStyle(color: Colors.black,
                          fontSize: 11, fontWeight: FontWeight.bold)),
                )
              else if (selected)
                Container(width: 4, height: 4,
                    decoration: const BoxDecoration(color: kAccent, shape: BoxShape.circle)),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PAGE: PAYMENTS
// ═══════════════════════════════════════════════════════════════════
class PaymentsPage extends StatefulWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> paymentDocs;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> userDocs;

  const PaymentsPage({super.key, required this.paymentDocs, required this.userDocs});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  String _filter = 'all';

  Map<String, dynamic>? _userDataFor(String? userId) {
    if (userId == null) return null;
    try {
      return widget.userDocs.firstWhere((d) => d.id == userId).data();
    } catch (_) {
      return null;
    }
  }

  Future<void> _verifyPayment(String paymentId, String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kPanel,
        title: const Text('Verify Payment', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Confirm this payment?\n\nThis will upgrade the user to Premium across the entire app.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kGreen),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Verify', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final batch = FirebaseFirestore.instance.batch();
    batch.update(
      FirebaseFirestore.instance.collection('payments').doc(paymentId),
      {'status': 'verified', 'verifiedAt': FieldValue.serverTimestamp()},
    );
    if (userId.isNotEmpty) {
      batch.update(
        FirebaseFirestore.instance.collection('users').doc(userId),
        {
          ..._premiumFields(),
          'upgradedAt': FieldValue.serverTimestamp(),
        },
      );
    }
    await batch.commit();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Payment verified & user upgraded to Premium.'),
        backgroundColor: kGreen,
      ));
    }
  }

  Future<void> _rejectPayment(String paymentId) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kPanel,
        title: const Text('Reject Payment', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Reason for rejection (optional):',
                style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. Invalid reference number',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true, fillColor: kBg,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: kRed.withOpacity(0.4))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: kRed.withOpacity(0.3))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: kRed)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await FirebaseFirestore.instance.collection('payments').doc(paymentId).update({
      'status':          'rejected',
      'rejectedAt':      FieldValue.serverTimestamp(),
      'rejectionReason': reasonController.text.trim(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Payment rejected.'), backgroundColor: kRed,
      ));
    }
  }

  Future<void> _showPaymentDetail(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final data     = doc.data();
    final userData = _userDataFor(data['userId']);
    final status   = _parseStatus(data['status']);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kPanel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.receipt_long_rounded, color: kAccent, size: 20),
          const SizedBox(width: 8),
          const Text('Payment Details', style: TextStyle(color: Colors.white)),
        ]),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow('User',      userData?['name']  ?? data['userId'] ?? '—'),
              _DetailRow('Email',     userData?['email'] ?? '—'),
              _DetailRow('Method',   (data['method'] ?? '—').toString().toUpperCase()),
              _DetailRow('Ref #',     data['referenceNumber'] ?? '—'),
              _DetailRow('Amount',   '₱${data['amount'] ?? kPremiumPrice}'),
              _DetailRow('Submitted', _formatDate(data['createdAt'])),
              if (data['verifiedAt'] != null)
                _DetailRow('Verified', _formatDate(data['verifiedAt'])),
              if (data['rejectedAt'] != null)
                _DetailRow('Rejected', _formatDate(data['rejectedAt'])),
              if ((data['rejectionReason'] ?? '').toString().isNotEmpty)
                _DetailRow('Reason',   data['rejectionReason']),
              if ((data['notes'] ?? '').toString().isNotEmpty)
                _DetailRow('Notes',    data['notes']),
              const SizedBox(height: 8),
              _StatusBadgeLarge(status),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white54)),
          ),
          if (status == PaymentStatus.pending) ...[
            ElevatedButton.icon(
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text('Reject'),
              style: ElevatedButton.styleFrom(backgroundColor: kRed),
              onPressed: () { Navigator.pop(context); _rejectPayment(doc.id); },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Verify', style: TextStyle(color: Colors.black)),
              style: ElevatedButton.styleFrom(backgroundColor: kGreen),
              onPressed: () {
                Navigator.pop(context);
                _verifyPayment(doc.id, data['userId'] ?? '');
              },
            ),
          ],
        ],
      ),
    );
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> get _filtered {
    return widget.paymentDocs.where((doc) {
      final status = _parseStatus(doc.data()['status']);
      if (_filter == 'pending')  return status == PaymentStatus.pending;
      if (_filter == 'verified') return status == PaymentStatus.verified;
      if (_filter == 'rejected') return status == PaymentStatus.rejected;
      return true;
    }).toList()
      ..sort((a, b) {
        final aTime = a.data()['createdAt'];
        final bTime = b.data()['createdAt'];
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return (bTime as Timestamp).compareTo(aTime as Timestamp);
      });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final pending  = widget.paymentDocs.where((d) => _parseStatus(d.data()['status']) == PaymentStatus.pending).length;
    final verified = widget.paymentDocs.where((d) => _parseStatus(d.data()['status']) == PaymentStatus.verified).length;
    final rejected = widget.paymentDocs.where((d) => _parseStatus(d.data()['status']) == PaymentStatus.rejected).length;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, isMobile ? 68 : 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageTitle(
            icon:     Icons.payment_rounded,
            title:    'Payments',
            subtitle: '${widget.paymentDocs.length} total payments',
          ),
          const SizedBox(height: 20),

          LayoutBuilder(builder: (ctx, constraints) {
            final cols = constraints.maxWidth > 700 ? 4 : 2;
            return GridView.count(
              crossAxisCount: cols, shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.4,
              children: [
                _StatCard(title: 'Total',    value: '${widget.paymentDocs.length}',
                    icon: Icons.receipt_rounded,          subtitle: 'All payments',    iconColor: kBlue),
                _StatCard(title: 'Pending',  value: '$pending',
                    icon: Icons.hourglass_empty_rounded,  subtitle: 'Awaiting review', iconColor: kGold),
                _StatCard(title: 'Verified', value: '$verified',
                    icon: Icons.check_circle_rounded,     subtitle: 'Approved',        iconColor: kGreen),
                _StatCard(title: 'Rejected', value: '$rejected',
                    icon: Icons.cancel_rounded,           subtitle: 'Declined',        iconColor: kRed),
              ],
            );
          }),

          const SizedBox(height: 20),

          Wrap(spacing: 8, runSpacing: 8, children: [
            _FilterChip(label: 'All',      selected: _filter == 'all',
                onTap: () => setState(() => _filter = 'all')),
            _FilterChip(label: 'Pending',  selected: _filter == 'pending',  color: kGold,
                onTap: () => setState(() => _filter = 'pending')),
            _FilterChip(label: 'Verified', selected: _filter == 'verified', color: kGreen,
                onTap: () => setState(() => _filter = 'verified')),
            _FilterChip(label: 'Rejected', selected: _filter == 'rejected', color: kRed,
                onTap: () => setState(() => _filter = 'rejected')),
          ]),

          const SizedBox(height: 16),

          if (_filtered.isEmpty)
            _GlassPanel(
              child: Center(child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  _filter == 'all' ? 'No payments yet.' : 'No $_filter payments.',
                  style: const TextStyle(color: Colors.white60),
                ),
              )),
            )
          else
            _GlassPanel(
              padding: EdgeInsets.zero,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(children: const [
                    Expanded(flex: 3, child: Text('USER',
                        style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
                    Expanded(flex: 2, child: Text('METHOD / REF',
                        style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
                    Expanded(child: Text('AMOUNT',
                        style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
                    Expanded(child: Text('STATUS',
                        style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
                    SizedBox(width: 80),
                  ]),
                ),
                Divider(color: Colors.white.withOpacity(0.06), height: 1),
                for (int i = 0; i < _filtered.length; i++) ...[
                  if (i != 0) Divider(color: Colors.white.withOpacity(0.04), height: 1),
                  _PaymentRow(
                    doc:      _filtered[i],
                    userData: _userDataFor(_filtered[i].data()['userId']),
                    onTap:    () => _showPaymentDetail(_filtered[i]),
                    onVerify: () => _verifyPayment(_filtered[i].id, _filtered[i].data()['userId'] ?? ''),
                    onReject: () => _rejectPayment(_filtered[i].id),
                  ),
                ],
              ]),
            ),

          const SizedBox(height: 24),

          _GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle(icon: Icons.info_outline_rounded,
                    title: 'Firestore Field Contract'),
                const SizedBox(height: 8),
                const Text(
                  'Admin writes these fields on verify/reject so both apps stay in sync:',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 14),
                _FieldGuideRow('subscription', 'String',    '"premium" | "free"  — read by admin'),
                _FieldGuideRow('plan',         'String',    '"premium" | "free"  — read by CleftTune SettingsScreen'),
                _FieldGuideRow('isPremium',    'bool',      'true | false        — read by CleftTune PremiumGate'),
                _FieldGuideRow('upgradedAt',   'Timestamp', 'set on verify'),
                _FieldGuideRow('cancelledAt',  'Timestamp', 'set on cancel'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PAYMENT ROW WIDGET
// ─────────────────────────────────────────────
class _PaymentRow extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final Map<String, dynamic>? userData;
  final VoidCallback onTap, onVerify, onReject;

  const _PaymentRow({
    required this.doc, required this.userData,
    required this.onTap, required this.onVerify, required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final data   = doc.data();
    final name   = userData?['name']  ?? data['userId'] ?? 'Unknown';
    final email  = userData?['email'] ?? '';
    final method = (data['method'] ?? '—').toString().toUpperCase();
    final ref    = data['referenceNumber'] ?? '—';
    final amount = data['amount'] ?? kPremiumPrice;
    final status = _parseStatus(data['status']);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Expanded(flex: 3, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
              if (email.isNotEmpty)
                Text(email, style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          )),
          Expanded(flex: 2, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: kBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: kBlue.withOpacity(0.4)),
                ),
                child: Text(method, style: const TextStyle(color: kBlue, fontSize: 10)),
              ),
              const SizedBox(height: 2),
              Text(ref, style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ],
          )),
          Expanded(child: Text('₱$amount',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          Expanded(child: _StatusBadge(status)),
          SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (status == PaymentStatus.pending) ...[
                  IconButton(
                    icon: const Icon(Icons.check_rounded, size: 18), color: kGreen,
                    tooltip: 'Verify', onPressed: onVerify,
                    padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18), color: kRed,
                    tooltip: 'Reject', onPressed: onReject,
                    padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                  ),
                ] else
                  IconButton(
                    icon: const Icon(Icons.visibility_rounded, size: 18), color: Colors.white38,
                    tooltip: 'View details', onPressed: onTap,
                    padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final PaymentStatus status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    Color color; String label; IconData icon;
    switch (status) {
      case PaymentStatus.verified:
        color = kGreen; label = 'Verified'; icon = Icons.check_circle_rounded; break;
      case PaymentStatus.rejected:
        color = kRed;   label = 'Rejected'; icon = Icons.cancel_rounded; break;
      default:
        color = kGold;  label = 'Pending';  icon = Icons.hourglass_empty_rounded;
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    ]);
  }
}

class _StatusBadgeLarge extends StatelessWidget {
  final PaymentStatus status;
  const _StatusBadgeLarge(this.status);

  @override
  Widget build(BuildContext context) {
    Color color; String label;
    switch (status) {
      case PaymentStatus.verified: color = kGreen; label = '✅ Verified'; break;
      case PaymentStatus.rejected: color = kRed;   label = '❌ Rejected'; break;
      default:                     color = kGold;  label = '⏳ Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 130,
            child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13))),
        Expanded(child: Text(value,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}

class _FieldGuideRow extends StatelessWidget {
  final String field, type, description;
  const _FieldGuideRow(this.field, this.type, this.description);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: kAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: kAccent.withOpacity(0.3)),
          ),
          child: Text(field, style: const TextStyle(color: kAccent, fontSize: 12)),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: kPurple.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
          child: Text(type, style: const TextStyle(color: kPurple, fontSize: 11)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(description,
            style: const TextStyle(color: Colors.white54, fontSize: 12))),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PAGE: DASHBOARD
// ═══════════════════════════════════════════════════════════════════
class DashboardPage extends StatelessWidget {
  final _AppStats stats;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  const DashboardPage({super.key, required this.stats, required this.docs});

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortedByRecent() {
    final sorted = [...docs];
    sorted.sort((a, b) {
      final aTime = a.data()['createdAt'];
      final bTime = b.data()['createdAt'];
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return (bTime as Timestamp).compareTo(aTime as Timestamp);
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final w           = MediaQuery.of(context).size.width;
    final isMobile    = w < 800;
    final recentUsers = _sortedByRecent().take(5).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 12 : 24,
        isMobile ? 68 : 20,   // extra top padding on mobile for hamburger button
        isMobile ? 12 : 24,
        20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DashboardHeader(),
          const SizedBox(height: 24),

          LayoutBuilder(builder: (context, constraints) {
            int cols = 1;
            if (constraints.maxWidth > 1200) cols = 4;
            else if (constraints.maxWidth > 700) cols = 2;
            return GridView.count(
              crossAxisCount: cols, shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.25,
              children: [
                _StatCard(title: 'Total Users',      value: '${stats.total}',
                    icon: Icons.people_alt_rounded,
                    subtitle: 'All registered users',              iconColor: kAccent),
                _StatCard(title: 'Free Users',       value: '${stats.free}',
                    icon: Icons.star_rounded,
                    subtitle: '${(stats.freePercent * 100).toStringAsFixed(1)}%',    iconColor: kPurple),
                _StatCard(title: 'Premium Users',    value: '${stats.premium}',
                    icon: Icons.diamond_rounded,
                    subtitle: '${(stats.premiumPercent * 100).toStringAsFixed(1)}%', iconColor: kBlue),
                _StatCard(title: 'Verified Revenue', value: '₱${stats.verifiedRevenue}',
                    icon: Icons.account_balance_wallet_rounded,
                    subtitle: '₱${stats.pendingRevenue} pending',  iconColor: kAccent),
              ],
            );
          }),

          const SizedBox(height: 18),

          _GlassPanel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _SectionTitle(icon: Icons.payment_rounded, title: 'Payment Overview'),
              const SizedBox(height: 16),
              Row(children: [
                _MiniStat('Total',    '${stats.totalPayments}', Colors.white70),
                _MiniStat('Pending',  '${stats.pendingCount}',  kGold),
                _MiniStat('Verified', '${stats.verifiedCount}', kGreen),
                _MiniStat('Rejected', '${stats.rejectedCount}', kRed),
              ]),
            ]),
          ),

          const SizedBox(height: 18),

          _GlassPanel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _SectionTitle(icon: Icons.pie_chart_rounded, title: 'Subscription Overview'),
              const SizedBox(height: 18),
              _ProgressRow(label: 'Free Users',    count: stats.free,    percent: stats.freePercent,    color: kPurple),
              const SizedBox(height: 18),
              _ProgressRow(label: 'Premium Users', count: stats.premium, percent: stats.premiumPercent, color: kAccent),
            ]),
          ),

          const SizedBox(height: 18),

          _GlassPanel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _SectionTitle(icon: Icons.analytics_rounded, title: 'Income Overview'),
              const SizedBox(height: 14),
              Text('₱${stats.verifiedRevenue}',
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 4),
              Text('₱${stats.pendingRevenue} pending verification',
                  style: const TextStyle(color: kGold, fontSize: 13)),
              const SizedBox(height: 8),
              const Text('Based on verified payments in Firestore',
                  style: TextStyle(color: Colors.white60)),
              const SizedBox(height: 20),
              SizedBox(height: 100, width: double.infinity,
                  child: CustomPaint(painter: _LineChartPainter(premiumCount: stats.premium))),
            ]),
          ),

          const SizedBox(height: 18),

          _GlassPanel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _SectionTitle(icon: Icons.group_rounded, title: 'Recent Users'),
              const SizedBox(height: 12),
              if (recentUsers.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No users found.', style: TextStyle(color: Colors.white60))),
              for (final user in recentUsers)
                _UserTile(
                  name:  user.data()['name']  ?? 'No name',
                  email: user.data()['email'] ?? 'No email',
                  plan:  _isPremium(user.data()) ? 'premium' : 'free',
                  color: _isPremium(user.data()) ? kAccent : kPurple,
                ),
            ]),
          ),

          const SizedBox(height: 24),
          const Center(child: Text('© 2026 CleftTune Admin',
              style: TextStyle(color: Colors.white38))),
        ],
      ),
    );
  }
}

/// Dashboard header — no hamburger here; the hamburger is rendered
/// by AdminShell as a Stack overlay so it appears on every page.
class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader();

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(height: 50, width: 50,
          decoration: BoxDecoration(color: kAccent.withOpacity(0.15), shape: BoxShape.circle),
          child: const Icon(Icons.admin_panel_settings_rounded, color: kAccent)),
      const SizedBox(width: 14),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('CleftTune Admin',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 2),
        Text('Realtime database overview', style: TextStyle(color: Colors.white60)),
      ])),
      IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
    ]);
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  final Color  color;
  const _MiniStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Column(children: [
      Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
    ]));
  }
}

// ═══════════════════════════════════════════════════════════════════
// PAGE: USERS
// ═══════════════════════════════════════════════════════════════════
class UsersPage extends StatefulWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  const UsersPage({super.key, required this.docs});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  String _search = '';
  String _filter = 'all';

  Future<void> _deleteUser(String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kPanel,
        title:   const Text('Delete User',    style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete this user? This cannot be undone.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await FirebaseFirestore.instance.collection('users').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('User deleted.'), backgroundColor: Colors.redAccent));
      }
    }
  }

  Future<void> _editSubscription(String docId, String currentPlan) async {
    String newPlan = currentPlan;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kPanel,
        title: const Text('Edit Subscription', style: TextStyle(color: Colors.white)),
        content: StatefulBuilder(
          builder: (context, setInner) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PlanOption(label: 'Free',    selected: newPlan == 'free',    color: kPurple,
                  onTap: () => setInner(() => newPlan = 'free')),
              const SizedBox(height: 12),
              _PlanOption(label: 'Premium', selected: newPlan == 'premium', color: kAccent,
                  onTap: () => setInner(() => newPlan = 'premium')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kAccent),
            onPressed: () async {
              final fields = newPlan == 'premium' ? _premiumFields() : _freeFields();
              await FirebaseFirestore.instance.collection('users').doc(docId).update(fields);
              if (mounted) Navigator.pop(context);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Subscription updated to $newPlan.'),
                  backgroundColor: kAccent.withOpacity(0.8),
                ));
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final filtered = widget.docs.where((doc) {
      final data    = doc.data();
      final name    = (data['name']  ?? '').toString().toLowerCase();
      final email   = (data['email'] ?? '').toString().toLowerCase();
      final isPrem  = _isPremium(data);
      final matchSearch = _search.isEmpty || name.contains(_search) || email.contains(_search);
      final matchFilter = _filter == 'all'
          || (_filter == 'premium' && isPrem)
          || (_filter == 'free'    && !isPrem);
      return matchSearch && matchFilter;
    }).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, isMobile ? 68 : 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageTitle(icon: Icons.people_alt_rounded,
              title: 'Users', subtitle: '${widget.docs.length} total users'),
          const SizedBox(height: 20),

          // Search bar + filter chips (wrap on mobile)
          isMobile
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  TextField(
                    onChanged: (v) => setState(() => _search = v.toLowerCase()),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search by name or email...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.search, color: Colors.white38),
                      filled: true, fillColor: kPanel.withOpacity(0.72),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: kAccent.withOpacity(0.2))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: kAccent.withOpacity(0.2))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: kAccent)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _FilterChip(label: 'All',     selected: _filter == 'all',
                        onTap: () => setState(() => _filter = 'all')),
                    _FilterChip(label: 'Free',    selected: _filter == 'free',    color: kPurple,
                        onTap: () => setState(() => _filter = 'free')),
                    _FilterChip(label: 'Premium', selected: _filter == 'premium', color: kAccent,
                        onTap: () => setState(() => _filter = 'premium')),
                  ]),
                ])
              : Row(children: [
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v.toLowerCase()),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search by name or email...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(Icons.search, color: Colors.white38),
                        filled: true, fillColor: kPanel.withOpacity(0.72),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: kAccent.withOpacity(0.2))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: kAccent.withOpacity(0.2))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: kAccent)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _FilterChip(label: 'All',     selected: _filter == 'all',
                      onTap: () => setState(() => _filter = 'all')),
                  const SizedBox(width: 8),
                  _FilterChip(label: 'Free',    selected: _filter == 'free',    color: kPurple,
                      onTap: () => setState(() => _filter = 'free')),
                  const SizedBox(width: 8),
                  _FilterChip(label: 'Premium', selected: _filter == 'premium', color: kAccent,
                      onTap: () => setState(() => _filter = 'premium')),
                ]),

          const SizedBox(height: 20),

          if (filtered.isEmpty)
            _GlassPanel(child: const Center(child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('No users found.', style: TextStyle(color: Colors.white60)))))
          else
            _GlassPanel(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (int i = 0; i < filtered.length; i++) ...[
                  if (i != 0) Divider(color: Colors.white.withOpacity(0.06), height: 1),
                  _UserRowEditable(
                    doc:      filtered[i],
                    onDelete: () => _deleteUser(filtered[i].id),
                    onEdit:   () => _editSubscription(
                      filtered[i].id,
                      _isPremium(filtered[i].data()) ? 'premium' : 'free',
                    ),
                  ),
                ],
              ]),
            ),
        ],
      ),
    );
  }
}

class _UserRowEditable extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final VoidCallback onDelete, onEdit;

  const _UserRowEditable({required this.doc, required this.onDelete, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final data   = doc.data();
    final name   = data['name']  ?? 'No name';
    final email  = data['email'] ?? 'No email';
    final isPrem = _isPremium(data);
    final plan   = isPrem ? 'premium' : 'free';
    final color  = isPrem ? kAccent : kPurple;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        CircleAvatar(
          backgroundColor: color.withOpacity(0.18),
          child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(email, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color)),
          child: Text(plan, style: TextStyle(color: color, fontSize: 12)),
        ),
        const SizedBox(width: 8),
        IconButton(icon: const Icon(Icons.edit_rounded,   size: 18),
            color: kBlue, tooltip: 'Edit subscription', onPressed: onEdit),
        IconButton(icon: const Icon(Icons.delete_rounded, size: 18),
            color: Colors.redAccent, tooltip: 'Delete user', onPressed: onDelete),
      ]),
    );
  }
}

class _PlanOption extends StatelessWidget {
  final String label; final bool selected; final Color color; final VoidCallback onTap;
  const _PlanOption({required this.label, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : Colors.white12),
        ),
        child: Row(children: [
          Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: selected ? color : Colors.white38, size: 18),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(
            color:      selected ? color : Colors.white70,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          )),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PAGE: PREMIUM
// ═══════════════════════════════════════════════════════════════════
class PremiumPage extends StatelessWidget {
  final _AppStats stats;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  const PremiumPage({super.key, required this.stats, required this.docs});

  @override
  Widget build(BuildContext context) {
    final isMobile  = MediaQuery.of(context).size.width < 800;
    final premiumDocs = docs.where((d) => _isPremium(d.data())).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, isMobile ? 68 : 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageTitle(icon: Icons.workspace_premium_rounded,
              title: 'Premium', subtitle: '${stats.premium} premium subscribers'),
          const SizedBox(height: 20),

          LayoutBuilder(builder: (ctx, constraints) {
            final cols = constraints.maxWidth > 700 ? 3 : 1;
            return GridView.count(
              crossAxisCount: cols, shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.5,
              children: [
                _StatCard(title: 'Premium Users',    value: '${stats.premium}',
                    icon: Icons.diamond_rounded,
                    subtitle: '${(stats.premiumPercent * 100).toStringAsFixed(1)}% of total',
                    iconColor: kAccent),
                _StatCard(title: 'Price / User',     value: '₱$kPremiumPrice',
                    icon: Icons.sell_rounded,         subtitle: 'Per month', iconColor: kBlue),
                _StatCard(title: 'Verified Revenue', value: '₱${stats.verifiedRevenue}',
                    icon: Icons.account_balance_wallet_rounded,
                    subtitle: '₱${stats.pendingRevenue} pending', iconColor: kPurple),
              ],
            );
          }),

          const SizedBox(height: 18),

          _GlassPanel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _SectionTitle(icon: Icons.trending_up_rounded, title: 'Conversion Rate'),
              const SizedBox(height: 16),
              Text('${(stats.premiumPercent * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: kAccent)),
              const Text('Free → Premium conversion',
                  style: TextStyle(color: Colors.white54)),
              const SizedBox(height: 16),
              ClipRRect(borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(value: stats.premiumPercent,
                      minHeight: 14, backgroundColor: Colors.white12, color: kAccent)),
            ]),
          ),

          const SizedBox(height: 18),

          _GlassPanel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _SectionTitle(icon: Icons.diamond_rounded, title: 'Premium Subscribers'),
              const SizedBox(height: 12),
              if (premiumDocs.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No premium users yet.', style: TextStyle(color: Colors.white60)))
              else
                for (final user in premiumDocs)
                  _UserTile(
                    name:  user.data()['name']  ?? 'No name',
                    email: user.data()['email'] ?? 'No email',
                    plan:  'premium', color: kAccent,
                  ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PAGE: ANALYTICS
// ═══════════════════════════════════════════════════════════════════
class AnalyticsPage extends StatelessWidget {
  final _AppStats stats;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> paymentDocs;

  const AnalyticsPage({super.key, required this.stats, required this.docs, required this.paymentDocs});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, isMobile ? 68 : 24, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageTitle(icon: Icons.analytics_rounded,
              title: 'Analytics', subtitle: 'Real-time stats from Firestore'),
          const SizedBox(height: 20),

          LayoutBuilder(builder: (ctx, constraints) {
            final cols = constraints.maxWidth > 700 ? 2 : 1;
            return GridView.count(
              crossAxisCount: cols, shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 2,
              children: [
                _KpiCard(
                  title: 'Avg Revenue Per User',
                  value: stats.total == 0 ? '₱0'
                      : '₱${(stats.verifiedRevenue / stats.total).toStringAsFixed(2)}',
                  icon: Icons.person_rounded, color: kAccent,
                ),
                _KpiCard(
                  title: 'Free-to-Premium Ratio',
                  value: stats.premium == 0 ? 'N/A'
                      : '${(stats.free / stats.premium).toStringAsFixed(1)}x',
                  icon: Icons.compare_arrows_rounded, color: kBlue,
                ),
                _KpiCard(
                  title: 'Payment Approval Rate',
                  value: stats.totalPayments == 0 ? 'N/A'
                      : '${((stats.verifiedCount / stats.totalPayments) * 100).toStringAsFixed(1)}%',
                  icon: Icons.check_circle_rounded, color: kGreen,
                ),
                _KpiCard(
                  title: 'Pending Revenue',
                  value: '₱${stats.pendingRevenue}',
                  icon: Icons.hourglass_empty_rounded, color: kGold,
                ),
              ],
            );
          }),

          const SizedBox(height: 18),

          _GlassPanel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _SectionTitle(icon: Icons.donut_large_rounded, title: 'User Breakdown'),
              const SizedBox(height: 20),
              SizedBox(height: 160,
                  child: CustomPaint(
                    painter: _DonutPainter(
                        freeRatio: stats.freePercent, premiumRatio: stats.premiumPercent),
                    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('${stats.total}', style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                      const Text('users', style: TextStyle(color: Colors.white54)),
                    ])),
                  )),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _Legend(color: kPurple, label: 'Free (${stats.free})'),
                const SizedBox(width: 24),
                _Legend(color: kAccent,  label: 'Premium (${stats.premium})'),
              ]),
            ]),
          ),

          const SizedBox(height: 18),

          _GlassPanel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _SectionTitle(icon: Icons.show_chart_rounded, title: 'Revenue Trend'),
              const SizedBox(height: 8),
              const Text('Simulated monthly trend based on current premium count',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 16),
              SizedBox(height: 120, width: double.infinity,
                  child: CustomPaint(painter: _LineChartPainter(premiumCount: stats.premium))),
            ]),
          ),

          const SizedBox(height: 18),

          _GlassPanel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _SectionTitle(icon: Icons.table_chart_rounded, title: 'Summary'),
              const SizedBox(height: 16),
              _SummaryRow(label: 'Total Users',       value: '${stats.total}'),
              _SummaryRow(label: 'Free Users',        value: '${stats.free}'),
              _SummaryRow(label: 'Premium Users',     value: '${stats.premium}'),
              _SummaryRow(label: 'Total Payments',    value: '${stats.totalPayments}'),
              _SummaryRow(label: 'Pending Payments',  value: '${stats.pendingCount}'),
              _SummaryRow(label: 'Verified Payments', value: '${stats.verifiedCount}'),
              _SummaryRow(label: 'Pending Revenue',   value: '₱${stats.pendingRevenue}'),
              _SummaryRow(label: 'Verified Revenue',  value: '₱${stats.verifiedRevenue}', highlight: true),
            ]),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────
class _PageTitle extends StatelessWidget {
  final IconData icon; final String title, subtitle;
  const _PageTitle({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(height: 48, width: 48,
          decoration: BoxDecoration(color: kAccent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: kAccent)),
      const SizedBox(width: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 13)),
      ]),
    ]);
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _GlassPanel({required this.child, this.padding = const EdgeInsets.all(18)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, padding: padding,
      decoration: BoxDecoration(
        color: kPanel.withOpacity(0.72),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kAccent.withOpacity(0.2)),
      ),
      child: child,
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title, value, subtitle; final IconData icon; final Color iconColor;
  const _StatCard({required this.title, required this.value, required this.subtitle,
      required this.icon, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CircleAvatar(backgroundColor: iconColor.withOpacity(0.18), child: Icon(icon, color: iconColor)),
      const Spacer(),
      Text(title,   style: const TextStyle(color: Colors.white70)),
      const SizedBox(height: 6),
      Text(value,   style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white)),
      const SizedBox(height: 4),
      Text(subtitle, style: TextStyle(color: iconColor, fontSize: 12)),
    ]));
  }
}

class _KpiCard extends StatelessWidget {
  final String title, value; final IconData icon; final Color color;
  const _KpiCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(child: Row(children: [
      Container(height: 48, width: 48,
          decoration: BoxDecoration(color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: color)),
      const SizedBox(width: 16),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
      ]),
    ]));
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon; final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: kAccent, size: 20),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
    ]);
  }
}

class _ProgressRow extends StatelessWidget {
  final String label; final int count; final double percent; final Color color;
  const _ProgressRow({required this.label, required this.count,
      required this.percent, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(label, style: const TextStyle(color: Colors.white70))),
        Text('$count users', style: const TextStyle(color: Colors.white54)),
      ]),
      const SizedBox(height: 8),
      ClipRRect(borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(value: percent,
              minHeight: 12, backgroundColor: Colors.white12, color: color)),
    ]);
  }
}

class _UserTile extends StatelessWidget {
  final String name, email, plan; final Color color;
  const _UserTile({required this.name, required this.email,
      required this.plan, required this.color});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.18),
        child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ),
      title:    Text(name,  style: const TextStyle(color: Colors.white)),
      subtitle: Text(email, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color)),
        child: Text(plan, style: TextStyle(color: color, fontSize: 12)),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label; final bool selected; final VoidCallback onTap; final Color color;
  const _FilterChip({required this.label, required this.selected,
      required this.onTap, this.color = kAccent});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Colors.white24),
        ),
        child: Text(label, style: TextStyle(
          color:      selected ? color : Colors.white54,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          fontSize:   13,
        )),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label, value; final bool highlight;
  const _SummaryRow({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(
          color:      highlight ? Colors.white : Colors.white60,
          fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
        ))),
        Text(value, style: TextStyle(
          color:      highlight ? kAccent : Colors.white,
          fontWeight: FontWeight.bold,
          fontSize:   highlight ? 18 : 14,
        )),
      ]),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color; final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 12, height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
    ]);
  }
}

// ─────────────────────────────────────────────
// ERROR / LOADING
// ─────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String error;
  const _ErrorView({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
      const SizedBox(height: 12),
      Text('Error: $error', style: const TextStyle(color: Colors.white70)),
    ]));
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: kAccent));
}

// ─────────────────────────────────────────────
// PAINTERS
// ─────────────────────────────────────────────
class _LineChartPainter extends CustomPainter {
  final int premiumCount;
  const _LineChartPainter({this.premiumCount = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()..color = kAccent..strokeWidth = 2.5..style = PaintingStyle.stroke;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [kAccent.withOpacity(0.3), kAccent.withOpacity(0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    const values = [0.1, 0.2, 0.3, 0.35, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0];
    final points = List.generate(values.length, (i) =>
        Offset(size.width * i / (values.length - 1), size.height * (1 - values[i])));

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) path.lineTo(p.dx, p.dy);

    final fillPath = Path.from(path)..lineTo(size.width, size.height)..lineTo(0, size.height)..close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = kAccent;
    for (final p in points) canvas.drawCircle(p, 3.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _DonutPainter extends CustomPainter {
  final double freeRatio, premiumRatio;
  const _DonutPainter({required this.freeRatio, required this.premiumRatio});

  @override
  void paint(Canvas canvas, Size size) {
    final center      = Offset(size.width / 2, size.height / 2);
    final radius      = size.height / 2 - 10;
    const strokeWidth = 22.0;

    canvas.drawCircle(center, radius, Paint()
      ..color = Colors.white12..style = PaintingStyle.stroke..strokeWidth = strokeWidth);

    const startAngle  = -3.14159 / 2;
    const fullCircle  = 2 * 3.14159;

    if (premiumRatio > 0) {
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
          startAngle, fullCircle * premiumRatio, false,
          Paint()..color = kAccent..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth..strokeCap = StrokeCap.round);
    }
    if (freeRatio > 0) {
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
          startAngle + fullCircle * premiumRatio, fullCircle * freeRatio, false,
          Paint()..color = kPurple..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.freeRatio != freeRatio || old.premiumRatio != premiumRatio;
}
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
const kBg = Color(0xFF020C12);
const kPanel = Color(0xFF0B2E39);
const kSidebar = Color(0xFF081920);
const kAccent = Color(0xFF00E6C3);
const kPurple = Color(0xFF9B6DFF);
const kBlue = Color(0xFF2D9CFF);
const kPremiumPrice = 99;

// ─────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────
bool _isPremium(Map<String, dynamic> data) {
  final sub = (data['subscription'] ?? '').toString().toLowerCase().trim();
  return sub == 'premium';
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
// SHELL — holds page state + sidebar
// ─────────────────────────────────────────────
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0;

  static const _navItems = [
    _NavItem(Icons.dashboard_rounded, 'Dashboard'),
    _NavItem(Icons.people_alt_rounded, 'Users'),
    _NavItem(Icons.workspace_premium_rounded, 'Premium'),
    _NavItem(Icons.analytics_rounded, 'Analytics'),
  ];

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 800;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final stats = _AppStats.from(docs);

        final pages = [
          DashboardPage(stats: stats, docs: docs),
          UsersPage(docs: docs),
          PremiumPage(stats: stats, docs: docs),
          AnalyticsPage(stats: stats, docs: docs),
        ];

        return Scaffold(
          backgroundColor: kBg,
          drawer: isMobile
              ? Drawer(
                  backgroundColor: kSidebar,
                  child: SafeArea(
                    child: _SidebarContent(
                      selectedIndex: _selectedIndex,
                      navItems: _navItems,
                      onSelect: (i) {
                        setState(() => _selectedIndex = i);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                )
              : null,
          body: SafeArea(
            child: Row(
              children: [
                if (!isMobile)
                  _SidebarContent(
                    selectedIndex: _selectedIndex,
                    navItems: _navItems,
                    onSelect: (i) => setState(() => _selectedIndex = i),
                  ),
                Expanded(
                  child: snapshot.hasError
                      ? _ErrorView(error: snapshot.error.toString())
                      : snapshot.connectionState == ConnectionState.waiting
                          ? const _LoadingView()
                          : pages[_selectedIndex],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// STATS MODEL
// ─────────────────────────────────────────────
class _AppStats {
  final int total, free, premium, income;

  _AppStats({
    required this.total,
    required this.free,
    required this.premium,
    required this.income,
  });

  factory _AppStats.from(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final total = docs.length;
    // FIX: count premium using helper; everyone else is free
    final premium = docs.where((d) => _isPremium(d.data())).length;
    final free = total - premium;
    return _AppStats(
      total: total,
      free: free,
      premium: premium,
      income: premium * kPremiumPrice,
    );
  }

  double get freePercent => total == 0 ? 0 : free / total;
  double get premiumPercent => total == 0 ? 0 : premium / total;
}

// ─────────────────────────────────────────────
// SIDEBAR
// ─────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem(this.icon, this.label);
}

class _SidebarContent extends StatelessWidget {
  final int selectedIndex;
  final List<_NavItem> navItems;
  final ValueChanged<int> onSelect;

  const _SidebarContent({
    required this.selectedIndex,
    required this.navItems,
    required this.onSelect,
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
            child: Text(
              'CleftTune',
              style: TextStyle(
                color: kAccent,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Text(
              'Admin Panel',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
          const SizedBox(height: 36),
          for (int i = 0; i < navItems.length; i++) ...[
            _SidebarTile(
              icon: navItems[i].icon,
              label: navItems[i].label,
              selected: selectedIndex == i,
              onTap: () => onSelect(i),
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
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
              Icon(icon,
                  color: selected ? kAccent : Colors.white38, size: 20),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: selected ? kAccent : Colors.white60,
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (selected) ...[
                const Spacer(),
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: kAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PAGE: DASHBOARD
// ─────────────────────────────────────────────
class DashboardPage extends StatelessWidget {
  final _AppStats stats;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  const DashboardPage({super.key, required this.stats, required this.docs});

  /// Sort docs by createdAt descending, fall back to Firestore order.
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
    final w = MediaQuery.of(context).size.width;
    // FIX: show 5 most recently created users
    final recentUsers = _sortedByRecent().take(5).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: w < 600 ? 12 : 24,
        vertical: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(mobile: w < 800),
          const SizedBox(height: 24),

          // Stat Cards
          LayoutBuilder(builder: (context, constraints) {
            int cols = 1;
            if (constraints.maxWidth > 1200) cols = 4;
            else if (constraints.maxWidth > 700) cols = 2;

            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.25,
              children: [
                _StatCard(
                  title: 'Total Users',
                  value: '${stats.total}',
                  icon: Icons.people_alt_rounded,
                  subtitle: 'All registered users',
                  iconColor: kAccent,
                ),
                _StatCard(
                  title: 'Free Users',
                  value: '${stats.free}',
                  icon: Icons.star_rounded,
                  subtitle:
                      '${(stats.freePercent * 100).toStringAsFixed(1)}%',
                  iconColor: kPurple,
                ),
                _StatCard(
                  title: 'Premium Users',
                  value: '${stats.premium}',
                  icon: Icons.diamond_rounded,
                  subtitle:
                      '${(stats.premiumPercent * 100).toStringAsFixed(1)}%',
                  iconColor: kBlue,
                ),
                _StatCard(
                  title: 'Income',
                  value: '₱${stats.income}',
                  icon: Icons.account_balance_wallet_rounded,
                  subtitle: 'Premium × ₱$kPremiumPrice',
                  iconColor: kAccent,
                ),
              ],
            );
          }),

          const SizedBox(height: 18),

          // Subscription Overview
          _GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle(
                  icon: Icons.pie_chart_rounded,
                  title: 'Subscription Overview',
                ),
                const SizedBox(height: 18),
                _ProgressRow(
                  label: 'Free Users',
                  count: stats.free,
                  percent: stats.freePercent,
                  color: kPurple,
                ),
                const SizedBox(height: 18),
                _ProgressRow(
                  label: 'Premium Users',
                  count: stats.premium,
                  percent: stats.premiumPercent,
                  color: kAccent,
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Income Overview
          _GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle(
                  icon: Icons.analytics_rounded,
                  title: 'Income Overview',
                ),
                const SizedBox(height: 14),
                Text(
                  '₱${stats.income}',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Estimated premium revenue',
                  style: TextStyle(color: Colors.white60),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 100,
                  width: double.infinity,
                  child: CustomPaint(
                      painter: _LineChartPainter(
                          premiumCount: stats.premium)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Recent Users
          _GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle(
                  icon: Icons.group_rounded,
                  title: 'Recent Users',
                ),
                const SizedBox(height: 12),
                if (recentUsers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No users found.',
                        style: TextStyle(color: Colors.white60)),
                  ),
                for (final user in recentUsers)
                  _UserTile(
                    name: user.data()['name'] ?? 'No name',
                    email: user.data()['email'] ?? 'No email',
                    plan: _isPremium(user.data()) ? 'premium' : 'free',
                    color: _isPremium(user.data()) ? kAccent : kPurple,
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Center(
            child: Text(
              '© 2026 CleftTune Admin',
              style: TextStyle(color: Colors.white38),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PAGE: USERS
// ─────────────────────────────────────────────
class UsersPage extends StatefulWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  const UsersPage({super.key, required this.docs});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  String _search = '';
  String _filter = 'all'; // all, free, premium

  Future<void> _deleteUser(String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kPanel,
        title:
            const Text('Delete User', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this user? This cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(docId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User deleted.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _editSubscription(
    String docId,
    String currentPlan,
  ) async {
    String newPlan = currentPlan;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kPanel,
        title: const Text('Edit Subscription',
            style: TextStyle(color: Colors.white)),
        content: StatefulBuilder(
          builder: (context, setInner) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PlanOption(
                label: 'Free',
                selected: newPlan == 'free',
                color: kPurple,
                onTap: () => setInner(() => newPlan = 'free'),
              ),
              const SizedBox(height: 12),
              _PlanOption(
                label: 'Premium',
                selected: newPlan == 'premium',
                color: kAccent,
                onTap: () => setInner(() => newPlan = 'premium'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kAccent),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(docId)
                  .update({'subscription': newPlan});
              if (mounted) Navigator.pop(context);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Subscription updated to $newPlan.'),
                    backgroundColor: kAccent.withOpacity(0.8),
                  ),
                );
              }
            },
            child:
                const Text('Save', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.docs.where((doc) {
      final data = doc.data();
      final name = (data['name'] ?? '').toString().toLowerCase();
      final email = (data['email'] ?? '').toString().toLowerCase();
      final isPrem = _isPremium(data);

      final matchSearch =
          _search.isEmpty || name.contains(_search) || email.contains(_search);

      // FIX: filter using _isPremium helper so missing/null fields work correctly
      final matchFilter = _filter == 'all' ||
          (_filter == 'premium' && isPrem) ||
          (_filter == 'free' && !isPrem);

      return matchSearch && matchFilter;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageTitle(
            icon: Icons.people_alt_rounded,
            title: 'Users',
            subtitle: '${widget.docs.length} total users',
          ),
          const SizedBox(height: 20),

          // Search & Filter
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) =>
                      setState(() => _search = v.toLowerCase()),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search by name or email...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon:
                        const Icon(Icons.search, color: Colors.white38),
                    filled: true,
                    fillColor: kPanel.withOpacity(0.72),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: kAccent.withOpacity(0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: kAccent.withOpacity(0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: kAccent),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _FilterChip(
                  label: 'All',
                  selected: _filter == 'all',
                  onTap: () => setState(() => _filter = 'all')),
              const SizedBox(width: 8),
              _FilterChip(
                  label: 'Free',
                  selected: _filter == 'free',
                  onTap: () => setState(() => _filter = 'free'),
                  color: kPurple),
              const SizedBox(width: 8),
              _FilterChip(
                  label: 'Premium',
                  selected: _filter == 'premium',
                  onTap: () => setState(() => _filter = 'premium'),
                  color: kAccent),
            ],
          ),

          const SizedBox(height: 20),

          if (filtered.isEmpty)
            _GlassPanel(
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No users found.',
                      style: TextStyle(color: Colors.white60)),
                ),
              ),
            )
          else
            _GlassPanel(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (int i = 0; i < filtered.length; i++) ...[
                    if (i != 0)
                      Divider(
                          color: Colors.white.withOpacity(0.06), height: 1),
                    _UserRowEditable(
                      doc: filtered[i],
                      onDelete: () => _deleteUser(filtered[i].id),
                      onEdit: () => _editSubscription(
                        filtered[i].id,
                        // FIX: pass normalized plan string
                        _isPremium(filtered[i].data()) ? 'premium' : 'free',
                      ),
                    ),
                  ]
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _UserRowEditable extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _UserRowEditable({
    required this.doc,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final name = data['name'] ?? 'No name';
    final email = data['email'] ?? 'No email';
    // FIX: use helper for consistent plan display
    final isPrem = _isPremium(data);
    final plan = isPrem ? 'premium' : 'free';
    final color = isPrem ? kAccent : kPurple;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.18),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(email,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color),
            ),
            child:
                Text(plan, style: TextStyle(color: color, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 18),
            color: kBlue,
            tooltip: 'Edit subscription',
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_rounded, size: 18),
            color: Colors.redAccent,
            tooltip: 'Delete user',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _PlanOption extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _PlanOption({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(0.15)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : Colors.white12),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? color : Colors.white38,
              size: 18,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : Colors.white70,
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PAGE: PREMIUM
// ─────────────────────────────────────────────
class PremiumPage extends StatelessWidget {
  final _AppStats stats;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  const PremiumPage(
      {super.key, required this.stats, required this.docs});

  @override
  Widget build(BuildContext context) {
    // FIX: use helper so recently upgraded users appear immediately
    final premiumDocs =
        docs.where((d) => _isPremium(d.data())).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageTitle(
            icon: Icons.workspace_premium_rounded,
            title: 'Premium',
            subtitle: '${stats.premium} premium subscribers',
          ),
          const SizedBox(height: 20),

          // Revenue summary cards
          LayoutBuilder(builder: (ctx, constraints) {
            final cols = constraints.maxWidth > 700 ? 3 : 1;
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _StatCard(
                  title: 'Premium Users',
                  value: '${stats.premium}',
                  icon: Icons.diamond_rounded,
                  subtitle:
                      '${(stats.premiumPercent * 100).toStringAsFixed(1)}% of total',
                  iconColor: kAccent,
                ),
                _StatCard(
                  title: 'Price / User',
                  value: '₱$kPremiumPrice',
                  icon: Icons.sell_rounded,
                  subtitle: 'Per month',
                  iconColor: kBlue,
                ),
                _StatCard(
                  title: 'Total Revenue',
                  value: '₱${stats.income}',
                  icon: Icons.account_balance_wallet_rounded,
                  subtitle: 'Premium × ₱$kPremiumPrice',
                  iconColor: kPurple,
                ),
              ],
            );
          }),

          const SizedBox(height: 18),

          // Conversion bar
          _GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle(
                  icon: Icons.trending_up_rounded,
                  title: 'Conversion Rate',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${(stats.premiumPercent * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: kAccent,
                            ),
                          ),
                          const Text(
                            'Free → Premium conversion',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: stats.premiumPercent,
                    minHeight: 14,
                    backgroundColor: Colors.white12,
                    color: kAccent,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Premium users list
          _GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle(
                  icon: Icons.diamond_rounded,
                  title: 'Premium Subscribers',
                ),
                const SizedBox(height: 12),
                if (premiumDocs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No premium users yet.',
                        style: TextStyle(color: Colors.white60)),
                  )
                else
                  for (final user in premiumDocs)
                    _UserTile(
                      name: user.data()['name'] ?? 'No name',
                      email: user.data()['email'] ?? 'No email',
                      plan: 'premium',
                      color: kAccent,
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PAGE: ANALYTICS
// ─────────────────────────────────────────────
class AnalyticsPage extends StatelessWidget {
  final _AppStats stats;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;

  const AnalyticsPage(
      {super.key, required this.stats, required this.docs});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PageTitle(
            icon: Icons.analytics_rounded,
            title: 'Analytics',
            subtitle: 'Real-time stats from Firestore',
          ),
          const SizedBox(height: 20),

          // KPI row
          LayoutBuilder(builder: (ctx, constraints) {
            final cols = constraints.maxWidth > 700 ? 2 : 1;
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2,
              children: [
                _KpiCard(
                  title: 'Avg Revenue Per User',
                  value: stats.total == 0
                      ? '₱0'
                      : '₱${(stats.income / stats.total).toStringAsFixed(2)}',
                  icon: Icons.person_rounded,
                  color: kAccent,
                ),
                _KpiCard(
                  title: 'Free-to-Premium Ratio',
                  value: stats.premium == 0
                      ? 'N/A'
                      : '${(stats.free / stats.premium).toStringAsFixed(1)}x',
                  icon: Icons.compare_arrows_rounded,
                  color: kBlue,
                ),
              ],
            );
          }),

          const SizedBox(height: 18),

          // Subscription breakdown
          _GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle(
                  icon: Icons.donut_large_rounded,
                  title: 'User Breakdown',
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 160,
                  child: CustomPaint(
                    painter: _DonutPainter(
                      freeRatio: stats.freePercent,
                      premiumRatio: stats.premiumPercent,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${stats.total}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const Text('users',
                              style:
                                  TextStyle(color: Colors.white54)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Legend(
                        color: kPurple,
                        label: 'Free (${stats.free})'),
                    const SizedBox(width: 24),
                    _Legend(
                        color: kAccent,
                        label: 'Premium (${stats.premium})'),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Revenue chart
          _GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle(
                  icon: Icons.show_chart_rounded,
                  title: 'Revenue Trend',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Simulated monthly trend based on current premium count',
                  style:
                      TextStyle(color: Colors.white38, fontSize: 12),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _LineChartPainter(
                        premiumCount: stats.premium),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Summary table
          _GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle(
                  icon: Icons.table_chart_rounded,
                  title: 'Summary',
                ),
                const SizedBox(height: 16),
                _SummaryRow(
                    label: 'Total Users', value: '${stats.total}'),
                _SummaryRow(
                    label: 'Free Users', value: '${stats.free}'),
                _SummaryRow(
                    label: 'Premium Users',
                    value: '${stats.premium}'),
                _SummaryRow(
                    label: 'Premium Price',
                    value: '₱$kPremiumPrice'),
                _SummaryRow(
                  label: 'Total Revenue',
                  value: '₱${stats.income}',
                  highlight: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────

class _Header extends StatelessWidget {
  final bool mobile;
  const _Header({required this.mobile});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (mobile)
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
        Container(
          height: 50,
          width: 50,
          decoration: BoxDecoration(
            color: kAccent.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.admin_panel_settings_rounded,
              color: kAccent),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CleftTune Admin',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 2),
              Text('Realtime database overview',
                  style: TextStyle(color: Colors.white60)),
            ],
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ],
    );
  }
}

class _PageTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PageTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: kAccent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: kAccent),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            Text(subtitle,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 13)),
          ],
        ),
      ],
    );
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
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
  final String title, value, subtitle;
  final IconData icon;
  final Color iconColor;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: iconColor.withOpacity(0.18),
            child: Icon(icon, color: iconColor),
          ),
          const Spacer(),
          Text(title,
              style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: TextStyle(color: iconColor, fontSize: 12)),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 12)),
              const SizedBox(height: 4),
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: kAccent, size: 20),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
      ],
    );
  }
}

class _ProgressRow extends StatelessWidget {
  final String label;
  final int count;
  final double percent;
  final Color color;

  const _ProgressRow({
    required this.label,
    required this.count,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
                child: Text(label,
                    style:
                        const TextStyle(color: Colors.white70))),
            Text('$count users',
                style: const TextStyle(color: Colors.white54)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 12,
            backgroundColor: Colors.white12,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _UserTile extends StatelessWidget {
  final String name, email, plan;
  final Color color;

  const _UserTile({
    required this.name,
    required this.email,
    required this.plan,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.18),
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style:
              TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ),
      title:
          Text(name, style: const TextStyle(color: Colors.white)),
      subtitle: Text(email,
          style:
              const TextStyle(color: Colors.white54, fontSize: 12)),
      trailing: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color),
        ),
        child:
            Text(plan, style: TextStyle(color: color, fontSize: 12)),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = kAccent,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.white24,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : Colors.white54,
            fontWeight:
                selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label, value;
  final bool highlight;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: highlight ? Colors.white : Colors.white60,
                fontWeight: highlight
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: highlight ? kAccent : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: highlight ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                color: Colors.white60, fontSize: 13)),
      ],
    );
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.redAccent, size: 48),
          const SizedBox(height: 12),
          Text('Error: $error',
              style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: kAccent),
    );
  }
}

// ─────────────────────────────────────────────
// PAINTERS
// ─────────────────────────────────────────────

class _LineChartPainter extends CustomPainter {
  final int premiumCount;

  const _LineChartPainter({this.premiumCount = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = kAccent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [kAccent.withOpacity(0.3), kAccent.withOpacity(0)],
      ).createShader(
          Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final List<double> values = [
      0.1, 0.2, 0.3, 0.35, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0,
    ];

    final points = List.generate(values.length, (i) {
      return Offset(
        size.width * i / (values.length - 1),
        size.height * (1 - values[i]),
      );
    });

    final path = Path()
      ..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = kAccent;
    for (final p in points) {
      canvas.drawCircle(p, 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DonutPainter extends CustomPainter {
  final double freeRatio;
  final double premiumRatio;

  const _DonutPainter(
      {required this.freeRatio, required this.premiumRatio});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.height / 2 - 10;
    const strokeWidth = 22.0;

    final bgPaint = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, bgPaint);

    const startAngle = -3.14159 / 2;
    const fullCircle = 2 * 3.14159;

    if (premiumRatio > 0) {
      final premPaint = Paint()
        ..color = kAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        fullCircle * premiumRatio,
        false,
        premPaint,
      );
    }

    if (freeRatio > 0) {
      final freePaint = Paint()
        ..color = kPurple
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + fullCircle * premiumRatio,
        fullCircle * freeRatio,
        false,
        freePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.freeRatio != freeRatio || old.premiumRatio != premiumRatio;
}